# psfzf-profile

[한국어](#한국어) | [English](#english)

---

## 한국어

한국어 Windows(코드 페이지 949) 환경에서 [fzf](https://github.com/junegunn/fzf)와 [PSFzf](https://github.com/kelleyma49/PSFzf)를 PowerShell 7에서 문제없이 쓰기 위한 프로파일입니다.
PSFzf 모듈 코드는 수정하지 않고, `Set-PsFzfOption`과 PSFzf가 공개한 함수만 사용합니다.

### 확인한 환경

| 항목 | 버전 |
|---|---|
| OS | Windows 11 (시스템 로캘 ko-KR, ACP/OEMCP 949) |
| PowerShell | 7.6.9 |
| PSReadLine | 2.4.5 |
| PSFzf | 2.7.12 |
| fzf | 0.75.0 |
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

또한 이 프로파일은 **pwsh 콘솔의 입출력 코드 페이지를 UTF-8(65001)로 바꿉니다.** 영향은 아래 "주의할 점"을 참고하세요.

### 설치

```powershell
winget install junegunn.fzf
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

fzf 실행 파일이나 PSFzf 모듈이 없으면 경고만 출력하고 PSFzf 설정을 건너뜁니다. 코드 페이지 설정은 그와 관계없이 적용됩니다.

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
| 1, 2, 3 | pwsh 콘솔의 `[Console]::InputEncoding`/`OutputEncoding`을 **UTF-8(65001)로 고정**합니다. fzf가 UTF-8 바이트를 받고(1), .NET이 fzf 출력을 UTF-8로 디코딩하고(2), 자식 cmd도 65001을 이어받아 `dir` 목록을 UTF-8로 내보냅니다(3). |
| 4-1 | `Set-PsFzfOption -AltCCommand`로 이동 명령을 `Set-Location -LiteralPath $Location`으로 바꿉니다. |
| 4-2 | `Ctrl+T`를 감싸서, PSFzf가 경로를 넣은 뒤 **새로 들어간 경로만** PowerShell 탭 완성과 같은 규칙으로 다시 씁니다. |

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

### 주의할 점: 콘솔 코드 페이지 65001의 영향

코드 페이지 설정은 이 pwsh 콘솔과 그 안에서 실행하는 자식 프로그램에 적용됩니다. 시스템 전체 설정("Beta: 세계 언어 지원을 위해 Unicode UTF-8 사용")은 바꾸지 않습니다.

949와 65001에서 외부 프로그램 출력을 pwsh로 받아 비교한 결과입니다.

| 명령 | 949 | 65001 |
|---|---|---|
| `cmd /c echo 한글 日本語 込` | `込` → `?` | 정상 |
| `python -c "print('한글 込')"` | 깨짐 | 정상 |
| `git log` | 정상 | 정상 |
| `ipconfig`, `ping`, `where` | 한국어 메시지 | **영어 메시지** |

- Windows 기본 명령 일부는 65001에서 메시지를 영어로 출력합니다. 글자가 깨지는 것은 아닙니다.
- 이 콘솔에서 실행한 cmd와 `.bat`/`.cmd` 파일도 65001을 이어받습니다. CP949로 저장된 배치 파일에 한글이 있으면 오동작할 수 있습니다.
- 코드 페이지와 관계없이 CP949 바이트를 출력하는 오래된 프로그램은 글자가 깨질 수 있습니다.

이런 프로그램을 자주 쓴다면, PSFzf 동작이 실행되는 동안에만 UTF-8로 바꾸는 방식도 가능합니다. 이 저장소의 이전 커밋(`043dbe2`, `07afb00`)에 그 구현이 있습니다.

### 참고: 전체 화면과 부분 화면

PSFzf가 fzf를 어떤 크기로 띄울지는 사용하는 내부 함수에 따라 다릅니다.

- `Invoke-Fzf`(대부분의 기능): `WT_SESSION`, `ConEmuANSI`, `TERM_PROGRAM=WezTerm` 중 하나가 있을 때만 `--height=40%`를 붙입니다. Alacritty나 Zellij에서는 **전체 화면**입니다.
- `Invoke-FzfDefaultSystem`(`Ctrl+T` 기본 경로): 터미널과 관계없이 항상 `--height=40%`를 붙입니다. **부분 화면**입니다.

통일하려면 `$PROFILE`에서 `$env:_PSFZF_FZF_DEFAULT_OPTS`를 설정합니다. PSFzf는 fzf를 띄울 때마다 이 값을 읽고, 두 함수 모두 이 값에 `--height`가 있으면 기본값을 붙이지 않습니다.

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=40% --layout=reverse'  # 부분 화면으로 통일
$env:_PSFZF_FZF_DEFAULT_OPTS = '--no-height'                    # 전체 화면으로 통일
```

---

## English

A PowerShell 7 profile for using [fzf](https://github.com/junegunn/fzf) and [PSFzf](https://github.com/kelleyma49/PSFzf) without problems on Korean Windows (code page 949).
It does not modify the PSFzf module; it only uses `Set-PsFzfOption` and functions that PSFzf exports.

### Tested environment

| Item | Version |
|---|---|
| OS | Windows 11 (system locale ko-KR, ACP/OEMCP 949) |
| PowerShell | 7.6.9 |
| PSReadLine | 2.4.5 |
| PSFzf | 2.7.12 |
| fzf | 0.75.0 |
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

This profile also **switches the pwsh console input/output code page to UTF-8 (65001).** See "Caveats" below for the effects.

### Installation

```powershell
winget install junegunn.fzf
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

If the fzf executable or the PSFzf module is missing, the profile prints a warning and skips the PSFzf setup. The code page setting is applied either way.

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
| 1, 2, 3 | **Sets the pwsh console's `[Console]::InputEncoding`/`OutputEncoding` to UTF-8 (65001).** fzf receives UTF-8 bytes (1), .NET decodes fzf's output as UTF-8 (2), and the child cmd inherits 65001 and writes the `dir` list in UTF-8 (3). |
| 4-1 | `Set-PsFzfOption -AltCCommand` replaces the location change with `Set-Location -LiteralPath $Location`. |
| 4-2 | Wraps `Ctrl+T` so that, after PSFzf inserts the paths, **only the newly inserted paths** are rewritten with the same rules as PowerShell tab completion. |

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

### Caveats: effects of console code page 65001

The code page setting applies to this pwsh console and the child programs run in it. It does not change the system-wide setting ("Beta: Use Unicode UTF-8 for worldwide language support").

Comparison of native program output captured by pwsh under 949 and 65001:

| Command | 949 | 65001 |
|---|---|---|
| `cmd /c echo 한글 日本語 込` | `込` → `?` | correct |
| `python -c "print('한글 込')"` | garbled | correct |
| `git log` | correct | correct |
| `ipconfig`, `ping`, `where` | Korean messages | **English messages** |

- Some built-in Windows commands print English messages under 65001. The text is not garbled.
- cmd and `.bat`/`.cmd` files run from this console also inherit 65001. Batch files saved in CP949 that contain Korean may misbehave.
- Old programs that always write CP949 bytes regardless of the code page may show garbled text.

If you use such programs often, you can switch to UTF-8 only while a PSFzf action runs instead. Earlier commits in this repository (`043dbe2`, `07afb00`) contain that implementation.

### Note: full screen vs. partial window

Whether PSFzf shows fzf full screen or in a partial window depends on the internal function it uses.

- `Invoke-Fzf` (most features): adds `--height=40%` only when `WT_SESSION`, `ConEmuANSI` or `TERM_PROGRAM=WezTerm` is set. In Alacritty or Zellij it is **full screen**.
- `Invoke-FzfDefaultSystem` (default `Ctrl+T` path): always adds `--height=40%`, regardless of the terminal. It is a **partial window**.

To make them consistent, set `$env:_PSFZF_FZF_DEFAULT_OPTS` in your `$PROFILE`. PSFzf reads this value each time it runs fzf, and both functions skip their default when it contains `--height`.

```powershell
$env:_PSFZF_FZF_DEFAULT_OPTS = '--height=40% --layout=reverse'  # partial window everywhere
$env:_PSFZF_FZF_DEFAULT_OPTS = '--no-height'                    # full screen everywhere
```
