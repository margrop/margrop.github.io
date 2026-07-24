#!/usr/bin/env python3
import base64
import json
import sys
import unittest
from pathlib import Path
from urllib.parse import parse_qs

from cryptography.hazmat.primitives import padding as symmetric_padding
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR))

from synology_login import SynologyEncryptor, synology_login  # noqa: E402


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self.payload


class FakeSession:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = []

    def post(self, url, **kwargs):
        self.calls.append((url, kwargs))
        return FakeResponse(next(self.responses))


class SynologyEncryptorTests(unittest.TestCase):
    def setUp(self):
        self.private_key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
        public_numbers = self.private_key.public_key().public_numbers()
        self.enc_info = {
            "cipherkey": "__cIpHeRtExT",
            "ciphertoken": "synotoken",
            "public_key": format(public_numbers.n, "x"),
            "server_time": 1777777777,
        }

    def test_pkcs7_padding_adds_a_full_block_for_aligned_input(self):
        encryptor = SynologyEncryptor(self.enc_info)

        padded = encryptor.pkcs7_pad(b"0123456789abcdef")

        self.assertEqual(len(padded), 32)
        self.assertEqual(padded[-16:], bytes([16]) * 16)

    def test_key_and_iv_derivation_matches_known_vector(self):
        key, iv = SynologyEncryptor.derive_key_and_iv(
            b"correct horse battery staple",
            bytes.fromhex("0102030405060708"),
        )

        self.assertEqual(
            key.hex(),
            "6f920a43e427bc52eb313ace899b93b1f97d81751def5647ebab3f3bb7d0f679",
        )
        self.assertEqual(iv.hex(), "e99863375e6eb096f347a8f7a07e8a27")

    def test_aes_envelope_uses_openssl_salted_prefix(self):
        encryptor = SynologyEncryptor(self.enc_info)

        encrypted = encryptor.encrypt_aes(
            b"A" * 64,
            "account=reader&session=DSM",
            salt=bytes.fromhex("0102030405060708"),
        )

        self.assertEqual(encrypted[:8], b"Salted__")
        self.assertEqual(encrypted[8:16], bytes.fromhex("0102030405060708"))
        self.assertEqual(len(encrypted) % 16, 0)

    def test_encrypt_params_uses_dynamic_cipher_fields(self):
        encryptor = SynologyEncryptor(
            self.enc_info,
            passphrase_factory=lambda length: b"B" * length,
            salt_factory=lambda length: b"12345678",
        )

        result = encryptor.encrypt_params(
            {
                "account": "reader@example",
                "passwd": "not-a-real-password",
                "session": "DSM",
                "format": "sid",
            }
        )

        self.assertEqual(list(result), ["__cIpHeRtExT"])
        envelope = json.loads(result["__cIpHeRtExT"])
        self.assertEqual(set(envelope), {"rsa", "aes"})

        passphrase = self.private_key.decrypt(
            base64.b64decode(envelope["rsa"]),
            padding.PKCS1v15(),
        )
        self.assertEqual(passphrase, b"B" * 501)

        encrypted_aes = base64.b64decode(envelope["aes"])
        salt = encrypted_aes[8:16]
        key, iv = SynologyEncryptor.derive_key_and_iv(passphrase, salt)
        decryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
        padded = decryptor.update(encrypted_aes[16:]) + decryptor.finalize()
        unpadder = symmetric_padding.PKCS7(128).unpadder()
        plaintext = unpadder.update(padded) + unpadder.finalize()
        params = parse_qs(plaintext.decode("utf-8"))
        self.assertEqual(params["account"], ["reader@example"])
        self.assertEqual(params["session"], ["DSM"])
        self.assertEqual(params["synotoken"], ["1777777777"])

    def test_invalid_encryption_info_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing encryption fields"):
            SynologyEncryptor({"cipherkey": "only-one-field"})

    def test_login_fetches_encryption_info_then_posts_dynamic_cipher_field(self):
        fake_session = FakeSession(
            [
                {"success": True, "data": self.enc_info},
                {"success": True, "data": {"sid": "temporary-session-id"}},
            ]
        )

        result = synology_login(
            "https://nas.example.test:5001/",
            "reader",
            "not-a-real-password",
            http_session=fake_session,
        )

        self.assertEqual(result.sid, "temporary-session-id")
        self.assertEqual(fake_session.calls[0][0], "https://nas.example.test:5001/webapi/encryption.cgi")
        self.assertEqual(fake_session.calls[1][0], "https://nas.example.test:5001/webapi/auth.cgi")
        login_data = fake_session.calls[1][1]["data"]
        self.assertEqual(login_data["api"], "SYNO.API.Auth")
        self.assertIn("__cIpHeRtExT", login_data)
        self.assertNotIn("passwd", login_data)


if __name__ == "__main__":
    unittest.main()
