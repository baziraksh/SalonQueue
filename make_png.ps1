Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\rakes\.gemini\antigravity-ide\brain\17bdff3f-9117-4461-a805-0bac394947fc\modern_salon_chair_1787335079575.jpg"
$destPath = "c:\Users\rakes\Music\akash\salon_queue\assets\images\salon_chair.png"

$bmp = [System.Drawing.Bitmap]::FromFile($srcPath)
$out = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Lock bits for high speed pixel manipulation
$rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
$bmpData = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outData = $out.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$bytes = [Math]::Abs($bmpData.Stride) * $bmp.Height
$rgbValues = New-Object byte[] $bytes
$outValues = New-Object byte[] $bytes

[System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $rgbValues, 0, $bytes)

for ($i = 0; $i -lt $bytes; $i += 4) {
    $b = $rgbValues[$i]
    $g = $rgbValues[$i + 1]
    $r = $rgbValues[$i + 2]
    
    # Calculate difference from white (255, 255, 255)
    $db = 255 - $b
    $dg = 255 - $g
    $dr = 255 - $r
    $maxDiff = [Math]::Max([Math]::Max($dr, $dg), $db)
    
    if ($maxDiff -lt 8) {
        # Completely transparent
        $outValues[$i] = 0
        $outValues[$i + 1] = 0
        $outValues[$i + 2] = 0
        $outValues[$i + 3] = 0
    } elseif ($maxDiff -lt 30) {
        # Antialiased edge
        $alpha = [byte](($maxDiff - 8) * 255 / 22)
        $outValues[$i] = $b
        $outValues[$i + 1] = $g
        $outValues[$i + 2] = $r
        $outValues[$i + 3] = $alpha
    } else {
        $outValues[$i] = $b
        $outValues[$i + 1] = $g
        $outValues[$i + 2] = $r
        $outValues[$i + 3] = 255
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($outValues, 0, $outData.Scan0, $bytes)

$bmp.UnlockBits($bmpData)
$out.UnlockBits($outData)
$bmp.Dispose()

$out.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()

Write-Host "Processed transparent PNG successfully!"
