# Upgrade a skill from source repository
# Usage: .\upgrade-skill.ps1 -SkillName "skill-name"

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cacheDir = "$env:USERPROFILE\.skill\$SkillName"
$parsedDir = "$cacheDir\parsed"
$metadataFile = "$cacheDir\metadata.json"

# Check if skill exists in cache
if (-not (Test-Path $metadataFile)) {
    Write-Host "❌ Skill '$SkillName' not found in cache or missing metadata." -ForegroundColor Red
    Write-Host "   Please reinstall the skill using download-skill.ps1" -ForegroundColor Yellow
    exit 1
}

# Read existing metadata
$metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
$oldVersion = $metadata.version
$repoUrl = $metadata.source.repoUrl
$relativePath = $metadata.source.relativePath
$branch = if ($metadata.source.branch) { $metadata.source.branch } else { "main" }

Write-Host "📥 Upgrading skill '$SkillName'..." -ForegroundColor Cyan
Write-Host "   Current version: $oldVersion" -ForegroundColor Gray
Write-Host ""

# Reuse download script to fetch latest version
& "$scriptDir\download-skill.ps1" -SkillName $SkillName -RepoUrl $repoUrl -RelativePath $relativePath -Branch $branch
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to download latest version" -ForegroundColor Red
    exit 1
}

# Read new version from updated metadata
$newMetadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
$newVersion = $newMetadata.version

# Find and update all installed locations
$gitRoot = git rev-parse --show-toplevel 2>$null
if ($gitRoot) {
    $gitRoot = $gitRoot -replace '/', '\'
}

$locations = @()
if ($gitRoot) {
    $locations += Join-Path $gitRoot ".github\skills\$SkillName"
    $locations += Join-Path $gitRoot ".claude\skills\$SkillName"
}
$locations += "$env:USERPROFILE\.copilot\skills\$SkillName"
$locations += "$env:USERPROFILE\.claude\skills\$SkillName"

$updated = @()
foreach ($target in $locations) {
    if (Test-Path $target) {
        Copy-Item -Path "$parsedDir\*" -Destination $target -Recurse -Force
        $updated += $target
        Write-Host "   ✅ Updated: $target" -ForegroundColor Green
    }
}

Write-Host ""
if ($updated.Count -eq 0) {
    Write-Host "⚠️ No installed locations found for '$SkillName'" -ForegroundColor Yellow
    Write-Host "   Cache has been updated. Use install-skill.ps1 to install." -ForegroundColor Gray
} else {
    if ($oldVersion -eq $newVersion) {
        Write-Host "✅ Skill '$SkillName' is already up to date!" -ForegroundColor Green
        Write-Host ""
        Write-Host "   📦 Version: $newVersion" -ForegroundColor White
    } else {
        Write-Host "✅ Skill '$SkillName' upgraded successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "   📦 Old Version: $oldVersion" -ForegroundColor Gray
        Write-Host "   📦 New Version: $newVersion" -ForegroundColor White
        Write-Host ""
        Write-Host "   ⚠️  Please reopen your chat session for changes to take effect." -ForegroundColor Yellow
    }
}
Write-Host ""
