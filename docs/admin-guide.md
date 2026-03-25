# Admin guide

Setup, deployment, and configuration for platform engineers managing claude-hub.

## Prerequisites

- Claude Code CLI installed on developer machines
- Git on PATH
- Read access to the central claude-hub Git repository (SSH key, PAT, or GitHub App)

## Initial setup

The repo has three parts. `plugin/` is the sync engine -- use it as-is. `org/` and `teams/` hold your actual standards and conventions. `examples/` has reference material you can copy if useful. See the [README](../README.md#repository-structure) for the full layout.

### 1. Fork and customize

Fork or clone this repository into your organization's Git hosting:

```bash
git clone git@github.com:your-org/claude-hub.git
cd claude-hub
```

### 2. Write your org CLAUDE.md

Replace the starter `org/CLAUDE.md` with your organization's standards. `examples/org/CLAUDE.md` has a sample covering coding standards, code review, security, CI/CD, and communication conventions. If your org uses MCP servers, see [MCP servers](#mcp-servers) after completing deployment.

### 3. Add org skills (optional -- can do later)

Copy example skills or create your own under `org/skills/`:

```bash
# Copy example skills
cp -r examples/org/skills/code-standards org/skills/
cp -r examples/org/skills/security-review org/skills/

# Or create a new skill
mkdir org/skills/my-skill
# Edit org/skills/my-skill/SKILL.md
```

Each skill is a directory containing a `SKILL.md` file. Developers run them as `/hub-<skill-name>` in Claude Code.

### 4. Create teams (optional -- can do later)

```bash
cp -r teams/_template teams/frontend
# Edit teams/frontend/CLAUDE.md with team-specific instructions
# Add team skills under teams/frontend/skills/
```

Repeat for each team. `examples/teams/` has sample team structures. You can start with just org content and add teams later.

### 5. Commit and push

```bash
git add .
git commit -m "Configure claude-hub for our organization"
git push
```

## Deployment

Two approaches. Pick whichever fits your infrastructure.

### Option A: MDM deployment (recommended)

Uses your existing MDM solution to deploy org-wide standards to Claude Code's [managed policy path](https://code.claude.com/docs/en/third-party-integrations#best-practices-for-organizations), a system-level location that Claude Code reads automatically and users cannot exclude. The sync script handles team content and skills separately.

| Content | Deployed by | Location |
|---|---|---|
| Org CLAUDE.md | MDM | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) |
| | | `/etc/claude-code/CLAUDE.md` (Linux) |
| | | `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows) |
| Org settings.json | MDM | Same directory as CLAUDE.md above |
| (MCP servers, permissions) | | |
| Team CLAUDE.md | Sync script | `~/.claude/CLAUDE.md` |
| Team MCP servers | Sync script | `~/.claude/settings.json` (merged) |
| Skills | Sync script | `~/.claude/skills/hub-*` |

Users cannot exclude or override managed policy files, so security policies, compliance requirements, and org-wide MCP servers stay active regardless. The sync script detects the managed policy and writes only team content to `~/.claude/CLAUDE.md` and team MCP servers to `~/.claude/settings.json`.

`examples/mdm/` has deployment scripts for each platform. Each script clones the claude-hub repo, copies `org/CLAUDE.md` and `org/settings.json` to the managed policy path (requires admin/root), configures the SessionStart hook for the user, and sets the team based on group membership.

#### macOS (Jamf Pro)

```bash
# Run as Jamf policy script with parameters:
#   $4 = team name, $5 = repo URL
sudo bash examples/mdm/deploy-macos.sh
```

Writes to `/Library/Application Support/ClaudeCode/CLAUDE.md`. Sets team from Jamf group membership or extension attributes.

#### Linux (Ansible/Chef/Puppet)

```bash
CLAUDE_HUB_TEAM="platform" \
CLAUDE_HUB_REPO_URL="https://github.com/your-org/claude-hub.git" \
sudo bash examples/mdm/deploy-linux.sh
```

Writes to `/etc/claude-code/CLAUDE.md`. Sets team from LDAP group, host role, or inventory variable.

#### Windows (Intune)

```powershell
# Run as Intune script or manually with admin privileges
.\examples\mdm\deploy-windows.ps1 -Team "platform" -RepoUrl "https://github.com/your-org/claude-hub.git"
```

Writes to `C:\Program Files\ClaudeCode\CLAUDE.md`. Sets team from Azure AD group membership.

#### Updating org standards via MDM

When you update `org/CLAUDE.md` in the repo, re-run the MDM deployment to push the new version. The sync script can't update the managed policy file because it doesn't have admin privileges.

Ways to keep it current:
- Re-run the MDM script on a schedule (daily Jamf policy, Ansible playbook, etc.)
- Trigger a deployment from CI/CD on push to `org/CLAUDE.md`
- Re-run manually when standards change (fine if changes are infrequent)

### Option B: Manual setup (no MDM)

For organizations without MDM or those who prefer a simpler setup. The sync script writes both org and team content to `~/.claude/CLAUDE.md`.

Share these steps with developers or include in onboarding docs. The [User Guide](user-guide.md) has a developer-friendly version.

There are two clones involved. `~/.claude-hub` holds the sync script itself. `~/.claude/claude-hub/repo` is a separate shallow clone that the sync script pulls content from on each session start.

**Step 1.** Clone the hub repo (this gives developers the sync script):

```bash
git clone git@github.com:your-org/claude-hub.git ~/.claude-hub
```

**Step 2.** Create the config directory and set repo URL + team:

```bash
mkdir -p ~/.claude/claude-hub
echo "https://github.com/your-org/claude-hub.git" > ~/.claude/claude-hub/repo_url
echo "frontend" > ~/.claude/claude-hub/team
```

**Step 3.** Add the SessionStart hook to `~/.claude/settings.json` (create the file if it doesn't exist):

```json
{
  "hooks": {
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
  }
}
```

If the file already has a `hooks` key, add the `SessionStart` entry alongside existing hooks.

**Step 4.** Clone the content repo (the sync script handles updates after this):

```bash
git clone --depth=1 "$(cat ~/.claude/claude-hub/repo_url)" ~/.claude/claude-hub/repo
```

**Step 5.** Run the sync script manually to populate CLAUDE.md and skills:

```bash
bash ~/.claude-hub/plugin/scripts/sync.sh
```

**Step 6.** Start a new Claude Code session -- sync runs automatically from now on.

#### macOS note

The sync script uses `timeout` (from GNU coreutils) for git operations. macOS does not include this by default. Either install it:

```bash
brew install coreutils
```

Or perform the initial clone manually (step 4 above) and accept that git fetch warnings will appear in `sync.log` when offline. The sync script handles this gracefully — it falls back to cached files and never blocks a session.

In this mode, org and team content are concatenated into `~/.claude/CLAUDE.md` on every session start. The sync script detects that no managed policy file exists and includes org content automatically.

The trade-off: users can override `~/.claude/CLAUDE.md` manually, though the sync script restores it on the next session. If you need standards that can't be bypassed, use the MDM approach.

### Git authentication

The sync script needs read access to pull updates. Three options: deploy a read-only SSH key to each machine, store an HTTPS PAT or fine-grained token in the system credential store, or install a GitHub App with `contents:read` permission and let the sync script use the installation token.

---

At this point, basic setup is done. Developers will get org content on their next Claude Code session start. The sections below cover ongoing management -- add teams, skills, MCP servers, and fragments as you need them.

---

## Team management

Each team has a directory under `teams/` with a `CLAUDE.md` and an optional `skills/` directory. The sync script appends team content after org-level content, so teams can refine or override org guidance. Each developer's team is read from `~/.claude/claude-hub/team`.

### Creating a new team

Copy the template and edit the CLAUDE.md:

```bash
cp -r teams/_template teams/data-engineering
```

The template has sections for tech stack, code style, branching, testing, and deployment. If your team needs to override org-level guidance (say, a different branching model), document the rationale in the team CLAUDE.md so the context is clear.

Add team-specific skills under `teams/data-engineering/skills/`. These are copied alongside org skills and override org skills with the same name.

### Assigning developers to teams

Each developer sets their team locally:

```bash
echo "data-engineering" > ~/.claude/claude-hub/team
```

With MDM deployment, this is typically derived from group membership (AD group, LDAP group, Jamf group). The team takes effect on the next Claude Code session start.

## Skill management

A skill is a directory containing a `SKILL.md` file. The sync script copies skills from `org/skills/` and `teams/<team>/skills/` into `~/.claude/skills/` with a `hub-` prefix, so `org/skills/code-standards/SKILL.md` becomes `/hub-code-standards` in Claude Code.

Skills in `org/skills/` go to all developers. Skills in `teams/<team>/skills/` go only to that team. If a team skill has the same name as an org skill, the team version wins.

### Creating a skill

Create a directory with a `SKILL.md` inside it:

```bash
mkdir org/skills/my-skill
# Write the skill prompt in org/skills/my-skill/SKILL.md
```

The `SKILL.md` is a prompt that Claude Code executes when a developer runs the skill. It can include instructions, checklists, or multi-step workflows.

### Skill design guidelines

A good skill prompt starts with a title and one-line description, then walks through numbered steps Claude Code can follow in order. Put shell commands in fenced code blocks. End with an **Output** section so the developer knows what to expect. Keep the prompt self-contained -- if someone has to go find an external doc, the skill isn't doing its job.

Skills work well for repeatable workflows: code reviews, deployments, test generation, infrastructure checks. They work less well for open-ended exploration where the developer needs to guide the conversation.

### Example skills

`examples/org/skills/` has generic starting points:

| Skill | What it does |
|---|---|
| `code-standards` | Reviews code against naming, documentation, error handling, and testing standards |
| `security-review` | Checks for OWASP Top 10, hardcoded secrets, IAM misconfigurations |
| `fragment-update` | Reviews and applies fragment updates (requires fragment setup) |

Team-level skills target specific workflows. Examples:

| Team | Skill | What it does |
|---|---|---|
| Backend | `api-design` | Reviews REST API design, pagination, auth, and infrastructure config |
| Backend | `load-test` | Generates load test scripts |
| Frontend | `component-review` | Reviews components for accessibility, performance, TypeScript |
| Frontend | `e2e-test` | Generates E2E tests |

Fragment-level skills ship with project types (not synced via hub, live in the project's `.claude/skills/`):

| Fragment | Skill | What it does |
|---|---|---|
| `terraform-service` | `deploy` | Validate, plan, and apply the Terraform configuration |
| `terraform-service` | `api-test` | Run or generate integration tests against the deployed API |

Copy example skills and customize:

```bash
cp -r examples/org/skills/code-standards org/skills/
```

## MCP servers

MCP servers let Claude Code talk to external tools and data sources: Jira, internal knowledge bases, artifact registries, team-specific services. Claude Hub distributes these configs centrally so developers don't set them up by hand.

### Where configs live

MCP server configs go in `settings.json` files under the `mcpServers` key:

- `org/settings.json` -- org-wide servers, available to all developers
- `teams/<team>/settings.json` -- team-specific servers, merged with org servers

With MDM, `org/settings.json` is deployed to the managed policy settings path alongside `CLAUDE.md`. Users can't remove these. The sync script merges team MCP servers into `~/.claude/settings.json`.

Without MDM, the sync script merges both org and team servers into `~/.claude/settings.json`.

If a team defines a server with the same name as an org server, the team version wins. When a server is removed from the repo, the sync script cleans it up from developer settings on the next session start.

### Configuring org MCP servers

Edit `org/settings.json`:

```json
{
  "mcpServers": {
    "jira": {
      "type": "streamable-http",
      "url": "https://mcp.internal.acme.com/jira"
    },
    "knowledge-base": {
      "type": "streamable-http",
      "url": "https://mcp.internal.acme.com/kb"
    }
  }
}
```

See `examples/org/settings.json` for a fuller sample.

### Configuring team MCP servers

Create `teams/<team>/settings.json` with the same format. Only include servers specific to the team -- org servers are inherited automatically.

```json
{
  "mcpServers": {
    "team-data-lake": {
      "type": "streamable-http",
      "url": "https://mcp.internal.acme.com/data-lake"
    }
  }
}
```

### Server types

MCP servers can be remote (HTTP) or local (stdio):

| Type | Example | Config |
|---|---|---|
| Remote (org-hosted) | Jira, Confluence, internal KB | `"type": "streamable-http", "url": "https://..."` |
| Remote (SaaS) | GitHub, Linear, Slack | `"type": "streamable-http", "url": "https://..."` |
| Local (stdio) | File system tools, local DB | `"type": "stdio", "command": "...", "args": [...]` |

For local stdio servers, make sure the command is installed on developer machines before adding it to the config.

## Project fragments (optional)

Skip this section if your org doesn't use a scaffolding tool like Backstage or Cookiecutter to create new repos. You can always come back to it later.

Fragments let you ship a ready-made `.claude/` configuration with each project type.

### Setting up fragments

1. Copy example fragments or create your own:

   ```bash
   cp -r examples/fragments/ fragments/
   ```

2. Customize fragment content for your project types.

3. Add project-type-specific skills under `.claude/skills/`.

4. Generate version markers:

   ```bash
   bash examples/scripts/generate-markers.sh fragments
   ```

5. Enable the fragment-update skill so developers can apply updates:

   ```bash
   cp -r examples/org/skills/fragment-update org/skills/
   ```

### Integrating fragments with Backstage

There are two approaches to shipping fragments in Backstage software templates.

#### Recommended: embed fragments in the skeleton

Include the fragment files directly in the Backstage template's skeleton directory. The sync script's drift detection handles freshness automatically.

```
your-backstage-template/
  template.yaml              # Backstage scaffolder definition
  skeleton/                  # Project skeleton (rendered by Nunjucks)
    .claude/                 # Fragment files copied from claude-hub
      .fragment              # Drift detection marker
      settings.json          # Pre-approved permissions
      skills/                # Project-type-specific skills
    CLAUDE.md                # Fragment CLAUDE.md (managed + project sections)
    main.tf                  # Application infrastructure
    src/                     # Application code
    tests/                   # Test code
    ...
