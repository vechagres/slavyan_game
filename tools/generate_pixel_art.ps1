param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\assets\pixel_art")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function ColorFromHex([string]$Hex) {
    return [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function New-Bitmap([int]$CellsWide, [int]$CellsHigh, [int]$Scale, [System.Drawing.Color]$Background) {
    $pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList @(
        ($CellsWide * $Scale),
        ($CellsHigh * $Scale),
        $pixelFormat
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($Background)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.Dispose()
    return $bitmap
}

function Use-Graphics([System.Drawing.Bitmap]$Bitmap, [scriptblock]$Script) {
    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    try {
        & $Script $graphics
    }
    finally {
        $graphics.Dispose()
    }
}

function Paint-Rect(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [System.Drawing.Color]$Color,
    [int]$X,
    [int]$Y,
    [int]$W,
    [int]$H
) {
    if ($W -le 0 -or $H -le 0) {
        return
    }

    $brush = New-Object System.Drawing.SolidBrush $Color
    try {
        $Graphics.FillRectangle($brush, $X * $Scale, $Y * $Scale, $W * $Scale, $H * $Scale)
    }
    finally {
        $brush.Dispose()
    }
}

function Paint-OutlinedRect(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [System.Drawing.Color]$Outline,
    [System.Drawing.Color]$Fill,
    [int]$X,
    [int]$Y,
    [int]$W,
    [int]$H
) {
    Paint-Rect $Graphics $Scale $Outline $X $Y $W $H
    if ($W -gt 2 -and $H -gt 2) {
        Paint-Rect $Graphics $Scale $Fill ($X + 1) ($Y + 1) ($W - 2) ($H - 2)
    }
}

function Save-Png([System.Drawing.Bitmap]$Bitmap, [string]$Path) {
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
}

function Get-Char([int]$CodePoint) {
    return [string][char]$CodePoint
}

function Get-DumaTitle() {
    return -join ([char[]](
        0x0413, 0x041E, 0x0421, 0x0423, 0x0414, 0x0410, 0x0420, 0x0421, 0x0422, 0x0412,
        0x0415, 0x041D, 0x041D, 0x0410, 0x042F, 0x0020, 0x0414, 0x0423, 0x041C, 0x0410
    ))
}

$PixelFont = @{}
$PixelFont[" "] = @("000", "000", "000", "000", "000", "000", "000")
$PixelFont[(Get-Char 0x0410)] = @("01110", "10001", "10001", "11111", "10001", "10001", "10001")
$PixelFont[(Get-Char 0x0412)] = @("11110", "10001", "10001", "11110", "10001", "10001", "11110")
$PixelFont[(Get-Char 0x0413)] = @("11111", "10000", "10000", "10000", "10000", "10000", "10000")
$PixelFont[(Get-Char 0x0414)] = @("00110", "01001", "01001", "10001", "11111", "10001", "10001")
$PixelFont[(Get-Char 0x0415)] = @("11111", "10000", "10000", "11110", "10000", "10000", "11111")
$PixelFont[(Get-Char 0x041C)] = @("10001", "11011", "10101", "10101", "10001", "10001", "10001")
$PixelFont[(Get-Char 0x041D)] = @("10001", "10001", "10001", "11111", "10001", "10001", "10001")
$PixelFont[(Get-Char 0x041E)] = @("01110", "10001", "10001", "10001", "10001", "10001", "01110")
$PixelFont[(Get-Char 0x0420)] = @("11110", "10001", "10001", "11110", "10000", "10000", "10000")
$PixelFont[(Get-Char 0x0421)] = @("01111", "10000", "10000", "10000", "10000", "10000", "01111")
$PixelFont[(Get-Char 0x0422)] = @("11111", "00100", "00100", "00100", "00100", "00100", "00100")
$PixelFont[(Get-Char 0x0423)] = @("10001", "10001", "10001", "01111", "00001", "00010", "11100")
$PixelFont[(Get-Char 0x042F)] = @("01111", "10001", "10001", "01111", "00101", "01001", "10001")

function Draw-Glyph(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [string[]]$Glyph,
    [int]$X,
    [int]$Y,
    [System.Drawing.Color]$Color
) {
    for ($row = 0; $row -lt $Glyph.Count; $row++) {
        $line = $Glyph[$row]
        for ($col = 0; $col -lt $line.Length; $col++) {
            if ($line[$col] -eq '1') {
                Paint-Rect $Graphics $Scale $Color ($X + $col) ($Y + $row) 1 1
            }
        }
    }
}

function Get-PixelTextWidth([string]$Text, [int]$LetterSpacing = 1) {
    $chars = $Text.ToCharArray()
    $width = 0

    for ($index = 0; $index -lt $chars.Count; $index++) {
        $glyphKey = [string]$chars[$index]
        $glyph = if ($PixelFont.ContainsKey($glyphKey)) { $PixelFont[$glyphKey] } else { $PixelFont[" "] }
        $width += $glyph[0].Length
        if ($index -lt ($chars.Count - 1)) {
            $width += $LetterSpacing
        }
    }

    return $width
}

function Draw-PixelText(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [string]$Text,
    [int]$X,
    [int]$Y,
    [System.Drawing.Color]$Primary,
    [System.Drawing.Color]$Shadow,
    [int]$LetterSpacing = 1
) {
    $cursor = $X
    foreach ($char in $Text.ToCharArray()) {
        $glyphKey = [string]$char
        $glyph = if ($PixelFont.ContainsKey($glyphKey)) { $PixelFont[$glyphKey] } else { $PixelFont[" "] }

        if ($Shadow.A -gt 0) {
            Draw-Glyph $Graphics $Scale $glyph ($cursor + 1) ($Y + 1) $Shadow
        }
        Draw-Glyph $Graphics $Scale $glyph $cursor $Y $Primary

        $cursor += $glyph[0].Length + $LetterSpacing
    }
}

function Draw-Crest(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [int]$CenterX,
    [int]$Y
) {
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX - 1) $Y 3 1
    Paint-Rect $Graphics $Scale $Palette.brass $CenterX ($Y - 1) 1 3
    Paint-Rect $Graphics $Scale $Palette.banner ($CenterX - 2) ($Y + 1) 5 3
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX - 1) ($Y + 1) 3 3
    Paint-Rect $Graphics $Scale $Palette.banner $CenterX ($Y + 2) 1 2
    Paint-Rect $Graphics $Scale $Palette.woodDark ($CenterX - 5) ($Y + 1) 2 1
    Paint-Rect $Graphics $Scale $Palette.woodDark ($CenterX + 3) ($Y + 1) 2 1
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX - 6) ($Y + 2) 3 2
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX + 3) ($Y + 2) 3 2
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX - 7) ($Y + 4) 2 1
    Paint-Rect $Graphics $Scale $Palette.brass ($CenterX + 5) ($Y + 4) 2 1
    Paint-Rect $Graphics $Scale $Palette.white $CenterX ($Y + 2) 1 1
}

