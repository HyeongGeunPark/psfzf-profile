# psfzf-profile.ps1
# fzf + PSFzf 연동 프로파일 (alacritty + zellij, pwsh 7) - 콘솔 코드 페이지 949 유지 버전
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
# PSFzf 모듈 코드는 수정하지 않고, Set-PsFzfOption, PSFzf 공개 함수, PSFzf README 에 문서화된 환경 변수만 사용한다.
# 콘솔 코드 페이지를 세션 전체에서 UTF-8(65001)로 바꾸는 버전은 utf8-codepage 브랜치에 있다.

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
# 부분 화면(light 렌더러)에서는 아래 문제 1 이 모든 동작에 해당하지만, 이 파일의 키와 fkill 은
# 모두 아래 UTF-8 래퍼 안에서 실행된다. 다른 값을 쓰려면 $PROFILE 에서 이 파일을 불러온 뒤 지정한다.
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=60% --layout=reverse'

# [Alt+C 목록: fd]
# fd 가 있으면 Alt+C 목록을 PSFzf 기본값(cmd /c dir /s/b/ad) 대신 fd 로 만든다. 기본값보다 빠르다.
# 숨김 폴더(점으로 시작하는 폴더, AppData 같은 Windows 숨김 속성 폴더)와 .gitignore 에 적힌 폴더도
# fd 의 --hidden --no-ignore 로 모두 포함하고, .git 과 node_modules 는 뺀다.
# cmd dir 과 달리 정션은 목록에 나오지 않는다.
# fd 는 콘솔 코드 페이지와 관계없이 UTF-8 로 출력하므로 949 에서 읽으면 이름이 깨지지만,
# Alt+C 는 아래 UTF-8 래퍼 안에서 실행되므로 문제없다.
# Set-PsFzfOption -EnableFd 는 쓰지 않는다. PSFzf 2.7.12 는 fd 를 `fd . --full-path <경로> --fixed-strings`
# 로 실행해서, 절대 경로에 '.' 이 없는 항목을 목록에서 뺀다.
# Ctrl+T 는 커서 위치의 경로에서 검색을 시작하는 기능을 유지하려고 PSFzf 기본값(fzf 내장 탐색기)을 쓴다.
if (Get-Command fd -CommandType Application -ErrorAction SilentlyContinue) {
    # PSFzf 는 이 명령의 출력을 Invoke-Fzf 로 넘기고, Invoke-Fzf 는 받은 항목마다 fzf 입력에 한 줄을
    # 쓰고 Flush 하고 프로세스 상태를 확인한다. 1000 줄씩 한 문자열로 묶어 넘기면 fzf 는 같은 목록을
    # 받고, 항목 처리 횟수는 1000 분의 1 로 준다. 홈 폴더(약 13만 개)에서 한 줄씩 넘기면 Alt+C 목록이
    # 다 차는 데 9초, 묶어 넘기면 4초 정도 걸린다.
    # fzf 내장 탐색기(--walker)는 쓸 수 없다. fzf 는 표준 입력이 터미널일 때만 내장 탐색기를 쓰는데,
    # PSFzf 의 Alt+C 는 항상 이 명령의 출력을 Invoke-Fzf 로 파이프해 fzf 표준 입력에 넣는다.
    # 인자는 fd 에 그대로 넘긴다. (예: Get-PsFzfAltCDirectory --hidden --no-ignore)
    function Get-PsFzfAltCDirectory {
        $batch = [System.Collections.Generic.List[string]]::new(1000)
        fd --type directory @args | ForEach-Object {
            $batch.Add($_)
            if ($batch.Count -ge 1000) { $batch -join "`n"; $batch.Clear() }
        }
        if ($batch.Count -gt 0) { $batch -join "`n" }
    }
    $env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --no-ignore --exclude .git --exclude node_modules'
}

