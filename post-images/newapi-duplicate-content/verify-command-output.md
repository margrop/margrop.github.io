首先，用一个简单的 prompt 验证 OneAPI 通过 openai-completions（Chat Completions）协议转发 MiniMax 流式响应时，最终的 finish chunk 是否同时包含 delta.content 和 message.content。

```bash
# 测试环境：OneAPI v1.0.0-rc.10 (QuantumNous/new-api)
# 模型：MiniMax-M2.7（通过 OneAPI 类型35 MiniMax 通道转发）
curl -s -X POST "https://ONEAPI_ENDPOINT/v1/chat/completions" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"DIY-123","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":500}' \
  | python3 -c '
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line or line == "data: [DONE]": continue
    if line.startswith("data: "):
        d = json.loads(line[6:])
        for c in d.get("choices",[]):
            delta = c.get("delta",{})
            finish = c.get("finish_reason","")
            msg = c.get("message",{})
            if "content" in delta and delta["content"]:
                print("DELTA content:", repr(delta["content"]))
            if finish:
                if "content" in msg and msg["content"]:
                    print("FINAL message.content:", repr(msg["content"]))
                print("FINISH:", finish)
'
```

输出结果：

```
DELTA content: 'Hello! How can I help you today?'
FINISH: stop
FINAL message.content: 'Hello! How can I help you today?'
FINISH: stop
```

可以看到：**同一个 content 被输出了两次**。第一次来自 delta.content，第二次来自 finish chunk 中的 message.content。OpenClaw 的流式处理器在处理时，两个事件都被解析为"可见文本"，最终拼接出了重复的回复。