$Palette = @{
    outline    = ColorFromHex "#191515"
    shadow     = ColorFromHex "#2B1B1D"
    skin       = ColorFromHex "#E3BE9A"
    hair       = ColorFromHex "#573826"
    white      = ColorFromHex "#EEE6D9"
    suit       = ColorFromHex "#25232C"
    navy       = ColorFromHex "#22324A"
    tieBlue    = ColorFromHex "#2B6FA3"
    tieRed     = ColorFromHex "#8F3236"
    gold       = ColorFromHex "#C89A37"
    gray       = ColorFromHex "#7E8792"
    lightGray  = ColorFromHex "#AEB6C0"
    visor      = ColorFromHex "#BFD3E2"
    tactical   = ColorFromHex "#1E2328"
    olive      = ColorFromHex "#46513E"
    chairDark  = ColorFromHex "#57341E"
    chairLight = ColorFromHex "#8A5B32"
    chairSeat  = ColorFromHex "#6D1F28"
    wall       = ColorFromHex "#C7B89E"
    panel      = ColorFromHex "#7A6048"
    woodDark   = ColorFromHex "#493023"
    woodMid    = ColorFromHex "#6D4732"
    woodLight  = ColorFromHex "#906043"
    banner     = ColorFromHex "#7B2B30"
    carpet     = ColorFromHex "#6E1D28"
    carpetDark = ColorFromHex "#4C131B"
    brass      = ColorFromHex "#B98B33"
    desk       = ColorFromHex "#3B271D"
    glass      = ColorFromHex "#7D97A7"
    door       = ColorFromHex "#2F211B"
    plant      = ColorFromHex "#44654A"
}

