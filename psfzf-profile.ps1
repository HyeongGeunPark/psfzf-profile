# psfzf-profile.ps1
# fzf + PSFzf 연동 프로파일 (alacritty + zellij, pwsh 7)
#
# 이 파일은 $PROFILE 에서 dot-source 되어 로드된다.
# PSFzf 모듈이 기본으로 제공하는 기능을 사용한다 (README 의 권장 구성):
#   Ctrl+T : 커서 위치 경로를 기준으로 파일/디렉터리 검색 후 명령줄에 삽입
#   Ctrl+R : PSReadLine 명령 기록 검색 후 명령줄에 삽입
#   Alt+C  : 디렉터리 검색 후 즉시 이동
#   Alt+A  : 과거 명령의 인자 검색 후 명령줄에 삽입
#   Tab    : 표준 탭 완성을 fzf 기반 완성(Invoke-FzfTabCompletion)으로 대체
#   **<Tab>: git / Get-Process / Get-Service 등 인자 완성 트리거 (Set-PsFzfOption -TabExpansion)
#
# [한글 입출력 workaround] 출처: Obsidian "30 Resources/CS/개발도구/터미널/zoxide, fzf, PSFzf.md"
# 별도 설정이 없는 ko-KR 콘솔은 코드 페이지가 949 라서 다음 두 문제가 생긴다.
#   1. --height 로 부분 창을 띄운 fzf 에 한글을 입력하면 fzf 가 종료된다.
#   2. Ctrl+T 경로(PSFzf 의 Invoke-FzfDefaultSystem)는 fzf 의 UTF-8 출력을 콘솔 코드 페이지로
#      디코딩하므로 선택한 한글 경로가 깨진다.
# 각 PSFzf 단축키가 실행되는 동안에만 콘솔 입출력 인코딩을 UTF-8 로 바꾸고, fzf 가 끝나면
# 원래 인코딩으로 되돌리는 래퍼(Invoke-PsFzfWithUtf8Console)로 우회한다.

# fzf 실행 파일과 PSFzf 모듈이 모두 있을 때만 연동한다.
$fzfCommand = Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
$psFzfModule = Get-Module -ListAvailable -Name PSFzf |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $fzfCommand) {
    Write-Warning 'psfzf-profile: fzf 실행 파일을 PATH에서 찾지 못했습니다. PSFzf 연동을 건너뜁니다.'
    return
}
if (-not $psFzfModule) {
    Write-Warning 'psfzf-profile: PSFzf 모듈을 찾지 못했습니다. PSFzf 연동을 건너뜁니다.'
    return
}

# [fzf 실행 옵션]
# PSFzf 가 fzf 를 실행할 때 사용한다 (PSFzf README: _PSFZF_FZF_DEFAULT_OPTS).
# 현재 터미널 안에서 높이 60% 의 창으로 표시한다. 한글 입력 문제는 아래 UTF-8 래퍼가 막는다.
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=60% --layout=reverse --border --info=inline'

# [사용자 정의 함수: PSFzf 전용 임시 UTF-8 콘솔]
# PSFzf 단축키가 실행되는 동안에만 Windows 콘솔 입력·출력 코드 페이지를 UTF-8(65001)로 맞춘다.
# 한글 검색 입력과 선택된 한글 경로 출력을 모두 보호한다.
function Invoke-PsFzfWithUtf8Console {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    # fzf 가 끝난 뒤 현재 PowerShell 세션의 원래 설정으로 돌아가기 위해 보관한다.
    $previousInputEncoding = [Console]::InputEncoding
    $previousOutputEncoding = [Console]::OutputEncoding
    $utf8NoBom = [Text.UTF8Encoding]::new($false)

    try {
        # `chcp 65001` 을 별도 프로세스로 실행하지 않고 같은 효과를 적용한다.
        [Console]::InputEncoding = $utf8NoBom
        [Console]::OutputEncoding = $utf8NoBom
        & $Action
    }
    finally {
        # 정상 선택, Esc 취소, 오류 발생 여부와 관계없이 원래 인코딩을 복원한다.
        [Console]::InputEncoding = $previousInputEncoding
        [Console]::OutputEncoding = $previousOutputEncoding
    }
}

Import-Module PSFzf -ErrorAction Stop

# PSReadLine 기본 바인딩(Ctrl+R: ReverseSearchHistory, Alt+A: SelectCommandArgument)을
# PSFzf 동작으로 덮어쓴다. Set-PsFzfOption 은 -Override 로 등록한다.
# -TabExpansion 은 '**' 트리거 인자 완성기(git, Get-Process, Get-Service 등)를 등록한다.
Set-PsFzfOption `
    -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r' `
    -PSReadlineChordSetLocation 'Alt+c' `
    -PSReadlineChordReverseHistoryArgs 'Alt+a' `
    -TabExpansion

# [PSReadLine 재바인딩]
# PSFzf 가 등록한 키를 다시 연결하여 각 PSFzf 동작이 위 UTF-8 래퍼 안에서 실행되게 한다.
# fzf 가 종료되면 래퍼가 콘솔 인코딩을 즉시 복원한다.

# PSFzf: 현재 입력 토큰을 기준으로 파일 또는 디렉터리를 선택한다.
Set-PSReadLineKeyHandler `
    -Chord 'Ctrl+t' `
    -BriefDescription 'FzfProviderUtf8' `
    -Description 'Run PSFzf provider selection with temporary UTF-8 console encoding' `
    -ScriptBlock {
        Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerProvider }
    }

# PSFzf: PSReadLine 명령 기록을 역방향으로 검색한다.
Set-PSReadLineKeyHandler `
    -Chord 'Ctrl+r' `
    -BriefDescription 'FzfHistoryUtf8' `
    -Description 'Run PSFzf history selection with temporary UTF-8 console encoding' `
    -ScriptBlock {
        Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerHistory }
    }

# PSFzf: 검색한 디렉터리로 현재 위치를 변경한다.
Set-PSReadLineKeyHandler `
    -Chord 'Alt+c' `
    -BriefDescription 'FzfLocationUtf8' `
    -Description 'Run PSFzf location selection with temporary UTF-8 console encoding' `
    -ScriptBlock {
        Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerSetLocation }
    }

# PSFzf: 이전 명령에 사용된 인자를 검색한다.
Set-PSReadLineKeyHandler `
    -Chord 'Alt+a' `
    -BriefDescription 'FzfHistoryArgsUtf8' `
    -Description 'Run PSFzf history argument selection with temporary UTF-8 console encoding' `
    -ScriptBlock {
        Invoke-PsFzfWithUtf8Console { Invoke-FzfPsReadlineHandlerHistoryArgs }
    }

# PSFzf: 표준 탭 완성(TabCompleteNext) 대신 fzf 기반 완성을 실행한다. (PSFzf README 권장)
Set-PSReadLineKeyHandler `
    -Chord 'Tab' `
    -BriefDescription 'FzfTabUtf8' `
    -Description 'Run PSFzf tab completion with temporary UTF-8 console encoding' `
    -ScriptBlock {
        Invoke-PsFzfWithUtf8Console { Invoke-FzfTabCompletion }
    }
