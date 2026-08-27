Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\rakes\.gemini\antigravity-ide\brain\3b6f2523-9547-4668-b0fd-6a4eb82f2eaa\.user_uploaded\media_1787854785685.png"
$destPath = "c:\Users\rakes\Music\akash\salon_queue\assets\images\splash_chair_white.png"

$bmp = [System.Drawing.Bitmap]::FromFile($srcPath)
Write-Host "Width: $($bmp.Width), Height: $($bmp.Height)"

$rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
$bmpData = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$stride = [Math]::Abs($bmpData.Stride)
$bytes = $stride * $bmp.Height
$rgbValues = New-Object byte[] $bytes

[System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $rgbValues, 0, $bytes)
$bmp.UnlockBits($bmpData)

# Find bounding box of white chair (looking around middle of screen: Y between 0.35 and 0.65 of height)
$minY = [int]($bmp.Height * 0.35)
$maxY = [int]($bmp.Height * 0.65)
$minX = [int]($bmp.Width * 0.20)
$maxX = [int]($bmp.Width * 0.80)

$boxLeft = $bmp.Width
$boxRight = 0
$boxTop = $bmp.Height
$boxBottom = 0

for ($y = $minY; $y -lt $maxY; $y++) {
    for ($x = $minX; $x -lt $maxX; $x++) {
        $idx = ($y * $stride) + ($x * 4)
        $b = $rgbValues[$idx]
        $g = $rgbValues[$idx + 1]
        $r = $rgbValues[$idx + 2]
        
        # Check if near-white (low saturation, high brightness)
        $bright = ($r + $g + $b) / 3.0
        $diff = [Math]::Abs($r - $g) + [Math]::Abs($g - $b)
        
        if ($bright -gt 210 -and $diff -lt 30) {
            if ($x -lt $boxLeft) { $boxLeft = $x }
            if ($x -gt $boxRight) { $boxRight = $x }
            if ($y -lt $boxTop) { $boxTop = $y }
            if ($y -gt $boxBottom) { $boxBottom = $y }
        }
    }
}

Write-Host "Found Chair Box: Left=$boxLeft, Right=$boxRight, Top=$boxTop, Bottom=$boxBottom"
$pad = 8
$cropX = [Math]::Max(0, $boxLeft - $pad)
$cropY = [Math]::Max(0, $boxTop - $pad)
$cropW = ($boxRight - $boxLeft + 1) + ($pad * 2)
$cropH = ($boxBottom - $boxTop + 1) + ($pad * 2)

$outBmp = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outRect = New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)
$outData = $outBmp.LockBits($outRect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outStride = [Math]::Abs($outData.Stride)
$outBytes = $outStride * $cropH
$outValues = New-Object byte[] $outBytes

for ($y = 0; $y -lt $cropH; $y++) {
    for ($x = 0; $x -lt $cropW; $x++) {
        $srcX = $cropX + $x
        $srcY = $cropY + $y
        $srcIdx = ($srcY * $stride) + ($srcX * 4)
        $outIdx = ($y * $outStride) + ($x * 4)
        
        $b = $rgbValues[$srcIdx]
        $g = $rgbValues[$srcIdx + 1]
        $r = $rgbValues[$srcIdx + 2]
        
        $bright = ($r + $g + $b) / 3.0
        $diff = [Math]::Abs($r - $g) + [Math]::Abs($g - $b)
        
        if ($bright -gt 235 -and $diff -lt 20) {
            # Solid white
            $outValues[$outIdx] = 255
            $outValues[$outIdx + 1] = 255
            $outValues[$outIdx + 2] = 255
            $outValues[$outIdx + 3] = 255
        } elseif ($bright -gt 170 -and $diff -lt 55) {
            # Smooth antialiased border
            $alpha = [byte]([Math]::Min(255, [Math]::Max(0, ($bright - 170) * 255 / 65)))
            $outValues[$outIdx] = 255
            $outValues[$outIdx + 1] = 255
            $outValues[$outIdx + 2] = 255
            $outValues[$outIdx + 3] = $alpha
        } else {
            # Fully transparent
            $outValues[$outIdx] = 0
            $outValues[$outIdx + 1] = 0
            $outValues[$outIdx + 2] = 0
            $outValues[$outIdx + 3] = 0
        }
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($outValues, 0, $outData.Scan0, $outBytes)
$outBmp.UnlockBits($outData)
$bmp.Dispose()

$outBmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
$outBmp.Dispose()
Write-Host "Generated $destPath successfully ($cropW x $cropH)!"
