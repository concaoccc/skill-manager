# Skills Manager

An agent skill for managing AI agent skills. Install, upgrade, list, and uninstall skills from git repositories using natural language.

## Overview

Skills Manager allows you to manage other skills through conversational commands with your AI agent (Claude Code or GitHub Copilot). No need to run scripts manually—just ask your agent!

## Installation

1. Install this skill to your agent using your preferred method
2. Restart your AI chat session
3. Start managing skills with natural language!

## How to Use

Simply talk to your AI agent about skill management tasks. Here are examples:

### List Skills

**What to say:**
- "List all installed skills"
- "Show me what skills I have"
- "What skills are available?"

**What you'll get:**
A table showing all installed skills with their names, versions, locations (Project/Personal), and descriptions.

### Get Skill Details

**What to say:**
- "Get details about the pdf-handler skill"
- "Show me information for sfi-handler"
- "Tell me about the code-formatter skill"

**What you'll get:**
Detailed information including the skill's location, files, and full description.

### Install a Skill

**What to say:**
- "Install the skill from https://github.com/myorg/skills/tree/main/pdf-handler"
- "Install skill from https://github.com/user/repo path: skills/my-skill"
- "Add the utility skill from https://dev.azure.com/org/project/_git/repo?path=/utils"

**What happens:**
1. The agent downloads the skill to machine cache
2. You'll be asked to choose installation scope:
   - **Project scope** - Available only in this repository (default)
   - **Personal scope** - Available across all your projects
3. The skill is installed to the appropriate location
4. You'll receive confirmation with installation details

**Supported URL formats:**
- `https://github.com/owner/repo/tree/branch/path/to/skill`
- `https://github.com/owner/repo/path/to/skill` (defaults to main branch)
- `https://dev.azure.com/org/project/_git/repo?path=/path/to/skill`

**Important:** After installation, restart your AI chat session for the skill to take effect.

### Upgrade a Skill

**What to say:**
- "Upgrade the pdf-handler skill"
- "Update my code-formatter skill to the latest version"
- "Check for updates to sfi-handler"

**What happens:**
1. The agent reads the skill's metadata to find its source repository
2. Downloads the latest version
3. Updates all locations where the skill is installed
4. Shows you what was updated

### Uninstall a Skill

**What to say:**
- "Uninstall the old-skill"
- "Remove the pdf-handler from my personal skills"
- "Delete the code-formatter skill"

**What happens:**
1. The agent finds where the skill is installed
2. You'll be asked which installation to remove:
   - Project scope
   - Personal scope
   - Machine cache
   - All of the above
3. The skill is removed from selected locations

## Understanding Skill Scopes

**Project Scope:**
- Skills are available only in the current repository
- Stored in `.github/skills/` (Copilot) or `.claude/skills/` (Claude)
- Best for project-specific tools

**Personal Scope:**
- Skills are available across all your projects
- Stored in `%USERPROFILE%\.copilot\skills\` or `%USERPROFILE%\.claude\skills\`
- Best for general-purpose utilities

**Machine Cache:**
- All downloaded skills are cached in `%USERPROFILE%\.skill\`
- Enables quick reinstallation without re-downloading
- Can be safely removed if you uninstall a skill completely

## Troubleshooting

**Skill not appearing after installation:**
- Restart your AI chat session
- Ask the agent to list skills to verify installation

**Installation failed:**
- Ensure the repository URL is correct and accessible
- Check that you have internet connectivity
- Verify git is installed on your system

**Upgrade not working:**
- The skill may not have metadata about its source
- Try reinstalling the skill instead

---

# Developer Guide

This section is for developers who want to understand how the Skills Manager works internally, contribute to the project, or create their own skills.

## Architecture

### Three-Tier Storage System

1. **Machine Cache** (`%USERPROFILE%\.skill\{skill-name}\`)
   - `origin/` - Original files downloaded from git repository
   - `parsed/` - Processed skill files ready for installation
   - `metadata.json` - Skill metadata (name, version, source, author)

2. **Project Scope** - Repository-specific skills
   - GitHub Copilot: `.github\skills\{skill-name}`
   - Claude Code: `.claude\skills\{skill-name}`

3. **Personal Scope** - User-wide skills
   - GitHub Copilot: `%USERPROFILE%\.copilot\skills\{skill-name}`
   - Claude Code: `%USERPROFILE%\.claude\skills\{skill-name}`

### Skill Structure Requirements

A valid skill must contain a `Skill.md` file (case-insensitive) with YAML frontmatter:

```markdown
---
name: skill-name
description: Brief description of what the skill does
license: Apache-2.0           # Optional
metadata:
  author: your-name          # Optional
  version: "1.0"             # Optional
