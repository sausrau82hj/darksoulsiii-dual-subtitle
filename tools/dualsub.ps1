<#
Dark Souls III dual-language text tool (default: Chinese primary, English secondary).

How it works (UXM loose-file setup):
  1. read the text packs from <game>/msg/<lang>/*.msgbnd.dcx (zhocn + engus)
  2. unpack DCX -> BND4 -> FMG with Yabber, giving <lang>/msg/<LANG>/64bit/*.fmg
  3. merge both languages entry by entry into "Chinese\nEnglish" and write it into both
     language slots (the Chinese client shows English underneath, and vice versa)
  4. the config decides which FMGs (area titles / dialogue / items / menus / tutorials ...)
     take part
  5. repack into .msgbnd.dcx into the mod folder for UXM loose-file loading

Usage:
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1             # build everything
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Filter menu_dlc1
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Game "D:\...\Game" -Output <folder>

Requires Windows PowerShell 5.1 (shipped with Windows 10/11) and Yabber.
#>
[CmdletBinding()]
param(
    [string]$Game,
    [Alias('Out')][string]$Output,
    [string]$Config,
    [string]$Yabber,
    [string]$Primary,
    [string]$Secondary,
    [string]$Filter,
    [string]$Source,
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
# Package root: when the script lives in <package>/tools/ this is the package root,
# and the output defaults to <package>/msg/
$PackRoot = if ((Split-Path -Leaf $ScriptDir).ToLowerInvariant() -eq 'tools') {
    Split-Path -Parent $ScriptDir
} else {
    $ScriptDir
}
$DefaultOut = Join-Path $ScriptDir 'DualSubtitle'
$DefaultConfig = Join-Path $ScriptDir 'dualsub.config.json'

$YabberHelp = @"
Yabber not found.
  Extract Yabber anywhere under this package's root folder, or pass -Yabber <dir>,
  set "yabber_dir" in the config, or set the YABBER_DIR environment variable.
  The folder must hold both Yabber.exe and Yabber.DCX.exe.
  Download: https://github.com/JKAnderson/Yabber/releases
"@

$CategoryRules = @(
    @{ Name = 'Dialogue';           Patterns = @('会話*') }
    @{ Name = 'Cutscene Subtitles'; Patterns = @('ムービー字幕*') }
    @{ Name = 'Dialogue Boxes';     Patterns = @('ダイアログ*', 'FDP_ダイアログ*') }
    @{ Name = 'Event Text';         Patterns = @('イベントテキスト*') }
    @{ Name = 'Menu Text';          Patterns = @('*メニューテキスト*', 'メニューその他*', 'メニュー共通テキスト*', 'インゲームメニュー*') }
    @{ Name = 'Key Prompts';        Patterns = @('キーガイド*', 'FDP_キーガイド*') }
    @{ Name = 'Help Text';          Patterns = @('*一行ヘルプ*', '項目ヘルプ*') }
    @{ Name = 'System Messages';    Patterns = @('FDP_システムメッセージ*') }
    @{ Name = 'Place Names';        Patterns = @('地名*') }
    @{ Name = 'Item Lore';          Patterns = @('*うんちく*') }
    @{ Name = 'Item Descriptions';  Patterns = @('*説明*') }
    @{ Name = 'Item Names';         Patterns = @('*名.fmg', '*名_dlc*.fmg', 'NPC名*') }
    @{ Name = 'Blood Messages';     Patterns = @('血文字*') }
)

$DefaultCategories = @{
    'Dialogue'           = $true
    'Cutscene Subtitles' = $true
    'Dialogue Boxes'     = $true
    'Event Text'         = $true
    'Menu Text'          = $true
    'Key Prompts'        = $true
    'Help Text'          = $true
    'System Messages'    = $true
    'Place Names'        = $true
    'Item Names'         = $true
    'Item Descriptions'  = $true
    'Item Lore'          = $true
    'Blood Messages'     = $true
}

function Write-Log {
    param([string]$Message)
    Write-Host $Message
}

function Fail {
    param([string]$Message)
    Write-Host $Message
    exit 1
}

function Get-Prop {
    param($Node, [string]$Key, $Default)
    if ($null -eq $Node) { return $Default }
    if ($Node -is [System.Collections.IDictionary] -and $Node.Contains($Key)) {
        return $Node[$Key]
    }
    return $Default
}

function ConvertTo-Hashtable {
    param($Object)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in @($Object.Keys)) { $h[$k] = ConvertTo-Hashtable $Object[$k] }
        return $h
    }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Object) { [void]$list.Add((ConvertTo-Hashtable $item)) }
        return , $list.ToArray()
    }
    return $Object
}

function Get-Stem {
    param([string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    foreach ($suffix in @('.msgbnd.dcx', '.msgbnd')) {
        if ($name.ToLowerInvariant().EndsWith($suffix)) {
            return $name.Substring(0, $name.Length - $suffix.Length)
        }
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($name)
}

function Sort-Ordinal {
    param([string[]]$Items)
    $copy = [string[]]$Items.Clone()
    [Array]::Sort($copy, [System.StringComparer]::Ordinal)
    return , $copy
}

function Find-Yabber {
    param([string]$Hint)
    $cands = New-Object System.Collections.Generic.List[string]
    if ($Hint) { $cands.Add($Hint) }
    if ($env:YABBER_DIR) { $cands.Add($env:YABBER_DIR) }
    $cmd = Get-Command 'Yabber.exe' -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $cands.Add((Split-Path -Parent $cmd.Source)) }

    $roots = @(
        $PackRoot,
        (Join-Path $PackRoot 'tools'),
        'D:\game\TOOL', 'D:\Tools', 'D:\tool', 'C:\Tools', 'C:\tool',
        $env:LOCALAPPDATA,
        (Join-Path $HOME 'Downloads'),
        $HOME
    )
    foreach ($root in $roots) {
        if (-not $root) { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $found = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'Yabber*' -ErrorAction SilentlyContinue | Sort-Object Name)
        foreach ($f in $found) { $cands.Add($f.FullName) }
        $subs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -Filter 'Yabber*' -ErrorAction SilentlyContinue } |
            Sort-Object FullName)
        foreach ($f in $subs) { $cands.Add($f.FullName) }
    }
    foreach ($c in $cands) {
        if (-not $c) { continue }
        $exe = Join-Path $c 'Yabber.exe'
        $dcx = Join-Path $c 'Yabber.DCX.exe'
        if ((Test-Path -LiteralPath $exe -PathType Leaf) -and (Test-Path -LiteralPath $dcx -PathType Leaf)) {
            return [System.IO.Path]::GetFullPath($c)
        }
    }
    Fail $YabberHelp
}

function Get-DefaultGame {
    if ($env:DS3_GAME_DIR -and (Test-Path -LiteralPath (Join-Path $env:DS3_GAME_DIR 'DarkSoulsIII.exe'))) {
        return $env:DS3_GAME_DIR
    }
    $roots = New-Object System.Collections.Generic.List[string]
    try {
        $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steam) {
            $roots.Add($steam)
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf -PathType Leaf) {
                $text = Get-Content -LiteralPath $vdf -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($text) {
                    foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                        $roots.Add(($m.Groups[1].Value -replace '\\\\', '\'))
                    }
                }
            }
        }
    } catch { }
    foreach ($r in @('D:\steam\steamapps\common', 'E:\steam\steamapps\common',
                     'F:\steam\steamapps\common', 'C:\Program Files (x86)\Steam\steamapps\common')) {
        $roots.Add($r)
    }
    foreach ($r in $roots) {
        $cand = Join-Path $r 'DARK SOULS III\Game'
        if (Test-Path -LiteralPath (Join-Path $cand 'DarkSoulsIII.exe') -PathType Leaf) {
            return $cand
        }
    }
    return 'D:\steam\steamapps\common\DARK SOULS III\Game'
}

function Load-Config {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $obj = $raw | ConvertFrom-Json
        return (ConvertTo-Hashtable $obj)
    }
    $cats = @{}
    foreach ($k in $DefaultCategories.Keys) { $cats[$k] = $DefaultCategories[$k] }
    return @{ primary = 'zhocn'; secondary = 'engus'; separator = ' / '; categories = $cats }
}

function Get-Category {
    param([string]$Fmg)
    $base = [System.IO.Path]::GetFileName($Fmg)
    foreach ($rule in $CategoryRules) {
        foreach ($p in $rule.Patterns) {
            if ($base -clike $p) { return $rule.Name }
        }
    }
    return 'Other'
}

function Get-CatValue {
    param($Cfg, [string]$Fmg)
    $cats = Get-Prop $Cfg 'categories' $null
    if ($null -eq $cats -or $cats.Count -eq 0) { return $null }
    return (Get-Prop $cats (Get-Category $Fmg) $null)
}

function Get-ValueMode {
    param($Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $mode = Get-Prop $Value 'mode' $null
        if ($mode) { $Value = $mode } else { $Value = [bool](Get-Prop $Value 'enabled' $true) }
    }
    if ($Value -is [string]) { return $Value.Trim() }
    if ($Value) { return 'append' } else { return 'off' }
}

function Test-Enabled {
    param($Cfg, [string]$MsgBnd, [string]$Fmg)
    # files/ wins over the category, so a single FMG can be pulled out of its group
    $node = Get-Prop $Cfg 'files' @{}
    foreach ($key in @($MsgBnd, (Get-Stem $MsgBnd))) {
        if ($node.Contains($key)) {
            $entry = $node[$key]
            if (-not (Get-Prop $entry 'enabled' $true)) { return $false }
            $rules = Get-Prop $entry 'fmg' @{}
            foreach ($pat in @($rules.Keys)) {
                if ($Fmg -clike $pat) {
                    $val = $rules[$pat]
                    if ($val -is [System.Collections.IDictionary]) { return [bool](Get-Prop $val 'enabled' $true) }
                    return [bool]$val
                }
            }
        }
    }
    $v = Get-CatValue $Cfg $Fmg
    if ($null -ne $v) { return ((Get-ValueMode $v) -ne 'off') }
    # Unlisted files are merged; FMG-level rules apply globally
    $rules = Get-Prop $Cfg 'fmg' @{}
    foreach ($pat in @($rules.Keys)) {
        if ($Fmg -clike $pat) {
            $val = $rules[$pat]
            if ($val -is [System.Collections.IDictionary]) { return [bool](Get-Prop $val 'enabled' $true) }
            return [bool]$val
        }
    }
    return $true
}

function Get-Mode {
    param($Cfg, [string]$Pack, [string]$Fmg)
    # append  - append the other language (default)
    # off     - do not merge (the default for long descriptions, which would not fit)
    # sec_only - replace this language with the secondary one (English only)
    $files = Get-Prop $Cfg 'files' @{}
    $entry = Get-Prop (Get-Prop $files (Get-Stem $Pack) @{}) 'fmg' @{}
    $v = Get-Prop $entry $Fmg $null
    if ($v -is [System.Collections.IDictionary]) {
        $m = Get-Prop $v 'mode' $null
        if ($m) { return [string]$m }
    }
    if ($v -is [string]) { return $v }
    $catv = Get-CatValue $Cfg $Fmg
    if ($null -ne $catv) { return (Get-ValueMode $catv) }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Fmg)
    if ($base.Contains('説明') -or $base.Contains('うんちく')) { return 'off' }
    return 'append'
}

function Get-SepValue {
    param($Value)
    # None / "auto" / "" pick per FMG and per entry
    if ($Value -isnot [string]) { return $null }
    $t = $Value.Trim().ToLowerInvariant()
    if ($t -eq 'auto' -or $t -eq 'null' -or $Value -eq '') { return $null }
    if ($Value -eq '\n') { return "`n" }
    return $Value
}

function Get-InlineSep {
    param($Cfg)
    $s = Get-SepValue (Get-Prop $Cfg 'separator' $null)
    if ($null -eq $s) { return ' / ' }
    return $s
}

function Get-SeparatorFor {
    param($Cfg, [string]$Pack, [string]$Fmg)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Fmg)
    # Popup confirm windows: buttons are one line, message rows keep their own newline
    if ($base.StartsWith('FDP_ダイアログ')) { return $null }
    # Multiline widgets: dialogue / subtitles / long descriptions -> always a newline
    $multiline = @('会話', 'ムービー字幕', '説明', 'うんちく', 'ダイアログ')
    foreach ($m in $multiline) { if ($base.Contains($m)) { return "`n" } }
    $inline = Get-InlineSep $Cfg
    # Per-FMG override, for the widgets that sit on one line
    $files = Get-Prop $Cfg 'files' @{}
    $entry = Get-Prop (Get-Prop $files (Get-Stem $Pack) @{}) 'fmg' @{}
    if ($entry.Contains($Fmg)) {
        $v = $entry[$Fmg]
        if ($v -is [System.Collections.IDictionary] -and $v.Contains('separator')) {
            $forced = Get-SepValue $v['separator']
            if ($null -ne $forced) { return $forced }
        }
    }
    # Single-line widgets: names / place names / menus / prompts -> one line
    $oneLine = @('名.fmg', '地名', '一行ヘルプ', 'キーガイド', 'システムメッセージ',
                 'メニューテキスト', 'インゲームメニュー', '項目ヘルプ')
    foreach ($m in $oneLine) { if ($base.Contains($m)) { return $inline } }
    if ($base.EndsWith('名')) { return $inline }
    # Everything else is decided per entry (short labels one line, long text a newline)
    return $null
}

function Get-Norm {
    param([string]$Text)
    return ($Text -replace '\s+', '').ToLowerInvariant()
}

function Test-IsNull {
    param([string]$Text)
    if ($null -eq $Text) { return $true }
    $n = $Text.Trim().ToLowerInvariant()
    return ($n -eq '' -or $n -eq 'null' -or $n -eq '%null%')
}

function Test-AlreadyMerged {
    param([string]$T1, [string]$T2, $Sep)
    # True when this text pair is already merged (A+sep+B / B+sep+A), so a rebuild skips it
    if (-not $Sep) { return $false }
    if ($T1.EndsWith($Sep + $T2) -or $T2.EndsWith($Sep + $T1)) { return $true }
    $pattern = [regex]::Escape($Sep)
    $a = [string[]]@($T1 -split $pattern)
    $b = [string[]]@($T2 -split $pattern)
    # The merged pair holds the same fragments in opposite order; multiline text splits into
    # three or more pieces, so compare the sorted fragment sets
    if ($a.Count -le 1 -or $b.Count -le 1) { return $false }
    if ($a.Count -ne $b.Count) { return $false }
    $sa = [string[]]$a.Clone()
    $sb = [string[]]$b.Clone()
    [Array]::Sort($sa, [System.StringComparer]::Ordinal)
    [Array]::Sort($sb, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $sa.Count; $i++) {
        if ($sa[$i] -ne $sb[$i]) { return $false }
    }
    return $true
}

function New-Yabber {
    param([string]$Directory)
    $exe = Join-Path $Directory 'Yabber.exe'
    $dcx = Join-Path $Directory 'Yabber.DCX.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-Path -LiteralPath $dcx -PathType Leaf)) {
        Fail "Yabber not found in: $Directory`n$YabberHelp"
    }
    return @{ Exe = $exe; Dcx = $dcx; Dir = $Directory }
}

function Invoke-Yabber {
    param($Yabber, [string]$Tool, [string]$Path)
    $null = & $Tool $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Yabber failed: $Path (exit $LASTEXITCODE)"
    }
}

function Open-Fmg {
    param([string]$Path)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($Path)
    $parent = $doc.DocumentElement.SelectSingleNode('entries')
    if ($null -eq $parent) { throw "Not a valid FMG XML: $Path" }
    $entries = New-Object 'System.Collections.Generic.Dictionary[string,System.Xml.XmlElement]'
    foreach ($el in $parent.ChildNodes) {
        if ($el.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        $entries[$el.GetAttribute('id')] = $el
    }
    return @{ Path = $Path; Doc = $doc; Entries = $entries }
}

function Save-Fmg {
    param($Fmg)
    $Fmg.Doc.Save($Fmg.Path)
}

function Merge-Fmg {
    param($A, $B, $Sep, $Inline)
    # Append every text of B behind A, and A behind B.
    # Sep=None picks per entry: a newline when the source has one, otherwise Inline
    # (single-line widgets). Every entry is merged, short answers such as yes/no included.
    $changed = 0
    foreach ($key in @($A.Entries.Keys)) {
        if (-not $B.Entries.ContainsKey($key)) { continue }
        $el = $A.Entries[$key]
        $other = $B.Entries[$key]
        $t1 = $el.InnerText
        $t2 = $other.InnerText
        if (Test-IsNull $t1) { continue }
        if (Test-IsNull $t2) { continue }
        if ((Get-Norm $t1) -eq (Get-Norm $t2)) { continue }
        $useSep = $Sep
        if ($null -eq $useSep) {
            if ($t1.Contains("`n") -or $t2.Contains("`n")) { $useSep = "`n" } else { $useSep = $Inline }
        }
        # Idempotent: entries that are already merged (A+sep+B / B+sep+A) are skipped, so a
        # rebuild never stacks the two languages twice
        if (Test-AlreadyMerged $t1 $t2 $useSep) { continue }
        $new1 = $t1 + $useSep + $t2
        $new2 = $t2 + $useSep + $t1
        $el.InnerText = $new1
        $other.InnerText = $new2
        $changed++
        if ($new1.Length -gt 400) {
            Write-Log ("  ! entry {0} is long after merge ({1} chars)" -f $key, $new1.Length)
        }
    }
    return $changed
}

function Replace-From {
    param($A, $B)
    # sec_only mode: replace the text of this file with the other language
    $changed = 0
    foreach ($key in @($A.Entries.Keys)) {
        if (-not $B.Entries.ContainsKey($key)) { continue }
        $el = $A.Entries[$key]
        $t2 = $B.Entries[$key].InnerText
        if (Test-IsNull $t2) { continue }
        $t1 = $el.InnerText
        # Fill in the secondary language even when this language is empty (%null%), otherwise
        # the player still sees a blank line
        if (-not (Test-IsNull $t1)) {
            if ((Get-Norm $t1) -eq (Get-Norm $t2)) { continue }
        }
        $el.InnerText = $t2
        $changed++
    }
    return $changed
}

function Find-FmgDir {
    param([string]$Unpacked)
    $dirs = New-Object System.Collections.Generic.List[string]
    $dirs.Add($Unpacked)
    foreach ($d in Get-ChildItem -LiteralPath $Unpacked -Recurse -Directory -ErrorAction SilentlyContinue) {
        $dirs.Add($d.FullName)
    }
    foreach ($d in $dirs) {
        $hit = Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.ToLowerInvariant().EndsWith('.fmg') } |
            Select-Object -First 1
        if ($hit) { return $d }
    }
    throw "No FMG found in unpacked dir: $Unpacked"
}

function Get-Packs {
    param([string]$Game, [string]$PrimaryLang, [string]$SecondaryLang)
    $a = Join-Path $Game "msg\$PrimaryLang"
    $b = Join-Path $Game "msg\$SecondaryLang"
    if (-not (Test-Path -LiteralPath $a -PathType Container) -or -not (Test-Path -LiteralPath $b -PathType Container)) {
        Fail "msg language dirs not found: $a / $b"
    }
    $names = @{}
    foreach ($f in Get-ChildItem -LiteralPath $a -File -ErrorAction SilentlyContinue) {
        if ($f.Name.ToLowerInvariant().EndsWith('.msgbnd.dcx')) { $names[$f.Name.ToLowerInvariant()] = $f.Name }
    }
    $have = @{}
    foreach ($f in Get-ChildItem -LiteralPath $b -File -ErrorAction SilentlyContinue) {
        $have[$f.Name.ToLowerInvariant()] = $true
    }
    $res = New-Object System.Collections.Generic.List[string]
    foreach ($k in @($names.Keys)) {
        if ($have.ContainsKey($k)) { $res.Add($names[$k]) }
    }
    return (Sort-Ordinal $res.ToArray())
}

function Build-One {
    param([string]$Game, [string]$Out, $Cfg, [string]$Name, [bool]$KeepWork, [string]$YabberDir)

    $primary = $Cfg['primary']
    $secondary = $Cfg['secondary']
    $stem = Get-Stem $Name
    $work = Join-Path $Out "_work\$stem"
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    $ydir = $YabberDir
    if (-not $ydir) { $ydir = Get-Prop $Cfg 'yabber_dir' '' }
    if (-not $ydir) { $ydir = Find-Yabber }
    $y = New-Yabber $ydir

    $stats = @{ file = $Name; fmg_total = 0; fmg_merged = 0; entries = 0; skipped_fmg = 0 }
    $results = @{}

    foreach ($lang in @($primary, $secondary)) {
        $src = Join-Path $Game "msg\$lang\$Name"
        $wdir = Join-Path $work $lang
        New-Item -ItemType Directory -Path $wdir -Force | Out-Null
        $dcx = Join-Path $wdir $Name
        Copy-Item -LiteralPath $src -Destination $dcx -Force
        Invoke-Yabber $y $y.Dcx $dcx                    # DCX -> msgbnd
        $msgbnd = $dcx.Substring(0, $dcx.Length - 4)
        Invoke-Yabber $y $y.Exe $msgbnd                 # BND4 -> folder
        $unpacked = Join-Path $wdir "$stem-msgbnd"
        $fmgDir = Find-FmgDir $unpacked
        $results[$lang] = @{ dcx = $dcx; msgbnd = $msgbnd; unpacked = $unpacked; fmg_dir = $fmgDir }
    }

    $allFmg = New-Object System.Collections.Generic.List[string]
    foreach ($lang in @($primary, $secondary)) {
        foreach ($f in Get-ChildItem -LiteralPath $results[$lang].fmg_dir -File -ErrorAction SilentlyContinue) {
            if ($f.Name.ToLowerInvariant().EndsWith('.fmg') -and -not $allFmg.Contains($f.Name)) {
                $allFmg.Add($f.Name)
            }
        }
    }
    $allFmgSorted = Sort-Ordinal $allFmg.ToArray()
    $stats['fmg_total'] = $allFmgSorted.Count

    $primaryFmgs = @{}
    foreach ($f in Get-ChildItem -LiteralPath $results[$primary].fmg_dir -File -ErrorAction SilentlyContinue) { $primaryFmgs[$f.Name] = $true }
    $secondaryFmgs = @{}
    foreach ($f in Get-ChildItem -LiteralPath $results[$secondary].fmg_dir -File -ErrorAction SilentlyContinue) { $secondaryFmgs[$f.Name] = $true }

    foreach ($fmg in $allFmgSorted) {
        if (-not $primaryFmgs.ContainsKey($fmg) -or -not $secondaryFmgs.ContainsKey($fmg)) {
            Write-Log "  - skip $fmg (missing on one side)"
            $stats['skipped_fmg']++
            continue
        }
        if (-not (Test-Enabled $Cfg $Name $fmg)) {
            Write-Log "  - off $fmg"
            $stats['skipped_fmg']++
            continue
        }
        $fmgMode = Get-Mode $Cfg $Name $fmg
        if ($fmgMode -eq 'off') {
            Write-Log "  - skip $fmg (long text, keep original)"
            $stats['skipped_fmg']++
            continue
        }
        $p1 = Join-Path $results[$primary].fmg_dir $fmg
        $p2 = Join-Path $results[$secondary].fmg_dir $fmg
        Invoke-Yabber $y $y.Exe $p1                     # fmg -> xml
        Invoke-Yabber $y $y.Exe $p2
        $x1 = Open-Fmg ($p1 + '.xml')
        $x2 = Open-Fmg ($p2 + '.xml')
        if ($fmgMode -eq 'sec_only') {
            $n = Replace-From $x1 $x2
        } else {
            $fmgSep = Get-SeparatorFor $Cfg $Name $fmg
            $n = Merge-Fmg $x1 $x2 $fmgSep (Get-InlineSep $Cfg)
        }
        if ($n) {
            Save-Fmg $x1
            Save-Fmg $x2
            Invoke-Yabber $y $y.Exe ($p1 + '.xml')      # xml -> fmg
            Invoke-Yabber $y $y.Exe ($p2 + '.xml')
            $stats['fmg_merged']++
            $stats['entries'] += $n
            Write-Log "  + ${fmg}: $n entries"
        } else {
            Write-Log "  = ${fmg}: nothing to merge"
        }
    }

    if (-not $stats['entries']) {
        # Nothing merged -> the pack is identical to vanilla, so shipping it only adds risk: skip it
        Write-Log "  = nothing merged in $Name, not installed"
        if (-not $KeepWork) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
        return $stats
    }

    foreach ($lang in @($primary, $secondary)) {
        $r = $results[$lang]
        Invoke-Yabber $y $y.Exe $r['unpacked']          # folder -> msgbnd
        Invoke-Yabber $y $y.Dcx $r['msgbnd']            # msgbnd -> dcx
        $dst = Join-Path $Out "msg\$lang\$Name"
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath ($r['msgbnd'] + '.dcx') -Destination $dst -Force
        Write-Log "  -> $dst"
    }

    if (-not $KeepWork) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    return $stats
}

# ---- main ----

$interactive = ($PSBoundParameters.Count -eq 0)

$cfgPath = if ($Config) { $Config } else { $DefaultConfig }
$cfg = Load-Config $cfgPath
if ($Primary) { $cfg['primary'] = $Primary }
if ($Secondary) { $cfg['secondary'] = $Secondary }
$primaryLang = if ($cfg['primary']) { $cfg['primary'] } else { 'zhocn' }
$secondaryLang = if ($cfg['secondary']) { $cfg['secondary'] } else { 'engus' }
$cfg['primary'] = $primaryLang
$cfg['secondary'] = $secondaryLang

# With a bundled source\ the default is an in-place rebuild: read source\, write <package>/msg\
$packSrc = Join-Path $PackRoot 'source'
$usePackSrc = (-not $Source) -and (Test-Path -LiteralPath (Join-Path $packSrc 'msg') -PathType Container)
$srcGame = if ($usePackSrc) { $packSrc } elseif ($Source) { $Source } elseif ($Game) { $Game } else { Get-DefaultGame }
if (-not (Test-Path -LiteralPath $srcGame -PathType Container)) {
    Fail "Text pack directory not found: $srcGame`nPoint -Source at the package's source folder, or -Game at the game's Game folder."
}

if (-not $Output) {
    $Output = if ($usePackSrc) { $PackRoot } else { $DefaultOut }
    Write-Log "Writing to $Output"
}

$names = Get-Packs $srcGame $primaryLang $secondaryLang
# ngword holds the profanity list and never takes part in the dual-language display
$filtered = New-Object System.Collections.Generic.List[string]
foreach ($n in $names) {
    if ((Get-Stem $n).ToLowerInvariant().StartsWith('ngword')) { continue }
    if ($Filter -and -not ((Get-Stem $n) -clike $Filter)) { continue }
    $filtered.Add($n)
}
if ($filtered.Count -eq 0) { Fail 'No text packs to process (base text may not be unpacked)' }

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Log "Source: $srcGame"
Write-Log "Output: $Output"
Write-Log "Languages: $primaryLang + $secondaryLang, $($filtered.Count) packs"
Write-Log ''

$allStats = New-Object System.Collections.ArrayList
foreach ($name in $filtered) {
    Write-Log "[$name]"
    [void]$allStats.Add((Build-One $srcGame $Output $cfg $name $KeepWork.IsPresent $Yabber))
    Write-Log ''
}

$totalFmg = 0
$totalEntries = 0
foreach ($s in $allStats) { $totalFmg += $s['fmg_merged']; $totalEntries += $s['entries'] }
Write-Log ("Done: {0} packs, {1} FMGs, {2} entries, in {3:N1}s" -f $allStats.Count, $totalFmg, $totalEntries, $stopwatch.Elapsed.TotalSeconds)
Write-Log "Mod files in: $Output"

if ($interactive) {
    $null = Read-Host "`nPress Enter to close"
}
exit 0
