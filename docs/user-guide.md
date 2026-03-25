# Claude Hub -- developer guide

Your organization uses Claude Hub to keep Claude Code configured consistently across developers and teams. This guide covers what it does and how to use it.

## What is Claude Hub?

Claude Hub loads your organization's standards and your team's conventions at the start of every session. You don't maintain any configuration yourself; it comes from a central Git repository and stays current automatically.

In practice, Claude Code already knows your org's coding standards and your team's conventions. Skills like code review and security review work without setup. When standards change upstream, you get the update next time you start a session.

### How standards reach your machine

Claude Code reads instructions from three layers, each refining or overriding the previous:

1. **Organization standards** -- coding standards, security policies, compliance requirements. Apply to everyone.
2. **Team conventions** -- your team's tech stack, branching model, testing standards. Layer on top of org.
3. **Project-level** -- any `CLAUDE.md` in the repository you're working in. Specific to that project.

How these get onto your machine is handled by your platform team. You don't need to configure anything.

## Getting started

### First-time setup

Your platform team may have already installed Claude Hub on your machine via MDM. If so, just start a Claude Code session.

If your org uses the manual setup (no MDM):

1. Clone the repo and run the setup script (ask your team lead which team name to use):
   ```bash
   git clone --depth=1 git@github.com:your-org/claude-hub.git ~/.claude/claude-hub/repo
   bash ~/.claude/claude-hub/repo/plugin/scripts/setup.sh --team your-team-name
   ```

2. Start a new Claude Code session. The sync runs automatically from now on.

**macOS users:** If you see `timeout: command not found` in `~/.claude/claude-hub/sync.log`, install GNU coreutils: `brew install coreutils`. The sync still works without it (falls back to cached files), but fetches won't have timeout protection.

### Verify it works

```bash
cat ~/.claude/CLAUDE.md     # Should contain your org and/or team instructions
ls ~/.claude/skills/        # Should show hub-* skills
```

## What you get

### Organization instructions

Claude Code follows your org's standards for code style, naming, code review, security, CI/CD, and deployment -- whatever your platform team has configured.

### Team instructions

Your team's conventions layer on top of org standards: tech stack and framework preferences, branching strategy, testing standards, and any team-specific overrides.

### MCP servers

Your org and team may configure MCP servers that give Claude Code access to external tools -- Jira, internal knowledge bases, artifact registries, that kind of thing. The configs sync to your machine like everything else and show up when you start a session.

If an MCP server requires authentication (a Jira instance behind SSO, for example), your platform team will provide credential setup instructions separately.

### Skills

Skills are reusable prompts you run with a slash command. There are three levels.

**Org skills** -- available to everyone, prefixed with `hub-`:

```
/hub-code-standards       Review code against org coding standards
/hub-security-review      Run a security review of changes
```

**Team skills** -- available to your team only, also prefixed with `hub-`:

```
/hub-api-design           Review REST API design, pagination, auth
/hub-load-test            Generate load test scripts
/hub-component-review     Review components for accessibility, performance
```

**Project skills** -- available only when working in a specific project. These come from the project's `.claude/skills/` directory (shipped via fragments) and have no prefix:

```
/deploy                   Validate, plan, and apply this Terraform configuration
/api-test                 Run integration tests against the deployed API
```

Type `/hub-` in Claude Code to see all available org and team skills. Type `/` and browse to see project skills.

## Day-to-day usage

### It's automatic

Every time you start a Claude Code session, the sync script checks for updates and applies them. If you're offline, it uses the last cached version.

### Switching teams

If you move to a different team:

```bash
echo "new-team-name" > ~/.claude/claude-hub/team
```

Start a new Claude Code session to pick up the new team's configuration.

### About ~/.claude/CLAUDE.md

The hub writes to `~/.claude/CLAUDE.md` with your org and team configuration. Don't edit this file manually -- it gets overwritten on each sync.

You can still use project-level `CLAUDE.md` files in your repositories. Those are separate and unaffected by hub sync.

## Working with project CLAUDE.md

Skip this section if your project wasn't created from a scaffolding template (Backstage, Cookiecutter, etc.).

Scaffolded projects come with a `CLAUDE.md` and a `.claude/` directory pre-configured. This gives Claude Code project-specific context from the first session.

### What's in a scaffolded project

When you create a project from a template, it includes:

| File | Purpose |
|---|---|
| `CLAUDE.md` | Toolchain reference (managed section) + your project notes (yours to edit) |
| `.claude/settings.json` | Pre-approved permissions (e.g., `terraform plan`, `pytest`, `curl`) |
| `.claude/skills/` | Project-type-specific skills (e.g., `deploy`, `api-test`) |
| `.claude/.fragment` | Version marker for drift detection |

The `CLAUDE.md` has two zones separated by markers:

```markdown
<!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
# Terraform Service — Toolchain Reference
... (toolchain commands, patterns, pitfalls) ...
<!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

# Project Notes
Add your content here...
```

### Using project skills

Scaffolded projects include skills tailored to that project type (listed in the table above). These skills know about the project's structure and toolchain -- for example, a deploy skill might validate, test, plan, and apply in sequence.

### Fragment updates

The platform team may update the toolchain reference (new commands, updated pitfalls, improved patterns). When this happens, the sync script detects the difference on your next session start and shows a notice.

To review and apply:

```
/hub-fragment-update
```

This shows a diff of each changed file, lets you pick which updates to apply, and replaces only the managed section between the markers. Your content below the end marker is never touched. Files in `.claude/` (settings, skills) can also be updated this way.

### Adding your own project context

After scaffolding, fill in the project notes section of `CLAUDE.md`. Write down architecture decisions (and why you made them), key database patterns, environment-specific setup steps, and pitfalls you've hit. The more concrete you are, the less Claude Code has to guess.

## Troubleshooting

**Claude Code doesn't seem to know our standards**
Check that the sync is set up. Depending on how your org deployed Claude Hub, the hook lives in one of two places:
```bash
# MDM installs -- hook comes from the plugin:
ls ~/.claude/plugins/local/claude-hub/hooks/hooks.json

# Manual installs -- hook is in settings.json:
cat ~/.claude/settings.json | python3 -c "import sys,json; h=json.load(sys.stdin).get('hooks',{}); print('SessionStart hook:', 'found' if 'SessionStart' in h else 'MISSING')"
```
If neither exists, follow the setup steps above or ask your platform team.

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

**My project was created from a template but has no `.claude/` directory**
The template may predate the fragment system. Ask your platform team for the correct fragment name, then copy it from the hub repo. For example, if the fragment is `python-lambda`:
```bash
cp -r ~/.claude/claude-hub/repo/examples/fragments/python-lambda/.claude .
cp ~/.claude/claude-hub/repo/examples/fragments/python-lambda/CLAUDE.md .
```

**Will hub sync overwrite my personal settings?**
The hub manages `~/.claude/CLAUDE.md`, `~/.claude/skills/hub-*`, and the `mcpServers` entries it placed in `~/.claude/settings.json`. It tracks which MCP servers it added and only touches those; your own settings and servers are left alone. Project-level `.claude/` files are never modified by hub sync.

