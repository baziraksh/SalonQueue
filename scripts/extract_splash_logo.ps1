Add-Type -AssemblyName System.Drawing

$src = 'C:\Users\rakes\.gemini\antigravity-ide\brain\3b6f2523-9547-4668-b0fd-6a4eb82f2eaa\.user_uploaded\media_1787854785685.png'
$dest = 'c:\Users\rakes\Music\akash\salon_queue\assets\images\splash_chair_logo.png'

$bmp = [System.Drawing.Bitmap]::FromFile($src)
Write-Host "Source image: $($bmp.Width) x $($bmp.Height)"

# Sample gradient
$p1 = $bmp.GetPixel(50, 150)
$p2 = $bmp.GetPixel(540, 1200)
$p3 = $bmp.GetPixel(1030, 2250)

Write-Host "Top-Left Color: R=$($p1.R), G=$($p1.G), B=$($p1.B) (#$($p1.R.ToString('X2'))$($p1.G.ToString('X2'))$($p1.B.ToString('X2')))"
Write-Host "Center Color:   R=$($p2.R), G=$($p2.G), B=$($p2.B) (#$($p2.R.ToString('X2'))$($p2.G.ToString('X2'))$($p2.B.ToString('X2')))"
Write-Host "Bottom-Right:   R=$($p3.R), G=$($p3.G), B=$($p3.B) (#$($p3.R.ToString('X2'))$($p3.G.ToString('X2'))$($p3.B.ToString('X2')))"

# Find bounds of white chair logo
# The chair is around center (Y between 800 and 1500, X between 200 and 880)
$minX = $bmp.Width
$maxX = 0
$minY = $bmp.Height
$maxY = 0

for ($y = 800; $y -lt 1600; $y++) {
    for ($x = 200; $x -lt 900; $x++) {
        $c = $bmp.GetPixel($x, $y)
        # Check if pixel is white/near white (R > 230, G > 230, B > 230)
        if ($c.R -gt 220 -and $c.G -gt 220 -and $c.B -gt 220) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

Write-Host "Logo bounding box: X=$minX..$maxX, Y=$minY..$maxY (Width=$($maxX - $minX + 1), Height=$($maxY - $minY + 1))"

# Add padding
$pad = 10
$cropX = [Math]::Max(0, $minX - $pad)
$cropY = [Math]::Max(0, $minY - $pad)
$cropW = ($maxX - $minX + 1) + ($pad * 2)
$cropH = ($maxY - $minY + 1) + ($pad * 2)

$out = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

for ($y = 0; $y -lt $cropH; $y++) {
    for ($x = 0; $x -lt $cropW; $x++) {
        $srcX = $cropX + $x
        $srcY = $cropY + $y
        if ($srcX -lt $bmp.Width -and $srcY -lt $bmp.Height) {
            $c = $bmp.GetPixel($srcX, $srcY)
            # Threshold for white logo with antialiasing
            $brightness = ($c.R + $c.G + $c.B) / 3.0
            $colorDiff = [Math]::Abs($c.R - $c.G) + [Math]::Abs($c.G - $c.B)
            
            if ($brightness -gt 240 -and $colorDiff -lt 25) {
                # Pure white
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 255, 255, 255))
            } elseif ($brightness -gt 190 -and $colorDiff -lt 45) {
                # Anti-aliased edge
                $alpha = [int]([Math]::Min(255, [Math]::Max(0, ($brightness - 190) * 255 / 50)))
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
            } else {
                # Transparent background
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            }
        }
    }
}

$out.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()
$bmp.Dispose()
Write-Host "Successfully saved $dest"
