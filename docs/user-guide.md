# Claude Hub -- developer guide

Your organization uses Claude Hub to keep Claude Code configured consistently across developers and teams. This guide covers what it does and how to use it.

## What is Claude Hub?

Claude Hub is a Claude Code plugin that loads your organization's standards and your team's conventions at the start of every session. You don't maintain any configuration yourself; it comes from a central Git repository and stays current automatically.

In practice, Claude Code already knows your org's coding standards, review expectations, and security requirements. Your team's conventions are loaded too. Shared skills like code review and security review work without setup. When standards change, the update arrives on your next session start.

### How standards reach your machine

Claude Code reads instructions from multiple layers, in order:

1. Organization standards (coding standards, security policies, compliance requirements). How they reach your machine depends on your platform team's setup. With MDM, they're installed to a system path that Claude Code reads automatically -- always active, cannot be excluded. Without MDM, the sync plugin includes them in `~/.claude/CLAUDE.md`.
2. Team conventions -- your team's specific guidance, written to `~/.claude/CLAUDE.md` by the sync plugin.
3. Project-level -- any `CLAUDE.md` in the repository you're working in. Maintained by your team, specific to that project.

You don't need to know which deployment method your org uses. It's handled for you.

## Getting started

### First-time setup

Your platform team may have already installed Claude Hub on your machine via MDM. If so, just start a Claude Code session.

If your org uses the manual (plugin-only) setup:

1. Clone the hub repository:
   ```bash
   git clone git@github.com:your-org/claude-hub.git ~/.claude-hub
   ```

2. Create the config directory and set your team:
   ```bash
   mkdir -p ~/.claude/claude-hub
   echo "https://github.com/your-org/claude-hub.git" > ~/.claude/claude-hub/repo_url
   echo "your-team-name" > ~/.claude/claude-hub/team
   ```
   Ask your team lead which team name to use.

