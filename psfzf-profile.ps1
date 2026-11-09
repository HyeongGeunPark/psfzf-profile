# psfzf-profile.ps1
# fzf + PSFzf 연동 프로파일 (alacritty + zellij, pwsh 7) - 콘솔 코드 페이지 65001 버전
#
# $PROFILE 에서 dot-source 되어 로드된다.
#   Ctrl+T  : 파일/디렉터리를 골라 명령줄에 넣기 (명령에 맞춰 따옴표/이스케이프)
#   Ctrl+R  : 명령 기록 검색
#   Alt+C   : 디렉터리를 골라 바로 이동
#   Alt+A   : 이전 명령에서 쓴 인자 검색
#   Tab     : fzf 기반 탭 완성
#   **<Tab> : git / Get-Process / Get-Service 등 인자 완성
#   fkill   : 프로세스를 골라 종료
#
# PSFzf 모듈 코드는 수정하지 않고, Set-PsFzfOption 과 PSFzf 공개 함수만 사용한다.
# 콘솔 코드 페이지 949 를 유지하고 PSFzf 동작 중에만 UTF-8 로 바꾸는 버전은 main 브랜치에 있다.

# [콘솔 코드 페이지를 UTF-8(65001)로 고정]
# 한국어 Windows 의 콘솔 기본 코드 페이지는 949(CP949)이고 fzf 는 항상 UTF-8 로 입출력한다.
# 이 차이 때문에 다음 문제가 생긴다.
#   1. fzf 의 --height(light 렌더러)는 콘솔 입력을 코드 페이지 바이트로 읽고 UTF-8 로
#      해석한다. CP949 한글 바이트는 해석에 실패해 Esc(abort)로 처리되어 fzf 가 종료된다.
#      (fzf src/tui/light.go GetChar, light_windows.go setupTerminal)
#   2. PSFzf 의 Invoke-FzfDefaultSystem(Ctrl+T 기본 경로)은 fzf 출력 인코딩을 지정하지
#      않아 .NET 이 콘솔 출력 코드 페이지(949)로 디코딩하므로 한글 경로가 깨진다.
#   3. Alt+C 목록을 만드는 `cmd /c dir` 의 파이프 출력이 949 로 인코딩되어
#      CP949 에 없는 글자(込, 们, é, 이모지 등)가 ? 로 바뀐다.
# 이 pwsh 세션의 콘솔 입출력을 UTF-8 로 고정해 세 문제를 함께 해결한다.
# 이 콘솔에서 실행되는 자식 프로그램(cmd 등)도 65001 을 이어받는다.
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if (-not (Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue) -or
    -not (Get-Module -ListAvailable -Name PSFzf)) {
    Write-Warning 'psfzf-profile: fzf 또는 PSFzf 를 찾지 못해 PSFzf 설정을 건너뜁니다.'
    return
}

Import-Module PSFzf

# [fzf 화면 크기: 높이 60% 부분 화면으로 통일]
# PSFzf 기본값은 기능마다 다르다. Invoke-Fzf(대부분의 기능)는 Alacritty/Zellij 에서 전체 화면,
# Invoke-FzfDefaultSystem(Ctrl+T 기본 경로)은 항상 높이 40% 부분 화면으로 띄운다.
# PSFzf 는 fzf 를 띄울 때마다 이 값을 읽고, 이 값에 --height 가 있으면 두 함수 모두 이 값을 따른다.
# 부분 화면(light 렌더러)의 한글 입력 문제(위 1)는 위 코드 페이지 설정으로 이미 해결된다.
# 다른 값을 쓰려면 $PROFILE 에서 이 파일을 불러온 뒤 지정한다.
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=60% --layout=reverse'

Set-PsFzfOption `
    -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r' `
    -PSReadlineChordSetLocation 'Alt+c' `
    -PSReadlineChordReverseHistoryArgs 'Alt+a' `
    -TabExpansion `
    -EnableAliasFuzzyKillProcess `
    -AltCCommand {
        # PSFzf 기본값은 `Set-Location $Location` 이라 경로의 [ ] 를 와일드카드로 해석해
        # '報告書 [最終版]' 같은 폴더로 이동하지 못한다. 경로를 문자 그대로 사용한다.
        param($Location)
        Set-Location -LiteralPath $Location
    }