---

# Skill Name

Your skill documentation here...
```

**Version handling:**
- If `version` is in frontmatter → use that version
- If not → use last git commit date of the skill folder
- Fallback → use file last modified date

## PowerShell Scripts

All automation is handled by scripts in `skills/skills-manager/scripts/`:

### list-skills.ps1
```powershell
.\list-skills.ps1
```
Scans all storage locations (project and personal) and displays installed skills in a table format.

**Implementation:**
- Finds git root to support running from any subdirectory
- Scans `.github/skills`, `.claude/skills`, `skills/` (project)
- Scans `%USERPROFILE%\.copilot\skills`, `%USERPROFILE%\.claude\skills` (personal)
- Parses `Skill.md` frontmatter to extract name, description, version
- Uses file last modified date if version not in frontmatter

### get-skill.ps1
```powershell
.\get-skill.ps1 -SkillName "name"
```
Retrieves detailed information about a specific skill.

**Implementation:**
- Searches all storage locations for the skill
- Reads full `Skill.md` content
- Displays skill metadata and file structure

### download-skill.ps1
```powershell
.\download-skill.ps1 `
    -SkillName "name" `
    -RepoUrl "https://github.com/owner/repo" `
    -RelativePath "path/to/skill" `
    [-Branch "main"]
```
Downloads a skill to machine cache using git sparse-checkout.

**Implementation:**
1. Removes existing cache if present
2. Creates cache structure: `origin/` and `parsed/`
3. Clones repository with `git clone --filter=blob:none --sparse`
4. Uses `git sparse-checkout set` to download only the skill folder
5. Gets last commit date for the skill folder using `git log -1 --format="%ci"`
6. Parses `Skill.md` frontmatter (name, description, version, author, license)
7. Uses version from frontmatter, or git commit date, or current date
8. Copies files to both `origin/` and `parsed/` folders
9. Creates `metadata.json` with all extracted information

**metadata.json format:**
```json
{
  "name": "skill-name",
  "description": "Skill description",
  "version": "1.0",
  "license": "Apache-2.0",
  "author": "author-name",
  "lastUpdated": "2026-02-11T10:30:00Z",
  "source": {
    "repoUrl": "https://github.com/owner/repo",
    "relativePath": "path/to/skill",
    "branch": "main"
  }
}
```

### install-skill.ps1
```powershell
.\install-skill.ps1 `
    -SkillName "name" `
    -Scope "project|personal" `
    -Agent "copilot|claude"
```
Installs a skill from cache to target location.

**Parameters:**
- `SkillName` (required) - Name of the skill in cache
- `Scope` (optional) - `project` or `personal`, defaults to `personal`
- `Agent` (optional) - `copilot` or `claude`, defaults to `claude`

