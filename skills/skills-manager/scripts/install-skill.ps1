# Install a skill from machine cache to agent path
# Usage: .\install-skill.ps1 -SkillName "skill-name" -Scope "project|personal" -Agent "copilot|claude"

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,
    
    [ValidateSet("project", "personal")]
    [string]$Scope = "personal",
    
    [ValidateSet("copilot", "claude")]
    [string]$Agent = "claude"
)

$cacheDir = "$env:USERPROFILE\.skill\$SkillName"
$parsedDir = "$cacheDir\parsed"
$metadataFile = "$cacheDir\metadata.json"

# Check if skill exists in cache
if (-not (Test-Path $parsedDir)) {
    Write-Host "❌ Skill '$SkillName' not found in cache. Run download-skill.ps1 first." -ForegroundColor Red
    exit 1
}

# Read metadata
$metadata = $null
if (Test-Path $metadataFile) {
    $metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
}

# Determine target path based on scope and agent
switch ("$Scope-$Agent") {
    "project-copilot" { 
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $gitRoot = $gitRoot -replace '/', '\'
            $target = Join-Path $gitRoot ".github\skills\$SkillName"
        } else {
            $target = ".github\skills\$SkillName"
        }
    }
    "project-claude" { 
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $gitRoot = $gitRoot -replace '/', '\'
            $target = Join-Path $gitRoot ".claude\skills\$SkillName"
        } else {
            $target = ".claude\skills\$SkillName"
        }
    }
    "personal-copilot" { $target = "$env:USERPROFILE\.copilot\skills\$SkillName" }
    "personal-claude"  { $target = "$env:USERPROFILE\.claude\skills\$SkillName" }
}

# Create target directory and copy files from parsed folder
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path "$parsedDir\*" -Destination $target -Recurse -Force

# Display success message
$name = if ($metadata) { $metadata.name } else { $SkillName }
$version = if ($metadata) { $metadata.version } else { "unknown" }
$description = if ($metadata) { $metadata.description } else { "" }

Write-Host ""
Write-Host "✅ Skill '$name' installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  📁 Location: $target" -ForegroundColor Cyan
Write-Host "  📦 Version:  $version" -ForegroundColor White
if ($description) {
    Write-Host "  📄 $description" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  💡 To use this skill, simply ask about topics related to it." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ⚠️  Please restart your chat session for the skill to take effect." -ForegroundColor Yellow
Write-Host ""
