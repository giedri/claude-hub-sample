# claude-hub

Centralized Claude Code configuration for teams and organizations.

Claude Code reads [CLAUDE.md](https://code.claude.com/docs/en/memory) files to know how to behave: what standards to follow, what tools to use, what patterns to prefer. Without something distributing these files, each developer sets up Claude Code on their own. Some follow your security policies. Some don't know they exist.

Claude Hub syncs organizational configuration from a single Git repo to every developer's machine. One repo controls:

- Org standards and team conventions, written as CLAUDE.md files Claude follows in every session
- MCP server connections, plugin marketplaces, and auto-enabled plugins
- Per-team configuration: different teams get different guidance, skills, and tools, layered on a shared org baseline
- Project scaffolding: Backstage (or similar) templates ship a `.claude/` directory with toolchain guidance, pre-approved permissions, and project-type skills, with drift detection when the central template changes
- Enforcement boundaries: org-level policies go to MDM-managed system paths users can't override; team-level settings remain user-modifiable

Developers open Claude Code and the configuration is already in place. Nothing to install or remember.

### Why not just a marketplace plugin?

Claude Code's [plugin marketplace](https://code.claude.com/docs/en/plugins) distributes reusable tools and workflows. Plugins run inside the boundaries Claude Code gives them. They can't change those boundaries, and that's where Claude Hub operates.

A plugin can add skills and hooks. It can't write CLAUDE.md files, which are the primary way to tell Claude how to behave. It can't push MCP server configs, marketplace registrations, or `enabledPlugins` into developer settings. It can't deploy anything to the managed policy path where MDM puts files users can't remove. And it serves the same content to everyone; there's no way to give the frontend team different guidance than the platform team.

Claude Hub handles all of that. It also handles cleanup: when you remove an MCP server or marketplace from the hub repo, the sync script removes it from every developer's settings on the next session. And for project scaffolding, the fragment system ships `.claude/` directories with new repos and detects when the central template drifts.

Claude Hub can also distribute marketplace plugins. You can register internal marketplaces, auto-enable specific plugins, and restrict which marketplaces developers are allowed to add.

**[Admin Guide](docs/admin-guide.md):** Setup, deployment, and configuration for platform engineers.
**[User Guide](docs/user-guide.md):** Developer onboarding and daily usage.

## Repository structure

```
claude-hub/
  plugin/          # Claude Code plugin (sync script + SessionStart hook) -- install as-is
  org/             # Your org's standards, MCP servers, and skills -- customize these
  teams/           # Your teams' conventions, MCP servers, and skills -- one directory per team
  examples/        # Samples and optional features -- copy what you need
  docs/            # Guides for admins and developers
```

## What gets distributed

Each item targets a different level of the [CLAUDE.md hierarchy](https://code.claude.com/docs/en/memory):

| What | Scope | Example |
|---|---|---|
| **CLAUDE.md** | Instructions Claude follows in every session | Coding standards, security policies, review expectations |
| **Skills** | Slash-command workflows developers invoke on demand | `/hub-infra-review`, `/hub-security-review`, `/hub-deploy` |
| **MCP servers** | Tool connections distributed centrally | Jira, internal knowledge base, artifact registry |
| **Plugin marketplaces** | Private marketplace registrations and auto-enabled plugins | Internal plugin catalog, approved third-party plugins |
| **Fragments** | Project-level `.claude/` configs shipped via scaffolding | Pre-approved permissions, project-type skills, toolchain reference |

Fragments extend this beyond runtime configuration. When a developer creates a new project from a Backstage (or similar) template, the project arrives with a complete `.claude/` directory: a project CLAUDE.md with toolchain-specific guidance, pre-approved permissions, and project-type skills, ready to use from the first session.

## How it works

Configuration reaches developers through two channels:

| Layer | Deployed to | Managed by | Modifiable by user |
|---|---|---|---|
| Org standards | [System managed policy path](https://code.claude.com/docs/en/third-party-integrations#best-practices-for-organizations) | MDM (or sync script) | No (when using managed policy) |
| Org MCP servers | System managed policy `managed-settings.json` | MDM (or sync script) | No (when using managed policy) |
| Org marketplaces & plugins | System managed policy `managed-settings.json` | MDM (or sync script) | No (when using managed policy) |
| Marketplace restrictions | System managed policy `managed-settings.json` | MDM | No |
| Team conventions | `~/.claude/CLAUDE.md` | Sync script | Yes |
| Team MCP servers | `~/.claude/settings.json` | Sync script | Yes |
| Team marketplaces & plugins | `~/.claude/settings.json` | Sync script | Yes |
| Skills | `~/.claude/skills/hub-*` | Sync script | Yes |

### With MDM (recommended)

MDM deploys `org/CLAUDE.md` to the [system managed policy path](https://code.claude.com/docs/en/third-party-integrations#best-practices-for-organizations) where Claude Code reads it automatically. Users can't modify or exclude it. The sync script handles team content, skills, and settings merging.

```
  MDM deploys & keeps current:
    org/CLAUDE.md ──────> /Library/Application Support/ClaudeCode/CLAUDE.md
    org/settings.json ──> /Library/Application Support/ClaudeCode/managed-settings.json
                          (or /etc/claude-code/ on Linux)
                          (includes mcpServers, marketplaces, plugins, restrictions)

  Sync script runs on every session start:
    teams/<team>/CLAUDE.md ───> ~/.claude/CLAUDE.md

    org/skills/ ──────────────┐
                              ├─> ~/.claude/skills/hub-*
    teams/<team>/skills/ ─────┘

    org/settings.json ────────┐  mcpServers,
                              ├─> ~/.claude/settings.json  extraKnownMarketplaces,
    teams/<team>/settings.json┘  enabledPlugins (merged)
```

This is not a one-time setup. When you update `org/CLAUDE.md` in this repo, re-run the MDM deployment to push the new version. A scheduled MDM policy (daily Jamf policy, Ansible playbook, Intune script) works well. You can also trigger from CI/CD on push to `org/CLAUDE.md`, or re-run manually when changes are infrequent.

See the [Admin Guide](docs/admin-guide.md#option-a-mdm-deployment-recommended) for platform-specific deployment scripts.

### Without MDM (manual setup)

The sync script writes both org and team content to the user-level `~/.claude/CLAUDE.md`. Simpler to set up, but users can override it.

```
  Sync script runs on every session start:
    org/CLAUDE.md ──────────────┐
                                ├─> ~/.claude/CLAUDE.md  (org + team combined)
    teams/<team>/CLAUDE.md ─────┘

    org/skills/ ────────────────┐
                                ├─> ~/.claude/skills/hub-*
    teams/<team>/skills/ ───────┘

    org/settings.json ──────────┐  mcpServers,
                                ├─> ~/.claude/settings.json  extraKnownMarketplaces,
    teams/<team>/settings.json──┘  enabledPlugins (merged)
```

The sync script auto-detects which mode to use: if a managed policy org CLAUDE.md exists on the system, it writes team content only; otherwise it writes org + team combined. See the [Admin Guide](docs/admin-guide.md#option-b-manual-setup-no-mdm) for setup instructions and [Sync script](#sync-script) below for operational details.

## What's in the repo

Three parts. Knowing which is which matters.

### 1. Plugin infrastructure: `plugin/`

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

### 2. Your organization's content: `org/` and `teams/`

This is where your organization's standards and team conventions live.

`org/` has the org CLAUDE.md (`org/CLAUDE.md`), settings (MCP servers, marketplaces), and skills. Every developer gets this. Start by replacing the starter files with your actual standards. `teams/` has team-specific overlays. Each team gets a directory with its own team CLAUDE.md, settings, and skills, layered on top of org content. A `_template/` is provided for creating new teams.

```
org/
  CLAUDE.md                     # Org CLAUDE.md — base instructions for ALL developers
  settings.json                 # Org-wide MCP servers and permissions
  skills/                       # Org-wide skills (developers run /hub-<name> in Claude Code)
teams/
  _template/                    # Copy this to create a new team
  frontend/                     # Example: a frontend team
    CLAUDE.md                   #   Team CLAUDE.md — team-specific instructions
    settings.json               #   Team MCP servers (merged with org)
    skills/                     #   Team-specific skills
```

### 3. Reference material: `examples/` and `docs/`

Samples, optional features, and documentation. Nothing here is required. Copy what you need.

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

Each run pulls the repo into `~/.claude/claude-hub/repo/` and reads the developer's team. From there it builds the user-level `~/.claude/CLAUDE.md` (from org + team, or team-only when MDM handles org content), copies skills into `~/.claude/skills/` with a `hub-` prefix, and merges settings from `org/settings.json` and `teams/<team>/settings.json` into `~/.claude/settings.json`: MCP servers, plugin marketplace registrations (`extraKnownMarketplaces`), and auto-enabled plugins (`enabledPlugins`). If the current project has a `.claude/.fragment` marker, it checks for fragment drift too.

The script never blocks a session. It exits 0 regardless of what goes wrong: network failure, missing repo, bad config. When a fetch fails (offline, VPN down, expired credentials), it uses whatever was last pulled and logs a warning.

To skip redundant work, it caches the last sync timestamp and repo HEAD hash. If less than 5 minutes have passed and HEAD hasn't changed, it bails out. A file lock prevents concurrent sessions from racing. The log at `~/.claude/claude-hub/sync.log` is truncated at 100KB.

### What lands on a developer's machine

This is the full file layout created by the sync process. MDM-only items are marked; everything else is created by the sync script or setup script.

```
/Library/Application Support/ClaudeCode/   (macOS; /etc/claude-code/ on Linux)
  CLAUDE.md                    # [MDM only] Org CLAUDE.md — enforced, users can't override
  managed-settings.json        # [MDM only] Org managed settings (MCP servers, marketplaces,
                               #   plugins, strictKnownMarketplaces restrictions)
                               #   Must be named managed-settings.json, not settings.json.

~/.claude/
  CLAUDE.md                    # User-level CLAUDE.md — built by sync from org + team,
                               #   or team-only when MDM handles org content.
                               #   Includes fragment drift notices if any projects are outdated.
  settings.json                # User-level settings — sync merges these keys into it:
                               #   mcpServers (org + team, team wins on conflict)
                               #   extraKnownMarketplaces (org + team)
                               #   enabledPlugins (org + team)
                               #   Other keys (hooks, permissions, etc.) are left untouched.
  skills/
    hub-code-standards/        # Org skill — from org/skills/code-standards/
      SKILL.md
    hub-security-review/       # Org skill — from org/skills/security-review/
      SKILL.md
    hub-api-design/            # Team skill — from teams/<team>/skills/api-design/
      SKILL.md                 #   (team skills override org skills with the same name)
    ...                        # Personal skills (no hub- prefix) are unaffected

  claude-hub/                  # Hub working directory
    repo/                      # Shallow clone of the central claude-hub Git repo
    team                       # Developer's team assignment (one line, e.g. "frontend")
    repo_url                   # Git remote URL of the central repo
    sync.log                   # Sync log (truncated at 100KB)
    last_sync                  # Timestamp + HEAD hash for TTL cache
    .lock                      # File lock to prevent concurrent syncs
    managed_mcp_servers        # Names of MCP servers placed by hub (for cleanup)
    managed_marketplaces       # Names of marketplaces placed by hub (for cleanup)
    managed_plugins            # Names of plugins placed by hub (for cleanup)
    drift/                     # Fragment drift state
      <hash>.json              # One file per project with outdated fragment

  plugins/                     # [MDM only] Claude Code plugin registration
    local/claude-hub/          #   Plugin files (hooks/hooks.json, scripts/sync.sh)
    installed_plugins.json     #   Plugin registry (lists claude-hub)
```

With manual setup (no MDM), there are no system-level files and no `~/.claude/plugins/` entries. Instead, the SessionStart hook is written directly into `~/.claude/settings.json` under the `hooks` key.

Fragment-based projects (not created by sync, but checked by it) have their own layout at the project root:

```
<project>/
  CLAUDE.md                    # Project CLAUDE.md — managed section (between markers)
                               #   + project-specific notes (below end marker)
  .claude/
    .fragment                  # Version marker (fragment name + SHA-256 hash)
    settings.json              # Project-level settings (pre-approved permissions)
    skills/
      deploy/SKILL.md          # Project-type-specific skills (no hub- prefix)
```

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
         CLAUDE.md              ──┘     (project CLAUDE.md)

  2. Developer creates a new project from the template.
     Fragment files end up in the new repo:

     New project repo
     ────────────────
     my-service/
       .claude/
         settings.json          # From fragment
         skills/deploy/         # From fragment
         .fragment              # Hash marker for drift detection
       CLAUDE.md                # Project CLAUDE.md (managed section + empty project section)
       src/                     # From other template steps
       ...
```

The project CLAUDE.md in the new repo has two zones separated by markers:

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

  4. Drift notice appears in user-level ~/.claude/CLAUDE.md:
     "Project at /path/to/my-service uses fragment terraform-service
      which has updates. Use /hub-fragment-update to review and apply."

  5. Developer runs /hub-fragment-update (when ready)
     ├── Shows diff of each changed file
     ├── Replaces only content between markers in project CLAUDE.md
     ├── Updates .claude/ files (settings, skills)
     └── Rewrites .fragment with new hash
```

The hash comparison uses file contents (SHA-256), not git commits. Cherry-picks or reverts that produce identical content are correctly detected as matching. Updates are opt-in. Drift detection only reads project files, never modifies them.

See the [Admin Guide](docs/admin-guide.md#project-fragments) for fragment setup and the [User Guide](docs/user-guide.md#fragment-updates) for usage.
