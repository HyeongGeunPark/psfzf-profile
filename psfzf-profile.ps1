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
