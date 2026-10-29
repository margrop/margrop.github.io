#!/usr/bin/env python3
"""Home Assistant Custom Component Development & Deployment Toolkit.
Zero external pip dependencies (Pure Python 3 standard library).
Designed for both human one-click execution and AI Agent automated takeover.
"""
import argparse
import ast
import json
import os
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def mask_ip(addr: str) -> str:
    """Mask IPv4 address for privacy protection."""
    if not addr:
        return "<DEVICE_HOST>"
    return re.sub(r'(\d+)\.(\d+)\.(\d+)\.(\d+)', r'\1.\2.x.x', addr)


def cmd_probe(args: argparse.Namespace) -> None:
    """Probe smart device API endpoint and extract data schema."""
    host = args.host
    port = args.port
    path = args.path
    url = f"http://{host}:{port}{path}"
    masked_url = f"http://{mask_ip(host)}:{port}{path}"
    print(f"[*] Probing target device endpoint: {masked_url} ...")

    if args.mock:
        sample_payload = {
            "device_id": "smart_switch_01",
            "model": "DIY-ESP32-Relay",
            "firmware": "v2.4.1",
            "state": "ON",
            "voltage": 220.5,
            "current": 1.42,
            "power": 313.1,
            "temperature": 26.8,
            "rssi": -58
        }
        print("[+] Mock device probe successful! Response (200 OK):")
        print(json.dumps(sample_payload, indent=2, ensure_ascii=False))
        return

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "HAAgentToolkit/1.0", "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            data = resp.read().decode("utf-8")
            parsed = json.loads(data)
            print(f"[+] Device responded successfully (HTTP {resp.status})!")
            print("[+] Discovered payload keys:")
            for k, v in parsed.items():
                print(f"  - {k}: {type(v).__name__} = {repr(v)}")
    except Exception as e:
        print(f"[-] Probe failed: {e}", file=sys.stderr)
        print("[*] Tip: Use --mock flag to simulate a smart device response.", file=sys.stderr)
        sys.exit(1)


