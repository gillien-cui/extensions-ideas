# mac-mini MCP Connector — Setup

A self-hosted MCP server running on a Mac mini, reachable over Tailscale.

## Why the URL isn't in this repo

This repository is **public**, and the server's URL contains an opaque
32-hex path segment that acts as a bearer credential — anyone with the
full URL can talk to the server. So `.mcp.json` references an environment
variable instead of hardcoding it:

```json
{
  "mcpServers": {
    "mac-mini": {
      "type": "http",
      "url": "${MAC_MINI_MCP_URL}"
    }
  }
}
```

## Local setup

Export the full URL before launching Claude Code:

```bash
export MAC_MINI_MCP_URL='https://mac-mini.<tailnet>.ts.net/<token>/mcp'
```

Put it in your shell profile (`~/.zshrc`) so it persists. Verify with:

```bash
claude mcp list
```

If you'd rather skip the env var entirely, register it at user scope —
that config lives in `~/.claude.json`, outside this repo:

```bash
claude mcp add --transport http --scope user mac-mini '<full URL>'
```

## Reachability

The host resolves only on the tailnet. It will **not** work from:

- Claude Code on the web / cloud sessions (no tailnet membership)
- claude.ai custom connectors (Anthropic's servers fetch the URL, and
  they aren't on the tailnet either)

For those, expose the server publicly via Tailscale Funnel or a tunnel
with its own auth, then use that hostname instead.

## Adding it as a claude.ai connector

Settings → Connectors → **Add custom connector** → paste the URL.
Requires the public hostname from the section above.
