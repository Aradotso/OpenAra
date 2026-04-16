```markdown
---
name: hermes-web-ui
description: Web dashboard for Hermes Agent — multi-platform AI chat, session management, scheduled jobs, usage analytics & channel configuration
triggers:
  - set up hermes web ui dashboard
  - configure hermes agent channels
  - add telegram discord slack to hermes
  - manage hermes chat sessions
  - schedule cron jobs for hermes agent
  - view hermes usage analytics and costs
  - integrate hermes web ui into my project
  - build custom hermes agent dashboard
---

# Hermes Web UI

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Full-featured Vue 3 web dashboard for [Hermes Agent](https://github.com/NousResearch/hermes-agent). Provides AI chat with streaming, multi-platform channel configuration (Telegram, Discord, Slack, WhatsApp, Matrix, Feishu, WeChat, WeCom), usage analytics, cron job scheduling, skill browsing, log viewing, and an integrated web terminal.

---

## Installation

### Global npm (Recommended)

```bash
npm install -g hermes-web-ui
hermes-web-ui start
# Open http://localhost:8648
```

### One-line Setup (Debian/Ubuntu/macOS)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EKKOLearnAI/hermes-web-ui/main/scripts/setup.sh)
```

### WSL

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EKKOLearnAI/hermes-web-ui/main/scripts/setup.sh)
hermes-web-ui start
```

---

## CLI Commands

| Command | Description |
|---|---|
| `hermes-web-ui start` | Start in background (daemon mode) on port 8648 |
| `hermes-web-ui start --port 9000` | Start on a custom port |
| `hermes-web-ui stop` | Stop the background process |
| `hermes-web-ui restart` | Restart the background process |
| `hermes-web-ui status` | Check if running |
| `hermes-web-ui update` | Update to latest version and restart |
| `hermes-web-ui -v` | Print version number |
| `hermes-web-ui -h` | Show help |

---

## Architecture

```
Browser → BFF (Koa, :8648) → Hermes Gateway (:8642)
                ↓
           Hermes CLI (sessions, logs, version)
                ↓
           ~/.hermes/config.yaml   (channel behavior)
           ~/.hermes/auth.json     (credential pool)
           ~/.hermes/.env          (platform credentials)
```

- **Frontend:** Vue 3 + TypeScript + Vite + Naive UI + Pinia + Vue Router + vue-i18n + SCSS + markdown-it + highlight.js
- **BFF:** Koa 2 server — proxies to Hermes on `:8642`, manages configs, SSE streaming, file uploads, WeChat QR login, model discovery, log reading, static serving
- **Terminal:** node-pty + @xterm/xterm over WebSocket

All Hermes-specific code lives under `hermes/` directories (`api/`, `components/`, `views/`, `stores/`) for multi-agent extensibility.

---

## Development Setup

```bash
git clone https://github.com/EKKOLearnAI/hermes-web-ui.git
cd hermes-web-ui
npm install
npm run dev
# Frontend: http://localhost:5173
# BFF:      http://localhost:8648
```

```bash
npm run build   # outputs to dist/
```

---

## Configuration Files

### `~/.hermes/config.yaml` — Channel Behavior

```yaml
api_server:
  host: 0.0.0.0
  port: 8642

telegram:
  enabled: true
  require_mention: false
  reactions: true
  free_response_chats: ["@my_chat"]

discord:
  enabled: true
  require_mention: true
  auto_thread: true
  reactions: true
  channel_allowlist: []
  channel_ignorelist: []

slack:
  enabled: false
  require_mention: true
  handle_bot_messages: false

whatsapp:
  enabled: false
  require_mention: true
  mention_patterns: ["@hermes"]

matrix:
  enabled: false
  homeserver: "https://matrix.org"
  auto_thread: false
  dm_mention_threads: true
