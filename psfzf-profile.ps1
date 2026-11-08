# psfzf-profile.ps1
# fzf + PSFzf 연동 프로파일 (alacritty + zellij, pwsh 7)
#
# $PROFILE 에서 dot-source 되어 로드된다.
#   Ctrl+T  : 파일/디렉터리를 골라 명령줄에 넣기
#   Ctrl+R  : 명령 기록 검색
#   Alt+C   : 디렉터리를 골라 바로 이동
#   Alt+A   : 이전 명령에서 쓴 인자 검색
#   Tab     : fzf 기반 탭 완성
#   **<Tab> : git / Get-Process / Get-Service 등 인자 완성
#   fkill   : 프로세스를 골라 종료
#
# PSFzf 모듈 코드는 수정하지 않고, Set-PsFzfOption 과 PSFzf 공개 함수만 사용한다.

if (-not (Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue) -or
    -not (Get-Module -ListAvailable -Name PSFzf)) {
    Write-Warning 'psfzf-profile: fzf 또는 PSFzf 를 찾지 못해 PSFzf 설정을 건너뜁니다.'
    return
}

Import-Module PSFzf

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

# [한글 입출력 보호]
# 이 PC의 콘솔 코드 페이지는 949(CP949)이고 fzf 는 항상 UTF-8 로 입출력한다.
#   1. fzf 의 --height(light 렌더러)는 콘솔 입력을 코드 페이지 바이트로 읽고 UTF-8 로
#      해석한다. CP949 한글 바이트는 해석에 실패해 Esc(abort)로 처리되어 fzf 가 종료된다.
#      (fzf src/tui/light.go GetChar, light_windows.go setupTerminal)
#   2. PSFzf 의 Invoke-FzfDefaultSystem(Ctrl+T 기본 경로)은 fzf 출력 인코딩을 지정하지
#      않아 .NET 이 콘솔 출력 코드 페이지(949)로 디코딩하므로 한글 경로가 깨진다.
# PSFzf 동작이 실행되는 동안에만 콘솔 입출력 인코딩을 UTF-8 로 바꾸고, 끝나면 되돌린다.
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

# Set-PsFzfOption 이 등록한 키와 Tab 을 위 래퍼를 거치도록 다시 연결한다.
# (**<Tab> 인자 완성기는 Tab 처리 중에 실행되므로 Tab 래퍼가 함께 보호한다)
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'FzfProviderUtf8' `
    -ScriptBlock { Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerProvider } }
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
