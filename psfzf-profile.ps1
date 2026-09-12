# psfzf-profile.ps1
# fzf + PSFzf 연동 프로파일 (alacritty + zellij, pwsh 7)
#
# 이 파일은 $PROFILE 에서 dot-source 되어 로드된다.
# PSFzf 모듈이 기본으로 제공하는 기능만 사용한다 (README 의 권장 구성):
#   Ctrl+T : 커서 위치 경로를 기준으로 파일/디렉터리 검색 후 명령줄에 삽입
#   Ctrl+R : PSReadLine 명령 기록 검색 후 명령줄에 삽입
#   Alt+C  : 디렉터리 검색 후 즉시 이동
#   Alt+A  : 과거 명령의 인자 검색 후 명령줄에 삽입
#   Tab    : 표준 탭 완성을 fzf 기반 완성(Invoke-FzfTabCompletion)으로 대체
#   **<Tab>: git / Get-Process / Get-Service 등 인자 완성 트리거 (Set-PsFzfOption -TabExpansion)

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

# 표준 탭 완성(TabCompleteNext)을 fzf 기반 완성으로 대체한다. (PSFzf README 권장)
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
