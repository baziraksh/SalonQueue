# PowerShell script for automatic Git push
# Resolves project root, stages all changes, commits, and pushes to origin main

# 1. Move to the project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) {
    $ProjectRoot = (Get-Item $ScriptDir).Parent.FullName
} else {
    $ProjectRoot = Get-Location
}

# Ensure we navigate to the repository root containing .git
if (Test-Path "$ProjectRoot\.git") {
    Set-Location $ProjectRoot
} else {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($gitRoot) {
        Set-Location $gitRoot
    }
}

# 2. Check whether there are uncommitted changes
$changes = git status --porcelain

if ($changes) {
    Write-Host "[auto-git-push] Uncommitted changes detected. Staging changes..."
    # 3. If there are changes, run git add .
    git add .
    
    # 4. Commit them with the message "Auto-save: Gemini completed task"
    Write-Host "[auto-git-push] Committing changes..."
    git commit -m "Auto-save: Gemini completed task"
    
    # 5. Push to origin main
    Write-Host "[auto-git-push] Pushing to origin main..."
    git push origin main
} else {
    # 6. If there are no changes, do nothing
    Write-Host "[auto-git-push] No uncommitted changes detected. Nothing to do."
}

# Output JSON for Antigravity Stop hook contract compatibility
Write-Output "{}"