# 표준 탭 완성(TabCompleteNext) 대신 fzf 기반 완성을 사용한다. (PSFzf README 권장)
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# [Ctrl+T: 문맥에 맞춘 경로 이스케이프]
# PSFzf 의 Ctrl+T 는 경로에 공백이 있으면 큰따옴표로 감싸기만 한다(FixCompletionResult).
#   - [ ] 를 이스케이프하지 않아 cd, Get-ChildItem 등 와일드카드를 해석하는 명령에서
#     '報告書 [最終版]' 같은 경로를 찾지 못한다.
#   - 큰따옴표 안의 $ 와 ` 가 해석되어 그런 글자가 든 경로가 바뀐다.
# PowerShell 자체 탭 완성처럼, 작은따옴표로 감싸고 명령 종류에 따라 이스케이프한다.
#   - 외부 프로그램(notepad, git 등)의 인자 : 따옴표만 ('...', ' 는 '' 로)
#   - cmdlet / 함수 / 스크립트의 인자       : 따옴표 + 와일드카드 이스케이프 ([ ] → `[ `])
#   - 명령 이름 자리, 명령이 아닌 식, 알 수 없는 명령 : 따옴표만

# 경로가 들어간 위치의 명령을 보고 'Escape' 또는 'Quote' 를 정한다.
function Get-PsFzfPathEscapeMode {
    param([string]$Line, [int]$Offset)

    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Line, [ref]$null, [ref]$null)
    $cmdAst = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and
            $n.Extent.StartOffset -le $Offset -and $Offset -le $n.Extent.EndOffset
        }, $true) |
        Sort-Object { $_.Extent.EndOffset - $_.Extent.StartOffset } |
        Select-Object -First 1
    if (-not $cmdAst) { return 'Quote' }

    $nameElement = $cmdAst.CommandElements[0]
    if ($Offset -le $nameElement.Extent.EndOffset) { return 'Quote' }

    $name = $cmdAst.GetCommandName()
    if (-not $name) { return 'Quote' }
    $info = Get-Command -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
    while ($info -is [System.Management.Automation.AliasInfo]) { $info = $info.ResolvedCommand }
    if (-not $info -or $info.CommandType -eq 'Application') { return 'Quote' }
    return 'Escape'
}

# Ctrl+T 전후의 명령줄을 비교해 새로 들어간 경로 토큰만 다시 쓴다.
# 반환값: @{ Line = 바뀐 명령줄; Cursor = 커서 위치 }, 바꿀 것이 없으면 $null
function Format-PsFzfInsertedPath {
    param([string]$Before, [string]$After)

    if ($Before -eq $After) { return $null }

    # 바뀐 구간 [start, end) 를 앞뒤 공통 부분을 빼서 구한다.
    $max = [Math]::Min($Before.Length, $After.Length)
    $start = 0
    while ($start -lt $max -and $Before[$start] -eq $After[$start]) { $start++ }
    $suffix = 0
    while ($suffix -lt ($max - $start) -and
        $Before[$Before.Length - 1 - $suffix] -eq $After[$After.Length - 1 - $suffix]) { $suffix++ }
    $end = $After.Length - $suffix

    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($After, [ref]$tokens, [ref]$null)
    $kinds = 'StringLiteral', 'StringExpandable', 'Generic'
    $targets = @($tokens | Where-Object {
            $_.Kind -in $kinds -and $_.Extent.StartOffset -lt $end -and $_.Extent.EndOffset -gt $start
        })
    if ($targets.Count -eq 0) { return $null }

    $mode = Get-PsFzfPathEscapeMode -Line $After -Offset $targets[0].Extent.StartOffset
    $line = $After
    $cursorEnd = $targets[-1].Extent.EndOffset
    $delta = 0
    # 뒤쪽 토큰부터 바꿔야 앞쪽 토큰의 위치가 바뀌지 않는다.
    for ($i = $targets.Count - 1; $i -ge 0; $i--) {
        $t = $targets[$i]
        $value = $t.Value
        if ($mode -eq 'Escape') { $value = [System.Management.Automation.WildcardPattern]::Escape($value) }
        if ($value -notmatch '[\s''"`$&@(){};,|<>#\[\]*?]' -and $t.Kind -eq 'Generic') { continue }
        $new = "'" + $value.Replace("'", "''") + "'"
        $line = $line.Remove($t.Extent.StartOffset, $t.Extent.EndOffset - $t.Extent.StartOffset).Insert($t.Extent.StartOffset, $new)
        $delta += $new.Length - ($t.Extent.EndOffset - $t.Extent.StartOffset)
    }
    if ($line -eq $After) { return $null }
    return @{ Line = $line; Cursor = $cursorEnd + $delta }
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'FzfProviderContextEscape' `
    -Description 'PSFzf Ctrl+T, then quote/escape the inserted paths like PowerShell tab completion' `
    -ScriptBlock {
        $before = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$before, [ref]$cursor)
        Invoke-FzfPsReadlineHandlerProvider
        $after = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$after, [ref]$cursor)
        $fixed = Format-PsFzfInsertedPath -Before $before -After $after
        if ($fixed) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $after.Length, $fixed.Line)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($fixed.Cursor)
        }
    }