**Implementation:**
1. Checks if skill exists in cache (`%USERPROFILE%\.skill\{name}\parsed\`)
2. Reads `metadata.json` if available
3. Determines target path based on scope and agent:
   - `project-copilot` → `{git-root}\.github\skills\{name}`
   - `project-claude` → `{git-root}\.claude\skills\{name}`
   - `personal-copilot` → `%USERPROFILE%\.copilot\skills\{name}`
   - `personal-claude` → `%USERPROFILE%\.claude\skills\{name}`
4. Creates target directory if needed
5. Copies all files from `parsed/` to target
6. Displays success message with location and version

### upgrade-skill.ps1
```powershell
.\upgrade-skill.ps1 -SkillName "name"
```
Upgrades a skill to the latest version.

**Implementation:**
1. Reads `%USERPROFILE%\.skill\{name}\metadata.json` for source info
2. Calls `download-skill.ps1` with source repo, path, and branch
3. Finds all installed locations by scanning project and personal paths
4. Calls `install-skill.ps1` for each installed location
5. Reports what was updated

### uninstall-skill.ps1
```powershell
.\uninstall-skill.ps1 -SkillName "name"
```
Removes a skill from specified locations.

**Implementation:**
1. Searches for skill in all storage locations
2. Displays found locations to user
3. Prompts user to select which locations to remove
4. Removes selected directories
5. Confirms removal

## How the Agent Uses These Scripts

When a user requests skill management through natural language:

1. **Agent parses the request** and identifies the operation (list, install, upgrade, etc.)
2. **Agent constructs appropriate PowerShell command** with parameters
3. **Agent executes the script** using the Bash tool
4. **Agent interprets the output** and presents results to the user in conversational format

### Installation Workflow (Internal)

```
User: "Install skill from https://github.com/owner/repo/tree/main/skills/my-skill"
    ↓
Agent parses URL:
  - RepoUrl: https://github.com/owner/repo
  - Branch: main
  - RelativePath: skills/my-skill
  - SkillName: my-skill (extracted from path)
    ↓
Agent runs: download-skill.ps1 -SkillName "my-skill" -RepoUrl "..." -RelativePath "..." -Branch "main"
    ↓
Agent asks user: "Where would you like to install? (1) Project (2) Personal"
    ↓
Agent runs: install-skill.ps1 -SkillName "my-skill" -Scope "project" -Agent "claude"
    ↓
Agent displays: "✅ Skill installed! Please restart your chat session."
```

### Upgrade Workflow (Internal)

```
User: "Upgrade pdf-handler skill"
    ↓
Agent reads: %USERPROFILE%\.skill\pdf-handler\metadata.json
    ↓
Agent extracts source info (repoUrl, relativePath, branch)
    ↓
Agent runs: download-skill.ps1 with source info
    ↓
Agent finds all installed locations (scans project + personal paths)
    ↓
Agent runs: install-skill.ps1 for each location
    ↓
Agent displays: "✅ Upgraded to version X.X in N locations"
```

## Git URL Parsing

The agent should parse various git URL formats and extract components:

### GitHub

**Format 1: With tree/branch path**
```
https://github.com/owner/repo/tree/branch/path/to/skill
→ RepoUrl: https://github.com/owner/repo
→ Branch: branch
→ RelativePath: path/to/skill
→ SkillName: skill (last path segment)
```

**Format 2: Direct path (assumes main branch)**
```
https://github.com/owner/repo/path/to/skill
→ RepoUrl: https://github.com/owner/repo
→ Branch: main
→ RelativePath: path/to/skill
→ SkillName: skill
```

### Azure DevOps

```
https://dev.azure.com/org/project/_git/repo?path=/path/to/skill&version=GBbranch
→ RepoUrl: https://dev.azure.com/org/project/_git/repo
→ Branch: branch (from version parameter, or "main" if not specified)
→ RelativePath: path/to/skill
→ SkillName: skill
```

### Parsing Logic

```javascript
// Pseudo-code for agent URL parsing
if (url.includes('github.com')) {
  // Extract repo: https://github.com/owner/repo
  let parts = url.split('/');
  let repoUrl = parts.slice(0, 5).join('/'); // https://github.com/owner/repo

  // Check for /tree/branch/
  if (url.includes('/tree/')) {
    let afterTree = url.split('/tree/')[1];
    let treeParts = afterTree.split('/');
    let branch = treeParts[0];
    let relativePath = treeParts.slice(1).join('/');
  } else {
    // No branch specified, use main
    let branch = 'main';
    let relativePath = parts.slice(5).join('/');
  }
}

if (url.includes('dev.azure.com')) {
  // Extract repo: https://dev.azure.com/org/project/_git/repo
  let baseUrl = url.split('?')[0];
  let params = parseQueryString(url);
  let branch = params.version?.replace('GB', '') || 'main';
  let relativePath = params.path?.replace(/^\//, '') || '';
}
```

## Development Setup

1. Clone this repository
2. Navigate to `skills/skills-manager/scripts/`
3. Test scripts individually with PowerShell
4. Ensure git is installed and in PATH

## Testing

### Test List Functionality
```powershell
.\list-skills.ps1
```

### Test Download (use a real repo)
```powershell
.\download-skill.ps1 `
    -SkillName "test-skill" `
    -RepoUrl "https://github.com/your/repo" `
    -RelativePath "skills/test" `
    -Branch "main"
```

Expected output:
- Creates `%USERPROFILE%\.skill\test-skill\`
- Contains `origin/`, `parsed/`, and `metadata.json`
- `metadata.json` has correct version from frontmatter or git commit date

### Test Installation
```powershell
.\install-skill.ps1 -SkillName "test-skill" -Scope "personal" -Agent "claude"
```

Expected output:
- Creates `%USERPROFILE%\.claude\skills\test-skill\`
- Contains all files from `parsed/`
- Displays success message

### Verify Cache Structure
```powershell
ls "$env:USERPROFILE\.skill\test-skill"
cat "$env:USERPROFILE\.skill\test-skill\metadata.json"
```

### Test Upgrade
```powershell
# Make changes to the skill in the repo
.\upgrade-skill.ps1 -SkillName "test-skill"
```

Expected output:
- Updates cache with latest version
- Updates all installed locations
- Shows what was updated

### Test Uninstall
```powershell
.\uninstall-skill.ps1 -SkillName "test-skill"
```

Expected output:
- Lists all locations where skill is installed
- Prompts for confirmation
- Removes selected locations

## Creating Your Own Skills

To create a skill compatible with Skills Manager:

1. **Create a skill folder** with a descriptive name (e.g., `pdf-handler`, `code-formatter`)

2. **Add a `Skill.md` file** with YAML frontmatter:
   ```markdown
   ---
   name: my-skill
   description: Brief description of what this skill does
   license: MIT
   metadata:
     author: your-name
     version: "1.0"
   ---

   # My Skill

   Detailed documentation about your skill...

   ## Instructions

   Tell the agent how to use your skill...
   ```

3. **Add any supporting files** (scripts, templates, data files)

4. **Commit to a git repository**

5. **Test installation**:
   ```powershell
   .\download-skill.ps1 `
       -SkillName "my-skill" `
       -RepoUrl "https://github.com/you/repo" `
       -RelativePath "path/to/my-skill"
   ```

## Contributing

When contributing to this skill:

1. **Maintain script compatibility** - Scripts must work from any directory (use git root detection)
2. **Handle errors gracefully** - Provide clear, actionable error messages
3. **Follow PowerShell conventions** - Use approved verbs, proper parameter validation, `-ErrorAction`
4. **Update metadata.json format** - Keep consistent with documented structure
5. **Test all scopes and agents** - Verify `project`/`personal` and `copilot`/`claude` combinations
6. **Update documentation** - Keep README and CLAUDE.md in sync with code changes

## Prerequisites

- Git (must be in PATH)
- PowerShell 5.1 or later (Windows)
- Network access to git repositories

## Troubleshooting for Developers

### Git not found
```powershell
git --version  # Verify git is accessible
# Add git to PATH if needed
```

### Permission denied
```powershell
# Run PowerShell as Administrator
# Check folder permissions: icacls "path"
```

### Sparse checkout fails
```powershell
# Verify repository URL is correct
# Check relative path exists in the repo
# Test manual clone: git clone --filter=blob:none --sparse <url>
```

### Metadata parsing errors
```powershell
# Ensure Skill.md has valid YAML frontmatter
# Check for required fields: name, description
# Validate YAML syntax (no tabs, proper indentation)
```

### Git root detection issues
```powershell
# Ensure script is run within a git repository
git rev-parse --show-toplevel  # Should return repository root
```

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Support

**For Users:**
- Ask your AI agent for help with skill management
- Check the [How to Use](#how-to-use) section above

**For Developers:**
- Review this Developer Guide
- Check script comments for implementation details
- Open an issue in the repository
