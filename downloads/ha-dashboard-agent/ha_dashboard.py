#!/usr/bin/env python3
"""Build an additive, read-only HA dashboard using only Python's standard library.

Default: inspect and write a local plan. --apply: create a NEW storage dashboard.
Requires Python >= 3.11 and a Home Assistant administrator token.
No device service calls, entity deletion, dependency installation, or cloud API.
"""

from __future__ import annotations

import argparse
import base64
import collections
import datetime as dt
import getpass
import hashlib
import json
import os
import pathlib
import re
import secrets
import socket
import ssl
import struct
import sys
import urllib.parse
import urllib.request

MAX_MESSAGE = 32 * 1024 * 1024
DISPLAY_DOMAINS = {"sensor", "binary_sensor", "light", "climate", "fan", "cover", "weather"}


class HAError(Exception):
    """Safe error message, without response bodies or credentials."""


def write_private(path, value):
    raw = json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8")
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(raw)


class HomeAssistant:
    def __init__(self, url, token):
        self.base = url.rstrip("/")
        self.url = urllib.parse.urlsplit(self.base)
        if (self.url.scheme not in {"http", "https"} or not self.url.hostname
                or self.url.username or self.url.password or self.url.query or self.url.fragment):
            raise HAError("Use an http(s) base URL without credentials, query or fragment.")
        self.token = token
        self.sequence = 0
        self.socket = None
        # Access the HA endpoint directly; do not send its token to an environment proxy.
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def states(self):
        req = urllib.request.Request(self.base + "/api/states", headers={
            "Authorization": "Bearer " + self.token, "Accept": "application/json"})
        with self.http.open(req, timeout=30) as response:
            data = response.read(MAX_MESSAGE + 1)
        if len(data) > MAX_MESSAGE:
            raise HAError("State response exceeds the size limit.")
        return json.loads(data)

    def exact(self, size):
        chunks = bytearray()
        while len(chunks) < size:
            part = self.socket.recv(size - len(chunks))
            if not part:
                raise HAError("WebSocket connection closed.")
            chunks.extend(part)
        return bytes(chunks)

    def send_frame(self, payload, opcode=1):
        if len(payload) > MAX_MESSAGE:
            raise HAError("Outgoing WebSocket message is too large.")
        length = len(payload)
        header = bytes([0x80 | opcode])
        if length < 126:
            header += bytes([0x80 | length])
        elif length < 65536:
            header += bytes([0xFE]) + struct.pack("!H", length)
        else:
            header += bytes([0xFF]) + struct.pack("!Q", length)
        mask = secrets.token_bytes(4)
        encoded = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.socket.sendall(header + mask + encoded)

    def receive(self):
        collected = bytearray()
        while True:
            first, second = self.exact(2)
            opcode = first & 15
            if first & 0x70 or second & 0x80:
                raise HAError("Unsupported WebSocket frame.")
            length = second & 127
            if length == 126:
                length = struct.unpack("!H", self.exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self.exact(8))[0]
            if length + len(collected) > MAX_MESSAGE:
                raise HAError("Incoming WebSocket message is too large.")
            payload = self.exact(length)
            if opcode == 8:
                raise HAError("Home Assistant closed the WebSocket.")
            if opcode == 9:
                self.send_frame(payload, 10)
                continue
            if opcode == 10:
                continue
            if opcode not in {0, 1}:
                raise HAError("Expected a text WebSocket frame.")
            collected.extend(payload)
            if first & 0x80:
                return json.loads(collected)

    def connect(self):
        secure = self.url.scheme == "https"
        port = self.url.port or (443 if secure else 80)
        connection = socket.create_connection((self.url.hostname, port), timeout=30)
        self.socket = connection
        if secure:
            self.socket = ssl.create_default_context().wrap_socket(
                connection, server_hostname=self.url.hostname)
        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        path = self.url.path.rstrip("/") + "/api/websocket"
        request = (f"GET {path} HTTP/1.1\r\nHost: {self.url.netloc}\r\n"
                   "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                   f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
        self.socket.sendall(request.encode("ascii"))
        header = bytearray()
        while not header.endswith(b"\r\n\r\n"):
            if len(header) > 16384:
                raise HAError("Invalid WebSocket upgrade response.")
            header.extend(self.exact(1))
        lines = header.decode("iso-8859-1").split("\r\n")
        if len(lines[0].split()) < 2 or lines[0].split()[1] != "101":
            raise HAError("WebSocket upgrade rejected. Check the URL and reverse proxy.")
        fields = {name.lower(): value.strip() for name, value in
                  (line.split(":", 1) for line in lines[1:] if ":" in line)}
        expected = base64.b64encode(hashlib.sha1(
            (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        if fields.get("sec-websocket-accept", "") != expected:
            raise HAError("WebSocket handshake verification failed.")
        if self.receive().get("type") != "auth_required":
            raise HAError("Unexpected authentication handshake.")
        self.send_frame(json.dumps({"type": "auth", "access_token": self.token}).encode())
        if self.receive().get("type") != "auth_ok":
            raise HAError("Authentication failed. Check the HA administrator token.")

    def command(self, command, **values):
        self.sequence += 1
        ident = self.sequence
        self.send_frame(json.dumps(dict(id=ident, type=command, **values)).encode())
        while True:
            message = self.receive()
            if message.get("id") == ident and message.get("type") == "result":
                if not message.get("success"):
                    code = message.get("error", {}).get("code", "unknown")
                    raise HAError(f"Home Assistant rejected {command} ({code}).")
                return message.get("result")

    def close(self):
        if self.socket is not None:
            self.socket.close()


def tile(entity, name=None):
    # Both icon and card open details; neither directly toggles a device.
    result = {"type": "tile", "entity": entity,
              "tap_action": {"action": "more-info"},
              "icon_tap_action": {"action": "more-info"},
              "hold_action": {"action": "none"}}
    if name:
        result["name"] = name
    return result


def build_dashboard(states, registry, devices, areas):
    state_by_id = {x["entity_id"]: x for x in states}
    device_areas = {x["id"]: x.get("area_id") for x in devices}
    area_names = {x["area_id"]: x["name"] for x in areas}
    groups = collections.defaultdict(list)
    diagnostics = []
    for record in registry:
        entity = record["entity_id"]
        state = state_by_id.get(entity)
        if record.get("disabled_by") or state is None:
            continue
        if state["state"] == "unavailable":
            diagnostics.append(entity)
        if (record.get("hidden_by") or record.get("entity_category")
                or entity.split(".", 1)[0] not in DISPLAY_DOMAINS
                or state.get("attributes", {}).get("restored")
                or state["state"] in {"unavailable", "unknown"}):
            continue
        area = record.get("area_id") or device_areas.get(record.get("device_id"))
        groups[area_names.get(area, "Unassigned / 未分配")].append(entity)
    views = []
    for name, entities in sorted(groups.items()):
        sections = []
        for start in range(0, len(entities), 12):
            sections.append({"type": "grid", "cards": [
                tile(entity) for entity in sorted(entities)[start:start + 12]]})
        views.append({"title": name, "path": f"room-{len(views) + 1}",
                      "type": "sections", "max_columns": 3, "sections": sections})
    report = {"type": "markdown", "content": (
        "## Review / 待人工核对\n\n"
        f"{len(diagnostics)} registered entities are currently unavailable. "
        "This is a snapshot, not a deletion list.\n\n"
        "不可用只是当前状态，不等于设备已停用。按钮没有状态也不等于故障。\n\n"
        "This dashboard was created separately. Existing dashboards and devices were preserved.")}
    views.append({"title": "Review / 管理", "path": "review", "cards": [report]})
    return {"title": "Home review / 家庭整理", "views": views}, diagnostics


def main(argv=None):
    if sys.version_info < (3, 11):
        raise HAError("Python 3.11 or newer is required.")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=os.environ.get("HA_URL", ""))
    parser.add_argument("--out", default="ha-dashboard-output")
    parser.add_argument("--apply", action="store_true", help="Create a NEW dashboard")
    parser.add_argument("--non-interactive", action="store_true")
    parser.add_argument("--rollback", type=pathlib.Path, help="Remove only a dashboard from a receipt")
    args = parser.parse_args(argv)
    if args.apply and args.rollback:
        parser.error("--apply and --rollback cannot be combined")
    url = args.url
    token = os.environ.get("HOME_ASSISTANT_TOKEN", "")
    if not args.non_interactive:
        url = url or input("Home Assistant base URL: ").strip()
        token = token or getpass.getpass("Home Assistant administrator token (hidden): ")
    if not url or not token:
        raise HAError("Provide HA_URL and HOME_ASSISTANT_TOKEN, or use interactive prompts.")
    output = pathlib.Path(args.out)
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name != "nt":
        output.chmod(0o700)
    client = HomeAssistant(url, token)
    try:
        client.connect()
        dashboards = client.command("lovelace/dashboards/list")
        if args.rollback:
            receipt = json.loads(args.rollback.read_text(encoding="utf-8"))
            path = receipt.get("url_path", "")
            if (receipt.get("tool") != "ha-dashboard-agent-v1"
                    or not re.fullmatch(r"dashboard-agent-\d{8}-[a-f0-9]{12}", path)):
                raise HAError("Receipt does not describe a dashboard created by this tool.")
            match = next((x for x in dashboards if x.get("url_path") == path
                          and x["id"] == receipt.get("dashboard_id")), None)
            if match is None:
                raise HAError("Receipt dashboard not found; nothing was removed.")
            saved = client.command("lovelace/config", url_path=path)
            digest = hashlib.sha256(json.dumps(saved, sort_keys=True).encode()).hexdigest()
            if digest != receipt.get("config_sha256"):
                raise HAError("Dashboard changed after creation; use the HA UI to review removal.")
            client.command("lovelace/dashboards/delete", dashboard_id=match["id"])
            print("Removed the unchanged dashboard recorded in the receipt.")
            return 0
        states = client.states()
        registry = client.command("config/entity_registry/list")
        devices = client.command("config/device_registry/list")
        areas = client.command("config/area_registry/list")
        config, unavailable = build_dashboard(states, registry, devices, areas)
        write_private(output / "dashboard.json", config)
        # JSON is valid YAML; this file can be pasted into HA's raw configuration editor.
        (output / "dashboard.yaml").write_text(json.dumps(config, ensure_ascii=False, indent=2),
                                                encoding="utf-8")
        if os.name != "nt":
            (output / "dashboard.yaml").chmod(0o600)
        write_private(output / "inventory.json", {"entities": registry, "areas": areas,
                                                  "unavailable_snapshot": unavailable,
                                                  "existing_dashboards": dashboards})
        summary = {"state_count": len(states), "registered_count": len(registry),
                   "room_views": len(config["views"]) - 1,
                   "unavailable_registered": len(unavailable),
                   "applied": False}
        write_private(output / "summary.json", summary)
        print("Plan saved. Current states:", summary["state_count"],
              "Room views:", summary["room_views"],
              "Unavailable snapshot:", len(unavailable))
        if not args.apply:
            print("Read-only plan complete. Add --apply to create a separate dashboard.")
            return 0
        path = "dashboard-agent-" + dt.datetime.now().strftime("%Y%m%d") + "-" + secrets.token_hex(6)
        if any(x.get("url_path") == path for x in dashboards):
            raise HAError("Generated path already exists; no dashboard was changed.")
        created = client.command("lovelace/dashboards/create", url_path=path,
                                 title=config["title"], icon="mdi:home-search",
                                 mode="storage", show_in_sidebar=True, require_admin=True)
        receipt = {"tool": "ha-dashboard-agent-v1", "dashboard_id": created["id"],
                   "url_path": path, "config_sha256": hashlib.sha256(
                       json.dumps(config, sort_keys=True).encode()).hexdigest()}
        write_private(output / "receipt.json", receipt)
        client.command("lovelace/config/save", url_path=path, config=config)
        saved = client.command("lovelace/config", url_path=path)
        if saved != config:
            raise HAError("Dashboard read-back mismatch. Inspect the new dashboard in HA.")
        summary["applied"] = True
        write_private(output / "summary.json", summary)
        print("Created and read back NEW dashboard:", "/" + path)
        print("Existing dashboards, automations, devices and history were preserved.")
        print("Keep output private: entity and area names may reveal household information.")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Cancelled.", file=sys.stderr)
        sys.exit(130)
    except Exception as exc:
        # Network/HTTP response bodies and input URLs may contain private data.
        message = str(exc) if isinstance(exc, HAError) else type(exc).__name__
        print("Failed:", message, file=sys.stderr)
        sys.exit(1)
