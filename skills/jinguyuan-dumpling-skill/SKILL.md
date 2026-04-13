```markdown
---
name: jinguyuan-dumpling-skill
description: AI Skill for 金谷园饺子馆 — query restaurant info, hours, delivery, Wi-Fi, and trigger Meituan queue-taking via MCP tools embedded in your AI coding agent.
triggers:
  - install jinguyuan dumpling skill
  - 帮我安装金谷园饺子馆 Skill
  - query jinguyuan restaurant info
  - 金谷园怎么排队
  - add meituan queue skill to my agent
  - 金谷园几点开门
  - help me queue at jinguyuan dumplings
  - 金谷园外卖怎么点
---

# 金谷园饺子馆 AI Skill

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

An official AI Skill for 金谷园饺子馆 (JinGuYuan Dumpling Restaurant) — the beloved Beijing dumpling shop near BUPT. Once installed, your AI agent gains 5 MCP query tools plus an embedded Meituan queue-taking capability, letting users ask about the restaurant and even grab a queue number without opening any app.

---

## What This Skill Does

| Capability | Example Query | Mechanism |
|---|---|---|
| Restaurant info (location, hours) | "金谷园在哪？几点开门？" | MCP tool |
| Delivery service | "能送外卖吗？怎么点？" | MCP tool |
| Raw dumpling takeaway | "生饺子怎么煮？" | MCP tool |
| In-store Wi-Fi | "Wi-Fi密码多少？" | MCP tool |
| Latest announcements | "有什么新活动？" | MCP tool |
| **Meituan queue (take number, check progress, cancel)** | "帮我排个队，2个人" | Embedded sub-Skill |

---

## Installation

### Option 1 — Tell Your Agent (Recommended)

Paste this into your AI assistant:

```
帮我安装金谷园饺子馆 Skill，仓库地址：https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill
```

The agent will clone the repo and place it in the correct Skill directory automatically.

### Option 2 — Manual Clone

```bash
# Qoder
git clone https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .qoder/skills/jinguyuan-dumpling-skill

# Cursor
git clone https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .cursor/skills/jinguyuan-dumpling-skill

# Claude Code
git clone https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .claude/skills/jinguyuan-dumpling-skill

# Windsurf
git clone https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .windsurf/skills/jinguyuan-dumpling-skill

# Generic / other agents
git clone https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .agents/skills/jinguyuan-dumpling-skill
```

Any IDE/agent that discovers a `SKILL.md` in the Skill directory will auto-load it on next startup.

### Option 3 — GitHub Mirror

```bash
git clone https://github.com/JinGuYuan/jinguyuan-dumpling-skill.git \
  .agents/skills/jinguyuan-dumpling-skill
```

---

## Repository Structure

```
jinguyuan-dumpling-skill/
├── SKILL.md                        # Agent instructions + metadata (core file)
├── skill.json                      # Machine-readable config: MCP endpoints, tool definitions
├── scripts/                        # Reserved for future scripts
├── references/
│   └── meituan-queue/              # Embedded Meituan queue sub-Skill (self-contained)
│       ├── SKILL.md                #   Queue instructions and command reference
│       ├── scripts/
│       │   └── mt_queue.py         #   Queue implementation script
│       └── references/
│           └── meituan-passport-user-auth/   # Auth sub-Skill
├── README.md
└── LICENSE                         # MIT
```

The **critical files** for agent operation:
- `SKILL.md` — loaded by the agent; contains all natural-language instructions
- `skill.json` — MCP endpoint URLs and tool schemas
- `references/meituan-queue/` — self-contained sub-Skill for live queue operations

---

## MCP Configuration (`skill.json`)

The `skill.json` defines the MCP server endpoints and tool list. Example structure the agent reads:

```json
{
  "name": "jinguyuan-dumpling-skill",
  "version": "0.3.3",
  "protocol": "MCP",
  "transport": "streamable-http",
  "mcp_server": {
    "url": "https://<cloudbase-endpoint>/mcp",
    "auth": "none"
  },
  "tools": [
    "get_restaurant_info",
    "get_delivery_info",
    "get_raw_dumpling_info",
    "get_wifi_info",
    "get_announcements"
  ],
  "embedded_skills": [
    "references/meituan-queue"
  ]
}
```

> The MCP server is hosted on Tencent CloudBase. No local server setup required.

---

## MCP Tools Reference

### `get_restaurant_info`

Returns location, hours, and branch details.

```python
# Example MCP tool call (via any MCP-compatible client)
import httpx

