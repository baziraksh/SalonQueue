Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("C:\Users\rakes\.gemini\antigravity-ide\brain\3b6f2523-9547-4668-b0fd-6a4eb82f2eaa\.user_uploaded\media_1787938459103.png")

Write-Host "Width: $($img.Width), Height: $($img.Height)"

$steps = @(0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
foreach ($s in $steps) {
    $y = [Math]::Min($img.Height - 1, [int]($s * ($img.Height - 1)))
    $x = [int]($img.Width * 0.1) # Left side to avoid the chair
    $c = $img.GetPixel($x, $y)
    Write-Host "Y%: $s -> #$($c.R.ToString('X2'))$($c.G.ToString('X2'))$($c.B.ToString('X2'))"
}
$img.Dispose()