```

### `~/.hermes/auth.json` — Credential Pool

```json
{
  "providers": [
    {
      "name": "openai",
      "base_url": "https://api.openai.com/v1",
      "api_key": "$OPENAI_API_KEY",
      "models": ["gpt-4o", "gpt-4o-mini"]
    },
    {
      "name": "custom",
      "base_url": "https://my-provider.example.com/v1",
      "api_key": "$CUSTOM_API_KEY"
    }
  ]
}
```

### `~/.hermes/.env` — Platform Credentials

```bash
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN
SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN
SLACK_APP_TOKEN=$SLACK_APP_TOKEN
FEISHU_APP_ID=$FEISHU_APP_ID
FEISHU_APP_SECRET=$FEISHU_APP_SECRET
WECOM_BOT_ID=$WECOM_BOT_ID
WECOM_BOT_SECRET=$WECOM_BOT_SECRET
```

---

## Frontend — Key Patterns

### API Client (BFF proxy calls)

```typescript
// packages/client/src/hermes/api/chat.ts
import axios from 'axios'

const BASE = '/api/hermes'

export async function sendMessage(
  sessionId: string,
  content: string,
  model?: string
): Promise<void> {
  const response = await fetch(`${BASE}/chat/${sessionId}/stream`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content, model }),
  })

  const reader = response.body!.getReader()
  const decoder = new TextDecoder()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    const chunk = decoder.decode(value)
    // parse SSE lines
    for (const line of chunk.split('\n')) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6))
        // handle delta, tool_call, done events
      }
    }
  }
}
```

### Pinia Store — Sessions

```typescript
// packages/client/src/hermes/stores/sessions.ts
import { defineStore } from 'pinia'
import axios from 'axios'

interface Session {
  id: string
  name: string
  source: string
  model: string
  createdAt: string
}

export const useSessionStore = defineStore('sessions', {
  state: () => ({
    sessions: [] as Session[],
    activeSessionId: null as string | null,
  }),
  actions: {
    async fetchSessions() {
      const { data } = await axios.get('/api/hermes/sessions')
      this.sessions = data
    },
    async createSession(name: string, model: string) {
      const { data } = await axios.post('/api/hermes/sessions', { name, model })
      this.sessions.unshift(data)
      this.activeSessionId = data.id
      return data
    },
    async deleteSession(id: string) {
      await axios.delete(`/api/hermes/sessions/${id}`)
      this.sessions = this.sessions.filter(s => s.id !== id)
      if (this.activeSessionId === id) this.activeSessionId = null
    },
    async renameSession(id: string, name: string) {
      await axios.patch(`/api/hermes/sessions/${id}`, { name })
      const s = this.sessions.find(s => s.id === id)
      if (s) s.name = name
    },
  },
  getters: {
    sessionsBySource: (state) => {
      return state.sessions.reduce((acc, s) => {
        ;(acc[s.source] ??= []).push(s)
        return acc
      }, {} as Record<string, Session[]>)
    },
  },
})
```

### Vue Component — Streaming Chat Message

```vue
<!-- packages/client/src/hermes/components/ChatMessage.vue -->
<template>
  <div class="message" :class="role">
    <div v-if="role === 'assistant'" class="content">
      <div v-html="renderedMarkdown" />
      <ToolCallExpander
        v-for="call in toolCalls"
        :key="call.id"
        :call="call"
      />
      <span v-if="streaming" class="cursor">▋</span>
    </div>
    <div v-else class="content">{{ content }}</div>
    <div class="meta">
      <n-tag size="small">{{ model }}</n-tag>
      <span v-if="tokens">{{ tokens }} tokens</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import MarkdownIt from 'markdown-it'
import hljs from 'highlight.js'

const md = new MarkdownIt({
  highlight: (str, lang) => {
    if (lang && hljs.getLanguage(lang)) {
      return hljs.highlight(str, { language: lang }).value
    }
    return ''
  },
})

const props = defineProps<{
  role: 'user' | 'assistant'
  content: string
  model?: string
  tokens?: number
  toolCalls?: Array<{ id: string; name: string; args: unknown; result: unknown }>
  streaming?: boolean
}>()

const renderedMarkdown = computed(() => md.render(props.content))
</script>
```

### Cron Job Management

```typescript
// packages/client/src/hermes/api/jobs.ts
import axios from 'axios'

export interface CronJob {
  id: string
  name: string
  cron: string
  prompt: string
  enabled: boolean
  lastRun?: string
  nextRun?: string
}