response = httpx.post(
    "https://<cloudbase-endpoint>/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get_restaurant_info",
            "arguments": {}
        },
        "id": 1
    }
)
print(response.json())
# {
#   "result": {
#     "name": "金谷园饺子馆",
#     "hours": "10:00 - 22:00",
#     "branches": {
#       "bupt": "杏坛路文教产业园K座南2层",
#       "wudaokou": "五道口东源大厦4层"
#     }
#   }
# }
```

### `get_delivery_info`

Returns delivery platforms and ordering instructions.

```python
response = httpx.post(
    "https://<cloudbase-endpoint>/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {"name": "get_delivery_info", "arguments": {}},
        "id": 2
    }
)
```

### `get_raw_dumpling_info`

Returns packaging options and home-cooking instructions for raw dumplings.

```python
response = httpx.post(
    "https://<cloudbase-endpoint>/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {"name": "get_raw_dumpling_info", "arguments": {}},
        "id": 3
    }
)
```

### `get_wifi_info`

Returns current in-store Wi-Fi credentials.

```python
response = httpx.post(
    "https://<cloudbase-endpoint>/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {"name": "get_wifi_info", "arguments": {}},
        "id": 4
    }
)
```

### `get_announcements`

Returns latest promotions and news.

```python
response = httpx.post(
    "https://<cloudbase-endpoint>/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {"name": "get_announcements", "arguments": {}},
        "id": 5
    }
)
```

---

## Embedded Sub-Skill: Meituan Queue (`meituan-queue`)

The queue capability is a **self-contained sub-Skill** in `references/meituan-queue/`. It wraps Meituan's queue API via `mt_queue.py`.

### Supported Operations

| Operation | User can say | Script action |
|---|---|---|
| Check queue status | "现在排队情况怎么样？" | Query Meituan for table types + wait count |
| Take a number | "帮我排个队，2个人" | Confirm → call take-number API |
| Check progress | "我前面还有几桌？" | Query current position |
| Cancel queue | "取消排队" | Confirm → call cancel API |

### Authentication Flow

First-time use triggers Meituan account OAuth. The agent guides the user through the flow using the `meituan-passport-user-auth` sub-Skill in `references/meituan-queue/references/`. Credentials are cached for the session.

```python
# references/meituan-queue/scripts/mt_queue.py — usage pattern
# Environment variables used by the script:
#   MEITUAN_ACCESS_TOKEN  — set after OAuth, managed by the auth sub-Skill
#   MEITUAN_USER_ID       — populated post-login

import os
import httpx

MEITUAN_ACCESS_TOKEN = os.environ["MEITUAN_ACCESS_TOKEN"]

def get_queue_status(branch: str) -> dict:
    """
    branch: "bupt" | "wudaokou"
    """
    headers = {"Authorization": f"Bearer {MEITUAN_ACCESS_TOKEN}"}
    resp = httpx.get(
        "https://api.meituan.com/queue/status",
        params={"poiId": branch},
        headers=headers
    )
    resp.raise_for_status()
    return resp.json()

def take_queue_number(branch: str, table_type: str, party_size: int) -> dict:
    headers = {"Authorization": f"Bearer {MEITUAN_ACCESS_TOKEN}"}
    resp = httpx.post(
        "https://api.meituan.com/queue/take",
        json={"poiId": branch, "tableType": table_type, "partySize": party_size},
        headers=headers
    )
    resp.raise_for_status()
    return resp.json()

