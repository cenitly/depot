---
name: claude-hooks
description: Create or update Claude Code hooks for this project. Use when the user asks to add a hook, create a pre/post tool hook, lint on edit, validate commands, or automate checks.
---

# Claude Code Hooks

Create shell-based hooks that run in response to Claude Code events.

## Project Conventions

- Hook scripts go in `.claude/hooks/`
- Hook config goes in `.claude/settings.json`
- Use `#!/usr/bin/env bash` (no `/bin/bash` — this is NixOS)
- Use `$CLAUDE_PROJECT_DIR` for paths in settings.json
- Add tool dependencies to the devshell in `flake.nix` rather than using `nix run`

## Hook Events

| Event | Matcher | Can Block? | Description |
|-------|---------|-----------|-------------|
| `PreToolUse` | tool name | Yes | Before tool execution |
| `PostToolUse` | tool name | No* | After successful tool execution |
| `PostToolUseFailure` | tool name | No | After failed tool execution |
| `UserPromptSubmit` | none | Yes | Before processing user prompt |
| `Stop` | none | Yes | When Claude finishes responding |
| `SessionStart` | source | No | Session begins/resumes |
| `SessionEnd` | reason | No | Session terminates |
| `Notification` | type | No | When notification sent |
| `SubagentStart` | agent type | No | Subagent spawned |
| `SubagentStop` | agent type | Yes | Subagent finishes |
| `PreCompact` | trigger | No | Before context compaction |
| `PermissionRequest` | tool name | Yes | Permission dialog appears |

*PostToolUse exit 2 feeds stderr to Claude as context but cannot undo the action.

## Exit Code Behavior

| Exit Code | Effect |
|-----------|--------|
| `0` | Success. Stdout parsed for JSON (verbose mode only otherwise) |
| `2` | Blocking error. stderr fed to Claude. Blocks action on blocking events |
| Other | Non-blocking error. stderr logged, shown as "hook error" to user |

## Stdin JSON Format

All hooks receive JSON on stdin with these common fields:

```json
{
  "session_id": "string",
  "transcript_path": "string",
  "cwd": "string",
  "permission_mode": "string",
  "hook_event_name": "string"
}
```

Tool events (`PreToolUse`, `PostToolUse`) add:

```json
{
  "tool_name": "string",
  "tool_input": { /* varies by tool */ },
  "tool_use_id": "string"
}
```

`PostToolUse` also includes `"tool_response": { ... }`.

### Common tool_input Shapes

- **Bash:** `{ "command": "string" }`
- **Edit:** `{ "file_path": "string", "old_string": "string", "new_string": "string" }`
- **Write:** `{ "file_path": "string", "content": "string" }`
- **Read:** `{ "file_path": "string" }`

## Settings Format

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex pattern",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/my-hook.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

Matcher is a regex on tool name (e.g. `"Edit|Write"`, `"Bash"`, `"mcp__.*"`).

## Existing Hook Example

See `.claude/hooks/check-ci-pinned-deps.sh` — a PostToolUse hook that:
- Checks CI workflow files for unpinned action dependencies
- Runs actionlint on workflow files
- Outputs errors to stderr and exits 2 on failure

## Steps to Create a Hook

1. **Create the script** in `.claude/hooks/<name>.sh`
2. **Make executable**: `chmod +x .claude/hooks/<name>.sh`
3. **Register in `.claude/settings.json`** under the appropriate event
4. **Add any tool dependencies** to the devshell in `flake.nix`

## Gotchas

- **NixOS has no `/bin/bash`** — always use `#!/usr/bin/env bash`
- **Exit 0 stdout is hidden** — use exit 2 + stderr to surface warnings to Claude
- **Matchers are case-sensitive** — `Bash` not `bash`
- **Shell profile noise** — if `~/.bashrc` has unconditional `echo`, it breaks JSON output
- **`nix run` in hooks** — avoid; emits `warn-dirty` stderr in dirty repos. Add tools to devshell instead
- **Stop hooks can loop** — check `stop_hook_active` field, exit early if true
