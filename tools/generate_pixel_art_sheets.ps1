param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\assets\pixel_art\animated")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$FrameCells = 16
$Scale = 4
$FrameCount = 6

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

function Convert-DirX([string]$Direction, [int]$X, [int]$W) {
    if ($Direction -eq "left") {
        return $FrameCells - $X - $W
    }

    return $X
}

function Paint-DirRect(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [System.Drawing.Color]$Color,
    [int]$OriginX,
    [int]$OriginY,
    [string]$Direction,
    [int]$X,
    [int]$Y,
    [int]$W,
    [int]$H
) {
    $mappedX = Convert-DirX $Direction $X $W
    Paint-Rect $Graphics $Scale $Color ($OriginX + $mappedX) ($OriginY + $Y) $W $H
}

function Paint-DirOutlinedRect(
    [System.Drawing.Graphics]$Graphics,
    [int]$Scale,
    [System.Drawing.Color]$Outline,
    [System.Drawing.Color]$Fill,
    [int]$OriginX,
    [int]$OriginY,
    [string]$Direction,
    [int]$X,
    [int]$Y,
    [int]$W,
    [int]$H
) {
    Paint-DirRect $Graphics $Scale $Outline $OriginX $OriginY $Direction $X $Y $W $H
    if ($W -gt 2 -and $H -gt 2) {
        Paint-DirRect $Graphics $Scale $Fill $OriginX $OriginY $Direction ($X + 1) ($Y + 1) ($W - 2) ($H - 2)
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

function Save-Json([string]$Path, [object]$Data) {
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $json = $Data | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
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
    Paint-Rect $Graphics $Scale $Palette.paper $CenterX ($Y + 2) 1 1
}

$Palette = @{
    outline      = ColorFromHex "#171315"
    shadow       = [System.Drawing.Color]::FromArgb(120, 34, 21, 24)
    hit          = ColorFromHex "#C84A55"
    skin         = ColorFromHex "#E3BE9A"
    skinDark     = ColorFromHex "#C79872"
    hair         = ColorFromHex "#5A3B2A"
    black        = ColorFromHex "#111015"
    suit         = ColorFromHex "#26232B"
    navy         = ColorFromHex "#24354E"
    red          = ColorFromHex "#8D2C38"
    blue         = ColorFromHex "#3774A4"
    gold         = ColorFromHex "#C89A37"
    gray         = ColorFromHex "#6F7681"
    lightGray    = ColorFromHex "#AEB6C0"
    visor        = ColorFromHex "#BFD3E2"
    armorDark    = ColorFromHex "#4D5560"
    armorLight   = ColorFromHex "#7E8792"
    tactical     = ColorFromHex "#1E2328"
    olive        = ColorFromHex "#46513E"
    chairDark    = ColorFromHex "#56331D"
    chairMid     = ColorFromHex "#8A5C34"
    chairSeat    = ColorFromHex "#6F2029"
    wall         = ColorFromHex "#C8BAA3"
    wallShadow   = ColorFromHex "#AA9A80"
    panel        = ColorFromHex "#7A6048"
    woodDark     = ColorFromHex "#4B3023"
    woodMid      = ColorFromHex "#6D4733"
    woodLight    = ColorFromHex "#926145"
    brass        = ColorFromHex "#B98B33"
    banner       = ColorFromHex "#7B2B30"
    carpet       = ColorFromHex "#6E1E28"
    carpetDark   = ColorFromHex "#4C131B"
    podium       = ColorFromHex "#3A261C"
    screen       = ColorFromHex "#738A98"
    paper        = ColorFromHex "#E8E2D7"
    plant        = ColorFromHex "#46674D"
    door         = ColorFromHex "#2E211C"
}

function Get-HumanPose([int]$Frame) {
    switch ($Frame) {
        0 { return @{ bounce = 0; lean = 0; frontLeg = 0; backLeg = 0; frontArm = 0; backArm = 0; attack = $false; hit = $false } }
        1 { return @{ bounce = 1; lean = 0; frontLeg = 1; backLeg = 0; frontArm = 0; backArm = 1; attack = $false; hit = $false } }
        2 { return @{ bounce = 0; lean = 1; frontLeg = -1; backLeg = 1; frontArm = 1; backArm = -1; attack = $false; hit = $false } }
        3 { return @{ bounce = 1; lean = 1; frontLeg = 1; backLeg = -1; frontArm = -1; backArm = 1; attack = $false; hit = $false } }
        4 { return @{ bounce = 0; lean = 2; frontLeg = 0; backLeg = 1; frontArm = 2; backArm = -1; attack = $true; hit = $false } }
        5 { return @{ bounce = 1; lean = -1; frontLeg = 1; backLeg = 0; frontArm = -1; backArm = 0; attack = $false; hit = $true } }
        default { return @{ bounce = 0; lean = 0; frontLeg = 0; backLeg = 0; frontArm = 0; backArm = 0; attack = $false; hit = $false } }
    }
}

function Draw-HitSpark(
    [System.Drawing.Graphics]$Graphics,
    [int]$OriginX,
    [int]$OriginY,
    [string]$Direction,
    [int]$Lean
) {
    Paint-DirRect $Graphics $Scale $Palette.hit $OriginX $OriginY $Direction (11 + $Lean) 4 2 1
    Paint-DirRect $Graphics $Scale $Palette.hit $OriginX $OriginY $Direction (12 + $Lean) 5 1 1
    Paint-DirRect $Graphics $Scale $Palette.hit $OriginX $OriginY $Direction (11 + $Lean) 6 2 1
}

function Draw-SuitHuman(
    [System.Drawing.Graphics]$Graphics,
    [int]$OriginX,
    [int]$OriginY,
    [string]$Direction,
    [hashtable]$Pose,
    [hashtable]$Style
) {
    $lean = [int]$Pose.lean
    $bounce = [int]$Pose.bounce
    $frontLeg = [int]$Pose.frontLeg
    $backLeg = [int]$Pose.backLeg
    $frontArm = [int]$Pose.frontArm
    $backArm = [int]$Pose.backArm

    Paint-DirRect $Graphics $Scale $Palette.shadow $OriginX $OriginY $Direction 4 14 8 1

    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Style.pants $OriginX $OriginY $Direction (6 + $lean) (11 + $bounce + $backLeg) 2 3
    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Style.pants $OriginX $OriginY $Direction (9 + $lean) (11 + $bounce + $frontLeg) 2 3
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY $Direction (6 + $lean) (14 + $bounce + $backLeg) 2 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY $Direction (9 + $lean) (14 + $bounce + $frontLeg) 2 1

    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Style.body $OriginX $OriginY $Direction (6 + $lean) (8 + $bounce) 5 4
    Paint-DirRect $Graphics $Scale $Style.shirt $OriginX $OriginY $Direction (8 + $lean) (8 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Style.tie $OriginX $OriginY $Direction (9 + $lean) (9 + $bounce) 1 2

    Paint-DirRect $Graphics $Scale $Style.body $OriginX $OriginY $Direction (5 + $lean) (9 + $bounce + $backArm) 1 3
    Paint-DirRect $Graphics $Scale $Style.body $OriginX $OriginY $Direction (11 + $lean + $frontArm) (9 + $bounce) 1 3
    Paint-DirRect $Graphics $Scale $Palette.skin $OriginX $OriginY $Direction (11 + $lean + $frontArm) (12 + $bounce) 1 1

    Paint-DirRect $Graphics $Scale $Palette.skinDark $OriginX $OriginY $Direction (8 + $lean) (7 + $bounce) 2 1
    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Palette.skin $OriginX $OriginY $Direction (7 + $lean) (3 + $bounce) 4 5
    Paint-DirRect $Graphics $Scale $Palette.outline $OriginX $OriginY $Direction (9 + $lean) (5 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.skinDark $OriginX $OriginY $Direction (10 + $lean) (6 + $bounce) 1 1

    if ($Pose.hit) {
        Draw-HitSpark $Graphics $OriginX $OriginY $Direction $lean
    }
}

function Draw-WeinsteinFrame([System.Drawing.Graphics]$Graphics, [int]$OriginX, [int]$OriginY, [int]$Frame) {
    $pose = Get-HumanPose $Frame
    $style = @{
        body  = $Palette.suit
        pants = $Palette.suit
        shirt = $Palette.paper
        tie   = $Palette.blue
    }

    Draw-SuitHuman $Graphics $OriginX $OriginY "right" $pose $style

    $lean = [int]$pose.lean
    $bounce = [int]$pose.bounce

    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "right" (5 + $lean) (1 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "right" (6 + $lean) (0 + $bounce) 4 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "right" (7 + $lean) (1 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "right" (5 + $lean) (3 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "right" (6 + $lean) (4 + $bounce) 1 4
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "right" (6 + $lean) (7 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "right" (7 + $lean) (9 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "right" (9 + $lean) (9 + $bounce) 1 2

    if ($pose.attack) {
        Paint-DirRect $Graphics $Scale $Palette.paper $OriginX $OriginY "right" (13 + $lean) (9 + $bounce) 2 2
        Paint-DirRect $Graphics $Scale $Palette.blue $OriginX $OriginY "right" (13 + $lean) (10 + $bounce) 2 1
    } else {
        Paint-DirRect $Graphics $Scale $Palette.paper $OriginX $OriginY "right" (12 + $lean) (10 + $bounce) 2 1
    }
}

function Draw-SlavyanFrame([System.Drawing.Graphics]$Graphics, [int]$OriginX, [int]$OriginY, [int]$Frame) {
    $pose = Get-HumanPose $Frame
    $style = @{
        body  = $Palette.navy
        pants = $Palette.navy
        shirt = $Palette.paper
        tie   = $Palette.red
    }

    Draw-SuitHuman $Graphics $OriginX $OriginY "right" $pose $style

    $lean = [int]$pose.lean
    $bounce = [int]$pose.bounce
    Paint-DirRect $Graphics $Scale $Palette.hair $OriginX $OriginY "right" (6 + $lean) (2 + $bounce) 3 1
    Paint-DirRect $Graphics $Scale $Palette.hair $OriginX $OriginY "right" (6 + $lean) (3 + $bounce) 1 3

    if ($pose.attack) {
        Paint-DirRect $Graphics $Scale $Palette.skin $OriginX $OriginY "right" (13 + $lean) (9 + $bounce) 1 1
        Paint-DirRect $Graphics $Scale $Palette.red $OriginX $OriginY "right" (12 + $lean) (8 + $bounce) 1 1
    }
}

function Draw-ProsecutorFrame([System.Drawing.Graphics]$Graphics, [int]$OriginX, [int]$OriginY, [int]$Frame) {
    $pose = Get-HumanPose $Frame
    $style = @{
        body  = $Palette.navy
        pants = $Palette.navy
        shirt = $Palette.paper
        tie   = $Palette.red
    }

    Draw-SuitHuman $Graphics $OriginX $OriginY "left" $pose $style

    $lean = [int]$pose.lean
    $bounce = [int]$pose.bounce

    Paint-DirRect $Graphics $Scale $Palette.navy $OriginX $OriginY "left" (5 + $lean) (1 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.navy $OriginX $OriginY "left" (6 + $lean) (0 + $bounce) 4 2
    Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (7 + $lean) (1 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.outline $OriginX $OriginY "left" (5 + $lean) (3 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (7 + $lean) (8 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (10 + $lean) (8 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" (7 + $lean) (9 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" (9 + $lean) (9 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (7 + $lean) (12 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (9 + $lean) (12 + $bounce) 1 1

    if ($pose.attack) {
        Paint-DirRect $Graphics $Scale $Palette.red $OriginX $OriginY "left" (12 + $lean) (9 + $bounce) 2 2
        Paint-DirRect $Graphics $Scale $Palette.gold $OriginX $OriginY "left" (12 + $lean) (10 + $bounce) 2 1
    } else {
        Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" (12 + $lean) (10 + $bounce) 2 1
    }
}

function Draw-GuardFrame([System.Drawing.Graphics]$Graphics, [int]$OriginX, [int]$OriginY, [int]$Frame) {
    $pose = Get-HumanPose $Frame
    $lean = [int]$pose.lean
    $bounce = [int]$pose.bounce
    $frontLeg = [int]$pose.frontLeg
    $backLeg = [int]$pose.backLeg
    $frontArm = [int]$pose.frontArm
    $backArm = [int]$pose.backArm

    Paint-DirRect $Graphics $Scale $Palette.shadow $OriginX $OriginY "left" 4 14 8 1

    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Palette.tactical $OriginX $OriginY "left" (6 + $lean) (11 + $bounce + $backLeg) 2 3
    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Palette.tactical $OriginX $OriginY "left" (9 + $lean) (11 + $bounce + $frontLeg) 2 3
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" (6 + $lean) (14 + $bounce + $backLeg) 2 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" (9 + $lean) (14 + $bounce + $frontLeg) 2 1

    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Palette.tactical $OriginX $OriginY "left" (6 + $lean) (8 + $bounce) 5 4
    Paint-DirRect $Graphics $Scale $Palette.olive $OriginX $OriginY "left" (7 + $lean) (9 + $bounce) 3 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" (8 + $lean) (11 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.tactical $OriginX $OriginY "left" (5 + $lean) (9 + $bounce + $backArm) 1 3
    Paint-DirRect $Graphics $Scale $Palette.tactical $OriginX $OriginY "left" (10 + $lean + $frontArm) (9 + $bounce) 1 3
    Paint-DirRect $Graphics $Scale $Palette.skin $OriginX $OriginY "left" (10 + $lean + $frontArm) (12 + $bounce) 1 1

    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" (6 + $lean) (2 + $bounce) 4 2
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" (5 + $lean) (4 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" (7 + $lean) (5 + $bounce) 3 1
    Paint-DirOutlinedRect $Graphics $Scale $Palette.outline $Palette.skin $OriginX $OriginY "left" (7 + $lean) (5 + $bounce) 3 3
    Paint-DirRect $Graphics $Scale $Palette.outline $OriginX $OriginY "left" (8 + $lean) (6 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" (10 + $lean) (5 + $bounce) 1 3

    $weaponX = if ($pose.attack) { 11 + $lean } else { 10 + $lean }
    $weaponY = if ($pose.attack) { 9 + $bounce } else { 10 + $bounce }
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" $weaponX $weaponY 3 1
    Paint-DirRect $Graphics $Scale $Palette.black $OriginX $OriginY "left" ($weaponX + 2) ($weaponY + 1) 1 2
    Paint-DirRect $Graphics $Scale $Palette.gray $OriginX $OriginY "left" ($weaponX + 3) $weaponY 1 1
    Paint-DirRect $Graphics $Scale $Palette.olive $OriginX $OriginY "left" ($weaponX + 1) ($weaponY + 1) 1 1

    if ($pose.hit) {
        Draw-HitSpark $Graphics $OriginX $OriginY "left" $lean
    }
}

function Draw-ChairFrame([System.Drawing.Graphics]$Graphics, [int]$OriginX, [int]$OriginY, [int]$Frame) {
    $bounce = if ($Frame % 2 -eq 1) { 1 } else { 0 }
    $lean = 0
    $frontShift = 0
    $hit = $false

    switch ($Frame) {
        2 { $lean = 1 }
        3 { $lean = 2 }
        4 { $lean = 2; $frontShift = 1 }
        5 { $lean = -1; $hit = $true }
    }

    Paint-DirRect $Graphics $Scale $Palette.shadow $OriginX $OriginY "right" 3 14 10 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (6 + $lean) (1 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (4 + $lean) (2 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (2 + $lean) (3 + $bounce) 1 2
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (11 + $lean) (3 + $bounce) 1 2

    Paint-DirRect $Graphics $Scale $Palette.chairDark $OriginX $OriginY "right" (3 + $lean) (3 + $bounce) 1 10
    Paint-DirRect $Graphics $Scale $Palette.chairMid $OriginX $OriginY "right" (4 + $lean) (3 + $bounce) 6 6
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (5 + $lean) (3 + $bounce) 4 1
    Paint-DirRect $Graphics $Scale $Palette.chairSeat $OriginX $OriginY "right" (5 + $lean) (4 + $bounce) 4 4
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (4 + $lean) (4 + $bounce) 1 3
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (9 + $lean) (4 + $bounce) 1 3
    Paint-DirRect $Graphics $Scale $Palette.lightGray $OriginX $OriginY "right" (6 + $lean) (5 + $bounce) 2 1

    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (2 + $lean) (9 + $bounce) 3 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (9 + $lean) (9 + $bounce) 3 1
    Paint-DirRect $Graphics $Scale $Palette.chairDark $OriginX $OriginY "right" (4 + $lean) (9 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (4 + $lean) (10 + $bounce) 6 1
    Paint-DirRect $Graphics $Scale $Palette.chairSeat $OriginX $OriginY "right" (5 + $lean) (11 + $bounce) 4 2
    Paint-DirRect $Graphics $Scale $Palette.lightGray $OriginX $OriginY "right" (6 + $lean) (11 + $bounce) 2 1

    Paint-DirRect $Graphics $Scale $Palette.chairDark $OriginX $OriginY "right" (3 + $lean) (13 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.chairDark $OriginX $OriginY "right" (9 + $lean + $frontShift) (12 + $bounce) 2 2
    Paint-DirRect $Graphics $Scale $Palette.chairMid $OriginX $OriginY "right" (4 + $lean) (13 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.chairMid $OriginX $OriginY "right" (9 + $lean + $frontShift) (12 + $bounce) 1 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (3 + $lean) (14 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (9 + $lean + $frontShift) (14 + $bounce) 2 1
    Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (5 + $lean) (13 + $bounce) 4 1

    if ($Frame -eq 4) {
        Paint-DirRect $Graphics $Scale $Palette.brass $OriginX $OriginY "right" (11 + $lean) (9 + $bounce) 3 1
        Paint-DirRect $Graphics $Scale $Palette.chairSeat $OriginX $OriginY "right" (11 + $lean) (10 + $bounce) 2 1
    }

    if ($hit) {
        Paint-DirRect $Graphics $Scale $Palette.hit $OriginX $OriginY "right" (8 + $lean) (6 + $bounce) 2 1
        Paint-DirRect $Graphics $Scale $Palette.hit $OriginX $OriginY "right" (9 + $lean) (7 + $bounce) 1 1
    }
}

function New-SheetBitmap() {
    return New-Bitmap ($FrameCells * $FrameCount) $FrameCells $Scale ([System.Drawing.Color]::Transparent)
}

function Draw-Sheet([string]$Path, [scriptblock]$FrameDrawer) {
    $sheet = New-SheetBitmap
    Use-Graphics $sheet {
        param($g)

        for ($frame = 0; $frame -lt $FrameCount; $frame++) {
            $originX = $frame * $FrameCells
            & $FrameDrawer $g $originX 0 $frame
        }
    }

    Save-Png $sheet $Path
}

function Draw-BackgroundV2([string]$Path) {
    $bitmap = New-Bitmap 160 90 $Scale $Palette.wall

    Use-Graphics $bitmap {
        param($g)

        $title = Get-DumaTitle
        $titleX = [Math]::Floor((160 - (Get-PixelTextWidth $title 1)) / 2)

        Paint-Rect $g $Scale $Palette.panel 0 0 160 20
        Paint-Rect $g $Scale $Palette.woodDark 0 20 160 2
        Paint-Rect $g $Scale $Palette.wallShadow 0 22 160 4
        Paint-Rect $g $Scale $Palette.wall 0 26 160 22
        Draw-Crest $g $Scale 80 2
        Draw-PixelText $g $Scale $title $titleX 8 $Palette.paper $Palette.woodDark 1
        Paint-Rect $g $Scale $Palette.brass 46 14 68 1

        Paint-Rect $g $Scale $Palette.woodMid 6 10 18 34
        Paint-Rect $g $Scale $Palette.woodLight 8 12 14 30
        Paint-Rect $g $Scale $Palette.woodMid 136 10 18 34
        Paint-Rect $g $Scale $Palette.woodLight 138 12 14 30

        Paint-Rect $g $Scale $Palette.banner 73 12 14 16
        Paint-Rect $g $Scale $Palette.brass 77 15 6 6
        Paint-Rect $g $Scale $Palette.paper 79 17 2 2

        Paint-Rect $g $Scale $Palette.woodMid 44 28 24 14
        Paint-Rect $g $Scale $Palette.screen 46 30 20 10
        Paint-Rect $g $Scale $Palette.woodMid 92 28 24 14
        Paint-Rect $g $Scale $Palette.screen 94 30 20 10

        Paint-Rect $g $Scale $Palette.podium 0 48 26 34
        Paint-Rect $g $Scale $Palette.brass 26 48 1 34
        Paint-Rect $g $Scale $Palette.woodLight 3 52 18 18
        Paint-Rect $g $Scale $Palette.brass 6 72 12 2

        Paint-Rect $g $Scale $Palette.door 146 44 10 24
        Paint-Rect $g $Scale $Palette.brass 147 54 1 1
        Paint-Rect $g $Scale $Palette.red 143 46 2 2
        Paint-Rect $g $Scale $Palette.red 157 46 2 2

        for ($lane = 0; $lane -lt 5; $lane++) {
            $laneY = 52 + ($lane * 7)
            $laneColor = if ($lane % 2 -eq 0) { $Palette.carpet } else { $Palette.carpetDark }
            Paint-Rect $g $Scale $laneColor 0 $laneY 160 6
            Paint-Rect $g $Scale $Palette.shadow 0 ($laneY + 5) 160 1
        }

        $desks = @(
            @{ X = 34; Y = 51 },
            @{ X = 50; Y = 58 },
            @{ X = 66; Y = 51 },
            @{ X = 82; Y = 58 },
            @{ X = 98; Y = 51 },
            @{ X = 114; Y = 58 },
            @{ X = 34; Y = 66 },
            @{ X = 50; Y = 73 },
            @{ X = 66; Y = 66 },
            @{ X = 82; Y = 73 },
            @{ X = 98; Y = 66 },
            @{ X = 114; Y = 73 }
        )

        foreach ($desk in $desks) {
            Paint-Rect $g $Scale $Palette.woodDark $desk.X $desk.Y 12 4
            Paint-Rect $g $Scale $Palette.woodLight ($desk.X + 1) ($desk.Y + 1) 10 1
            Paint-Rect $g $Scale $Palette.gray ($desk.X + 3) ($desk.Y + 4) 2 2
            Paint-Rect $g $Scale $Palette.gray ($desk.X + 7) ($desk.Y + 4) 2 2
        }

        Paint-Rect $g $Scale $Palette.woodDark 46 82 64 4
        Paint-Rect $g $Scale $Palette.woodLight 47 83 62 1
        Paint-Rect $g $Scale $Palette.plant 132 50 4 8
        Paint-Rect $g $Scale $Palette.panel 131 58 6 3
    }

    Save-Png $bitmap $Path
}

function Draw-ScenePreview([string]$Path) {
    $bitmap = New-Bitmap 160 90 $Scale $Palette.wall
    $laneTops = @(42, 49, 56, 63, 70)

    Use-Graphics $bitmap {
        param($g)

        $title = Get-DumaTitle
        $titleX = [Math]::Floor((160 - (Get-PixelTextWidth $title 1)) / 2)

        Paint-Rect $g $Scale $Palette.panel 0 0 160 20
        Paint-Rect $g $Scale $Palette.woodDark 0 20 160 2
        Paint-Rect $g $Scale $Palette.wallShadow 0 22 160 4
        Paint-Rect $g $Scale $Palette.wall 0 26 160 22
        Draw-Crest $g $Scale 80 2
        Draw-PixelText $g $Scale $title $titleX 8 $Palette.paper $Palette.woodDark 1
        Paint-Rect $g $Scale $Palette.brass 46 14 68 1
        Paint-Rect $g $Scale $Palette.podium 0 48 26 34
        Paint-Rect $g $Scale $Palette.brass 26 48 1 34

        for ($lane = 0; $lane -lt 5; $lane++) {
            $laneY = 52 + ($lane * 7)
            $laneColor = if ($lane % 2 -eq 0) { $Palette.carpet } else { $Palette.carpetDark }
            Paint-Rect $g $Scale $laneColor 0 $laneY 160 6
            Paint-Rect $g $Scale $Palette.shadow 0 ($laneY + 5) 160 1
        }

        Draw-SlavyanFrame $g 4 $laneTops[2] 0
        Draw-ChairFrame $g 22 $laneTops[1] 0
        Draw-WeinsteinFrame $g 38 $laneTops[1] 4
        Draw-ChairFrame $g 26 $laneTops[3] 2
        Draw-WeinsteinFrame $g 42 $laneTops[3] 0
        Draw-ProsecutorFrame $g 112 $laneTops[1] 2
        Draw-GuardFrame $g 128 $laneTops[2] 2
        Draw-ProsecutorFrame $g 104 $laneTops[3] 0
        Draw-GuardFrame $g 120 $laneTops[4] 4
    }

    Save-Png $bitmap $Path
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDir)
if (-not (Test-Path -LiteralPath $resolvedOutput)) {
    New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
}

Draw-Sheet (Join-Path $resolvedOutput "slavyan_sheet.png") ${function:Draw-SlavyanFrame}
Draw-Sheet (Join-Path $resolvedOutput "weinstein_sheet.png") ${function:Draw-WeinsteinFrame}
Draw-Sheet (Join-Path $resolvedOutput "prosecutor_sheet.png") ${function:Draw-ProsecutorFrame}
Draw-Sheet (Join-Path $resolvedOutput "guard_sheet.png") ${function:Draw-GuardFrame}
Draw-Sheet (Join-Path $resolvedOutput "chair_sheet.png") ${function:Draw-ChairFrame}
Draw-BackgroundV2 (Join-Path $resolvedOutput "background_hall_v2.png")
Draw-ScenePreview (Join-Path $resolvedOutput "scene_preview.png")

$manifest = [ordered]@{
    frameWidth  = 64
    frameHeight = 64
    frameCount  = $FrameCount
    frameOrder  = @("idle_0", "idle_1", "move_0", "move_1", "attack_0", "hit_0")
    animations  = [ordered]@{
        idle   = @{ frames = @(0, 1); frameRate = 3; repeat = -1 }
        move   = @{ frames = @(2, 3); frameRate = 6; repeat = -1 }
        attack = @{ frames = @(4); frameRate = 10; repeat = 0 }
        hit    = @{ frames = @(5); frameRate = 10; repeat = 0 }
    }
    units       = [ordered]@{
        slavyan    = @{ file = "slavyan_sheet.png"; facing = "right"; role = "goal" }
        weinstein  = @{ file = "weinstein_sheet.png"; facing = "right"; role = "ranged" }
        chair      = @{ file = "chair_sheet.png"; facing = "right"; role = "tank" }
        prosecutor = @{ file = "prosecutor_sheet.png"; facing = "left"; role = "attacker" }
        guard      = @{ file = "guard_sheet.png"; facing = "left"; role = "attacker" }
    }
}

Save-Json (Join-Path $resolvedOutput "sprite_manifest.json") $manifest

Get-ChildItem -LiteralPath $resolvedOutput -File | Sort-Object Name | Select-Object -ExpandProperty FullName
