# List all installed skills across all scopes
# Usage: .\list-skills.ps1

# Function to parse Skill.md and extract name, description, and version from YAML frontmatter
function Get-SkillInfo {
    param (
        [string]$SkillPath,
        [string]$Location
    )
    
    $skillMdPaths = @(
        (Join-Path $SkillPath "Skill.md"),
        (Join-Path $SkillPath "SKILL.md"),
        (Join-Path $SkillPath "skill.md")
    )
    
    $skillMdPath = $skillMdPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    $name = Split-Path $SkillPath -Leaf
    $description = ""
    $version = "-"
    
    if ($skillMdPath) {
        $content = Get-Content $skillMdPath -Raw -ErrorAction SilentlyContinue
        if ($content -match "(?s)^---\s*\n(.*?)\n---") {
            $frontmatter = $matches[1]
            if ($frontmatter -match "(?m)^name:\s*(.+)$") {
                $name = $matches[1].Trim()
            }
            if ($frontmatter -match "(?m)^description:\s*(.+)$") {
                $description = $matches[1].Trim()
            }
            # Check for version in metadata block
            if ($frontmatter -match "(?s)metadata:\s*\n(.*?)(?=\n[^\s]|$)") {
                $metaBlock = $matches[1]
                if ($metaBlock -match "(?m)version:\s*[`"']?([^`"'\n]+)[`"']?") {
                    $version = $matches[1].Trim()
                }
            }
        }
        
        # If no version found, use file last modified time
        if ($version -eq "-") {
            $lastModified = (Get-Item $skillMdPath).LastWriteTime
            $version = $lastModified.ToString("yyyy-MM-dd")
        }
    }
    
    # Truncate description if too long
    if ($description.Length -gt 50) {
        $description = $description.Substring(0, 47) + "..."
    }
    
    return [PSCustomObject]@{
        Name        = $name
        Version     = $version
        Location    = $Location
        Description = $description
    }
}

# Collect all skills
$allSkills = @()

# Find git root for project skills (supports running from any subdirectory)
$gitRoot = git rev-parse --show-toplevel 2>$null
if ($gitRoot) {
    $gitRoot = $gitRoot -replace '/', '\'
}

# Project Skills - use absolute paths from git root
if ($gitRoot) {
    $projectPaths = @(
        (Join-Path $gitRoot ".github\skills"),
        (Join-Path $gitRoot ".claude\skills"),
        (Join-Path $gitRoot "skills")
    )
    foreach ($path in $projectPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $allSkills += Get-SkillInfo -SkillPath $_.FullName -Location "Project"
            }
        }
    }
}

# Personal Skills
$personalPaths = @(
    "$env:USERPROFILE\.copilot\skills",
    "$env:USERPROFILE\.claude\skills"
)
foreach ($path in $personalPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $allSkills += Get-SkillInfo -SkillPath $_.FullName -Location "Personal"
        }
    }
}

# Output as table
if ($allSkills.Count -eq 0) {
    Write-Host "No skills installed." -ForegroundColor DarkGray
} else {
    $allSkills | Sort-Object Location, Name | Format-Table -Property Name, Version, Location, Description -AutoSize -Wrap
}
