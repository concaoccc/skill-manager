# Download a skill to machine cache with origin/parsed structure
# Usage: .\download-skill.ps1 -SkillName "skill-name" -RepoUrl "https://github.com/owner/repo" -RelativePath "path/to/skill" [-Branch "main"]

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,
    
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$RelativePath,
    
    [string]$Branch = "main"
)

$cacheDir = "$env:USERPROFILE\.skill\$SkillName"
$originDir = "$cacheDir\origin"
$parsedDir = "$cacheDir\parsed"
$metadataFile = "$cacheDir\metadata.json"

# Remove existing cache if present
Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue

# Create cache structure
New-Item -ItemType Directory -Force -Path $originDir | Out-Null
New-Item -ItemType Directory -Force -Path $parsedDir | Out-Null

Write-Host "📥 Downloading skill '$SkillName'..." -ForegroundColor Cyan

# Clone with sparse checkout to origin folder
$tempClone = "$env:TEMP\skill-clone-$SkillName"
Remove-Item -Path $tempClone -Recurse -Force -ErrorAction SilentlyContinue

git clone --filter=blob:none --sparse -b $Branch $RepoUrl $tempClone 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to clone repository" -ForegroundColor Red
    exit 1
}

Push-Location $tempClone
git sparse-checkout set $RelativePath 2>$null
Pop-Location

# Get last commit date for the skill folder
Push-Location $tempClone
$gitCommitDate = git log -1 --format="%ci" -- $RelativePath 2>$null
Pop-Location

# Copy to origin folder
$sourceSkillPath = Join-Path $tempClone $RelativePath
if (-not (Test-Path $sourceSkillPath)) {
    Write-Host "❌ Skill path '$RelativePath' not found in repository" -ForegroundColor Red
    Remove-Item -Path $tempClone -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Copy-Item -Path "$sourceSkillPath\*" -Destination $originDir -Recurse -Force

# Cleanup temp clone
Remove-Item -Path $tempClone -Recurse -Force -ErrorAction SilentlyContinue

# Find and parse Skill.md
$skillMdPaths = @(
    (Join-Path $originDir "Skill.md"),
    (Join-Path $originDir "SKILL.md"),
    (Join-Path $originDir "skill.md")
)
$skillMdPath = $skillMdPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $skillMdPath) {
    Write-Host "❌ No Skill.md found in the skill folder" -ForegroundColor Red
    exit 1
}

# Parse metadata from Skill.md frontmatter
$name = $SkillName
$description = ""
$version = $null
$author = $null
$license = $null

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
    # Check for version in metadata block
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

# If no version found, use git commit date or fall back to current date
if (-not $version) {
    if ($gitCommitDate) {
        # Parse git date format (e.g., "2026-01-21 10:30:45 -0800")
        $commitDateTime = [DateTime]::Parse($gitCommitDate.Substring(0, 19))
        $version = $commitDateTime.ToString("yyyy-MM-dd")
    } else {
        $version = (Get-Date).ToString("yyyy-MM-dd")
    }
}

# Copy files to parsed folder
Copy-Item -Path "$originDir\*" -Destination $parsedDir -Recurse -Force

# Create metadata.json
$metadata = @{
    name = $name
    description = $description
    version = $version
    license = $license
    author = $author
    lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    source = @{
        repoUrl = $RepoUrl
        relativePath = $RelativePath
        branch = $Branch
    }
}

$metadata | ConvertTo-Json -Depth 3 | Set-Content $metadataFile -Encoding UTF8

Write-Host ""
Write-Host "✅ Skill downloaded successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Name:        $name" -ForegroundColor White
Write-Host "  Version:     $version" -ForegroundColor White
Write-Host "  Description: $description" -ForegroundColor Gray
Write-Host ""
Write-Host "  Cache:       $cacheDir" -ForegroundColor DarkGray
Write-Host "  Origin:      $originDir" -ForegroundColor DarkGray
Write-Host "  Parsed:      $parsedDir" -ForegroundColor DarkGray
Write-Host ""
