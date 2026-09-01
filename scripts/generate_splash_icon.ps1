Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\rakes\Music\akash\salon_queue\assets\images\splash_chair_white.png"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

$densities = @{
    "drawable-mdpi" = 288
    "drawable-hdpi" = 432
    "drawable-xhdpi" = 576
    "drawable-xxhdpi" = 864
    "drawable-xxxhdpi" = 1152
    "drawable" = 576
}

foreach ($folder in $densities.Keys) {
    $size = $densities[$folder]
    $dir = "C:\Users\rakes\Music\akash\salon_queue\android\app\src\main\res\$folder"
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }

    $dest = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    # Chair fits inside the center 45% of the 288dp canvas (approx 130dp)
    $chairW = [int]($size * 0.44)
    $chairH = [int]($chairW * ($src.Height / $src.Width))
    $chairX = [int](($size - $chairW) / 2)
    $chairY = [int](($size - $chairH) / 2)

    $g.DrawImage($src, $chairX, $chairY, $chairW, $chairH)
    $g.Dispose()

    $outPath = Join-Path $dir "splash_chair_icon.png"
    $dest.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $dest.Dispose()
    Write-Host "Generated: $outPath ($size x $size, Chair: $chairW x $chairH)"
}

$src.Dispose()
