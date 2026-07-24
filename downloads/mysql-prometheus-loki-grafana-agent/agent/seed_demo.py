import json
import os
import time
import urllib.request


def push(message, level="ERROR"):
    payload = {
        "streams": [{
            "stream": {"service": "checkout-api", "env": "lab", "level": level.lower()},
            "values": [[str(time.time_ns()), json.dumps(message, ensure_ascii=False)]],
        }]
    }
    request = urllib.request.Request(
        os.environ["LOKI_URL"] + "/loki/api/v1/push",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=10):
        pass


push({"event": "slow_query", "trace_id": "demo-trace-7f3a", "duration_ms": 842,
      "sql_shape": "SELECT COUNT(*) FROM orders WHERE customer_email LIKE ?",
      "message": "checkout search exceeded latency budget"})
push({"event": "request_failed", "trace_id": "demo-trace-7f3a", "status": 504,
      "message": "upstream database request timed out"})
print("Demo incident logs pushed to Loki.")