function Draw-Weinstein([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 16 16 $scale ([System.Drawing.Color]::Transparent)

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.outline 3 1 10 1
        Paint-Rect $g $scale $Palette.outline 4 0 8 2
        Paint-Rect $g $scale $Palette.gray 5 1 6 1

        Paint-OutlinedRect $g $scale $Palette.outline $Palette.skin 5 3 6 5
        Paint-Rect $g $scale $Palette.hair 4 4 1 3
        Paint-Rect $g $scale $Palette.hair 11 4 1 3
        Paint-Rect $g $scale $Palette.hair 4 7 1 2
        Paint-Rect $g $scale $Palette.hair 11 7 1 2
        Paint-Rect $g $scale $Palette.outline 6 5 1 1
        Paint-Rect $g $scale $Palette.outline 9 5 1 1
        Paint-Rect $g $scale $Palette.outline 8 6 1 1
        Paint-Rect $g $scale $Palette.hair 6 3 4 1

        Paint-OutlinedRect $g $scale $Palette.outline $Palette.suit 4 8 8 5
        Paint-Rect $g $scale $Palette.white 7 9 2 2
        Paint-Rect $g $scale $Palette.tieBlue 8 10 1 2
        Paint-Rect $g $scale $Palette.gray 6 9 1 2
        Paint-Rect $g $scale $Palette.gray 9 9 1 2
        Paint-Rect $g $scale $Palette.suit 3 8 1 4
        Paint-Rect $g $scale $Palette.suit 12 8 1 4
        Paint-Rect $g $scale $Palette.skin 3 12 1 1
        Paint-Rect $g $scale $Palette.skin 12 12 1 1
        Paint-Rect $g $scale $Palette.white 12 10 2 2
        Paint-Rect $g $scale $Palette.tieBlue 13 10 1 1

        Paint-Rect $g $scale $Palette.suit 5 13 2 2
        Paint-Rect $g $scale $Palette.suit 9 13 2 2
        Paint-Rect $g $scale $Palette.outline 5 15 2 1
        Paint-Rect $g $scale $Palette.outline 9 15 2 1
    }

    Save-Png $bitmap $Path
}

function Draw-Slavyan([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 16 16 $scale ([System.Drawing.Color]::Transparent)

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.hair 5 2 6 2
        Paint-OutlinedRect $g $scale $Palette.outline $Palette.skin 5 4 6 5
        Paint-Rect $g $scale $Palette.outline 6 6 1 1
        Paint-Rect $g $scale $Palette.outline 9 6 1 1
        Paint-Rect $g $scale $Palette.outline 8 7 1 1

        Paint-OutlinedRect $g $scale $Palette.outline $Palette.navy 4 9 8 4
        Paint-Rect $g $scale $Palette.white 7 10 2 2
        Paint-Rect $g $scale $Palette.tieRed 8 11 1 2
        Paint-Rect $g $scale $Palette.navy 3 9 1 4
        Paint-Rect $g $scale $Palette.navy 12 9 1 4
        Paint-Rect $g $scale $Palette.skin 3 12 1 1
        Paint-Rect $g $scale $Palette.skin 12 12 1 1

        Paint-Rect $g $scale $Palette.navy 5 13 2 2
        Paint-Rect $g $scale $Palette.navy 9 13 2 2
        Paint-Rect $g $scale $Palette.outline 5 15 2 1
        Paint-Rect $g $scale $Palette.outline 9 15 2 1
    }

    Save-Png $bitmap $Path
}

