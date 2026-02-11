# Get detailed information about a skill by name
# Usage: .\get-skill.ps1 -SkillName "skill-name"

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName
)

# Find git root for project skills
$gitRoot = git rev-parse --show-toplevel 2>$null
if ($gitRoot) {
    $gitRoot = $gitRoot -replace '/', '\'
}

# Define all possible skill locations
$searchPaths = @(
    "$env:USERPROFILE\.copilot\skills",
    "$env:USERPROFILE\.claude\skills"
)

if ($gitRoot) {
    $searchPaths += Join-Path $gitRoot ".github\skills"
    $searchPaths += Join-Path $gitRoot ".claude\skills"
    $searchPaths += Join-Path $gitRoot "skills"
}

# Search for the skill
$foundPath = $null
$foundLocation = $null

foreach ($basePath in $searchPaths) {
    $skillPath = Join-Path $basePath $SkillName
    if (Test-Path $skillPath) {
        $foundPath = $skillPath
        # Determine location type
        if ($basePath -like "$env:USERPROFILE\.copilot\skills" -or $basePath -like "$env:USERPROFILE\.claude\skills") {
            $foundLocation = "Personal"
        } else {
            $foundLocation = "Project"
        }
        break
    }
}

if (-not $foundPath) {
    Write-Host "❌ Skill '$SkillName' not found." -ForegroundColor Red
    exit 1
}

# Find Skill.md file
$skillMdPaths = @(
    (Join-Path $foundPath "Skill.md"),
    (Join-Path $foundPath "SKILL.md"),
    (Join-Path $foundPath "skill.md")
)

$skillMdPath = $skillMdPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# Parse skill information from frontmatter
$name = $SkillName
$description = "(no description)"
$version = $null
$author = $null
$license = $null

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
        if ($frontmatter -match "(?m)^license:\s*(.+)$") {
            $license = $matches[1].Trim()
        }
        # Check for metadata block
        if ($frontmatter -match "(?s)metadata:\s*\n(.*?)(?=\n[^\s]|$)") {
            $metaBlock = $matches[1]
            if ($metaBlock -match "(?m)version:\s*[`"']?([^`"'\n]+)[`"']?") {
                $version = $matches[1].Trim()
            }
            if ($metaBlock -match "(?m)author:\s*(.+)$") {
                $author = $matches[1].Trim()
            }
        }
    }
    
    # If no version, use file last modified time
    if (-not $version) {
        $lastModified = (Get-Item $skillMdPath).LastWriteTimeUtc
        $version = $lastModified.ToString("yyyy-MM-dd HH:mm:ss") + " (file time)"
    }
}

# Check for cache metadata
$cacheMetadataFile = "$env:USERPROFILE\.skill\$SkillName\metadata.json"
$cacheMetadata = $null
if (Test-Path $cacheMetadataFile) {
    $cacheMetadata = Get-Content $cacheMetadataFile -Raw | ConvertFrom-Json
}

# Get folder contents
$files = Get-ChildItem -Path $foundPath -Recurse -File | Select-Object -ExpandProperty FullName | ForEach-Object {
    $_.Replace($foundPath, "").TrimStart("\")
}

# Display skill details
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SKILL DETAILS                                                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Name:        " -NoNewline -ForegroundColor Gray
Write-Host "$name" -ForegroundColor White
Write-Host "  Version:     " -NoNewline -ForegroundColor Gray
Write-Host "$version" -ForegroundColor White
Write-Host "  Location:    " -NoNewline -ForegroundColor Gray
Write-Host "$foundLocation" -ForegroundColor White
Write-Host "  Path:        " -NoNewline -ForegroundColor Gray
Write-Host "$foundPath" -ForegroundColor White
if ($author) {
    Write-Host "  Author:      " -NoNewline -ForegroundColor Gray
    Write-Host "$author" -ForegroundColor White
}
if ($license) {
    Write-Host "  License:     " -NoNewline -ForegroundColor Gray
    Write-Host "$license" -ForegroundColor White
}
Write-Host ""
Write-Host "  Description:" -ForegroundColor Gray
Write-Host "  $description" -ForegroundColor Yellow

# Show source info if available from cache
if ($cacheMetadata -and $cacheMetadata.source) {
    Write-Host ""
    Write-Host "  Source:" -ForegroundColor Gray
    Write-Host "    Repo:     $($cacheMetadata.source.repoUrl)" -ForegroundColor DarkGray
    Write-Host "    Path:     $($cacheMetadata.source.relativePath)" -ForegroundColor DarkGray
    Write-Host "    Branch:   $($cacheMetadata.source.branch)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Files:" -ForegroundColor Gray
foreach ($file in $files) {
    Write-Host "    - $file" -ForegroundColor DarkGray
}
Write-Host ""