export const jobsApi = {
  list: () => axios.get<CronJob[]>('/api/hermes/jobs').then(r => r.data),

  create: (job: Omit<CronJob, 'id'>) =>
    axios.post<CronJob>('/api/hermes/jobs', job).then(r => r.data),

  update: (id: string, patch: Partial<CronJob>) =>
    axios.patch<CronJob>(`/api/hermes/jobs/${id}`, patch).then(r => r.data),

  delete: (id: string) => axios.delete(`/api/hermes/jobs/${id}`),

  trigger: (id: string) =>
    axios.post(`/api/hermes/jobs/${id}/trigger`),

  toggle: (id: string, enabled: boolean) =>
    axios.patch(`/api/hermes/jobs/${id}`, { enabled }),
}

// Common cron presets
export const CRON_PRESETS = [
  { label: 'Every minute',   value: '* * * * *' },
  { label: 'Every hour',     value: '0 * * * *' },
  { label: 'Daily at 9am',   value: '0 9 * * *' },
  { label: 'Every Monday',   value: '0 9 * * 1' },
  { label: 'First of month', value: '0 9 1 * *' },
]
```

### Model Discovery

```typescript
// packages/client/src/hermes/api/models.ts
import axios from 'axios'

export interface ModelInfo {
  id: string
  provider: string
  endpoint: string
}

// Fetches models by reading auth.json then hitting each provider's /v1/models
export async function discoverModels(): Promise<ModelInfo[]> {
  const { data } = await axios.get<ModelInfo[]>('/api/hermes/models')
  return data
}

// Add a custom OpenAI-compatible provider
export async function addProvider(config: {
  name: string
  base_url: string
  api_key: string
}) {
  const { data } = await axios.post('/api/hermes/models/providers', config)
  return data
}
```

### Channel Configuration Component

```vue
<!-- packages/client/src/hermes/views/Channels/TelegramConfig.vue -->
<template>
  <n-form :model="form" label-placement="left" label-width="180px">
    <n-form-item label="Bot Token">
      <n-input
        v-model:value="form.token"
        type="password"
        show-password-on="click"
        placeholder="Enter from @BotFather"
      />
    </n-form-item>
    <n-form-item label="Require Mention">
      <n-switch v-model:value="form.requireMention" />
    </n-form-item>
    <n-form-item label="Enable Reactions">
      <n-switch v-model:value="form.reactions" />
    </n-form-item>
    <n-form-item>
      <n-button type="primary" :loading="saving" @click="save">
        Save & Restart Gateway
      </n-button>
    </n-form-item>
  </n-form>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import { useMessage } from 'naive-ui'

const msg = useMessage()
const saving = ref(false)
const form = ref({
  token: '',
  requireMention: false,
  reactions: true,
})

onMounted(async () => {
  const { data } = await axios.get('/api/hermes/channels/telegram')
  Object.assign(form.value, data)
})

async function save() {
  saving.value = true
  try {
    await axios.put('/api/hermes/channels/telegram', form.value)
    msg.success('Telegram config saved. Gateway restarting…')
  } finally {
    saving.value = false
  }
}
</script>
```

### Web Terminal Integration

```vue
<!-- packages/client/src/hermes/views/Terminal/TerminalTab.vue -->
<template>
  <div ref="termEl" class="terminal-container" />
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'

const props = defineProps<{ sessionId: string }>()
const termEl = ref<HTMLElement>()

onMounted(() => {
  const term = new Terminal({ cursorBlink: true, fontSize: 14 })
  const fit = new FitAddon()
  term.loadAddon(fit)
  term.open(termEl.value!)
  fit.fit()

  const ws = new WebSocket(
    `ws://${location.host}/api/terminal/${props.sessionId}`
  )

  ws.onmessage = e => term.write(e.data)
  term.onData(data => ws.send(data))

  const ro = new ResizeObserver(() => {
    fit.fit()
    ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }))
  })
  ro.observe(termEl.value!)

  onUnmounted(() => {
    ws.close()
    ro.disconnect()
    term.dispose()
  })
})
</script>

<style scoped>
.terminal-container {
  height: 100%;
  background: #1a1a2e;
  padding: 8px;
}
</style>
```

### i18n Setup

```typescript
// packages/client/src/i18n/index.ts
import { createI18n } from 'vue-i18n'
import en from './locales/en.json'
import zh from './locales/zh.json'

export const i18n = createI18n({
  legacy: false,
  locale: localStorage.getItem('locale') ?? 'en',
  fallbackLocale: 'en',
  messages: { en, zh },
})