function Draw-Prosecutor([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 16 16 $scale ([System.Drawing.Color]::Transparent)

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.navy 4 1 8 1
        Paint-Rect $g $scale $Palette.navy 5 0 6 2
        Paint-Rect $g $scale $Palette.gold 7 1 2 1
        Paint-Rect $g $scale $Palette.outline 4 2 8 1
        Paint-OutlinedRect $g $scale $Palette.outline $Palette.skin 5 4 6 4
        Paint-Rect $g $scale $Palette.outline 6 5 1 1
        Paint-Rect $g $scale $Palette.outline 9 5 1 1
        Paint-Rect $g $scale $Palette.outline 8 6 1 1
        Paint-Rect $g $scale $Palette.skin 10 7 1 1

        Paint-OutlinedRect $g $scale $Palette.outline $Palette.navy 4 8 8 5
        Paint-Rect $g $scale $Palette.gold 4 8 2 1
        Paint-Rect $g $scale $Palette.gold 10 8 2 1
        Paint-Rect $g $scale $Palette.white 7 9 2 2
        Paint-Rect $g $scale $Palette.tieRed 8 10 1 2
        Paint-Rect $g $scale $Palette.gray 6 9 1 2
        Paint-Rect $g $scale $Palette.gray 9 9 1 2
        Paint-Rect $g $scale $Palette.gold 7 12 1 1
        Paint-Rect $g $scale $Palette.gold 9 12 1 1
        Paint-Rect $g $scale $Palette.navy 3 8 1 4
        Paint-Rect $g $scale $Palette.navy 12 8 1 4
        Paint-Rect $g $scale $Palette.skin 3 12 1 1
        Paint-Rect $g $scale $Palette.skin 12 12 1 1
        Paint-Rect $g $scale $Palette.gray 12 10 2 1

        Paint-Rect $g $scale $Palette.navy 5 13 2 2
        Paint-Rect $g $scale $Palette.navy 9 13 2 2
        Paint-Rect $g $scale $Palette.outline 5 15 2 1
        Paint-Rect $g $scale $Palette.outline 9 15 2 1
    }

    Save-Png $bitmap $Path
}

function Draw-Guard([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 16 16 $scale ([System.Drawing.Color]::Transparent)

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.tactical 4 1 8 1
        Paint-Rect $g $scale $Palette.gray 5 2 6 2
        Paint-Rect $g $scale $Palette.tactical 5 4 6 1
        Paint-OutlinedRect $g $scale $Palette.outline $Palette.skin 6 5 4 3
        Paint-Rect $g $scale $Palette.outline 7 6 1 1
        Paint-Rect $g $scale $Palette.outline 9 6 1 1
        Paint-Rect $g $scale $Palette.tactical 5 5 1 3
        Paint-Rect $g $scale $Palette.tactical 10 5 1 3
        Paint-Rect $g $scale $Palette.tactical 7 8 2 1

        Paint-OutlinedRect $g $scale $Palette.outline $Palette.tactical 4 9 8 4
        Paint-Rect $g $scale $Palette.olive 6 9 4 3
        Paint-Rect $g $scale $Palette.lightGray 7 10 2 1
        Paint-Rect $g $scale $Palette.tactical 3 9 1 4
        Paint-Rect $g $scale $Palette.tactical 12 9 1 4
        Paint-Rect $g $scale $Palette.gray 13 9 2 1
        Paint-Rect $g $scale $Palette.outline 14 10 1 3

        Paint-Rect $g $scale $Palette.tactical 5 13 2 2
        Paint-Rect $g $scale $Palette.tactical 9 13 2 2
        Paint-Rect $g $scale $Palette.outline 5 15 2 1
        Paint-Rect $g $scale $Palette.outline 9 15 2 1
    }

    Save-Png $bitmap $Path
}