```

The Backstage template only needs one `fetch:template` step:

```yaml
steps:
  - id: fetch-skeleton
    name: Scaffold project from template
    action: fetch:template
    input:
      url: ./skeleton
      values:
        name: ${{ parameters.name }}
        description: ${{ parameters.description }}
        owner: ${{ parameters.owner }}
```

When a developer opens the scaffolded project in Claude Code, the sync script checks the `.fragment` marker hash against the current fragment in claude-hub. If claude-hub has a newer version, a drift notice appears and the developer can run `/hub-fragment-update` to review and apply changes.

To keep skeletons current, set up a CI job (or manual process) to periodically copy the latest fragment files from claude-hub into your Backstage template's skeleton directory. Even without this, drift detection catches staleness on first session.

#### Alternative: fetch fragments at scaffold time

For simpler setups or when you want to guarantee the latest fragment version at creation time, fetch directly from claude-hub during scaffolding:

```yaml
steps:
  - id: fetch-skeleton
    name: Scaffold project from template
    action: fetch:template
    input:
      url: ./skeleton
      values: ...

  - id: fetch-claude-config
    name: Copy Claude Code config
    action: fetch:plain
    input:
      url: https://github.com/your-org/claude-hub/tree/main/fragments/${{ parameters.projectType }}/.claude
      targetPath: .claude

  - id: fetch-claude-md
    name: Copy project CLAUDE.md
    action: fetch:plain:file
    input:
      url: https://github.com/your-org/claude-hub/tree/main/fragments/${{ parameters.projectType }}/CLAUDE.md
      targetPath: ./CLAUDE.md
