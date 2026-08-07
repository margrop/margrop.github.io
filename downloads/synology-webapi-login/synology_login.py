#!/usr/bin/env python3
import argparse
import base64
import getpass
import hashlib
import json
import os
import secrets
import sys
import urllib.parse
from dataclasses import dataclass
from typing import Callable, Mapping

import requests
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


PASSPHRASE_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()_+-/"


class SynologyAPIError(RuntimeError):
    pass


class SynologyEncryptor:
    SALT_MAGIC = b"Salted__"
    AES_BLOCK_SIZE = 16
    PASSPHRASE_LENGTH = 501
    REQUIRED_FIELDS = {"cipherkey", "ciphertoken", "public_key", "server_time"}

    def __init__(
        self,
        enc_info: Mapping[str, object],
        passphrase_factory: Callable[[int], bytes] | None = None,
        salt_factory: Callable[[int], bytes] | None = None,
    ):
        missing = self.REQUIRED_FIELDS.difference(enc_info)
        if missing:
            raise ValueError(f"missing encryption fields: {', '.join(sorted(missing))}")

        self.cipher_key = str(enc_info["cipherkey"])
        self.cipher_token = str(enc_info["ciphertoken"])
        self.public_key_hex = str(enc_info["public_key"])
        self.server_time = str(enc_info["server_time"])
        self.passphrase_factory = passphrase_factory or self.random_passphrase
        self.salt_factory = salt_factory or secrets.token_bytes

    @staticmethod
    def random_passphrase(length: int) -> bytes:
        return "".join(secrets.choice(PASSPHRASE_ALPHABET) for _ in range(length)).encode("utf-8")

    @staticmethod
    def derive_key_and_iv(
        password: bytes,
        salt: bytes,
        key_length: int = 32,
        iv_length: int = 16,
    ) -> tuple[bytes, bytes]:
        derived = b""
        digest = b""
        while len(derived) < key_length + iv_length:
            digest = hashlib.md5(digest + password + salt).digest()
            derived += digest
        return derived[:key_length], derived[key_length:key_length + iv_length]

    @classmethod
    def pkcs7_pad(cls, data: bytes) -> bytes:
        padding_length = cls.AES_BLOCK_SIZE - (len(data) % cls.AES_BLOCK_SIZE)
        return data + bytes([padding_length]) * padding_length

    def encrypt_aes(self, passphrase: bytes, text: str, salt: bytes | None = None) -> bytes:
        actual_salt = salt if salt is not None else self.salt_factory(8)
        if len(actual_salt) != 8:
            raise ValueError("AES salt must be exactly 8 bytes")
        key, iv = self.derive_key_and_iv(passphrase, actual_salt)
        encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
        padded = self.pkcs7_pad(text.encode("utf-8"))
        ciphertext = encryptor.update(padded) + encryptor.finalize()
        return self.SALT_MAGIC + actual_salt + ciphertext

    def encrypt_rsa(self, passphrase: bytes) -> bytes:
        modulus = int(self.public_key_hex, 16)
        public_key = rsa.RSAPublicNumbers(65537, modulus).public_key()
        return public_key.encrypt(passphrase, padding.PKCS1v15())

    def encrypt_params(self, params: Mapping[str, object]) -> dict[str, str]:
        plaintext_params = {key: str(value) for key, value in params.items()}
        plaintext_params[self.cipher_token] = self.server_time
        passphrase = self.passphrase_factory(self.PASSPHRASE_LENGTH)
        if len(passphrase) != self.PASSPHRASE_LENGTH:
            raise ValueError(f"AES passphrase must be {self.PASSPHRASE_LENGTH} bytes")

        payload = {
            "rsa": base64.b64encode(self.encrypt_rsa(passphrase)).decode("ascii"),
            "aes": base64.b64encode(
                self.encrypt_aes(passphrase, urllib.parse.urlencode(plaintext_params))
            ).decode("ascii"),
        }
        return {self.cipher_key: json.dumps(payload, separators=(",", ":"))}


@dataclass(frozen=True)
class LoginResult:
    sid: str
    response: dict[str, object]


def synology_login(
    base_url: str,
    account: str,
    password: str,
    session_name: str = "DSM",
    verify_tls: bool = True,
    timeout: float = 15.0,
    http_session: requests.Session | None = None,
) -> LoginResult:
    session = http_session or requests.Session()
    normalized_base_url = base_url.rstrip("/")

    encryption_response = session.post(
        f"{normalized_base_url}/webapi/encryption.cgi",
        data={
            "api": "SYNO.API.Encryption",
            "version": 1,
            "method": "getinfo",
            "format": "module",
        },
        verify=verify_tls,
        timeout=timeout,
    )
    encryption_response.raise_for_status()
    encryption_json = encryption_response.json()
    if not encryption_json.get("success") or not isinstance(encryption_json.get("data"), dict):
        raise SynologyAPIError(f"encryption getinfo failed: {redact_response(encryption_json)}")

    encrypted_params = SynologyEncryptor(encryption_json["data"]).encrypt_params(
        {
            "account": account,
            "passwd": password,
            "session": session_name,
            "format": "sid",
        }
    )
    login_response = session.post(
        f"{normalized_base_url}/webapi/auth.cgi",
        data={
            "api": "SYNO.API.Auth",
            "version": 6,
            "method": "login",
            **encrypted_params,
        },
        verify=verify_tls,
        timeout=timeout,
    )
    login_response.raise_for_status()
    login_json = login_response.json()
    if not login_json.get("success") or not isinstance(login_json.get("data"), dict):
        raise SynologyAPIError(f"login failed: {redact_response(login_json)}")

    sid = str(login_json["data"].get("sid", ""))
    if not sid:
        raise SynologyAPIError("login succeeded without returning a SID")
    return LoginResult(sid=sid, response=login_json)


def redact_response(value: object) -> str:
    text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    for key in ("sid", "did", "token", "access_token", "cookie"):
        text = text.replace(f'"{key}":"', f'"{key}":"<redacted>')
    return text[:500]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Log in to an authorized Synology WebAPI using its hybrid RSA/AES request format."
    )
    parser.add_argument("--url", required=True, help="DSM base URL, for example https://nas.example.test:5001")
    parser.add_argument("--account", default=os.environ.get("SYNOLOGY_ACCOUNT"))
    parser.add_argument("--password-env", default="SYNOLOGY_PASSWORD")
    parser.add_argument("--session", default="DSM")
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--insecure", action="store_true", help="Disable TLS certificate verification")
    parser.add_argument("--show-sid", action="store_true", help="Print the SID; avoid in shared terminals or logs")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    account = args.account or input("Synology account: ").strip()
    password = os.environ.get(args.password_env) or getpass.getpass("Synology password: ")
    if not account or not password:
        print("Account and password are required.", file=sys.stderr)
        return 2
    if args.insecure:
        print("WARNING: TLS certificate verification is disabled.", file=sys.stderr)

    try:
        result = synology_login(
            base_url=args.url,
            account=account,
            password=password,
            session_name=args.session,
            verify_tls=not args.insecure,
            timeout=args.timeout,
        )
    except (requests.RequestException, ValueError, SynologyAPIError, json.JSONDecodeError) as error:
        print(f"Login failed: {error}", file=sys.stderr)
        return 1

    print("Login succeeded; a session identifier was returned.")
    if args.show_sid:
        print(result.sid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