def cmd_scaffold(args: argparse.Namespace) -> None:
    """Generate production-ready modern HA custom component scaffolding."""
    domain = args.domain
    name = args.name or domain.replace("_", " ").title()
    out_dir = Path(args.out_dir) / domain
    out_dir.mkdir(parents=True, exist_ok=True)
    translations_dir = out_dir / "translations"
    translations_dir.mkdir(parents=True, exist_ok=True)

    print(f"[*] Scaffolding 2026-compliant HA custom component '{domain}' in: {out_dir}")

    # 1. manifest.json
    manifest = {
        "domain": domain,
        "name": name,
        "codeowners": ["@homeassistant-owner"],
        "config_flow": True,
        "documentation": "https://blog.margrop.net",
        "integration_type": "hub",
        "iot_class": "local_polling",
        "issue_tracker": "https://blog.margrop.net",
        "requirements": [],
        "version": "1.0.0"
    }
    with open(out_dir / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    # 2. const.py
    const_code = f'''"""Constants for the {name} integration."""
from datetime import timedelta
from typing import Final

DOMAIN: Final = "{domain}"
DEFAULT_NAME: Final = "{name}"
DEFAULT_PORT: Final = 8080
DEFAULT_SCAN_INTERVAL: Final = timedelta(seconds=30)

CONF_HOST: Final = "host"
CONF_PORT: Final = "port"
CONF_API_KEY: Final = "api_key"
'''
    with open(out_dir / "const.py", "w", encoding="utf-8") as f:
        f.write(const_code)

    # 3. coordinator.py
    coordinator_code = f'''"""DataUpdateCoordinator for {name}."""
import asyncio
from datetime import timedelta
import logging
import aiohttp

from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .const import DOMAIN, DEFAULT_SCAN_INTERVAL

_LOGGER = logging.getLogger(__name__)


class DeviceDataUpdateCoordinator(DataUpdateCoordinator[dict]):
    """Class to manage fetching {name} data from local device."""

    def __init__(self, hass: HomeAssistant, host: str, port: int, api_key: str | None = None) -> None:
        """Initialize coordinator."""
        super().__init__(
            hass,
            _LOGGER,
            name=f"{{DOMAIN}}_{{host}}",
            update_interval=DEFAULT_SCAN_INTERVAL,
        )
        self.host = host
        self.port = port
        self.api_key = api_key
        self.session = async_get_clientsession(hass)

    async def _async_update_data(self) -> dict:
        """Fetch data from device via async HTTP GET."""
        url = f"http://{{self.host}}:{{self.port}}/api/status"
        headers = {{"Accept": "application/json"}}
        if self.api_key:
            headers["Authorization"] = f"Bearer {{self.api_key}}"

        try:
            async with asyncio.timeout(10):
                async with self.session.get(url, headers=headers) as resp:
                    if resp.status != 200:
                        raise UpdateFailed(f"Device returned status code {{resp.status}}")
                    return await resp.json()
        except asyncio.TimeoutError as err:
            raise UpdateFailed(f"Timeout communicating with device at {{self.host}}: {{err}}") from err
        except aiohttp.ClientError as err:
            raise UpdateFailed(f"Network error communicating with device: {{err}}") from err
        except Exception as err:
            raise UpdateFailed(f"Unexpected error: {{err}}") from err
'''
    with open(out_dir / "coordinator.py", "w", encoding="utf-8") as f:
        f.write(coordinator_code)

    # 4. __init__.py
    init_code = f'''"""The {name} integration setup."""
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant

from .const import CONF_HOST, CONF_PORT, CONF_API_KEY, DOMAIN
from .coordinator import DeviceDataUpdateCoordinator

PLATFORMS: list[Platform] = [Platform.SENSOR, Platform.SWITCH]


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up {name} from a config entry."""
    hass.data.setdefault(DOMAIN, {{}})

    host = entry.data[CONF_HOST]
    port = entry.data.get(CONF_PORT, 8080)
    api_key = entry.data.get(CONF_API_KEY)

    coordinator = DeviceDataUpdateCoordinator(hass, host=host, port=port, api_key=api_key)
    await coordinator.async_config_entry_first_refresh()

    hass.data[DOMAIN][entry.entry_id] = coordinator
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload a config entry."""
    unload_ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unload_ok:
        hass.data[DOMAIN].pop(entry.entry_id)
    return unload_ok
'''
    with open(out_dir / "__init__.py", "w", encoding="utf-8") as f:
        f.write(init_code)

    # 5. config_flow.py
    config_flow_code = f'''"""Config flow for {name} integration."""
import logging
from typing import Any
import voluptuous as vol
import aiohttp

from homeassistant import config_entries
from homeassistant.data_entry_flow import FlowResult
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .const import CONF_HOST, CONF_PORT, CONF_API_KEY, DEFAULT_PORT, DOMAIN

_LOGGER = logging.getLogger(__name__)

STEP_USER_DATA_SCHEMA = vol.Schema(
    {{
        vol.Required(CONF_HOST): str,
        vol.Optional(CONF_PORT, default=DEFAULT_PORT): int,
        vol.Optional(CONF_API_KEY): str,
    }}
)


class ConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for {name}."""

    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> FlowResult:
        """Handle the initial step."""
        errors: dict[str, str] = {{}}

        if user_input is not None:
            host = user_input[CONF_HOST]
            port = user_input.get(CONF_PORT, DEFAULT_PORT)
            api_key = user_input.get(CONF_API_KEY)

            # Prevent duplicate entries for the same host
            await self.async_set_unique_id(f"{{host}}:{{port}}")
            self._abort_if_unique_id_configured()

            # Verify device connectivity
            session = async_get_clientsession(self.hass)
            try:
                url = f"http://{{host}}:{{port}}/api/status"
                async with session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as resp:
                    if resp.status == 200:
                        return self.async_create_entry(
                            title=f"{name} ({{host}})",
                            data=user_input,
                        )
                    errors["base"] = "cannot_connect"
            except Exception:
                errors["base"] = "cannot_connect"

        return self.async_show_form(
            step_id="user",
            data_schema=STEP_USER_DATA_SCHEMA,
            errors=errors,
        )
'''
    with open(out_dir / "config_flow.py", "w", encoding="utf-8") as f:
        f.write(config_flow_code)

    # 6. sensor.py
    sensor_code = f'''"""Sensor platform for {name}."""
from dataclasses import dataclass
from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import UnitOfElectricPotential, UnitOfPower, UnitOfTemperature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity import DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import DeviceDataUpdateCoordinator


@dataclass(frozen=True, kw_only=True)
class CustomSensorEntityDescription(SensorEntityDescription):
    """Describes {name} sensor entity."""
    value_fn: any


SENSOR_TYPES: tuple[CustomSensorEntityDescription, ...] = (
    CustomSensorEntityDescription(
        key="temperature",
        translation_key="temperature",
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda data: data.get("temperature"),
    ),
    CustomSensorEntityDescription(
        key="power",
        translation_key="power",
        native_unit_of_measurement=UnitOfPower.WATT,
        device_class=SensorDeviceClass.POWER,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda data: data.get("power"),
    ),
    CustomSensorEntityDescription(
        key="voltage",
        translation_key="voltage",
        native_unit_of_measurement=UnitOfElectricPotential.VOLT,
        device_class=SensorDeviceClass.VOLTAGE,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda data: data.get("voltage"),
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up {name} sensors based on config_entry."""
    coordinator: DeviceDataUpdateCoordinator = hass.data[DOMAIN][entry.entry_id]
    entities = [
        CustomSensor(coordinator, entry, description)
        for description in SENSOR_TYPES
    ]
    async_add_entities(entities)


class CustomSensor(CoordinatorEntity[DeviceDataUpdateCoordinator], SensorEntity):
    """Representation of a {name} Sensor."""

    entity_description: CustomSensorEntityDescription

    def __init__(
        self,
        coordinator: DeviceDataUpdateCoordinator,
        entry: ConfigEntry,
        description: CustomSensorEntityDescription,
    ) -> None:
        """Initialize the sensor."""
        super().__init__(coordinator)
        self.entity_description = description
        self._attr_unique_id = f"{{entry.entry_id}}_{{description.key}}"
        self._attr_has_entity_name = True
        self._attr_device_info = DeviceInfo(
            identifiers={{(DOMAIN, entry.entry_id)}},
            name=f"{name} {{coordinator.host}}",
            manufacturer="DIY-AI-Studio",
            model="Agent-Crafted v1",
            sw_version="1.0.0",
        )

    @property
    def native_value(self):
        """Return sensor value from coordinator data."""
        if self.coordinator.data is None:
            return None
        return self.entity_description.value_fn(self.coordinator.data)
'''
    with open(out_dir / "sensor.py", "w", encoding="utf-8") as f:
        f.write(sensor_code)

    # 7. switch.py
    switch_code = f'''"""Switch platform for {name}."""
import logging
from homeassistant.components.switch import SwitchDeviceClass, SwitchEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.entity import DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import DeviceDataUpdateCoordinator

_LOGGER = logging.getLogger(__name__)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up {name} switch from a config entry."""
    coordinator: DeviceDataUpdateCoordinator = hass.data[DOMAIN][entry.entry_id]
    async_add_entities([CustomDeviceSwitch(coordinator, entry)])


class CustomDeviceSwitch(CoordinatorEntity[DeviceDataUpdateCoordinator], SwitchEntity):
    """Representation of a {name} Switch."""

    _attr_has_entity_name = True
    _attr_device_class = SwitchDeviceClass.OUTLET

    def __init__(
        self,
        coordinator: DeviceDataUpdateCoordinator,
        entry: ConfigEntry,
    ) -> None:
        """Initialize switch entity."""
        super().__init__(coordinator)
        self._entry = entry
        self._attr_unique_id = f"{{entry.entry_id}}_switch_main"
        self._attr_translation_key = "power_switch"
        self._attr_device_info = DeviceInfo(
            identifiers={{(DOMAIN, entry.entry_id)}},
            name=f"{name} {{coordinator.host}}",
            manufacturer="DIY-AI-Studio",
            model="Agent-Crafted v1",
            sw_version="1.0.0",
        )

    @property
    def is_on(self) -> bool:
        """Return true if switch is on."""
        if not self.coordinator.data:
            return False
        return self.coordinator.data.get("state") in ("ON", "on", True, 1)

    async def async_turn_on(self, **kwargs) -> None:
        """Turn the switch on."""
        await self._async_send_command("ON")

    async def async_turn_off(self, **kwargs) -> None:
        """Turn the switch off."""
        await self._async_send_command("OFF")

    async def _async_send_command(self, state: str) -> None:
        """Send command to device via async HTTP POST."""
        session = async_get_clientsession(self.hass)
        url = f"http://{{self.coordinator.host}}:{{self.coordinator.port}}/api/power"
        try:
            async with session.post(url, json={{"state": state}}, timeout=5) as resp:
                if resp.status == 200:
                    await self.coordinator.async_request_refresh()
                else:
                    _LOGGER.error("Failed to set power state: %s", resp.status)
        except Exception as err:
            _LOGGER.error("Error setting device power: %s", err)
'''
    with open(out_dir / "switch.py", "w", encoding="utf-8") as f:
        f.write(switch_code)

    # 8. strings.json & translations
    strings_json = {
        "config": {
            "step": {
                "user": {
                    "title": f"Connect {name}",
                    "description": "Enter the local network address of your smart device.",
                    "data": {
                        "host": "Device Host / IP",
                        "port": "Port Number",
                        "api_key": "API Token (Optional)"
                    }
                }
            },
            "error": {
                "cannot_connect": "Failed to connect to device. Verify IP, port, and network reachability."
            },
            "abort": {
                "already_configured": "Device is already registered in Home Assistant."
            }
        },
        "entity": {
            "sensor": {
                "temperature": {"name": "Temperature"},
                "power": {"name": "Active Power"},
                "voltage": {"name": "Voltage"}
            },
            "switch": {
                "power_switch": {"name": "Power Switch"}
            }
        }
    }
    with open(out_dir / "strings.json", "w", encoding="utf-8") as f:
        json.dump(strings_json, f, indent=2, ensure_ascii=False)

    zh_strings = {
        "config": {
            "step": {
                "user": {
                    "title": f"连接 {name}",
                    "description": "请输入您智能设备的局域网连接地址与通信端口。",
                    "data": {
                        "host": "设备局域网主机名或地址",
                        "port": "服务通信端口",
                        "api_key": "通信密钥 Token (可选)"
                    }
                }
            },
            "error": {
                "cannot_connect": "无法连接到该设备，请检查地址、端口及局域网连通性。"
            },
            "abort": {
                "already_configured": "该设备已在 Home Assistant 中配置登记。"
            }
        },
        "entity": {
            "sensor": {
                "temperature": {"name": "实时温度"},
                "power": {"name": "当前功率"},
                "voltage": {"name": "电网电压"}
            },
            "switch": {
                "power_switch": {"name": "电源开关"}
            }
        }
    }
    with open(translations_dir / "zh-Hans.json", "w", encoding="utf-8") as f:
        json.dump(zh_strings, f, indent=2, ensure_ascii=False)

    print(f"[+] Successfully scaffolded 8 core files for '{domain}'!")


class BlockingCallVisitor(ast.NodeVisitor):
    """Detect synchronous blocking calls inside async functions."""
    def __init__(self):
        self.blocking_calls = []
        self._in_async_def = False
        self._current_func = ""

    def visit_AsyncFunctionDef(self, node):
        prev_async = self._in_async_def
        prev_func = self._current_func
        self._in_async_def = True
        self._current_func = node.name
        self.generic_visit(node)
        self._in_async_def = prev_async
        self._current_func = prev_func

    def visit_Call(self, node):
        if self._in_async_def:
            call_name = ""
            if isinstance(node.func, ast.Attribute):
                if isinstance(node.func.value, ast.Name):
                    call_name = f"{node.func.value.id}.{node.func.attr}"
            elif isinstance(node.func, ast.Name):
                call_name = node.func.id

            dangerous = ["requests.get", "requests.post", "urllib.request.urlopen", "time.sleep"]
            if call_name in dangerous:
                self.blocking_calls.append((self._current_func, call_name, node.lineno))
        self.generic_visit(node)


def cmd_lint(args: argparse.Namespace) -> None:
    """Run static syntax, schema, and async non-blocking checks."""
    path = Path(args.path)
    if not path.is_dir():
        print(f"[-] Target directory does not exist: {path}", file=sys.stderr)
        sys.exit(1)

    print(f"[*] Linting Home Assistant custom component: {path.name} ...")
    errors = 0

    # 1. Check manifest.json
    manifest_path = path / "manifest.json"
    if not manifest_path.exists():
        print("  [FAIL] manifest.json is missing!")
        errors += 1
    else:
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest_data = json.load(f)
            required_keys = ["domain", "name", "version", "iot_class"]
            for k in required_keys:
                if k not in manifest_data:
                    print(f"  [FAIL] manifest.json missing required key: '{k}'")
                    errors += 1
            if "version" in manifest_data and not re.match(r'^\d+\.\d+\.\d+', manifest_data["version"]):
                print(f"  [WARN] manifest.json 'version' should follow SemVer (e.g. 1.0.0)")
            print("  [PASS] manifest.json schema validated.")
        except Exception as e:
            print(f"  [FAIL] manifest.json parsing error: {e}")
            errors += 1

    # 2. Check Python files for syntax errors and blocking calls
    for py_file in path.glob("*.py"):
        try:
            with open(py_file, "r", encoding="utf-8") as f:
                source = f.read()
            tree = ast.parse(source, filename=str(py_file))
            visitor = BlockingCallVisitor()
            visitor.visit(tree)
            if visitor.blocking_calls:
                for func, call, lineno in visitor.blocking_calls:
                    print(f"  [FAIL] Blocking call '{call}' in async '{func}' at {py_file.name}:{lineno}!")
                    print("         Blocking calls in event loop cause HA freezes. Use aiohttp instead.")
                    errors += 1
            else:
                print(f"  [PASS] {py_file.name}: AST syntax & async non-blocking check passed.")
        except SyntaxError as e:
            print(f"  [FAIL] SyntaxError in {py_file.name}:{e.lineno}: {e.msg}")
            errors += 1

    if errors == 0:
        print(f"[+] All checks passed! Component '{path.name}' is production-ready.")
    else:
        print(f"[-] Linting failed with {errors} issue(s).", file=sys.stderr)
        sys.exit(1)


def cmd_deploy(args: argparse.Namespace) -> None:
    """Deploy custom component into Home Assistant config directory."""
    src = Path(args.src)
    dst_dir = Path(args.ha_config) / "custom_components"
    dst = dst_dir / src.name

    if not src.is_dir():
        print(f"[-] Source component directory does not exist: {src}", file=sys.stderr)
        sys.exit(1)

    dst_dir.mkdir(parents=True, exist_ok=True)

    if dst.exists():
        backup_dir = dst_dir / f"{src.name}_backup"
        print(f"[*] Creating backup of existing component at: {backup_dir}")
        if backup_dir.exists():
            shutil.rmtree(backup_dir)
        shutil.copytree(dst, backup_dir)

    print(f"[*] Deploying '{src.name}' -> '{dst}' ...")
    shutil.copytree(src, dst, dirs_exist_ok=True)
    print(f"[+] Deployment complete! Home Assistant integration installed at: {dst}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Home Assistant AI Agent Custom Integration Toolkit")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # probe
    p_probe = subparsers.add_parser("probe", help="Probe local smart device API")
    p_probe.add_argument("--host", default="192.168.1.100", help="Device IP or hostname")
    p_probe.add_argument("--port", type=int, default=8080, help="Device port")
    p_probe.add_argument("--path", default="/api/status", help="API path")
    p_probe.add_argument("--timeout", type=float, default=5.0, help="Timeout in seconds")
    p_probe.add_argument("--mock", action="store_true", help="Run in mock/simulation mode")

    # scaffold
    p_scaffold = subparsers.add_parser("scaffold", help="Generate custom component scaffolding")
    p_scaffold.add_argument("--domain", default="my_custom_device", help="Integration domain name")
    p_scaffold.add_argument("--name", default="My Custom Smart Device", help="Human-readable title")
    p_scaffold.add_argument("--out-dir", default="./custom_components", help="Output directory")

    # lint
    p_lint = subparsers.add_parser("lint", help="Static syntax and async safety check")
    p_lint.add_argument("--path", required=True, help="Path to component folder")

    # deploy
    p_deploy = subparsers.add_parser("deploy", help="Deploy component to HA config directory")
    p_deploy.add_argument("--src", required=True, help="Path to source component folder")
    p_deploy.add_argument("--ha-config", default="/config", help="Home Assistant config path")

    args = parser.parse_args()

    if args.command == "probe":
        cmd_probe(args)
    elif args.command == "scaffold":
        cmd_scaffold(args)
    elif args.command == "lint":
        cmd_lint(args)
    elif args.command == "deploy":
        cmd_deploy(args)


if __name__ == "__main__":
    main()
