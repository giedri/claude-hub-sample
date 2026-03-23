# ACME Claude Hub

Centralized Claude Code configuration for the ACME organization. This repository manages coding standards, team conventions, MCP servers, and skills for all ACME developers using Claude Code.

A SessionStart hook syncs the latest configuration to every developer's machine on every Claude Code session, so standards propagate automatically.

**[Admin Guide](docs/admin-guide.md)** -- Setup, deployment, and operations.
**[User Guide](docs/user-guide.md)** -- Developer onboarding and daily usage.

## Repository structure

```
acme-claude-hub/
  plugin/              # Sync engine (do not modify)
  org/                 # Org-wide standards, MCP servers, and skills
  teams/
    frontend/          # Frontend team conventions and skills
    backend/           # Backend team conventions and skills
  examples/            # Reference material from upstream claude-hub
  docs/                # Admin and developer guides
```

## What we manage

### Organization level (`org/`)

Standards that apply to **every ACME developer**, regardless of team.

| File | Purpose |
|------|---------|
| `org/CLAUDE.md` | Serverless AWS coding standards (Python, SAM, Lambda, API Gateway, DynamoDB) |
| `org/settings.json` | Org-wide MCP servers (Jira, knowledge base, etc.) |
| `org/skills/` | Org-wide skills available to all developers |

**Org skills:**

| Skill | Invoked as | Purpose |
|-------|-----------|---------|
| [python-standards](org/skills/python-standards/SKILL.md) | `/hub-python-standards` | Python code style, Lambda handler patterns, logging, error handling |
| [dynamodb-standards](org/skills/dynamodb-standards/SKILL.md) | `/hub-dynamodb-standards` | Data modeling, queries, pagination, write safety |
| [sam-standards](org/skills/sam-standards/SKILL.md) | `/hub-sam-standards` | SAM template rules, IAM policies, deployment config |
| [testing-standards](org/skills/testing-standards/SKILL.md) | `/hub-testing-standards` | pytest, moto mocking, fixtures, coverage |
| [security-review](org/skills/security-review/SKILL.md) | `/hub-security-review` | Secrets, injection, OWASP Top 10, IAM review |
| [code-review](org/skills/code-review/SKILL.md) | `/hub-code-review` | Full PR review combining all standards |

### Frontend team (`teams/frontend/`)

Standards for the frontend team: React 18+, Next.js 14+, TypeScript, Tailwind CSS, Playwright E2E testing.

| File | Purpose |
|------|---------|
| [teams/frontend/CLAUDE.md](teams/frontend/CLAUDE.md) | Component patterns, accessibility (WCAG 2.1 AA), performance budgets, API integration |

**Frontend skills:**

| Skill | Invoked as | Purpose |
|-------|-----------|---------|
| [component-review](teams/frontend/skills/component-review/SKILL.md) | `/hub-component-review` | Reviews React components for structure, accessibility, performance, TypeScript |
| [e2e-test](teams/frontend/skills/e2e-test/SKILL.md) | `/hub-e2e-test` | Generates Playwright E2E tests with accessible selectors |

### Backend team (`teams/backend/`)

Standards for the backend team: Python Lambda services, DynamoDB single-table design, SQS/EventBridge async patterns, Step Functions orchestration.

| File | Purpose |
|------|---------|
| [teams/backend/CLAUDE.md](teams/backend/CLAUDE.md) | Service architecture, API design, async processing, gradual deployments |

**Backend skills:**

| Skill | Invoked as | Purpose |
|-------|-----------|---------|
| [api-design](teams/backend/skills/api-design/SKILL.md) | `/hub-api-design` | REST API design, pagination, auth, SAM template config |
| [load-test](teams/backend/skills/load-test/SKILL.md) | `/hub-load-test` | Generates Locust load test scripts |
| [async-workflow](teams/backend/skills/async-workflow/SKILL.md) | `/hub-async-workflow` | Reviews SQS, EventBridge, Step Functions for reliability and idempotency |

## How it works

The sync plugin runs on every Claude Code session start. It pulls this repo, reads the developer's team assignment from `~/.claude/claude-hub/team`, and assembles the configuration:

```
  Plugin syncs on every session:
    org/CLAUDE.md ──────────────┐
                                ├─> ~/.claude/CLAUDE.md  (org + team combined)
    teams/<team>/CLAUDE.md ─────┘

    org/skills/ ────────────────┐
                                ├─> ~/.claude/skills/hub-*
    teams/<team>/skills/ ───────┘

    org/settings.json ──────────┐
                                ├─> ~/.claude/settings.json  (mcpServers merged)
    teams/<team>/settings.json──┘
```

With MDM deployment, `org/CLAUDE.md` goes to the system managed policy path instead (non-overridable by users), and only team content syncs to `~/.claude/`. See the [Admin Guide](docs/admin-guide.md) for details.

The sync has a 5-minute cache TTL, never blocks a session, and falls back to cached files when offline.

## Developer setup

```bash
# 1. Clone this repo
git clone git@github.com:acme-org/claude-hub.git ~/.claude-hub

# 2. Install the plugin
claude plugin add ~/.claude-hub/plugin

# 3. Set your team
echo "frontend" > ~/.claude/claude-hub/team   # or "backend"

# 4. Start Claude Code -- sync happens automatically
```

## Adding a new team

```bash
cp -r teams/_template teams/new-team-name
# Edit teams/new-team-name/CLAUDE.md
# Add skills under teams/new-team-name/skills/
git add teams/new-team-name && git commit -m "feat: add new-team-name team" && git push
```

Developers on the new team update their team file: `echo "new-team-name" > ~/.claude/claude-hub/team`

## Updating standards

Edit files in `org/` or `teams/`, commit, and push. Developers pick up changes on their next Claude Code session start. For MDM deployments, also re-run the MDM script to update the managed policy files.
