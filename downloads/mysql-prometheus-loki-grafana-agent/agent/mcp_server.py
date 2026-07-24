import base64
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

import pymysql


def http_json(url, params=None, auth=None):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    headers = {}
    if auth:
        headers["Authorization"] = "Basic " + base64.b64encode(auth.encode()).decode()
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode())


def mysql_query(sql):
    normalized = re.sub(r"\s+", " ", sql.strip())
    if not re.match(r"^(SELECT|SHOW|EXPLAIN)\b", normalized, re.I):
        raise ValueError("Only SELECT, SHOW and EXPLAIN are allowed")
    if ";" in normalized or re.search(r"(--|/\*|#)", normalized):
        raise ValueError("Comments and multiple statements are blocked")
    connection = pymysql.connect(
        host=os.environ["MYSQL_HOST"], user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"], database=os.environ["MYSQL_DATABASE"],
        connect_timeout=8, read_timeout=8, cursorclass=pymysql.cursors.DictCursor,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(normalized)
            return cursor.fetchmany(100)
    finally:
        connection.close()


TOOLS = [
    {"name": "mysql_readonly_query", "description": "Run a read-only SELECT, SHOW or EXPLAIN query with a 100-row limit.", "inputSchema": {"type": "object", "properties": {"sql": {"type": "string"}}, "required": ["sql"]}},
    {"name": "prometheus_query", "description": "Run an instant PromQL query.", "inputSchema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}},
    {"name": "loki_query", "description": "Query recent Loki logs with LogQL.", "inputSchema": {"type": "object", "properties": {"query": {"type": "string"}, "minutes": {"type": "integer", "default": 30}}, "required": ["query"]}},
    {"name": "grafana_datasources", "description": "List Grafana data sources for evidence and auditing.", "inputSchema": {"type": "object", "properties": {}}},
]


def call_tool(name, arguments):
    if name == "mysql_readonly_query":
        data = mysql_query(arguments["sql"])
    elif name == "prometheus_query":
        data = http_json(os.environ["PROMETHEUS_URL"] + "/api/v1/query", {"query": arguments["query"]})
    elif name == "loki_query":
        end = time.time_ns()
        start = end - int(arguments.get("minutes", 30)) * 60 * 1_000_000_000
        data = http_json(os.environ["LOKI_URL"] + "/loki/api/v1/query_range", {
            "query": arguments["query"], "start": start, "end": end, "limit": 100, "direction": "backward"
        })
    elif name == "grafana_datasources":
        data = http_json(os.environ["GRAFANA_URL"] + "/api/datasources", auth=os.environ["GRAFANA_USER"] + ":" + os.environ["GRAFANA_PASSWORD"])
    else:
        raise ValueError("Unknown tool")
    return {"content": [{"type": "text", "text": json.dumps(data, ensure_ascii=False, indent=2, default=str)}]}


def respond(request):
    method = request.get("method")
    if method == "initialize":
        return {"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "observability-agent-lab", "version": "1.0.0"}}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        params = request.get("params", {})
        return call_tool(params["name"], params.get("arguments", {}))
    return {}


for line in sys.stdin:
    try:
        request = json.loads(line)
        if "id" not in request:
            continue
        print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": respond(request)}, ensure_ascii=False), flush=True)
    except Exception as exc:
        print(json.dumps({"jsonrpc": "2.0", "id": request.get("id") if "request" in locals() else None,
                          "error": {"code": -32000, "message": str(exc)}}), flush=True)