def cancel_queue(queue_id: str) -> dict:
    headers = {"Authorization": f"Bearer {MEITUAN_ACCESS_TOKEN}"}
    resp = httpx.post(
        "https://api.meituan.com/queue/cancel",
        json={"queueId": queue_id},
        headers=headers
    )
    resp.raise_for_status()
    return resp.json()
```

> **Important:** Queue operations are **real business actions**. The agent always asks for user confirmation before calling `take_queue_number` or `cancel_queue`.

---

## Common Agent Interaction Patterns

### Pattern 1 — Simple Info Query

```
User: 金谷园北邮店几点关门？
Agent: [calls get_restaurant_info] → 营业时间 10:00–22:00，北邮店地址：杏坛路文教产业园K座南2层
```

### Pattern 2 — Queue Flow

```
User: 帮我在北邮店排个队，3个人
Agent: [calls meituan-queue: get_queue_status("bupt")]
       → 当前可选桌型：2人桌、4人桌、大桌。前方等待：5桌。
       请确认：为北邮店选择4人桌，3人就餐，帮您取号？
User: 确认
Agent: [calls take_queue_number("bupt", "4人桌", 3)]
       → 取号成功！您的号码：A-047，前方等待：5桌
```

### Pattern 3 — Check Progress

```
User: 我前面还有几桌？
Agent: [calls meituan-queue: check_progress]
       → 您当前排队号 A-047，前方还有 3 桌
```

### Pattern 4 — Cancel

```
User: 取消排队吧
Agent: 确认取消排队号 A-047？
User: 是的
Agent: [calls cancel_queue("A-047")] → 已成功取消排队
```

---

## Configuration Reference

| Variable | Required | Description |
|---|---|---|
| `MEITUAN_ACCESS_TOKEN` | For queue ops | Set by auth sub-Skill after OAuth |
| `MEITUAN_USER_ID` | For queue ops | Set by auth sub-Skill after OAuth |

No configuration is needed for the 5 MCP info tools — they are public, unauthenticated endpoints on Tencent CloudBase.

---

## Versioning

| Component | Version | Notes |
|---|---|---|
| jinguyuan-dumpling-skill | 0.3.3 | This Skill |
| meituan-queue (sub-Skill) | Independent | Versioned separately |
| meituan-passport-user-auth | Independent | Versioned separately |

Sub-Skill versions evolve independently. Updating one does not require updating the others.

---

## Troubleshooting

### Agent doesn't load the Skill after cloning

- Confirm the directory contains `SKILL.md` at the root level
- Restart your IDE or agent session — Skills are loaded at startup
- Verify the clone path matches your IDE's Skill directory (see installation table above)

### MCP tool calls return errors

- The CloudBase endpoint may be temporarily unavailable; retry after a moment
- Check `skill.json` for the correct endpoint URL (it may be updated in newer versions)
- Ensure your network can reach Tencent CloudBase services

### Meituan queue auth fails

- Delete cached tokens and restart the OAuth flow by saying: "重新登录美团账号"
- Ensure `MEITUAN_ACCESS_TOKEN` is not stale; the auth sub-Skill handles refresh automatically during a session
- If the OAuth window doesn't appear, check that your agent has browser/webview access

### Queue number taken but agent shows error

- The number may still be valid — check the Meituan app directly
- Call `get_queue_status` to verify current position before retrying

### Skill version mismatch

```bash
# Pull the latest version
cd .agents/skills/jinguyuan-dumpling-skill
git pull origin main
```

---

## Technical Details

| Item | Value |
|---|---|
| Protocol | MCP (Model Context Protocol) |
| Transport | Streamable HTTP |
| Hosting | Tencent CloudBase (云函数) |
| Language | Python |
| License | MIT |
| Primary repo | https://gitee.com/JinGuYuan/jinguyuan-dumpling-skill |
| Mirror | https://github.com/JinGuYuan/jinguyuan-dumpling-skill |
```
