Add-Type -AssemblyName System.Drawing

$chair = [System.Drawing.Bitmap]::FromFile("C:\Users\rakes\Music\akash\salon_queue\assets\images\splash_chair_white.png")
Write-Host "splash_chair_white: $($chair.Width) x $($chair.Height)"
$chair.Dispose()