3. Add the SessionStart hook to `~/.claude/settings.json`. Add this inside the `"hooks"` object (create the file and object if they don't exist):
   ```json
   "SessionStart": [
     {
       "matcher": "*",
       "hooks": [
         {
           "type": "command",
           "command": "bash ~/.claude-hub/plugin/scripts/sync.sh",
           "timeout": 15
         }
       ]
     }
   ]
   ```

4. Clone the repo and run the initial sync:
   ```bash
   git clone --depth=1 "$(cat ~/.claude/claude-hub/repo_url)" ~/.claude/claude-hub/repo
   bash ~/.claude-hub/plugin/scripts/sync.sh
   ```

5. Start a new Claude Code session. The sync runs automatically from now on.

**macOS users:** If you see `timeout: command not found` in `~/.claude/claude-hub/sync.log`, install GNU coreutils: `brew install coreutils`. The sync still works without it (falls back to cached files), but installs and fetches won't have timeout protection.

### Verify it works

```bash
cat ~/.claude/CLAUDE.md     # Should contain your org and/or team instructions
ls ~/.claude/skills/        # Should show hub-* skills
```

## What you get

### Organization instructions

Claude Code follows your org's standards for code style, naming, code review, security, CI/CD, and deployment -- whatever your platform team has configured.

These come from `org/CLAUDE.md` in the central repo. With MDM, they're loaded from a system path and cannot be excluded. Without MDM, they're part of `~/.claude/CLAUDE.md`.

### Team instructions

Your team's conventions layer on top of org standards: tech stack and framework preferences, branching strategy, testing standards, and any team-specific overrides.

### MCP servers

Your org and team may configure MCP servers that give Claude Code access to external tools and data -- things like Jira, internal knowledge bases, artifact registries, or team-specific services. These are set up centrally and synced to your machine alongside everything else. They show up automatically when you start a session.

If an MCP server requires authentication (a Jira instance behind SSO, for example), your platform team will provide credential setup instructions separately.

### Skills

Skills are reusable prompts you run with a slash command. There are three levels of skills, each serving a different purpose.

**Org skills** -- available to everyone, prefixed with `hub-`:

```
/hub-code-review          Full PR review combining all org standards
/hub-python-standards     Review Python code style, handler patterns, logging
/hub-dynamodb-standards   Check DynamoDB data modeling, pagination, write safety
/hub-sam-standards        Review SAM templates for IAM, naming, deployment config
/hub-testing-standards    Check pytest/moto usage, fixtures, coverage
/hub-security-review      Run a security review of changes
/hub-fragment-update      Review and apply updates to project toolchain config
```

**Team skills** -- available to your team only, also prefixed with `hub-`:

```
# Backend team examples
/hub-api-design           Review REST API design, pagination, auth
/hub-load-test            Generate Locust load test scripts
/hub-async-workflow       Review SQS/EventBridge patterns for reliability

# Frontend team examples
/hub-component-review     Review React components for accessibility, performance
/hub-e2e-test             Generate Playwright E2E tests
```

**Project skills** -- available only when working in a specific project. These come from the project's `.claude/skills/` directory (shipped via fragments) and have no prefix:

```
/sam-deploy               Build, validate, and deploy this SAM application
/api-test                 Run integration tests against the deployed API
```

Type `/hub-` in Claude Code to see all available org and team skills. Type `/` and browse to see project skills.

## Day-to-day usage

### It's automatic

Every time you start a Claude Code session, the plugin checks for updates and applies them. If you're offline, it uses the last cached version.

### Switching teams

If you move to a different team:

```bash
echo "new-team-name" > ~/.claude/claude-hub/team
```

Start a new Claude Code session to pick up the new team's configuration.

### About ~/.claude/CLAUDE.md

The hub writes to `~/.claude/CLAUDE.md` for team conventions (and org standards in plugin-only mode). Don't edit this file manually -- it gets overwritten on each sync.

You can still use project-level `CLAUDE.md` files in your repositories. Those are separate and unaffected by hub sync.

## Working with project CLAUDE.md

Projects created from Backstage templates come with a `CLAUDE.md` and a `.claude/` directory pre-configured. This gives Claude Code project-specific context from the first session.

### What's in a scaffolded project

When you create a service from a Backstage template, it includes:

| File | Purpose |
|---|---|
| `CLAUDE.md` | Toolchain reference (managed section) + your project notes (yours to edit) |
| `.claude/settings.json` | Pre-approved permissions (e.g., `sam build`, `pytest`, `curl`) |
| `.claude/skills/` | Project-type-specific skills (e.g., `sam-deploy`, `api-test`) |
| `.claude/.fragment` | Version marker for drift detection |

The `CLAUDE.md` has two zones separated by markers:

```markdown
<!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
# SAM API Service — Toolchain Reference
... (build commands, testing patterns, handler patterns, pitfalls) ...
<!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

# Project Notes
Add your content here: architecture decisions, access patterns, deployment notes...
```

### What the markers mean

Everything between the markers is managed by your platform team: build commands, testing patterns, framework pitfalls. Don't edit this section; it gets replaced when updates come in.

Everything below the end marker is yours. Architecture notes, project conventions, lessons learned, deployment notes -- write whatever helps. This section is **never touched** by updates.

### Using project skills

Projects include skills tailored to that project type. Run them like any other skill:

```
/sam-deploy               Build, validate, and deploy the SAM application
/api-test                 Run or generate integration tests against the deployed API
```

These skills know about your project's structure and toolchain. For example, `/sam-deploy` validates the template, runs tests, deploys, and verifies the stack -- all in sequence.

### Fragment updates

The platform team may update the toolchain reference (new commands, updated pitfalls, improved patterns). When this happens, the sync plugin detects the difference on your next session start and shows a notice.

To review and apply:

```
/hub-fragment-update
```

This shows a diff of each changed file, lets you pick which updates to apply, and replaces only the managed section between the markers. Your content below the end marker is never touched. Files in `.claude/` (settings, skills) can also be updated this way.

### Adding your own project context

After scaffolding, enrich the project notes section of `CLAUDE.md` with:

- **Architecture decisions** -- why you chose certain patterns, data models, or trade-offs.
- **Access patterns** -- DynamoDB key design, GSI usage, query patterns.
- **Deployment notes** -- environment-specific configuration, seed data steps.
- **Lessons learned** -- pitfalls you hit, workarounds, things to watch for.

This context helps Claude Code give more accurate, project-aware responses. The more specific you are, the better the assistance.

## Troubleshooting

**Claude Code doesn't seem to know our standards**
Check that the SessionStart hook is configured in `~/.claude/settings.json`:
```bash
cat ~/.claude/settings.json | python3 -c "import sys,json; h=json.load(sys.stdin).get('hooks',{}); print('SessionStart hook:', 'found' if 'SessionStart' in h else 'MISSING')"
```
If missing, follow the setup steps above to add the hook.

**My team's conventions aren't showing up**
Check your team file:
```bash
cat ~/.claude/claude-hub/team
```
If it's empty or wrong, set it and restart Claude Code.

**Skills aren't available**
Start a new Claude Code session. Skills are copied during sync. Type `/hub-` and see if any appear.

**Configuration seems stale**
The sync caches for 5 minutes. Close and reopen Claude Code. If it persists:
```bash
cat ~/.claude/claude-hub/sync.log
```

**Working offline**
Claude Hub works offline using cached files from the last successful sync. You won't get updates until you're back online, but nothing breaks.

## FAQ

**Can I override org standards for my project?**
Yes. Put project-specific instructions in your repository's `CLAUDE.md` (below the fragment end marker if the project uses fragments). Claude Code reads both user-level and project-level files, and project-level takes precedence for that project.

**Can I add my own skills?**
Yes. Create skill directories under `~/.claude/skills/` for personal skills, or under your project's `.claude/skills/` for project-specific skills. Don't use the `hub-` prefix, which is reserved for synced skills.

**What's the difference between hub skills and project skills?**
Hub skills (`/hub-*`) come from the central claude-hub repo and are synced to your machine. They cover org-wide and team-wide concerns (code review, security, standards). Project skills (no prefix) live in the project's `.claude/skills/` directory and are specific to that project type (deploy, test, inspect). Both are available as slash commands.

**My project was created from Backstage but has no `.claude/` directory**
The template may predate the fragment system. Ask your platform team for the correct fragment type, then manually copy it:
```bash
cp -r ~/.claude/claude-hub/repo/fragments/sam-api/.claude .
cp ~/.claude/claude-hub/repo/fragments/sam-api/CLAUDE.md .
```

**Will hub sync overwrite my personal settings?**
The hub manages `~/.claude/CLAUDE.md`, `~/.claude/skills/hub-*`, and the `mcpServers` entries it placed in `~/.claude/settings.json`. It tracks which MCP servers it added and only touches those; your own settings and servers are left alone. Project-level `.claude/` files are never modified by hub sync.

**What if the central repo is unavailable?**
The sync script uses the last cached version. Your session starts normally -- you just won't get updates that happened while you were disconnected.

**How often does it update?**
Every session start, with a 5-minute cache to skip redundant work. It won't re-sync mid-session; updates arrive when you start the next one.

**How do I know if my project's toolchain config is outdated?**
The sync plugin checks automatically. If a drift notice appears at session start mentioning your project, run `/hub-fragment-update` to see what changed and selectively apply updates.
