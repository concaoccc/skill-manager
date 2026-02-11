# Uninstall a skill from all installed locations (project and personal folders for both agents)
# Usage: .\uninstall-skill.ps1 -SkillName "skill-name"

param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName
)

# Define all possible skill locations
$skillPaths = @(
    ".github\skills\$SkillName",                          # project-copilot
    ".claude\skills\$SkillName",                          # project-claude
    "$env:USERPROFILE\.copilot\skills\$SkillName",        # personal-copilot
    "$env:USERPROFILE\.claude\skills\$SkillName"          # personal-claude
)

$removedCount = 0

foreach ($path in $skillPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "✅ Removed: $path" -ForegroundColor Green
        $removedCount++
    }
}

if ($removedCount -eq 0) {
    Write-Host "⚠️ Skill '$SkillName' was not found in any location." -ForegroundColor Yellow
} else {
    Write-Host "`n🗑️ Skill '$SkillName' uninstalled from $removedCount location(s)." -ForegroundColor Cyan
}
