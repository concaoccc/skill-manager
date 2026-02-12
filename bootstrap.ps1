#!/usr/bin/env pwsh
<#
.SYNOPSIS
Bootstrap installer for skills-manager skill.

.DESCRIPTION
Downloads and installs the skills-manager skill to your Claude personal skills directory.
If already installed, skips installation.

.EXAMPLE
irm https://raw.githubusercontent.com/concaoccc/skill-manager/main/bootstrap.ps1 | iex

.NOTES
Requires Git to be installed and in PATH.
#>

param(
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# Configuration
$RepoUrl = "https://github.com/concaoccc/skill-manager.git"
$SkillName = "skills-manager"
$TargetPath = Join-Path $env:USERPROFILE ".claude\skills\$SkillName"
$TempPath = Join-Path $env:TEMP "skill-manager-install"

Write-Host "🚀 Skills Manager Bootstrap Installer" -ForegroundColor Cyan
Write-Host ""

# Check if already installed
if (Test-Path $TargetPath) {
    Write-Host "✅ Skills Manager is already installed at:" -ForegroundColor Green
    Write-Host "   $TargetPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To upgrade, use: /skills-manager upgrade skills-manager" -ForegroundColor Yellow
    exit 0
}

# Check if git is available
try {
    $null = git --version
} catch {
    Write-Host "❌ Error: Git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "   Please install Git from https://git-scm.com/" -ForegroundColor Yellow
    exit 1
}

Write-Host "📥 Downloading skills-manager from GitHub..." -ForegroundColor Cyan

# Clean up temp directory if it exists
if (Test-Path $TempPath) {
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
}

try {
    # Clone repository to temp location using sparse checkout
    Write-Host "   Cloning repository..." -ForegroundColor Gray
    git clone --filter=blob:none --sparse --depth 1 --branch $Branch $RepoUrl $TempPath 2>&1 | Out-Null

    if (-not $?) {
        throw "Failed to clone repository"
    }

    # Set up sparse checkout for just the skills-manager folder
    Push-Location $TempPath
    try {
        git sparse-checkout set "skills/skills-manager" 2>&1 | Out-Null
    } finally {
        Pop-Location
    }

    $SourcePath = Join-Path $TempPath "skills\skills-manager"

    if (-not (Test-Path $SourcePath)) {
        throw "Skills Manager folder not found in repository"
    }

    # Create target directory
    Write-Host "📦 Installing to personal skills directory..." -ForegroundColor Cyan
    $TargetDir = Split-Path -Parent $TargetPath
    if (-not (Test-Path $TargetDir)) {
        New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
    }

    # Copy skills-manager to target location
    Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Force

    Write-Host ""
    Write-Host "✅ Skills Manager installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📍 Installed to:" -ForegroundColor Cyan
    Write-Host "   $TargetPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔄 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Restart your Claude Code chat session" -ForegroundColor Gray
    Write-Host "   2. Try: 'List all installed skills'" -ForegroundColor Gray
    Write-Host "   3. Try: 'Install skill from <git-url>'" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temp directory
    if (Test-Path $TempPath) {
        Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
