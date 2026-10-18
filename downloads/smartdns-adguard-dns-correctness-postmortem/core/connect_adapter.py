#!/usr/bin/env python3
"""dns-care-managed: restricted CONNECT forwarding; TLS is never decrypted."""
import argparse
import json
import logging
import selectors
import socket
import socketserver
import threading
import time


def header(sock):
    data = bytearray()
    while b'\r\n\r\n' not in data:
        part = sock.recv(4096)
        if not part:
            raise OSError('HTTP peer closed')
        data.extend(part)
        if len(data) > 16384:
            raise ValueError('oversized HTTP header')
    head, tail = bytes(data).split(b'\r\n\r\n', 1)
    return head, tail


class Handler(socketserver.BaseRequestHandler):
    def reject(self, code):
        self.request.sendall(f'HTTP/1.1 {code} Rejected\r\nContent-Length: 0\r\n\r\n'.encode())

    def handle(self):
        if not self.server.slots.acquire(False):
            self.reject(503)
            return
        other, established = None, False
        try:
            self.request.settimeout(8)
            if self.client_address[0] not in self.server.settings['allowed_clients']:
                self.reject(403)
                return
            head, tail = header(self.request)
            method, target, version = head.split(b'\r\n', 1)[0].decode('ascii').split()
            dest = self.server.settings['endpoints'].get(target)
            if method != 'CONNECT' or version not in ('HTTP/1.0', 'HTTP/1.1') or not dest:
                self.reject(403)
                return
            other = socket.create_connection(tuple(self.server.settings['upstream']), timeout=6)
            other.sendall(f'CONNECT {dest} HTTP/1.1\r\nHost: {dest}\r\nProxy-Connection: Keep-Alive\r\n\r\n'.encode())
            response, extra = header(other)
            if response.split(b'\r\n', 1)[0].split()[1] != b'200':
                raise OSError('upstream proxy rejected CONNECT')
            self.request.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n' + extra)
            established = True
            if tail:
                other.sendall(tail)
            other.settimeout(10)
            self.request.settimeout(10)
            with selectors.DefaultSelector() as selector:
                selector.register(other, selectors.EVENT_READ, self.request)
                selector.register(self.request, selectors.EVENT_READ, other)
                last = time.monotonic()
                while time.monotonic() - last < 300:
                    for key, _ in selector.select(5):
                        data = key.fileobj.recv(65536)
                        if not data:
                            return
                        key.data.sendall(data)
                        last = time.monotonic()
        except (OSError, ValueError, IndexError) as exc:
            logging.warning('DoH CONNECT failed: %s', exc)
            if not established:
                try:
                    self.reject(502)
                except OSError:
                    pass
        finally:
            if other:
                other.close()
            self.server.slots.release()


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    request_queue_size = 64


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--settings', required=True)
    args = parser.parse_args()
    with open(args.settings) as file:
        settings = json.load(file)
    logging.basicConfig(level=logging.INFO)
    with Server((settings['bind'], settings['port']), Handler) as server:
        server.settings = settings
        server.slots = threading.BoundedSemaphore(64)
        server.serve_forever()