Set-PsFzfOption `
    -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r' `
    -PSReadlineChordSetLocation 'Alt+c' `
    -PSReadlineChordReverseHistoryArgs 'Alt+a' `
    -TabExpansion `
    -AltCCommand {
        # PSFzf 기본값은 `Set-Location $Location` 이라 경로의 [ ] 를 와일드카드로 해석해
        # '報告書 [最終版]' 같은 폴더로 이동하지 못한다. 경로를 문자 그대로 사용한다.
        param($Location)
        Set-Location -LiteralPath $Location
    }

# [PSFzf 동작 중에만 UTF-8 콘솔]
# 한국어 Windows 의 콘솔 기본 코드 페이지는 949(CP949)이고 fzf 는 항상 UTF-8 로 입출력한다.
# 이 차이 때문에 다음 문제가 생긴다.
#   1. fzf 의 --height(light 렌더러)는 콘솔 입력을 코드 페이지 바이트로 읽고 UTF-8 로
#      해석한다. CP949 한글 바이트는 해석에 실패해 Esc(abort)로 처리되어 fzf 가 종료된다.
#      (fzf src/tui/light.go GetChar, light_windows.go setupTerminal)
#   2. PSFzf 의 Invoke-FzfDefaultSystem(Ctrl+T 기본 경로)은 fzf 출력 인코딩을 지정하지
#      않아 .NET 이 콘솔 출력 코드 페이지(949)로 디코딩하므로 한글 경로가 깨진다.
#   3. Alt+C 목록을 만드는 `cmd /c dir` 의 파이프 출력이 949 로 인코딩되어
#      CP949 에 없는 글자(込, 们, é, 이모지 등)가 ? 로 바뀐다.
# PSFzf 동작이 실행되는 동안에만 콘솔 입출력 인코딩을 UTF-8 로 바꾸고, 끝나면 되돌린다.
# (그 사이에 실행되는 cmd 등 자식 프로그램도 65001 을 이어받으므로 3 도 해결된다)
function Invoke-PsFzfWithUtf8Console {
    param([Parameter(Mandatory)][scriptblock]$Action)

    $previousInput = [Console]::InputEncoding
    $previousOutput = [Console]::OutputEncoding
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    try {
        [Console]::InputEncoding = $utf8NoBom
        [Console]::OutputEncoding = $utf8NoBom
        & $Action
    }
    finally {
        # 선택, Esc 취소, 오류와 관계없이 원래 인코딩으로 복원한다.
        [Console]::InputEncoding = $previousInput
        [Console]::OutputEncoding = $previousOutput
    }
}

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

# Set-PsFzfOption 이 등록한 키와 Tab 을 위 래퍼를 거치도록 다시 연결한다.
# (**<Tab> 인자 완성기는 Tab 처리 중에 실행되므로 Tab 래퍼가 함께 보호한다)
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'FzfProviderUtf8ContextEscape' `
    -Description 'PSFzf Ctrl+T in a UTF-8 console, then quote/escape the inserted paths like PowerShell tab completion' `
    -ScriptBlock {
        $before = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$before, [ref]$cursor)
        Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerProvider }
        $after = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$after, [ref]$cursor)
        $fixed = Format-PsFzfInsertedPath -Before $before -After $after
        if ($fixed) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $after.Length, $fixed.Line)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($fixed.Cursor)
        }
    }
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -BriefDescription 'FzfHistoryUtf8' `
    -ScriptBlock { Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerHistory } }
Set-PSReadLineKeyHandler -Chord 'Alt+c' -BriefDescription 'FzfLocationUtf8' `
    -ScriptBlock { Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerSetLocation } }
Set-PSReadLineKeyHandler -Chord 'Alt+a' -BriefDescription 'FzfHistoryArgsUtf8' `
    -ScriptBlock { Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerHistoryArgs } }
Set-PSReadLineKeyHandler -Chord 'Tab' -BriefDescription 'FzfTabUtf8' `
    -ScriptBlock { Invoke-PsFzfWithUtf8Console { Invoke-FzfTabCompletion } }

# fkill: 프로세스를 골라 종료한다. PSFzf 의 별칭(-EnableAliasFuzzyKillProcess) 대신
# 함수로 정의해 위 UTF-8 래퍼 안에서 실행한다. (별칭은 함수보다 우선하므로 함께 켜지 않는다)
function fkill {
    Invoke-PsFzfWithUtf8Console { Invoke-FuzzyKillProcess }
}