```

The trade-off: this requires network access to claude-hub at scaffold time and adds two extra steps. The skeleton approach avoids this dependency and still gets updates via drift detection.

### Structuring the Backstage catalog repo

Separate the template from sample service implementations:

```
your-backstage-catalog/
  template/                    # Backstage software template
    template.yaml              # Scaffolder definition (registered in Backstage)
    skeleton/                  # Project skeleton with embedded fragments
  services/                    # Sample implementations for reference
    order-service/             # Fully implemented example
    inventory-service/         # Another example
  README.md
```

The `template/` directory is self-contained. Backstage references `template/template.yaml`. The services in `services/` are working examples that show developers what the template produces.

### Fragment structure

Each fragment is a directory containing the `.claude/` config and a `CLAUDE.md`:

```
fragments/terraform-service/
  .claude/
    .fragment               # Version marker (generated)
    settings.json           # Permissions (e.g., terraform plan, pytest)
    skills/
      deploy/
        SKILL.md            # Project-type-specific skill
  CLAUDE.md                 # Toolchain reference + project starter
```

The `CLAUDE.md` uses markers to separate managed content from project-owned content:

```markdown
<!-- claude-hub:fragment:begin — managed centrally -->
(toolchain reference: commands, patterns, pitfalls)
<!-- claude-hub:fragment:end — project content below -->

