# claude-hub

Centralized Claude Code configuration management for teams and organizations.

A Claude Code plugin backed by a Git repository that keeps every developer's CLAUDE.md and skills in sync. A SessionStart hook pulls the latest configuration on every session, so standards and guardrails propagate without anyone doing anything.

**[Admin Guide](docs/admin-guide.md)** -- Setup, deployment, and configuration for platform engineers.
**[User Guide](docs/user-guide.md)** -- Developer onboarding and daily usage.

## Repository structure

```
claude-hub/
  plugin/          # Claude Code plugin (sync script + SessionStart hook) -- install as-is
  org/             # Your org's standards, MCP servers, and skills -- customize these
  teams/           # Your teams' conventions, MCP servers, and skills -- one directory per team
  examples/        # Samples and optional features -- copy what you need
  docs/            # Guides for admins and developers
```

## How it works

Claude Hub distributes configuration through two channels that map to Claude Code's [CLAUDE.md hierarchy](https://code.claude.com/docs/en/memory):

| Layer | Deployed to | Managed by | Modifiable by user |
|---|---|---|---|
| Org standards | [System managed policy path](https://code.claude.com/docs/en/third-party-integrations#best-practices-for-organizations) | MDM (or sync script) | No (when using managed policy) |
| Org MCP servers | System managed policy `settings.json` | MDM (or sync script) | No (when using managed policy) |
| Team conventions | `~/.claude/CLAUDE.md` | Sync script | Yes |
| Team MCP servers | `~/.claude/settings.json` | Sync script | Yes |
| Skills | `~/.claude/skills/hub-*` | Sync script | Yes |

### With MDM (recommended)

MDM deploys `org/CLAUDE.md` to the [system managed policy path](https://code.claude.com/docs/en/third-party-integrations#best-practices-for-organizations) where Claude Code reads it automatically. Users can't modify or exclude it. The sync script handles team content and skills.

```
  MDM deploys & keeps current:
    org/CLAUDE.md ──────> /Library/Application Support/ClaudeCode/CLAUDE.md
    org/settings.json ──> /Library/Application Support/ClaudeCode/settings.json
                          (or /etc/claude-code/ on Linux)

  Sync script runs on every session start:
    teams/<team>/CLAUDE.md ───> ~/.claude/CLAUDE.md

    org/skills/ ──────────────┐
                              ├─> ~/.claude/skills/hub-*
    teams/<team>/skills/ ─────┘

    org/settings.json ────────┐
                              ├─> ~/.claude/settings.json  (mcpServers merged)
    teams/<team>/settings.json┘
```

This is not a one-time setup. When you update `org/CLAUDE.md` in this repo, re-run the MDM deployment to push the new version. A scheduled MDM policy (daily Jamf policy, Ansible playbook, Intune script) works well. You can also trigger from CI/CD on push to `org/CLAUDE.md`, or re-run manually when changes are infrequent.

See the [Admin Guide](docs/admin-guide.md#option-a-mdm-deployment-recommended) for platform-specific deployment scripts.

### Without MDM (manual setup)

The sync script writes both org and team content to `~/.claude/CLAUDE.md`. Simpler to set up, but users can override it.

```
  Sync script runs on every session start:
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

The sync script auto-detects which mode to use: if a managed policy CLAUDE.md exists on the system, it writes team content only; otherwise it writes org + team combined. See the [Admin Guide](docs/admin-guide.md#option-b-manual-setup-no-mdm) for setup instructions and [Sync script](#sync-script) below for operational details.

## What's in the repo

Three kinds of content. Knowing which is which matters.

### 1. Plugin infrastructure -- `plugin/`

The engine. You shouldn't need to modify it.

Contains the Claude Code plugin definition, the SessionStart hook, and the sync script that pulls configuration from this repo onto every developer's machine.

```
plugin/
  .claude-plugin/
    plugin.json                 # Plugin metadata
  hooks/
    hooks.json                  # SessionStart hook definition
  scripts/
    sync.sh                     # Sync script (runs on every session start)
    setup.sh                    # Manual setup helper (no-MDM installs)
```

### 2. Your organization's content -- `org/` and `teams/`

This is where your organization's standards and team conventions live.

`org/` has org-wide CLAUDE.md, settings (MCP servers), and skills. Every developer gets this. Start by replacing the starter files with your actual standards. `teams/` has team-specific overlays. Each team gets a directory with its own CLAUDE.md, settings, and skills, layered on top of org content. A `_template/` is provided for creating new teams.

```
org/
  CLAUDE.md                     # Base instructions for ALL developers
  settings.json                 # Org-wide MCP servers and permissions
  skills/                       # Org-wide skills (developers run /hub-<name> in Claude Code)
teams/
  _template/                    # Copy this to create a new team
  frontend/                     # Example: a frontend team
    CLAUDE.md                   #   Team-specific instructions
    settings.json               #   Team MCP servers (merged with org)
    skills/                     #   Team-specific skills
```

### 3. Reference material -- `examples/` and `docs/`

Samples, optional features, and documentation. Nothing here is required -- copy what you need.

```
examples/
  org/              # Sample org CLAUDE.md and skills to use as starting points
  teams/            # Sample team structures
  fragments/        # Project scaffolding templates for Backstage or similar tools
  scripts/          # Fragment tooling (generate-markers.sh)
  mdm/              # Enterprise MDM deployment scripts for macOS, Linux, and Windows
docs/
  admin-guide.md    # Setup, deployment, and operations
  user-guide.md     # Developer onboarding and daily usage
```

## Sync script

The sync script (`plugin/scripts/sync.sh`) runs on every Claude Code session start via a SessionStart hook.

Each run pulls the repo into `~/.claude/claude-hub/repo/` and reads the developer's team. From there it builds `~/.claude/CLAUDE.md` (org + team, or team-only when MDM handles org content), copies skills into `~/.claude/skills/` with a `hub-` prefix, and merges MCP server configs into `~/.claude/settings.json`. If the current project has a `.claude/.fragment` marker, it checks for fragment drift too.

The script never blocks a session. It exits 0 regardless of what goes wrong: network failure, missing repo, bad config. When a fetch fails (offline, VPN down, expired credentials), it uses whatever was last pulled and logs a warning.

To skip redundant work, it caches the last sync timestamp and repo HEAD hash. If less than 5 minutes have passed and HEAD hasn't changed, it bails out. A file lock prevents concurrent sessions from racing. The log at `~/.claude/claude-hub/sync.log` is truncated at 100KB.

## Fragment system (optional)

If your org uses Backstage or another scaffolding tool to create new repos, fragments let you ship a ready-made `.claude/` configuration with each project type.

### How fragments get into projects

A platform engineer configures a scaffolding template (Backstage, Cookiecutter, etc.) to reference fragment files from this repo. The template definition points at the fragment directory; the scaffolding tool copies those files into new projects like any other template file.

```
  1. Template references fragment files in claude-hub:

     claude-hub repo                    Backstage template definition
     ──────────────                     ────────────────────────────
     examples/fragments/
       terraform-service/
         .claude/settings.json  ──┐
         .claude/skills/        ──┼──>  fetch:plain step points here
         .claude/.fragment      ──┤
         CLAUDE.md              ──┘

  2. Developer creates a new project from the template.
     Fragment files end up in the new repo:

     New project repo
     ────────────────
     my-service/
       .claude/
         settings.json          # From fragment
         skills/deploy/         # From fragment
         .fragment              # Hash marker for drift detection
       CLAUDE.md                # Managed section + empty project section
       src/                     # From other template steps
       ...
```

The `CLAUDE.md` in the new project has two zones separated by markers:

```markdown
<!-- claude-hub:fragment:begin — managed centrally, do not edit manually -->
# Terraform Service — Toolchain Reference
(build commands, testing patterns, framework pitfalls)
<!-- claude-hub:fragment:end — project-specific content below -->

# Project Notes
(developer adds architecture notes, lessons learned, etc.)
```

Everything above the end marker is managed centrally and gets replaced on updates. Everything below it belongs to the project.

### How drift detection works

When the platform team updates a fragment in claude-hub (new toolchain guidance, updated settings), the sync script detects that a project's copy is outdated:

```
  On every Claude Code session start:

  1. sync.sh checks: does $PWD/.claude/.fragment exist?
     ├── No  → skip (not a fragment-based project)
     └── Yes → read fragment name and hash

  2. Look up source fragment in claude-hub repo
     └── Compute SHA-256 of current source files

  3. Compare hashes
     ├── Match    → project is up to date, no action
     └── Mismatch → write drift notice

  4. Drift notice appears in ~/.claude/CLAUDE.md:
     "Project at /path/to/my-service uses fragment terraform-service
      which has updates. Use /hub-fragment-update to review and apply."

  5. Developer runs /hub-fragment-update (when ready)
     ├── Shows diff of each changed file
     ├── Replaces only content between markers in CLAUDE.md
     ├── Updates .claude/ files (settings, skills)
     └── Rewrites .fragment with new hash
```

The hash comparison uses file contents (SHA-256), not git commits. Cherry-picks or reverts that produce identical content are correctly detected as matching. Updates are opt-in -- drift detection only reads project files, it never modifies them.

See the [Admin Guide](docs/admin-guide.md#project-fragments) for fragment setup and the [User Guide](docs/user-guide.md#fragment-updates) for usage.
