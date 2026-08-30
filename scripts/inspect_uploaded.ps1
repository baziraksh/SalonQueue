Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem "C:\Users\rakes\.gemini\antigravity-ide\brain\3b6f2523-9547-4668-b0fd-6a4eb82f2eaa\.user_uploaded\*"
foreach ($f in $files) {
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        Write-Host "$($f.Name) $($img.Width) x $($img.Height)"
        $img.Dispose()
    } catch {
        Write-Host "Error reading $($f.Name): $_"
    }
}