# Project Notes
(developer writes here freely)
```

Everything above the end marker gets replaced on updates. Everything below it belongs to the project and is never touched.

### Available fragment types

| Fragment | Description |
|---|---|
| `terraform-service` | Terraform-managed service with deploy skill, pytest permissions |
| `react-app` | React application defaults |
| `node-api` | Node.js API service config |
| `python-api` | Python API service config |

### Creating custom fragments

1. Create the fragment directory:

   ```bash
   mkdir -p fragments/my-project-type/.claude/skills/my-skill
   ```

2. Add `settings.json` with pre-approved permissions:

   ```json
   {
     "permissions": {
       "allow": [
         "Bash(terraform plan*)",
         "Bash(terraform apply*)",
         "Bash(pytest*)"
       ]
     }
   }
   ```

3. Add project-type-specific skills under `.claude/skills/`. Each skill is a directory with a `SKILL.md` containing a prompt that Claude Code executes.

4. Create `CLAUDE.md` with the managed section between markers:

   ```markdown
   <!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
   # My Project Type — Toolchain Reference
   (build commands, testing patterns, framework pitfalls)
   <!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

   # Project Notes
   <!-- Developer writes here freely -->
   ```

5. Generate the version marker:

   ```bash
   bash examples/scripts/generate-markers.sh fragments
   ```

6. Copy the fragment files into any Backstage template skeletons that use this project type.

### Fragment versioning

Fragments include version tracking so projects can detect when upstream changes are available. See the [README](../README.md#how-drift-detection-works) for the full drift detection flow.

Each fragment has a `.claude/.fragment` marker containing a SHA-256 hash of its managed content. Generate these by running:

```bash
bash examples/scripts/generate-markers.sh fragments
```

Run this in CI after any fragment change, or manually before committing. It computes the hash of all tracked files and writes `.claude/.fragment` in each fragment directory.

Drift detection happens automatically during session sync. When the hash in a project's marker doesn't match the current source fragment, the sync script appends a notice to the developer's `~/.claude/CLAUDE.md`. To let developers act on these notices, copy the fragment-update skill:

```bash
cp -r examples/org/skills/fragment-update org/skills/
```

Developers run `/hub-fragment-update` to review diffs and selectively apply changes. Updates replace only the content between markers in `CLAUDE.md` and can replace `.claude/` files directly.

The `.fragment` marker format:

```
fragment=terraform-service
version=a3f8b2c
hash=<sha256 of managed content>
tracked_files=.claude/settings.json,.claude/skills/deploy/SKILL.md,CLAUDE.md
```

## Operations

### Updating org configuration

Edit files in `org/` or `teams/`, commit, and push. Developers pick up changes on their next session start. If a developer already has a session open, the cached config refreshes within 5 minutes (the TTL window).

For MDM deployments, pushing to `org/CLAUDE.md` or `org/settings.json` also requires re-running the MDM deployment to update the managed policy files. See [Updating org standards via MDM](#updating-org-standards-via-mdm).

### Sync behavior

The sync script (`plugin/scripts/sync.sh`) runs on every session start via the SessionStart hook. See the [README](../README.md#sync-script) for a full description.

What matters for ops: it never blocks a session (always exits 0), it skips redundant work within a 5-minute TTL window, it falls back to cached files when offline, and it logs to `~/.claude/claude-hub/sync.log` (auto-truncated at 100KB). A file lock prevents concurrent syncs from racing.

### Troubleshooting

**Sync fails with "permission denied"**
Check the developer's SSH key, PAT, or GitHub App token. The sync script needs read access to the Git remote. Look at `~/.claude/claude-hub/sync.log` for details.

**CLAUDE.md is empty or stale**
Run the sync script manually to see what's happening:
```bash
bash ~/.claude-hub/plugin/scripts/sync.sh
cat ~/.claude/claude-hub/sync.log
```

**Offline / no network**
The sync script skips `git pull` and uses cached files. Check `sync.log` to confirm it fell back.

**Skills not appearing**
Verify the team file is correct and the team directory exists. Check that skill directories contain a `SKILL.md` file (not just the directory).

**MCP servers not showing up**
The sync script needs python3 to merge MCP server configs. Check `sync.log` for "python3 not found" warnings. Also verify that `org/settings.json` or `teams/<team>/settings.json` has a valid `mcpServers` key.

**Stale configuration after switching teams**
Team changes take effect on the next session start. Close and reopen Claude Code.

**Sync not triggering**
Check that the `SessionStart` hook is configured in `~/.claude/settings.json`:
```bash
cat ~/.claude/settings.json | python3 -c "import sys,json; h=json.load(sys.stdin).get('hooks',{}); print('SessionStart hook:', 'found' if 'SessionStart' in h else 'MISSING')"
```
If missing, add the hook as described in [Installing the SessionStart hook](#installing-the-sessionstart-hook).

**`timeout: command not found` in sync.log**
The sync script uses GNU `timeout` which is not included on macOS. Install it with `brew install coreutils`, or perform the initial repo clone manually into `~/.claude/claude-hub/repo` — the sync script falls back to cached files when `timeout` is unavailable.

### Verification checklist

#### MDM deployment

After deploying via MDM, verify on a test machine:

- [ ] Managed policy files exist at the system path:
  - macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md` and `settings.json`
  - Linux: `/etc/claude-code/CLAUDE.md` and `settings.json`
  - Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` and `settings.json`
- [ ] Managed policy CLAUDE.md contains your org's content
- [ ] Managed policy settings.json contains your org's MCP servers (if configured)
- [ ] `~/.claude/settings.json` has a `SessionStart` hook pointing to `sync.sh`
- [ ] `cat ~/.claude/claude-hub/team` shows the expected team
- [ ] Start a new Claude Code session (or run `sync.sh` manually)
- [ ] `~/.claude/CLAUDE.md` has team content but not org content (org is in managed policy)
- [ ] `ls ~/.claude/skills/` shows `hub-*` skills
- [ ] `cat ~/.claude/claude-hub/sync.log` shows "team-only mode" and a successful sync

#### Manual setup deployment

After manual setup deployment, verify on a test machine:

- [ ] `~/.claude/settings.json` has a `SessionStart` hook pointing to `sync.sh`
- [ ] `cat ~/.claude/claude-hub/repo_url` shows the hub repo URL
- [ ] `cat ~/.claude/claude-hub/team` shows the expected team
- [ ] `~/.claude/claude-hub/repo/.git` exists (repo is cloned)
- [ ] Start a new Claude Code session (or run `sync.sh` manually)
- [ ] `~/.claude/CLAUDE.md` has both org and team content
- [ ] `ls ~/.claude/skills/` shows `hub-*` skills
- [ ] `cat ~/.claude/claude-hub/sync.log` shows "writing org + team" and a successful sync
