# psfzf-profile

[한국어](#한국어) | [English](#english)

---

## 한국어

한국어 Windows(코드 페이지 949) 환경에서 [fzf](https://github.com/junegunn/fzf)와 [PSFzf](https://github.com/kelleyma49/PSFzf)를 PowerShell 7에서 문제없이 쓰기 위한 프로파일입니다.
PSFzf 모듈 코드는 수정하지 않고, `Set-PsFzfOption`, PSFzf가 공개한 함수, PSFzf README에 문서화된 환경 변수만 사용합니다.

이 저장소에는 해결 방식이 다른 두 브랜치가 있습니다.

| 브랜치 | 방식 |
|---|---|
| **`main`** (이 문서) | 콘솔 코드 페이지 949를 유지하고, PSFzf 동작이 실행되는 동안에만 UTF-8로 바꿈 |
| `utf8-codepage` | pwsh 콘솔 코드 페이지를 세션 전체에서 UTF-8(65001)로 바꿈 |

차이는 아래 "다른 방식: `utf8-codepage` 브랜치"를 참고하세요.

### 확인한 환경

| 항목 | 버전 |
|---|---|
| OS | Windows 11 (시스템 로캘 ko-KR, ACP/OEMCP 949) |
| PowerShell | 7.6.9 |
| PSReadLine | 2.4.5 |
| PSFzf | 2.7.12 |
| fzf | 0.75.0 |
| fd (선택) | 10.5.0 |
| 터미널 | Alacritty + Zellij |

다른 버전에서도 동작할 수 있지만, 아래 분석은 위 버전의 소스를 기준으로 합니다.

### 제공하는 기능

| 키 / 명령 | 동작 |
|---|---|
| `Ctrl+T` | 파일/디렉터리를 골라 명령줄에 넣기 (명령에 맞춰 따옴표·이스케이프 처리) |
| `Ctrl+R` | 명령 기록 검색 |
| `Alt+C` | 디렉터리를 골라 바로 이동 |
| `Alt+A` | 이전 명령에서 쓴 인자 검색 |
| `Tab` | fzf 기반 탭 완성 |
| `**<Tab>` | git / Get-Process / Get-Service 등 인자 완성 |
| `fkill` | 프로세스를 골라 종료 |

이 프로파일은 **콘솔 코드 페이지(949)를 바꾸지 않습니다.** fzf를 쓰는 동작이 실행되는 동안에만 잠시 UTF-8로 바꿨다가 되돌립니다.

fzf는 모든 동작에서 높이 60% 부분 화면으로 뜹니다. 크기를 바꾸는 방법은 아래 "참고: 전체 화면과 부분 화면"을 보세요.

fd가 설치되어 있으면 `Alt+C` 목록을 fd로 만듭니다. 아래 "참고: fd로 만드는 `Alt+C` 목록"을 보세요.

### 설치

```powershell
winget install junegunn.fzf
winget install sharkdp.fd                # 선택: Alt+C 목록을 fd로 만든다
Install-Module PSFzf -Scope CurrentUser
git clone <이 저장소 URL> <원하는 경로>\psfzf-profile
```

`$PROFILE`에 다음을 추가합니다.

```powershell
$psFzfProfile = '<원하는 경로>\psfzf-profile\psfzf-profile.ps1'
if (Test-Path -LiteralPath $psFzfProfile) { . $psFzfProfile }
else { Write-Warning "psfzf-profile 을 찾지 못했습니다: $psFzfProfile" }
Remove-Variable psFzfProfile
```

fzf 실행 파일이나 PSFzf 모듈이 없으면 경고만 출력하고 설정을 건너뜁니다.

### 왜 필요한가: 기본 설정에서 생기는 문제

#### 배경: 콘솔 코드 페이지 949

따로 설정하지 않으면 한국어 Windows의 pwsh 콘솔은 입력·출력 코드 페이지가 949입니다. 위 환경의 conhost, Alacritty, Alacritty + Zellij에서 모두 949로 측정했습니다. 자신의 환경은 다음 명령으로 확인할 수 있습니다.

```powershell
[Console]::InputEncoding.CodePage; [Console]::OutputEncoding.CodePage
```

코드 페이지는 **바이트로 읽고 쓰는 경로**에만 적용됩니다. PowerShell 문자열, 화면 출력(`WriteConsoleW`), 콘솔에서 터미널로 가는 출력은 유니코드로 처리되므로, 949 환경에서도 일본어 등은 화면에 정상으로 보입니다. 문제는 아래처럼 바이트 경로를 거치는 곳에서 생깁니다. Go로 작성된 fzf는 항상 UTF-8 바이트를 기대합니다.

#### 문제 1. `--height` 모드에서 한글을 입력하면 fzf가 꺼진다

- PSFzf는 fzf를 부분 화면(`--height=40%`)으로 띄우는 경우가 있습니다(아래 "참고" 참조). 이때 fzf는 "light 렌더러"를 씁니다.
- light 렌더러는 Windows에서 `CONIN$`의 원시 바이트를 `ReadFile`로 읽습니다(`src/tui/light_windows.go`의 `setupTerminal`, `src/util/util_windows.go`의 `Read`). 이 바이트는 **콘솔 입력 코드 페이지(949)** 로 인코딩되어 들어옵니다. 예를 들어 "한"은 `C7 D1`입니다.
- fzf는 이 바이트를 UTF-8로 해석하고, 해석에 실패하면 **Esc 키로 처리**합니다(`src/tui/light.go`의 `GetChar`).
  ```go
  char, rsz := utf8.DecodeRune(r.buffer)
  if char == utf8.RuneError {
      return Event{Esc, 0, nil}
  }
  ```
- fzf의 기본 동작에서 Esc는 `abort`이므로, 한글을 입력하는 순간 fzf가 종료됩니다.
- 전체 화면 모드는 tcell 렌더러가 유니코드 API로 입력을 읽으므로 이 문제가 없습니다.

#### 문제 2. `Ctrl+T`로 고른 한글 경로가 깨진다

- `Ctrl+T`의 기본 경로(파일시스템 위치, fd 미사용)에서 PSFzf는 `Invoke-FzfDefaultSystem`으로 fzf를 실행합니다.
- 이 함수는 fzf 표준출력을 리디렉션하면서 `StandardOutputEncoding`을 지정하지 않습니다. 이 경우 .NET은 **콘솔 출력 코드 페이지(949)** 로 디코딩합니다.
- fzf가 보낸 UTF-8 경로를 CP949로 읽게 되어, 명령줄에 깨진 글자가 들어갑니다.
- 다른 기능이 쓰는 `Invoke-Fzf`는 `StandardOutputEncoding = UTF8`을 지정하므로 이 문제가 없습니다.

#### 문제 3. `Alt+C` 목록에서 CP949에 없는 글자가 `?`로 바뀐다

- PSFzf는 `Alt+C` 목록을 `cmd.exe /S /C dir /s/b/ad "."`로 만들고, 그 파이프 출력을 받습니다. 출력이 파이프일 때 cmd는 **콘솔 코드 페이지(949)** 로 인코딩해서 내보냅니다.
- CP949(KS X 1001 기반)에는 한글뿐 아니라 일본어 가나와 흔한 한자(`日本語フォルダ` 등)도 들어 있어서 이런 이름은 문제가 없습니다. 하지만 `込`, `辻`, `们`, `é`, 이모지처럼 **CP949에 없는 글자**는 `?`로 바뀌거나 비슷한 글자로 대체됩니다(`café` → `cafe`).
- 기본 동작은 `Set-Location $Location`이라, 우연히 `?`가 와일드카드로 해석되어 이동에 성공하는 경우도 있습니다. 대체된 글자는 그렇게 맞출 수 없어서 실패합니다.
- 코드 페이지 949인 콘솔에서 기본 PSFzf로 재현한 결과:

  | 실제 폴더 이름 | 목록에 나온 이름 | 기본 `Alt+C` |
  |---|---|---|
  | `日本語フォルダ_jp` | 그대로 | 이동됨 |
  | `込み辻_x1` | `?み?_x1` | 이동됨 (`?` 와일드카드로 우연히 일치) |
  | `café_x2` | `cafe_x2` | **실패** |
  | `我们_x4` | `我?_x4` | 이동됨 (`?` 와일드카드로 우연히 일치) |

#### 문제 4. 대괄호가 든 경로를 와일드카드로 해석한다 (`Alt+C`, `Ctrl+T`)

공통 원인은 **PowerShell cmdlet의 `-Path` 매개변수가 경로를 와일드카드 패턴으로 해석한다**는 점입니다. `報告書 [最終版]` 같은 경로의 `[...]`는 "괄호 안 글자 중 하나"로 해석되어 실제 폴더를 찾지 못합니다. 인코딩과는 관계없이 발생합니다.

이 규칙을 피하는 정석은 두 가지입니다.

- `-LiteralPath`로 넘겨 와일드카드 해석을 끈다.
- 와일드카드 문자를 백틱으로 이스케이프(`` `[ ``, `` `] ``)해서 `-Path`로 넘긴다.

PSFzf에서는 이 원인이 두 곳에서 드러납니다.

##### 4-1. `Alt+C`로 대괄호가 든 디렉터리에 이동하지 못한다

- PSFzf의 기본 `Alt+C` 동작은 `Set-Location $Location`입니다.
- fzf에서 선택까지는 정상이지만, `Set-Location`이 경로를 와일드카드로 해석해 이동에 실패합니다.

##### 4-2. `Ctrl+T`로 넣은 경로가 cmdlet에서 동작하지 않는다

- PSFzf의 `Ctrl+T`는 결과를 `FixCompletionResult`로 다듬습니다. 공백이 있으면 **큰따옴표로 감싸기만** 하고 다른 처리는 하지 않습니다.
- 그래서 다음 문제가 생깁니다.
  - `cd`, `Get-ChildItem` 같은 cmdlet은 `[...]`를 와일드카드로 해석하므로 `報告書 [最終版]` 같은 경로를 찾지 못합니다.
  - 큰따옴표 안에서는 `$`와 백틱이 해석되므로, 이름에 그런 글자가 있으면 경로가 바뀝니다.
- PowerShell 자체 탭 완성은 이 문제가 없습니다. 작은따옴표를 쓰고, **명령에 따라 다르게** 이스케이프합니다.

  | 명령줄 | PowerShell 탭 완성 결과 |
  |---|---|
  | `cd 報告書` | `` '.\報告書 `[最終版`] 2024' `` |
  | `notepad 報告書` | `'.\報告書 [最終版] 2024'` |

  와일드카드를 해석하는 cmdlet 인자에는 백틱을 넣고, 외부 프로그램 인자에는 넣지 않습니다. 외부 프로그램에 백틱을 넣으면 그 글자가 그대로 전달되기 때문입니다.
- PSFzf 변경 이력을 보면, 이 함수는 처음에 공백만 고려해 작은따옴표로 감쌌고(2020), 이름에 `'`가 있는 경우 때문에 큰따옴표로 바뀌었습니다(2022, #171). 와일드카드 이스케이프를 다룬 변경은 없습니다.

### 이 프로파일의 해결 방법

| 문제 | 해결 |
|---|---|
| 1, 2, 3 | `Invoke-PsFzfWithUtf8Console` 래퍼가 PSFzf 동작이 실행되는 **동안에만** `[Console]::InputEncoding`/`OutputEncoding`을 UTF-8로 바꾸고, 끝나면 `finally`에서 원래 값(949)으로 되돌립니다. 그동안 fzf가 UTF-8 바이트를 받고(1), .NET이 fzf 출력을 UTF-8로 디코딩하고(2), 그 사이 실행되는 자식 cmd도 65001을 이어받아 `dir` 목록을 UTF-8로 내보냅니다(3). |
| 4-1 | `Set-PsFzfOption -AltCCommand`로 이동 명령을 `Set-Location -LiteralPath $Location`으로 바꿉니다. |
| 4-2 | `Ctrl+T`를 감싸서, 래퍼 안에서 PSFzf를 실행한 뒤 **새로 들어간 경로만** PowerShell 탭 완성과 같은 규칙으로 다시 씁니다. |

래퍼를 거치는 동작은 `Ctrl+T`, `Ctrl+R`, `Alt+C`, `Alt+A`, `Tab`, `fkill`입니다. 키는 PSReadLine에 다시 연결합니다.

- `**<Tab>` 인자 완성기는 `Tab` 처리 중에 실행되므로 `Tab` 래퍼가 함께 보호합니다.
- PSFzf의 `-EnableAliasFuzzyKillProcess`는 `fkill`을 별칭으로 등록해서 래퍼를 끼울 수 없습니다. 그래서 래퍼 안에서 `Invoke-FuzzyKillProcess`를 실행하는 `fkill` **함수**를 정의하고, 별칭 옵션은 켜지 않습니다. 별칭은 함수보다 우선하기 때문입니다.
- 문제 3과 4-1은 함께 고쳐야 합니다. 래퍼 없이 `-LiteralPath`만 쓰면, 문제 3에서 `?` 와일드카드로 우연히 맞던 경우까지 실패합니다.

#### 4-1과 4-2를 다르게 고친 이유

원인은 같지만, 프로파일이 손댈 수 있는 위치가 다릅니다.

| | `Alt+C` (4-1) | `Ctrl+T` (4-2) |
|---|---|---|
| 프로파일이 다루는 것 | **명령 실행** (`Set-Location`을 직접 호출) | **명령줄 텍스트** (실행은 사용자가 나중에 함) |
| 경로를 받을 명령 | 항상 `Set-Location` | 넣는 시점에는 정해지지 않음 (`cd`, `notepad`, `git` 등) |
| 해결 | `-LiteralPath` | 명령에 맞춘 이스케이프 |

- `Alt+C`는 받을 명령이 정해져 있고 실행을 직접 하므로, 와일드카드 해석을 끄는 `-LiteralPath`가 가장 직접적입니다. 이스케이프해서 `-Path`로 넘겨도 결과는 같지만 얻는 이점이 없습니다.
- `Ctrl+T`는 텍스트만 넣으므로, 사용자가 입력할 명령에 `-LiteralPath`를 붙일 방법이 없습니다. 외부 프로그램은 그런 매개변수가 없고 백틱을 그대로 받기 때문에, 일괄 이스케이프도 맞지 않습니다. 그래서 PowerShell 탭 완성처럼 명령 종류를 보고 이스케이프합니다.

#### `Ctrl+T`의 처리 규칙

`Format-PsFzfInsertedPath`, `Get-PsFzfPathEscapeMode`가 다음 순서로 처리합니다.

1. `Ctrl+T` 실행 전과 후의 명령줄을 비교해 새로 들어간 경로 토큰을 찾습니다.
2. PowerShell 파서로 그 위치의 명령을 찾고, 별칭은 실제 명령으로 바꿔 종류를 확인합니다.
3. 종류에 따라 다시 씁니다.

| 문맥 | 처리 | 예 |
|---|---|---|
| cmdlet, 함수, 스크립트의 인자 | 작은따옴표 + 와일드카드 이스케이프 | `` cd '...\報告書 `[最終版`]\' `` (`[`→`` `[ ``, `]`→`` `] ``) |
| 외부 프로그램의 인자 | 작은따옴표만 | `notepad '...\報告書 [最終版]\'` |
| 명령 이름 자리, 식(`$p = `), 알 수 없는 명령 | 작은따옴표만 | |
| 특수 문자가 없는 경로 | 그대로 | `cd C:\work\日本語` |

모든 경우에 이름 속 `'`는 `''`로 바꿉니다. 작은따옴표 안에서는 `$`와 백틱이 해석되지 않으므로 4-2의 두 번째 경우도 함께 해결됩니다.

#### 알려진 한계

PSFzf의 `Ctrl+T`는 커서 위치의 단어가 경로인지 판단할 때 `Test-Path $currentPath`를 씁니다. 이것도 같은 원인으로 와일드카드 해석을 합니다. 코드상으로는, 대괄호가 든 경로를 이스케이프하지 않고 직접 입력한 뒤 `Ctrl+T`를 누르면 그 경로를 인식하지 못하고 현재 폴더에서 검색을 시작합니다. PSFzf 내부 코드라 공개 함수만으로는 고칠 수 없고, 검색 시작 위치만 달라지므로 그대로 둡니다.

### 다른 방식: `utf8-codepage` 브랜치

`utf8-codepage` 브랜치는 pwsh 콘솔의 코드 페이지를 세션 전체에서 65001로 바꿔 문제 1, 2, 3을 해결합니다. 래퍼, 키 재연결, `fkill` 함수가 필요 없어 프로파일이 단순합니다. 4-1과 4-2의 해결은 두 브랜치가 같습니다.

| | `main` (949 유지 + 래퍼) | `utf8-codepage` (세션 전체 65001) |
|---|---|---|
| 다른 프로그램에 주는 영향 | 없음 (PSFzf 동작 중에만 바뀜) | 이 콘솔에서 실행하는 모든 프로그램이 65001을 이어받음 |
| 프로파일 구성 | 래퍼 + 키 재연결 + `fkill` 함수 | 코드 페이지 설정 두 줄 + PSFzf 기본 핸들러 |
| PSFzf 밖에서 외부 프로그램 출력 | 949 기준 (아래 표의 949 열) | UTF-8 기준 (아래 표의 65001 열) |

949와 65001에서 외부 프로그램 출력을 pwsh로 받아 비교한 결과입니다.

| 명령 | 949 | 65001 |
|---|---|---|
| `cmd /c echo 한글 日本語 込` | `込` → `?` | 정상 |
| `python -c "print('한글 込')"` | 깨짐 | 정상 |
| `git log` | 정상 | 정상 |
| `ipconfig`, `ping`, `where` | 한국어 메시지 | **영어 메시지** |

65001에서는 다음 영향이 있습니다.

- Windows 기본 명령 일부가 메시지를 영어로 출력합니다. 글자가 깨지는 것은 아닙니다.
- 콘솔에서 실행한 cmd와 `.bat`/`.cmd` 파일도 65001을 이어받습니다. CP949로 저장된 배치 파일에 한글이 있으면 오동작할 수 있습니다.
- 코드 페이지와 관계없이 CP949 바이트를 출력하는 오래된 프로그램은 글자가 깨질 수 있습니다.

CP949를 기대하는 배치 파일이나 오래된 프로그램을 쓴다면 `main`이 안전합니다. UTF-8로 출력하는 도구(Python 등)를 pwsh에서 자주 다룬다면 `utf8-codepage`가 더 잘 맞습니다.

### 참고: 전체 화면과 부분 화면

PSFzf가 fzf를 어떤 크기로 띄울지는 사용하는 내부 함수에 따라 다릅니다.

- `Invoke-Fzf`(대부분의 기능): `WT_SESSION`, `ConEmuANSI`, `TERM_PROGRAM=WezTerm` 중 하나가 있을 때만 `--height=40%`를 붙입니다. Alacritty나 Zellij에서는 **전체 화면**입니다.
- `Invoke-FzfDefaultSystem`(`Ctrl+T` 기본 경로): 터미널과 관계없이 항상 `--height=40%`를 붙입니다. **부분 화면**입니다.

PSFzf는 fzf를 띄울 때마다 `$env:_PSFZF_FZF_DEFAULT_OPTS`를 읽고, 두 함수 모두 이 값에 `--height`가 있으면 기본값을 붙이지 않습니다. 이 프로파일은 이 값을 다음처럼 설정해 **높이 60% 부분 화면으로 통일**합니다.

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=60% --layout=reverse'
```

다른 값을 쓰려면 `$PROFILE`에서 psfzf-profile을 불러온 **뒤**에 지정합니다.

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=40% --layout=reverse'  # 높이 40% 부분 화면
$env:_PSFZF_FZF_DEFAULT_OPTS = '--no-height'                    # 전체 화면
```

부분 화면에서는 fzf가 light 렌더러를 쓰므로 문제 1이 모든 동작에 해당합니다. 이 프로파일의 키와 `fkill`은 래퍼 안에서 실행되므로 문제없습니다. 하지만 PSFzf 함수를 직접 실행하면(예: `Get-ChildItem | Invoke-Fzf`) 래퍼를 거치지 않으므로, 한글을 입력하는 순간 fzf가 꺼집니다. 이런 명령은 `Invoke-PsFzfWithUtf8Console { Get-ChildItem | Invoke-Fzf }`처럼 감싸서 실행하거나, 전체 화면(`--no-height`)을 쓰세요.

### 참고: fd로 만드는 `Alt+C` 목록

[fd](https://github.com/sharkdp/fd)가 설치되어 있으면 이 프로파일은 `Alt+C` 목록을 PSFzf 기본(`cmd /c dir /s/b/ad`) 대신 fd로 만듭니다. fd가 없으면 PSFzf 기본 동작을 그대로 씁니다.

```powershell
function Get-PsFzfAltCDirectory {
    $batch = [System.Collections.Generic.List[string]]::new(1000)
    fd --type directory @args | ForEach-Object {
        $batch.Add($_)
        if ($batch.Count -ge 1000) { $batch -join "`n"; $batch.Clear() }
    }
    if ($batch.Count -gt 0) { $batch -join "`n" }
}
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --no-ignore --exclude .git --exclude node_modules'
```

PSFzf는 `FZF_ALT_C_COMMAND`가 있으면 그 명령의 출력으로 `Alt+C` 목록을 만듭니다. `Get-PsFzfAltCDirectory`는 받은 인자를 fd에 그대로 넘기고, fd 출력을 1,000줄씩 묶어 내보냅니다. `--hidden --no-ignore`이므로 숨김 폴더와 `.gitignore`에 적힌 폴더도 모두 목록에 나오고, `--exclude`로 `.git`과 `node_modules`는 뺍니다.

#### fd를 넣은 이유

PSFzf 기본(`cmd dir`)보다 빠르기 때문입니다. 아래는 PSFzf의 실제 `Alt+C` 핸들러가 목록을 끝까지 받는 데 걸린 시간이며, 3회 측정의 중앙값입니다. fzf에 일치하는 항목이 없는 `--filter`를 줘서 목록을 끝까지 읽게 했고, 화면을 그리는 시간은 들어가지 않습니다.

| 측정 위치 | `cmd dir` (PSFzf 기본) | fd (이 프로파일) |
|---|---|---|
| 코드 저장소가 모인 폴더 | 26,010개, 2.69초 | 20,972개, 0.47초 |
| 사용자 홈 (AppData 포함) | 151,013개, 18.09초 | 133,909개, 4.08초 |

fd 목록이 적은 것은 `.git`, `node_modules`, 정션을 빼기 때문입니다(아래 "`cmd dir`과 다른 점").

#### 1,000줄씩 묶어 넘기는 이유

PSFzf는 `FZF_ALT_C_COMMAND`의 출력을 `Invoke-Fzf`로 파이프해 fzf에 넘깁니다. `Invoke-Fzf`는 받은 항목마다 fzf 입력에 한 줄을 쓰고, `Flush()`를 부르고, fzf 프로세스 상태를 확인합니다. fd 출력을 한 줄씩 넘기면 폴더 수만큼 이 처리가 반복되어, 목록이 크면 fd 자체보다 이 처리가 더 오래 걸립니다.

| 측정 위치 | fd를 fzf에 직접 연결 (참고) | fd, 한 줄씩 | fd, 1,000줄씩 묶음 |
|---|---|---|---|
| 코드 저장소가 모인 폴더 | 0.44초 | 1.31초 | 0.47초 |
| 사용자 홈 (AppData 포함) | 3.32초 | 9.10초 | 4.08초 |

`Invoke-Fzf`는 받은 문자열을 `WriteLine`으로 그대로 쓰므로, 여러 줄을 한 문자열로 묶어 넘기면 fzf는 같은 목록을 여러 줄로 받습니다. 1,000줄씩 묶으면 항목 처리 횟수가 1,000분의 1로 줄어, fd를 fzf에 직접 연결한 것과 거의 같은 시간이 걸립니다. 전체를 한 문자열로 묶지 않고 1,000줄씩 나누는 것은 fd가 끝나기 전에도 fzf 목록이 차례로 채워지게 하기 위해서입니다.

확인한 내용은 다음과 같습니다.

- 한 줄씩 넘길 때와 묶어 넘길 때 fzf가 받는 폴더 목록이 같습니다. 정렬해서 비교했습니다. fd는 병렬로 탐색하므로 실행할 때마다 순서만 다릅니다.
- 묶음 크기 1, 2, 3, 1,000에서 모두 같은 폴더로 이동했습니다. 묶음 안의 줄은 `\n`, 묶음의 마지막 줄은 `\r\n`으로 끝나지만 fzf는 둘을 똑같이 읽습니다.
- 목록이 다 차기 전에 fzf를 끝내도(예: Esc) 바로 정리되고, fd 프로세스가 남지 않습니다.

#### 이렇게 구현한 이유

- **`Set-PsFzfOption -EnableFd` 대신 `FZF_ALT_C_COMMAND`를 씁니다.** PSFzf에는 fd를 쓰게 하는 옵션이 있지만, 2.7.12에서는 Windows에서 제대로 동작하지 않습니다. PSFzf는 fd를 `fd . --full-path <경로> --fixed-strings`로 실행합니다. `--fixed-strings` 때문에 `.`을 글자 그대로 찾고, `--full-path` 때문에 절대 경로 전체에서 찾으므로 **절대 경로에 `.`이 없는 항목은 목록에서 빠집니다.** 점이 없는 폴더에서는 `Alt+C` 목록이 비었고, 코드 저장소가 모인 폴더에서는 숨김·무시된 폴더를 빼고 비교해도 6,916개 중 1,895개만 나왔습니다. `Ctrl+T`에서도 확장자가 없는 파일과 폴더가 빠집니다. 반면 `FZF_ALT_C_COMMAND`는 PSFzf README의 "Overriding Behavior"에 문서화된 환경 변수라서, PSFzf 코드를 고치지 않는다는 이 프로파일의 원칙에도 맞습니다.
- **`Alt+C`에만 쓰고 `Ctrl+T`에는 쓰지 않습니다.** `Ctrl+T`의 기본 경로는 fzf 내장 탐색기를 써서 이미 빠릅니다. 게다가 `FZF_CTRL_T_COMMAND`를 지정하면 PSFzf는 커서 위치의 경로를 무시하고 항상 그 명령을 실행하므로, 커서 위치의 경로에서 검색을 시작하는 기능이 사라집니다.
- **`Alt+C`에는 fzf 내장 탐색기를 쓸 수 없습니다.** fzf는 표준 입력이 터미널일 때만 내장 탐색기(`--walker`)를 씁니다. PSFzf에서 fzf를 그렇게 띄우는 함수는 `Invoke-FzfDefaultSystem` 하나이고, `Ctrl+T`의 기본 경로에서만 호출됩니다. `Alt+C` 핸들러는 항상 목록 명령의 출력을 `Invoke-Fzf`로 파이프하고, `Invoke-Fzf`는 fzf의 표준 입력을 파이프로 연결하므로 내장 탐색기가 동작하지 않습니다. 내장 탐색기를 쓰려면 PSFzf의 `Alt+C` 대신 키 핸들러를 직접 만들어야 하는데, 이 프로파일은 PSFzf 기능 위에서 동작하는 것을 원칙으로 합니다. 속도 이점도 없습니다. 같은 폴더 목록을 만드는 `fzf --walker=dir,hidden`이 코드 저장소가 모인 폴더에서 0.70초, 사용자 홈에서 5.54초로, 이 프로파일의 `Alt+C`(0.47초, 4.08초)보다 느렸습니다.
- **fd는 선택 사항입니다.** 필수 설치 항목을 늘리지 않으려고 fd가 있을 때만 값을 설정합니다. fd가 없으면 PSFzf 기본(`cmd dir`)으로 동작하고, 그 경로의 문제 3은 래퍼가 이미 해결합니다.
- **기존 해결책과 함께 동작합니다.** fd는 콘솔 코드 페이지와 관계없이 항상 UTF-8로 출력합니다. PowerShell은 외부 프로그램 출력을 콘솔 출력 코드 페이지로 읽으므로, 949에서는 한글을 포함해 ASCII가 아닌 이름이 모두 깨집니다. CP949에 없는 글자만 깨지던 `cmd dir`보다 더 넓게 깨집니다. `Alt+C`는 래퍼 안에서 실행되므로 UTF-8로 읽히고, 이동은 그대로 `Set-Location -LiteralPath`(4-1)가 처리합니다. 원인은 문제 3과 다르지만 같은 래퍼로 해결되므로, fd를 써도 래퍼는 필요합니다.
  - 확인한 결과: 코드 페이지 949 콘솔에서 `報告書 [最終版]`, `한글_폴더`, `café`, `込み辻`, 숨김 폴더 `.hidden`, `.gitignore`에 적힌 `build`로 모두 이동했고, `.git`과 `node_modules`는 목록에 나오지 않았습니다. 래퍼 없이 실행하면 `한글_폴더`로 이동하지 못했습니다.

#### `cmd dir`과 다른 점과 바꾸는 방법

fd 목록에는 숨김 폴더와 `.gitignore`에 적힌 폴더가 모두 들어갑니다. `cmd dir`과 다른 점은 다음과 같습니다.

- `.git`과 `node_modules`라는 이름의 폴더는 어디에 있든 그 안의 폴더까지 뺍니다.
- `cmd dir`은 정션(`My Documents`, `Application Data` 같은 호환용 폴더 등)을 폴더로 세고, 들어갈 수 있으면 그 안의 폴더까지 다시 나열합니다. fd는 정션을 링크로 취급해 목록에서 뺍니다. 그래서 같은 폴더가 정션 경로와 실제 경로로 두 번 나오지 않는 대신, 정션 경로로는 이동할 수 없고 실제 경로를 골라야 합니다.
- `fd --help`에는 점으로 시작하는 이름만 숨김으로 적혀 있지만, Windows에서는 숨김 속성 폴더(AppData 등)도 숨김으로 취급합니다. `--hidden`을 빼면 이런 폴더와 그 아래 폴더가 모두 빠집니다.

이 규칙은 `Ctrl+T`가 쓰는 fzf 내장 탐색기에 점 폴더를 더한 것(`--walker=dir,hidden`, 기본 `--walker-skip=.git,node_modules`)과 같습니다. 두 목록을 비교하면 코드 저장소가 모인 폴더에서는 같았고, 사용자 홈에서는 휴대폰 연결(CrossDevice)이 만든 특수 폴더 아래 28개만 fd에 더 있었습니다.

다른 값을 쓰려면 `$PROFILE`에서 psfzf-profile을 불러온 **뒤**에 바꿉니다. `Get-PsFzfAltCDirectory`의 인자는 fd에 그대로 넘어가므로 묶음 방식은 그대로 유지됩니다.

```powershell
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --no-ignore'                            # .git, node_modules도 포함
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --exclude .git --exclude node_modules'  # .gitignore에 적힌 폴더도 제외
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory'                                                 # 숨김·무시된 폴더 제외
Remove-Item Env:FZF_ALT_C_COMMAND                                                                 # PSFzf 기본(cmd dir)으로
```

---

## English

A PowerShell 7 profile for using [fzf](https://github.com/junegunn/fzf) and [PSFzf](https://github.com/kelleyma49/PSFzf) without problems on Korean Windows (code page 949).
It does not modify the PSFzf module; it only uses `Set-PsFzfOption`, functions that PSFzf exports, and environment variables documented in the PSFzf README.

This repository has two branches with different approaches:

| Branch | Approach |
|---|---|
| **`main`** (this document) | Keeps console code page 949 and switches to UTF-8 only while a PSFzf action runs |
| `utf8-codepage` | Switches the pwsh console code page to UTF-8 (65001) for the whole session |

See "Alternative: the `utf8-codepage` branch" below for the differences.

### Tested environment

| Item | Version |
|---|---|
| OS | Windows 11 (system locale ko-KR, ACP/OEMCP 949) |
| PowerShell | 7.6.9 |
| PSReadLine | 2.4.5 |
| PSFzf | 2.7.12 |
| fzf | 0.75.0 |
| fd (optional) | 10.5.0 |
| Terminal | Alacritty + Zellij |

It may work with other versions, but the analysis below is based on the source code of these versions.

### Features

| Key / command | Action |
|---|---|
| `Ctrl+T` | Pick files/directories and insert them into the command line (quoted and escaped for the command) |
| `Ctrl+R` | Search command history |
| `Alt+C` | Pick a directory and change to it |
| `Alt+A` | Search arguments used in previous commands |
| `Tab` | fzf-based tab completion |
| `**<Tab>` | Argument completion for git / Get-Process / Get-Service, etc. |
| `fkill` | Pick processes and kill them |

This profile **does not change the console code page (949).** It switches to UTF-8 only while an action that uses fzf runs, and then restores it.

fzf opens in a partial window 60% high for every action. See "Note: full screen vs. partial window" below to change the size.

If fd is installed, the `Alt+C` list is built with fd. See "Note: building the `Alt+C` list with fd" below.

### Installation

```powershell
winget install junegunn.fzf
winget install sharkdp.fd                # optional: build the Alt+C list with fd
Install-Module PSFzf -Scope CurrentUser
git clone <this repository URL> <your path>\psfzf-profile
```

Add the following to your `$PROFILE`:

```powershell
$psFzfProfile = '<your path>\psfzf-profile\psfzf-profile.ps1'
if (Test-Path -LiteralPath $psFzfProfile) { . $psFzfProfile }
else { Write-Warning "psfzf-profile not found: $psFzfProfile" }
Remove-Variable psFzfProfile
```

If the fzf executable or the PSFzf module is missing, the profile prints a warning and skips the setup.

### Why it is needed: problems with the default setup

#### Background: console code page 949

Unless configured otherwise, pwsh on Korean Windows uses code page 949 for both console input and output. In the environment above, it measured 949 in conhost, Alacritty, and Alacritty + Zellij. You can check yours with:

```powershell
[Console]::InputEncoding.CodePage; [Console]::OutputEncoding.CodePage
```

The code page only applies to **paths that read or write bytes**. PowerShell strings, screen output (`WriteConsoleW`), and output from the console to the terminal are Unicode, so Japanese and other text displays correctly even with 949. The problems below happen where bytes are involved. fzf, written in Go, always expects UTF-8 bytes.

#### Problem 1. Typing Korean in `--height` mode closes fzf

- PSFzf sometimes runs fzf in a partial window (`--height=40%`; see "Note" below). In that case fzf uses its "light renderer".
- On Windows, the light renderer reads raw bytes from `CONIN$` with `ReadFile` (`setupTerminal` in `src/tui/light_windows.go`, `Read` in `src/util/util_windows.go`). These bytes arrive encoded in the **console input code page (949)**. For example, "한" arrives as `C7 D1`.
- fzf decodes these bytes as UTF-8 and **treats a decoding failure as the Esc key** (`GetChar` in `src/tui/light.go`):
  ```go
  char, rsz := utf8.DecodeRune(r.buffer)
  if char == utf8.RuneError {
      return Event{Esc, 0, nil}
  }
  ```
- Esc is bound to `abort` by default, so fzf exits as soon as Korean text is typed.
- Full-screen mode does not have this problem because its tcell renderer reads input through the Unicode console API.

#### Problem 2. Korean paths picked with `Ctrl+T` are garbled

- On the default `Ctrl+T` path (file system location, no fd), PSFzf runs fzf through `Invoke-FzfDefaultSystem`.
- This function redirects fzf's standard output without setting `StandardOutputEncoding`, so .NET decodes it with the **console output code page (949)**.
- The UTF-8 path sent by fzf is read as CP949, and garbled text is inserted into the command line.
- `Invoke-Fzf`, used by the other features, sets `StandardOutputEncoding = UTF8` and does not have this problem.

#### Problem 3. Characters outside CP949 become `?` in the `Alt+C` list

- PSFzf builds the `Alt+C` list with `cmd.exe /S /C dir /s/b/ad "."` and reads its piped output. When its output is a pipe, cmd encodes it with the **console code page (949)**.
- CP949 (based on KS X 1001) contains not only Hangul but also Japanese kana and common kanji (e.g. `日本語フォルダ`), so such names are fine. But **characters not in CP949**, such as `込`, `辻`, `们`, `é` or emoji, become `?` or are replaced with a similar character (`café` → `cafe`).
- Because the default action is `Set-Location $Location`, `?` is sometimes interpreted as a wildcard and the change succeeds by accident. Replaced characters cannot match that way, so the change fails.
- Reproduction with the default PSFzf setup in a code page 949 console:

  | Actual folder name | Name in the list | Default `Alt+C` |
  |---|---|---|
  | `日本語フォルダ_jp` | unchanged | changes directory |
  | `込み辻_x1` | `?み?_x1` | changes directory (matched by the `?` wildcard by accident) |
  | `café_x2` | `cafe_x2` | **fails** |
  | `我们_x4` | `我?_x4` | changes directory (matched by the `?` wildcard by accident) |

#### Problem 4. Paths with brackets are treated as wildcards (`Alt+C`, `Ctrl+T`)

The common cause is that **the `-Path` parameter of PowerShell cmdlets treats paths as wildcard patterns**. In a path such as `報告書 [最終版]`, `[...]` is interpreted as "one of the characters in the brackets", so the actual folder is not found. This happens regardless of encoding.

There are two standard ways around this rule:

- Pass the path with `-LiteralPath` to turn off wildcard interpretation.
- Escape wildcard characters with backticks (`` `[ ``, `` `] ``) and pass it with `-Path`.

In PSFzf, this cause shows up in two places.

##### 4-1. `Alt+C` cannot change to directories whose names contain brackets

- PSFzf's default `Alt+C` action is `Set-Location $Location`.
- Selecting the directory in fzf works, but `Set-Location` treats the path as a wildcard and the change fails.

##### 4-2. Paths inserted by `Ctrl+T` do not work with cmdlets

- PSFzf's `Ctrl+T` passes results through `FixCompletionResult`, which **only wraps them in double quotes** when they contain spaces.
- This causes the following problems:
  - Cmdlets such as `cd` and `Get-ChildItem` treat `[...]` as wildcards and cannot find paths such as `報告書 [最終版]`.
  - `$` and backticks are interpreted inside double quotes, so names containing them are changed.
- PowerShell's own tab completion does not have these problems. It uses single quotes and escapes **depending on the command**:

  | Command line | PowerShell tab completion result |
  |---|---|
  | `cd 報告書` | `` '.\報告書 `[最終版`] 2024' `` |
  | `notepad 報告書` | `'.\報告書 [最終版] 2024'` |

  It adds backticks for cmdlet arguments that accept wildcards, but not for native program arguments, because a native program would receive the backticks as literal characters.
- According to PSFzf's history, this function first wrapped results in single quotes when they contained spaces (2020), and switched to double quotes because of names containing `'` (2022, #171). No change has addressed wildcard escaping.

### How this profile solves them

| Problem | Solution |
|---|---|
| 1, 2, 3 | The `Invoke-PsFzfWithUtf8Console` wrapper switches `[Console]::InputEncoding`/`OutputEncoding` to UTF-8 **only while** a PSFzf action runs, and restores the original values (949) in `finally`. During that time fzf receives UTF-8 bytes (1), .NET decodes fzf's output as UTF-8 (2), and a child cmd started in the meantime inherits 65001 and writes the `dir` list in UTF-8 (3). |
| 4-1 | `Set-PsFzfOption -AltCCommand` replaces the location change with `Set-Location -LiteralPath $Location`. |
| 4-2 | Wraps `Ctrl+T` so that PSFzf runs inside the wrapper and then **only the newly inserted paths** are rewritten with the same rules as PowerShell tab completion. |

The actions that go through the wrapper are `Ctrl+T`, `Ctrl+R`, `Alt+C`, `Alt+A`, `Tab` and `fkill`. The keys are rebound in PSReadLine.

- The `**<Tab>` argument completers run while `Tab` is being handled, so the `Tab` wrapper protects them as well.
- PSFzf's `-EnableAliasFuzzyKillProcess` registers `fkill` as an alias, which cannot be wrapped. Instead, an `fkill` **function** runs `Invoke-FuzzyKillProcess` inside the wrapper, and the alias option is not enabled because aliases take precedence over functions.
- Problems 3 and 4-1 must be fixed together. Using `-LiteralPath` without the wrapper would also break the cases in Problem 3 that matched by accident through the `?` wildcard.

#### Why 4-1 and 4-2 are fixed differently

The cause is the same, but what the profile can control is different.

| | `Alt+C` (4-1) | `Ctrl+T` (4-2) |
|---|---|---|
| What the profile handles | **Running the command** (calls `Set-Location` directly) | **Command-line text** (the user runs it later) |
| Command that receives the path | Always `Set-Location` | Not known when the text is inserted (`cd`, `notepad`, `git`, ...) |
| Fix | `-LiteralPath` | Escaping based on the command |

- `Alt+C` knows the receiving command and runs it directly, so `-LiteralPath`, which turns off wildcard interpretation, is the most direct fix. Escaping the path and passing it with `-Path` gives the same result but has no advantage.
- `Ctrl+T` only inserts text, so it cannot add `-LiteralPath` to whatever command the user types. Native programs have no such parameter and receive backticks literally, so escaping everything is not right either. It therefore escapes based on the command type, like PowerShell tab completion.

#### `Ctrl+T` rewriting rules

`Format-PsFzfInsertedPath` and `Get-PsFzfPathEscapeMode` work as follows:

1. Compare the command line before and after `Ctrl+T` to find the inserted path tokens.
2. Use the PowerShell parser to find the command at that position, resolving aliases to the actual command, and check its type.
3. Rewrite according to the type:

| Context | Handling | Example |
|---|---|---|
| Argument of a cmdlet, function or script | Single quotes + wildcard escaping | `` cd '...\報告書 `[最終版`]\' `` (`[`→`` `[ ``, `]`→`` `] ``) |
| Argument of a native program | Single quotes only | `notepad '...\報告書 [最終版]\'` |
| Command-name position, expression (`$p = `), unknown command | Single quotes only | |
| Path without special characters | Unchanged | `cd C:\work\日本語` |

In every case, `'` in a name is doubled to `''`. `$` and backticks are not interpreted inside single quotes, which also fixes the second case of 4-2.

#### Known limitation

PSFzf's `Ctrl+T` uses `Test-Path $currentPath` to decide whether the word at the cursor is a path, which also interprets wildcards for the same reason. Based on the code, if you type a path containing brackets without escaping it and then press `Ctrl+T`, PSFzf does not recognize that path and starts searching from the current folder. This is internal PSFzf code that cannot be fixed with exported functions alone, and it only changes where the search starts, so it is left as is.

### Alternative: the `utf8-codepage` branch

The `utf8-codepage` branch fixes Problems 1, 2 and 3 by switching the pwsh console code page to 65001 for the whole session. It needs no wrapper, no rebound keys and no `fkill` function, so the profile is simpler. The fixes for 4-1 and 4-2 are the same in both branches.

| | `main` (keep 949 + wrapper) | `utf8-codepage` (65001 for the session) |
|---|---|---|
| Effect on other programs | None (changed only during PSFzf actions) | Every program run from this console inherits 65001 |
| Profile structure | Wrapper + rebound keys + `fkill` function | Two code page lines + PSFzf's default handlers |
| Native program output outside PSFzf | Based on 949 (949 column below) | Based on UTF-8 (65001 column below) |

Comparison of native program output captured by pwsh under 949 and 65001:

| Command | 949 | 65001 |
|---|---|---|
| `cmd /c echo 한글 日本語 込` | `込` → `?` | correct |
| `python -c "print('한글 込')"` | garbled | correct |
| `git log` | correct | correct |
| `ipconfig`, `ping`, `where` | Korean messages | **English messages** |

Under 65001:

- Some built-in Windows commands print English messages. The text is not garbled.
- cmd and `.bat`/`.cmd` files run from the console also inherit 65001. Batch files saved in CP949 that contain Korean may misbehave.
- Old programs that always write CP949 bytes regardless of the code page may show garbled text.

If you use batch files or old programs that expect CP949, `main` is safer. If you often work with tools that write UTF-8 (such as Python) in pwsh, `utf8-codepage` fits better.

### Note: full screen vs. partial window

Whether PSFzf shows fzf full screen or in a partial window depends on the internal function it uses.

- `Invoke-Fzf` (most features): adds `--height=40%` only when `WT_SESSION`, `ConEmuANSI` or `TERM_PROGRAM=WezTerm` is set. In Alacritty or Zellij it is **full screen**.
- `Invoke-FzfDefaultSystem` (default `Ctrl+T` path): always adds `--height=40%`, regardless of the terminal. It is a **partial window**.

PSFzf reads `$env:_PSFZF_FZF_DEFAULT_OPTS` each time it runs fzf, and both functions skip their default when it contains `--height`. This profile sets it as follows to use **a partial window 60% high everywhere**:

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=60% --layout=reverse'
```

To use a different value, set it in your `$PROFILE` **after** loading psfzf-profile:

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=40% --layout=reverse'  # partial window 40% high
$env:_PSFZF_FZF_DEFAULT_OPTS = '--no-height'                    # full screen
```

In a partial window fzf uses the light renderer, so Problem 1 applies to every action. The keys and `fkill` in this profile run inside the wrapper, so they are fine. But if you run a PSFzf function directly (e.g. `Get-ChildItem | Invoke-Fzf`), it does not go through the wrapper, and fzf exits as soon as you type Korean. Run such commands wrapped, as in `Invoke-PsFzfWithUtf8Console { Get-ChildItem | Invoke-Fzf }`, or use full screen (`--no-height`).

### Note: building the `Alt+C` list with fd

If [fd](https://github.com/sharkdp/fd) is installed, this profile builds the `Alt+C` list with fd instead of PSFzf's default (`cmd /c dir /s/b/ad`). Without fd, PSFzf's default behavior is used as is.

```powershell
function Get-PsFzfAltCDirectory {
    $batch = [System.Collections.Generic.List[string]]::new(1000)
    fd --type directory @args | ForEach-Object {
        $batch.Add($_)
        if ($batch.Count -ge 1000) { $batch -join "`n"; $batch.Clear() }
    }
    if ($batch.Count -gt 0) { $batch -join "`n" }
}
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --no-ignore --exclude .git --exclude node_modules'
```

When `FZF_ALT_C_COMMAND` is set, PSFzf builds the `Alt+C` list from that command's output. `Get-PsFzfAltCDirectory` passes its arguments to fd as is and emits fd's output in batches of 1,000 lines. With `--hidden --no-ignore`, hidden folders and folders listed in `.gitignore` all appear in the list, and `--exclude` leaves out `.git` and `node_modules`.

#### Why fd was added

Because it is faster than PSFzf's default (`cmd dir`). The times below are how long PSFzf's real `Alt+C` handler took to receive the whole list, as the median of three runs. fzf was given a `--filter` that matches nothing so that it read the whole list; drawing the screen is not included.

| Location | `cmd dir` (PSFzf default) | fd (this profile) |
|---|---|---|
| Folder holding code repositories | 26,010 folders, 2.69 s | 20,972 folders, 0.47 s |
| User home (including AppData) | 151,013 folders, 18.09 s | 133,909 folders, 4.08 s |

The fd list is shorter because it leaves out `.git`, `node_modules` and junctions (see "Differences from `cmd dir`" below).

#### Why the output is passed in batches of 1,000 lines

PSFzf pipes the output of `FZF_ALT_C_COMMAND` into `Invoke-Fzf`, which passes it to fzf. For each item it receives, `Invoke-Fzf` writes a line to fzf's input, calls `Flush()` and checks the fzf process status. When fd's output is passed one line at a time, this repeats for every folder, and for a large list it takes longer than fd itself.

| Location | fd piped straight into fzf (reference) | fd, one line at a time | fd, batches of 1,000 lines |
|---|---|---|---|
| Folder holding code repositories | 0.44 s | 1.31 s | 0.47 s |
| User home (including AppData) | 3.32 s | 9.10 s | 4.08 s |

`Invoke-Fzf` writes each string it receives as is with `WriteLine`, so a string holding many lines reaches fzf as the same list of lines. Batches of 1,000 lines cut the number of items to a thousandth, and the time becomes almost the same as piping fd straight into fzf. The output is split into batches instead of being joined into one string so that the fzf list keeps filling up before fd finishes.

What was checked:

- fzf receives the same list of folders whether the output is passed one line at a time or in batches. The lists were sorted and compared; fd searches in parallel, so only the order changes between runs.
- With batch sizes 1, 2, 3 and 1,000, `Alt+C` changed to the same folders. Lines inside a batch end with `\n` and the last line of a batch ends with `\r\n`, and fzf reads both the same way.
- When fzf exits before the list is complete (e.g. Esc), everything is cleaned up right away and no fd process is left behind.

#### Why it is implemented this way

- **`FZF_ALT_C_COMMAND` is used instead of `Set-PsFzfOption -EnableFd`.** PSFzf has an option to use fd, but in 2.7.12 it does not work correctly on Windows. PSFzf runs fd as `fd . --full-path <path> --fixed-strings`. Because of `--fixed-strings` it looks for a literal `.`, and because of `--full-path` it looks for it in the whole absolute path, so **entries whose absolute path contains no `.` are dropped from the list.** In a folder without a dot the `Alt+C` list was empty, and in the folder holding code repositories only 1,895 of 6,916 folders appeared, even with hidden and ignored folders left out of the comparison. `Ctrl+T` also drops files without an extension and folders. `FZF_ALT_C_COMMAND`, on the other hand, is an environment variable documented under "Overriding Behavior" in the PSFzf README, so it also fits this profile's rule of not modifying PSFzf code.
- **fd is used for `Alt+C` only, not for `Ctrl+T`.** The default `Ctrl+T` path uses fzf's built-in walker and is already fast. Moreover, when `FZF_CTRL_T_COMMAND` is set, PSFzf ignores the path at the cursor and always runs that command, so the feature that starts the search from the path at the cursor would be lost.
- **fzf's built-in walker cannot be used for `Alt+C`.** fzf uses its built-in walker (`--walker`) only when its standard input is a terminal. The only PSFzf function that starts fzf that way is `Invoke-FzfDefaultSystem`, and it is called only on the default `Ctrl+T` path. The `Alt+C` handler always pipes the list command's output into `Invoke-Fzf`, and `Invoke-Fzf` connects fzf's standard input to a pipe, so the walker never runs. Using the walker would mean replacing PSFzf's `Alt+C` with a key handler of our own, while this profile is meant to work on top of PSFzf's features. There would be no speed gain either: `fzf --walker=dir,hidden`, which builds the same folder list, took 0.70 s in the folder holding code repositories and 5.54 s in the user home, slower than this profile's `Alt+C` (0.47 s and 4.08 s).
- **fd is optional.** To avoid adding a required dependency, the value is set only when fd is installed. Without fd, PSFzf's default (`cmd dir`) is used, and the wrapper already fixes Problem 3 on that path.
- **It works with the existing fixes.** fd always writes UTF-8, regardless of the console code page. PowerShell reads native program output with the console output code page, so under 949 every non-ASCII name, Korean included, is garbled. That is wider than `cmd dir`, which only garbled characters outside CP949. `Alt+C` runs inside the wrapper, so the output is read as UTF-8, and the location change is still handled by `Set-Location -LiteralPath` (4-1). The cause differs from Problem 3, but the same wrapper fixes it, so the wrapper is still needed with fd.
  - Result: in a code page 949 console, `Alt+C` changed to `報告書 [最終版]`, `한글_폴더`, `café`, `込み辻`, the hidden folder `.hidden` and `build`, which is listed in `.gitignore`, while `.git` and `node_modules` did not appear in the list. Without the wrapper, it could not change to `한글_폴더`.

#### Differences from `cmd dir` and how to change them

The fd list includes hidden folders and folders listed in `.gitignore`. It differs from `cmd dir` as follows:

- Folders named `.git` or `node_modules` are left out wherever they are, together with the folders inside them.
- `cmd dir` counts junctions (compatibility folders such as `My Documents` and `Application Data`, etc.) as folders and, when it can enter them, lists the folders inside them again. fd treats junctions as links and leaves them out. As a result the same folder does not appear twice, once through the junction and once through its real path, but you cannot change to a junction path and have to pick the real path.
- `fd --help` only mentions names starting with a dot as hidden, but on Windows fd also treats folders with the hidden attribute (such as AppData) as hidden. Without `--hidden`, these folders and everything below them are left out.

These rules match fzf's built-in walker used by `Ctrl+T` with dot folders added (`--walker=dir,hidden` with the default `--walker-skip=.git,node_modules`). Comparing the two lists, they were the same in the folder holding code repositories, and in the user home fd only had 28 more folders under a special folder created by Phone Link (CrossDevice).

To use a different value, change it in your `$PROFILE` **after** loading psfzf-profile. The arguments of `Get-PsFzfAltCDirectory` go straight to fd, so the batching is kept.

```powershell
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --no-ignore'                            # also include .git and node_modules
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory --hidden --exclude .git --exclude node_modules'  # also leave out folders listed in .gitignore
$env:FZF_ALT_C_COMMAND = 'Get-PsFzfAltCDirectory'                                                 # leave out hidden and ignored folders
Remove-Item Env:FZF_ALT_C_COMMAND                                                                 # back to the PSFzf default (cmd dir)
```
