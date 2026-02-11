# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a skill management system for AI agents (Copilot and Claude). It enables installing, upgrading, and managing skills from git repositories through PowerShell scripts.

## Core Concepts

### Three-Tier Storage Architecture

1. **Machine Cache** (`%USERPROFILE%\.skill\{skill-name}\`)
   - `origin/` - Original files from git repo
   - `parsed/` - Processed files ready for installation
   - `metadata.json` - Skill metadata including version, source repo, and install info

2. **Project Scope** - Repository-specific skills
   - Copilot: `.github\skills\{skill-name}`
   - Claude: `.claude\skills\{skill-name}`

3. **Personal Scope** - User-wide skills
   - Copilot: `%USERPROFILE%\.copilot\skills\{skill-name}`
   - Claude: `%USERPROFILE%\.claude\skills\{skill-name}`

### Skill Structure

Skills must contain a `Skill.md` (case-insensitive) with YAML frontmatter:

```yaml
---
name: skill-name
description: Brief description
license: Apache-2.0           # Optional
metadata:
  author: example-org
  version: "1.0"             # Optional, defaults to last modified date
---
```

## Key Commands

All scripts are in `skills/skills-manager/scripts/`.

### List Skills
```powershell
.\list-skills.ps1
```
Scans all storage locations (project and personal) and displays installed skills.

### Get Skill Details
```powershell
.\get-skill.ps1 -SkillName "name"
```

### Download Skill to Cache
```powershell
.\download-skill.ps1 -SkillName "name" -RepoUrl "https://github.com/owner/repo" -RelativePath "path/to/skill" [-Branch "main"]
```
Uses git sparse-checkout to download only the skill folder. Parses frontmatter, creates metadata.json with version (from frontmatter or git commit date).

### Install from Cache
```powershell
.\install-skill.ps1 -SkillName "name" -Scope "project|personal" -Agent "copilot|claude"
```
Copies from `%USERPROFILE%\.skill\{name}\parsed\` to target location. Default: personal scope, Claude agent.

### Upgrade Skill
```powershell
.\upgrade-skill.ps1 -SkillName "name"
```
Reads metadata.json for source info, re-downloads to cache, updates all installed locations.

### Uninstall Skill
```powershell
.\uninstall-skill.ps1 -SkillName "name"
```

## Installation Workflow

1. Parse git URL to extract repo URL, relative path, and branch
2. Download to cache using `download-skill.ps1` (creates origin/, parsed/, metadata.json)
3. Prompt user for scope (project/personal) and agent (copilot/claude)
4. Install to target path using `install-skill.ps1`
5. User must restart chat session for skills to take effect

## Git Repository URL Formats

Supported formats:
- `https://github.com/owner/repo/tree/branch/path/to/skill`
- `https://github.com/owner/repo/path/to/skill` (defaults to main branch)
- `https://dev.azure.com/org/project/_git/repo?path=/path/to/skill`

## Important Notes

- The skills-manager skill itself lives in `skills/skills-manager/` within this repo
- Git root detection is used to support running scripts from any subdirectory
- Version defaults to last git commit date for the skill folder if not in frontmatter
- Skills must be reinstalled (chat restart required) after upgrades