// Usage in component
// const { t } = useI18n()
// t('chat.newSession')
```

---

## BFF API Endpoints (Koa)

| Method | Path | Description |
|---|---|---|
| GET | `/api/hermes/sessions` | List all sessions |
| POST | `/api/hermes/sessions` | Create session |
| DELETE | `/api/hermes/sessions/:id` | Delete session |
| PATCH | `/api/hermes/sessions/:id` | Rename session |
| POST | `/api/hermes/chat/:id/stream` | SSE streaming chat |
| GET | `/api/hermes/models` | Discover models from auth.json |
| POST | `/api/hermes/models/providers` | Add custom provider |
| GET | `/api/hermes/channels/:platform` | Get channel config |
| PUT | `/api/hermes/channels/:platform` | Save channel config + restart |
| GET | `/api/hermes/jobs` | List cron jobs |
| POST | `/api/hermes/jobs` | Create cron job |
| PATCH | `/api/hermes/jobs/:id` | Update/toggle cron job |
| DELETE | `/api/hermes/jobs/:id` | Delete cron job |
| POST | `/api/hermes/jobs/:id/trigger` | Trigger immediately |
| GET | `/api/hermes/analytics` | Usage stats and cost data |
| GET | `/api/hermes/logs` | Read log files |
| GET | `/api/hermes/skills` | List installed skills |
| WS | `/api/terminal/:sessionId` | PTY WebSocket |

---

## Common Patterns

### Adding a New Platform Channel

1. Add credentials to `~/.hermes/.env` via the Channels UI (writes key=value pairs)
2. Add behavior config to `~/.hermes/config.yaml` (written by BFF on PUT)
3. BFF auto-triggers `hermes gateway restart`

### Custom OpenAI-Compatible Provider

```bash
# Via UI: Settings → Model Management → Add Provider
# Or directly in ~/.hermes/auth.json:
```

```json
{
  "providers": [
    {
      "name": "my-local-llm",
      "base_url": "http://localhost:11434/v1",
      "api_key": "ollama"
    }
  ]
}
```

### SSE Streaming (Raw Fetch)

```typescript
async function* streamChat(sessionId: string, prompt: string) {
  const res = await fetch(`/api/hermes/chat/${sessionId}/stream`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: prompt }),
  })
  const reader = res.body!.getReader()
  const dec = new TextDecoder()
  let buf = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buf += dec.decode(value, { stream: true })
    const lines = buf.split('\n')
    buf = lines.pop()!
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        yield JSON.parse(line.slice(6))
      }
    }
  }
}

// Usage
for await (const event of streamChat('sess_123', 'Hello!')) {
  if (event.type === 'delta') appendText(event.content)
  if (event.type === 'done') finalize(event.usage)
}
```

---

## Troubleshooting

### Port Already in Use

```bash
hermes-web-ui stop
hermes-web-ui start --port 9000
# BFF auto-kills stale processes on the default port at startup
```

### Gateway Not Connecting

```bash
hermes-web-ui status
# Check ~/.hermes/config.yaml has correct api_server.port (default 8642)
# BFF validates and patches missing api_server fields on startup
# Backup created at ~/.hermes/config.yaml.bak before any modification
```

### Models Not Appearing

```bash
# Verify auth.json is valid JSON
cat ~/.hermes/auth.json | python3 -m json.tool

# Check provider endpoint is reachable
curl -H "Authorization: Bearer $YOUR_API_KEY" \
  https://api.openai.com/v1/models
```

### Channel Config Not Saving

```bash
# Check write permissions
ls -la ~/.hermes/
chmod 644 ~/.hermes/config.yaml
chmod 644 ~/.hermes/.env
```

### WeChat QR Login

- Open Channels → WeChat → click "Generate QR Code"
- Scan with WeChat mobile app within 90 seconds
- Credentials auto-saved to `~/.hermes/.env` via Tencent iLink API

### SSE Streaming Stops Mid-Response

- Check Hermes gateway is running: `hermes gateway status`
- Ensure no reverse proxy is buffering (set `proxy_buffering off` in nginx)
- BFF proxies SSE with `Transfer-Encoding: chunked` — verify no middleware strips it

### Web Terminal Not Opening

```bash
# node-pty requires native compilation
cd node_modules/node-pty && npm rebuild
# On macOS, may need Xcode CLI tools:
xcode-select --install
```
```
