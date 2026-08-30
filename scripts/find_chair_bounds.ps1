Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("C:\Users\rakes\.gemini\antigravity-ide\brain\3b6f2523-9547-4668-b0fd-6a4eb82f2eaa\.user_uploaded\media_1787938459103.png")

$minX = $img.Width
$maxX = 0
$minY = $img.Height
$maxY = 0

for ($y = 0; $y -lt $img.Height; $y++) {
    for ($x = 0; $x -lt $img.Width; $x++) {
        $c = $img.GetPixel($x, $y)
        # White or near white chair pixels
        if ($c.R -gt 240 -and $c.G -gt 240 -and $c.B -gt 240) {
            # Exclude status bar icons near top
            if ($y -gt 50) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
}

Write-Host "Chair bounds: X: [$minX, $maxX], Y: [$minY, $maxY]"
$w = $maxX - $minX + 1
$h = $maxY - $minY + 1
Write-Host "Chair Size: $w x $h (Ratio: $([double]$w / $h))"
Write-Host "Center X%: $([double]($minX + $maxX) / (2 * $img.Width))"
Write-Host "Center Y%: $([double]($minY + $maxY) / (2 * $img.Height))"
Write-Host "Chair Width % of screen width: $([double]$w / $img.Width)"
Write-Host "Chair Height % of screen height: $([double]$h / $img.Height)"

$img.Dispose()
