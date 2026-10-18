"""DNS wire probes using only the Python standard library."""
import ipaddress
import secrets
import socket
import struct
import time


def exact(sock, size):
    data = bytearray()
    while len(data) < size:
        part = sock.recv(size - len(data))
        if not part:
            raise OSError('short DNS TCP reply')
        data.extend(part)
    return bytes(data)


def decode(data, expected_id):
    ident, flags, nq, na, _, _ = struct.unpack('!HHHHHH', data[:12])
    if ident != expected_id or not flags & 0x8000:
        raise ValueError('DNS transaction mismatch')

    def name_at(offset):
        labels, end = [], None
        for _ in range(128):
            value = data[offset]
            if value & 0xc0 == 0xc0:
                if end is None:
                    end = offset + 2
                offset = ((value & 63) << 8) | data[offset + 1]
            elif value == 0:
                return '.'.join(labels), end if end is not None else offset + 1
            else:
                offset += 1
                labels.append(data[offset:offset + value].decode('ascii'))
                offset += value
        raise ValueError('DNS compression loop')

    pos = 12
    for _ in range(nq):
        _, pos = name_at(pos)
        pos += 4
    records = []
    for _ in range(na):
        owner, pos = name_at(pos)
        kind, cls, ttl, size = struct.unpack('!HHIH', data[pos:pos + 10])
        pos += 10
        start, raw = pos, data[pos:pos + size]
        pos += size
        if kind in (1, 28):
            value = str(ipaddress.ip_address(raw))
        elif kind == 5:
            value = name_at(start)[0]
        else:
            value = raw.hex()
        records.append({'name': owner, 'type': kind, 'ttl': ttl, 'data': value})
    return {'rcode': flags & 15, 'truncated': bool(flags & 0x200), 'answers': records}


def query(server, port, name, kind=1, tcp=False):
    ident = secrets.randbelow(65536)
    packet = struct.pack('!HHHHHH', ident, 0x100, 1, 0, 0, 0)
    packet += b''.join(bytes([len(label)]) + label.encode('ascii') for label in name.split('.'))
    packet += b'\0' + struct.pack('!HH', kind, 1)
    start = time.monotonic()
    family = socket.AF_INET6 if ipaddress.ip_address(server).version == 6 else socket.AF_INET
    with socket.socket(family, socket.SOCK_STREAM if tcp else socket.SOCK_DGRAM) as sock:
        sock.settimeout(6)
        sock.connect((server, port))
        if tcp:
            sock.sendall(struct.pack('!H', len(packet)) + packet)
            reply = exact(sock, struct.unpack('!H', exact(sock, 2))[0])
        else:
            sock.send(packet)
            reply = sock.recv(65535)
    result = decode(reply, ident)
    if result['truncated'] and not tcp:
        return query(server, port, name, kind, True)
    result['ms'] = round((time.monotonic() - start) * 1000, 1)
    return result