function Draw-Chair([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 16 16 $scale ([System.Drawing.Color]::Transparent)

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.brass 7 0 2 1
        Paint-Rect $g $scale $Palette.brass 5 1 6 1
        Paint-Rect $g $scale $Palette.brass 3 2 1 2
        Paint-Rect $g $scale $Palette.brass 12 2 1 2

        Paint-Rect $g $scale $Palette.chairDark 4 2 1 11
        Paint-Rect $g $scale $Palette.chairDark 11 2 1 11
        Paint-Rect $g $scale $Palette.brass 4 2 1 1
        Paint-Rect $g $scale $Palette.brass 11 2 1 1

        Paint-Rect $g $scale $Palette.chairLight 5 2 6 1
        Paint-Rect $g $scale $Palette.brass 6 2 4 1
        Paint-Rect $g $scale $Palette.chairLight 5 3 6 6
        Paint-Rect $g $scale $Palette.chairSeat 6 4 4 4
        Paint-Rect $g $scale $Palette.brass 5 4 1 3
        Paint-Rect $g $scale $Palette.brass 10 4 1 3
        Paint-Rect $g $scale $Palette.lightGray 7 5 2 1

        Paint-Rect $g $scale $Palette.brass 3 9 3 1
        Paint-Rect $g $scale $Palette.brass 10 9 3 1
        Paint-Rect $g $scale $Palette.chairDark 5 9 6 1
        Paint-Rect $g $scale $Palette.brass 5 10 6 1
        Paint-Rect $g $scale $Palette.chairSeat 6 11 4 2
        Paint-Rect $g $scale $Palette.lightGray 7 11 2 1

        Paint-Rect $g $scale $Palette.chairDark 4 13 2 2
        Paint-Rect $g $scale $Palette.chairDark 10 13 2 2
        Paint-Rect $g $scale $Palette.chairLight 5 13 1 1
        Paint-Rect $g $scale $Palette.chairLight 10 13 1 1
        Paint-Rect $g $scale $Palette.brass 4 15 2 1
        Paint-Rect $g $scale $Palette.brass 10 15 2 1
        Paint-Rect $g $scale $Palette.brass 6 13 4 1
    }

    Save-Png $bitmap $Path
}

function Draw-Background([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 160 90 $scale $Palette.wall

    Use-Graphics $bitmap {
        param($g)

        $title = Get-DumaTitle
        $titleX = [Math]::Floor((160 - (Get-PixelTextWidth $title 1)) / 2)

        Paint-Rect $g $scale $Palette.panel 0 0 160 18
        Paint-Rect $g $scale $Palette.woodDark 0 18 160 3
        Paint-Rect $g $scale $Palette.wall 0 21 160 34
        Draw-Crest $g $scale 80 2
        Draw-PixelText $g $scale $title $titleX 8 $Palette.white $Palette.woodDark 1
        Paint-Rect $g $scale $Palette.brass 46 13 68 1

        Paint-Rect $g $scale $Palette.woodMid 4 12 22 38
        Paint-Rect $g $scale $Palette.woodLight 6 14 18 34
        Paint-Rect $g $scale $Palette.woodMid 134 12 22 38
        Paint-Rect $g $scale $Palette.woodLight 136 14 18 34

        Paint-Rect $g $scale $Palette.woodMid 42 24 28 18
        Paint-Rect $g $scale $Palette.glass 44 26 24 14
        Paint-Rect $g $scale $Palette.woodMid 90 24 28 18
        Paint-Rect $g $scale $Palette.glass 92 26 24 14

        Paint-Rect $g $scale $Palette.banner 74 20 12 18
        Paint-Rect $g $scale $Palette.brass 77 23 6 6
        Paint-Rect $g $scale $Palette.white 79 25 2 2
        Paint-Rect $g $scale $Palette.woodDark 60 40 40 3

        Paint-Rect $g $scale $Palette.woodMid 0 48 36 18
        Paint-Rect $g $scale $Palette.woodLight 4 50 28 14
        Paint-Rect $g $scale $Palette.desk 12 42 12 6
        Paint-Rect $g $scale $Palette.brass 14 44 8 2

        Paint-Rect $g $scale $Palette.door 146 38 10 24
        Paint-Rect $g $scale $Palette.brass 147 49 1 1

        for ($lane = 0; $lane -lt 5; $lane++) {
            $laneY = 58 + ($lane * 6)
            $laneColor = if ($lane % 2 -eq 0) { $Palette.carpet } else { $Palette.carpetDark }
            Paint-Rect $g $scale $laneColor 0 $laneY 160 6
            Paint-Rect $g $scale $Palette.shadow 0 ($laneY + 5) 160 1
        }

        Paint-Rect $g $scale $Palette.carpetDark 0 54 36 32
        Paint-Rect $g $scale $Palette.brass 36 54 1 32

        $deskRows = @(
            @{ X = 42; Y = 56; W = 18; H = 4 },
            @{ X = 66; Y = 60; W = 18; H = 4 },
            @{ X = 92; Y = 56; W = 18; H = 4 },
            @{ X = 116; Y = 60; W = 18; H = 4 },
            @{ X = 42; Y = 68; W = 18; H = 4 },
            @{ X = 66; Y = 72; W = 18; H = 4 },
            @{ X = 92; Y = 68; W = 18; H = 4 },
            @{ X = 116; Y = 72; W = 18; H = 4 }
        )

        foreach ($deskRow in $deskRows) {
            Paint-Rect $g $scale $Palette.desk $deskRow.X $deskRow.Y $deskRow.W $deskRow.H
            Paint-Rect $g $scale $Palette.woodLight ($deskRow.X + 1) ($deskRow.Y + 1) ($deskRow.W - 2) 1
            Paint-Rect $g $scale $Palette.gray ($deskRow.X + 5) ($deskRow.Y + 4) 2 2
            Paint-Rect $g $scale $Palette.gray ($deskRow.X + 11) ($deskRow.Y + 4) 2 2
        }

        Paint-Rect $g $scale $Palette.desk 48 82 64 4
        Paint-Rect $g $scale $Palette.woodLight 49 83 62 1
        Paint-Rect $g $scale $Palette.plant 138 54 4 8
        Paint-Rect $g $scale $Palette.panel 137 61 6 3
    }

    Save-Png $bitmap $Path
}

function Draw-Preview([string]$Path) {
    $scale = 4
    $bitmap = New-Bitmap 80 24 $scale $Palette.wall

    Use-Graphics $bitmap {
        param($g)

        Paint-Rect $g $scale $Palette.panel 0 18 80 6
    }

    $spriteFiles = @(
        (Join-Path $OutputDir "slavyan.png")
        (Join-Path $OutputDir "weinstein.png")
        (Join-Path $OutputDir "chair.png")
        (Join-Path $OutputDir "prosecutor.png")
        (Join-Path $OutputDir "guard.png")
    )

    Use-Graphics $bitmap {
        param($g)

        $x = 4
        foreach ($file in $spriteFiles) {
            $sprite = [System.Drawing.Image]::FromFile($file)
            try {
                $g.DrawImage($sprite, $x * $scale, 2 * $scale, 16 * $scale, 16 * $scale)
            }
            finally {
                $sprite.Dispose()
            }
            $x += 15
        }
    }

    Save-Png $bitmap $Path
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDir)
if (-not (Test-Path -LiteralPath $resolvedOutput)) {
    New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
}

Draw-Slavyan (Join-Path $resolvedOutput "slavyan.png")
Draw-Weinstein (Join-Path $resolvedOutput "weinstein.png")
Draw-Prosecutor (Join-Path $resolvedOutput "prosecutor.png")
Draw-Guard (Join-Path $resolvedOutput "guard.png")
Draw-Chair (Join-Path $resolvedOutput "chair.png")
Draw-Background (Join-Path $resolvedOutput "background_hall.png")
Draw-Preview (Join-Path $resolvedOutput "preview_sheet.png")

Get-ChildItem -LiteralPath $resolvedOutput -File | Sort-Object Name | Select-Object -ExpandProperty FullName
