# SeaLegs

언어: [English](README.md) | [한국어](README.ko.md)

<p align="center">
  <img src="SeaLegs/SeaLegs/Assets.xcassets/AppIcon.appiconset/sealegs-256256@1x.png" width="128" alt="SeaLegs app icon">
</p>

<p align="center">
  <a href="https://ko-fi.com/dawncr0w">Ko-fi로 후원하기</a>
</p>

SeaLegs는 macOS 3D 게임 위에 시각적 편안함을 위한 투명 오버레이를 띄우는 메뉴바 앱입니다. 가장자리 비네트, 중앙 점, 간단한 조준선, 수평선 가이드, 대시보드 프레임, 가상 코, 주변부 프레임을 표시해 빠르게 움직이는 3D 화면에서 시각적 기준점을 제공합니다.

선택적으로 화면 기록 권한을 사용하는 적응형 모드도 제공합니다. 적응형 모드는 낮은 해상도의 화면 움직임을 Mac 안에서만 분석하고, 숫자 움직임 지표로 변환한 뒤 오버레이 강도를 자동 조절합니다. SeaLegs는 스크린샷, 영상, 오디오, OCR 결과, 입력 텍스트, 키 문자열, 원본 마우스 경로를 저장하지 않습니다.

SeaLegs는 의료기기가 아닙니다. 멀미를 진단, 치료, 예방하지 않습니다. 심한 어지러움, 구토, 두통, 시야 이상, 기타 불편감이 있으면 즉시 플레이를 중단하고 휴식하세요.

## 중요 안내

SeaLegs는 오버레이 유틸리티입니다. 안티치트 우회 도구, 치트 도구, 게임 자동화 도구, 메모리 패치 도구, 인젝터, 게임 플레이 변경 도구가 아닙니다.

온라인 게임, 경쟁 게임, 안티치트가 적용된 게임에서 SeaLegs를 사용할 때는 본인이 위험을 판단해야 합니다. 일부 게임은 오버레이, 화면 캡처, 접근성 보조 기능, 서명되지 않았거나 공증되지 않은 앱을 제한할 수 있습니다. SeaLegs 유지보수자는 이 프로그램 사용으로 인한 계정 제한, 매칭 제한, 밴, 데이터 손실, 게임 플레이 문제, 기타 결과에 책임지지 않습니다.

SeaLegs를 안티치트 우회, 게임 메모리 변경, 게임 플레이 자동화, 부당한 이점 획득, 게임 약관 위반 목적으로 사용하지 마세요.

## 지원 환경

- 지원: Apple Silicon Mac, macOS 14 이상
- 권장: 창 모드 또는 테두리 없는 창 모드 게임
- 제한: 일부 네이티브 전체화면 게임은 macOS Spaces 동작 때문에 오버레이가 보이지 않을 수 있음
- 미지원: Windows, Linux, VR, 안티치트 우회, 게임 메모리 패치, 게임 플레이 자동화

## SeaLegs 설치

다운로드용 DMG는 Hardened Runtime을 사용해 ad-hoc 서명되어 있지만, Apple
Developer ID로 서명되지 않았고 Apple 공증도 받지 않았습니다. 따라서 처음 실행할 때
Gatekeeper가 확인되지 않은 개발자 경고를 표시합니다.

1. [GitHub Releases](https://github.com/DAWNCR0W/SeaLegs/releases)에서
   `SeaLegs-0.1.0-arm64.dmg`와 `SHA256SUMS.txt`를 다운로드합니다.
2. 터미널에서 다운로드 폴더로 이동해 파일을 검증합니다.

   ```bash
   shasum -a 256 -c SHA256SUMS.txt
   ```

3. DMG를 열고 `SeaLegs.app`을 `Applications` 폴더로 드래그합니다.
4. SeaLegs 실행을 한 번 시도합니다. 첫 실행이 차단되는 것은 예상된
   동작입니다.
5. System Settings > Privacy & Security의 Security 영역에서 SeaLegs의
   `Open Anyway`를 누르고 Mac 암호 또는 Touch ID로 확인합니다.
6. SeaLegs를 다시 열고, 적응형 모드나 선택적 입력 신호를 사용하려면
   앱 안내에 따라 권한을 허용합니다.

Gatekeeper를 전역으로 비활성화하지 마세요. `Open Anyway` 예외는 현재
SeaLegs 앱에만 적용됩니다. ad-hoc 서명은 개별 빌드를 식별하므로
업데이트 후 SeaLegs를 다시 허용해야 할 수 있습니다. 화면 기록 권한
(일부 macOS 버전에서는 Screen & System Audio Recording) 또는 입력
모니터링 권한이 풀렸다면 다시 켠 뒤 앱을 재실행하고 `Refresh`를
누르세요.

## SeaLegs가 하는 일

SeaLegs는 화면 움직임이 빠르거나 카메라 효과가 강한 게임에 안정적인 시각 기준점을 더합니다.

주요 기능:

- 메뉴바에서 설정과 오버레이 기능을 빠르게 실행
- 기본적으로 게임이 실행 중인 화면에만 표시되고 필요하면 모든 화면에 표시할 수 있는 투명 클릭 통과 오버레이. 게임 창을 다른 화면으로 옮기면 표시 대상도 자동으로 따라감
- 주변부 움직임 부담을 줄이는 부드러운 가장자리 비네트
- 안정적인 기준점을 위한 중앙 점과 간단한 조준선
- 운전, 비행, 큰 카메라 회전에 유용한 수평선 가이드
- 조종석처럼 기준을 잡아주는 대시보드 프레임과 가상 코
- 화면 경계를 은은하게 보여주는 주변부 프레임
- 수동 강도 모드: 끔, 낮음, 중간, 높음
- 로컬 움직임 분석으로 강도를 조절하는 선택적 적응형 모드
- 게임 종류별 프로필과 기본값
- 모든 시각 보조 요소를 12초 동안 고대비로 보여주는 기능 데모
- 오버레이 전환, 강도 조절, 응급 모드, 불편감 점수, 디버그 HUD 단축키
- 로컬 숫자 세션 로그와 리포트
- 게임 설정 체크리스트
- 캘리브레이션과 진단 내보내기

## 동작 방식

SeaLegs는 크게 두 가지 방식으로 동작합니다.

### 수동 오버레이

수동 모드는 화면 기록 권한이 필요 없습니다.

1. SeaLegs가 게임 위에 투명한 macOS 오버레이 창을 만듭니다.
2. 오버레이는 마우스와 키보드 입력을 무시하므로 클릭은 계속 게임으로 전달됩니다.
3. 메뉴바 또는 설정에서 낮음, 중간, 높음 강도를 선택합니다.
4. SeaLegs가 Metal로 비네트와 시각 기준점을 그립니다.

### 적응형 오버레이

적응형 모드는 화면 기록 권한이 필요합니다.

1. SeaLegs가 활성 게임 화면을 낮은 해상도로 캡처합니다.
2. 프레임은 메모리 안에서 분석용으로 축소됩니다.
3. 주변부 움직임, 수평/수직 움직임, 줌처럼 커지는 움직임, 회전처럼 보이는 움직임, 반복되는 움직임 패턴을 계산합니다.
4. 움직임 점수를 시간에 따라 부드럽게 만듭니다.
5. 화면 움직임 위험이 커지면 오버레이를 강하게, 안정적이면 부드럽게 조절합니다.
6. 원본 프레임은 분석 후 버려집니다.

적응형 모드는 편안함 조절을 위한 기능이며, 게임 분석, 치트, 자동화를 위한 기능이 아닙니다.

## 빠른 시작

1. SeaLegs를 빌드하거나 설치합니다.
2. 앱을 실행합니다.
3. macOS 메뉴바의 SeaLegs 아이콘을 클릭합니다.
4. `Show Feature Demo`를 눌러 오버레이가 보이는지 확인합니다.
5. Settings > Overlay에서 모드를 선택합니다.
6. 자동 강도 조절을 원하면 Settings > Adaptive에서 화면 기록 권한을 허용합니다.
7. 자동 게임 매칭을 원하면 메뉴바에서 현재 게임을 프로필로 추가합니다.
8. 여러 화면을 사용한다면 Settings > General에서 `Active Game Display` 또는 `All Displays`를 선택합니다.

이미 저장된 프로필이 너무 은은하면 Settings > Overlay에서 `Apply Recommended Visual Aids`를 사용하세요.

## 개인정보

화면 기록 권한은 적응형 모드에서만 필요합니다. 기본 오버레이와 수동 모드는 화면 기록 권한 없이 동작합니다.

입력 모니터링 권한은 선택 사항이며 기본값은 꺼짐입니다. 사용자가 켠 경우에만 회전 신호 보조값으로 사용합니다. 사용 여부는 저장되며, 권한을 허용하고 앱을 다시 실행하면 입력 신호가 자동으로 시작됩니다.

SeaLegs는 다음 데이터를 저장하지 않습니다.

- 스크린샷
- 영상
- 오디오
- OCR 결과
- 입력 텍스트
- 키 문자열
- 원본 마우스 경로
- 원본 캡처 프레임

로컬 파일:

- `~/Library/Application Support/SeaLegs/profiles.json`: 게임 프로필과 오버레이 설정
- `~/Library/Application Support/SeaLegs/settings.json`: 언어, 텔레메트리, 개인정보 설정
- `~/Library/Application Support/SeaLegs/Sessions/*.jsonl`: 숫자 움직임 샘플, 프로필 식별자, 권한 상태, 선택적 불편감 점수, 응급 모드 이벤트

세션 로그는 기본 14일 보관이며 Settings > Privacy에서 끄거나 삭제할 수 있습니다.

진단 내보내기는 숫자 상태와 솔트 해시만 포함합니다. 스크린샷, 영상, OCR 결과, 입력 텍스트, 원본 앱 식별자, 전체 실행 파일 경로는 포함하지 않아야 합니다.

## 기본 단축키

- 오버레이 전환: `Option + Command + F10`
- 강도 증가: `Option + Command + F11`
- 강도 감소: `Option + Command + F9`
- 응급 편안함: `Option + Command + F12`
- 불편감 점수 기록: `Control + Option + Command + S`
- 디버그 HUD: `Control + Option + Command + D`

모든 핵심 기능은 메뉴바에서도 사용할 수 있습니다.

## 빌드

```bash
cd SeaLegs
ruby Scripts/generate_xcodeproj.rb
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
```

0.x 릴리즈와 동일한 Apple Silicon ad-hoc 서명 DMG는 깨끗한 Git
worktree에서 다음과 같이 생성합니다.

```bash
cd SeaLegs
./Scripts/build_dmg.sh
```

기본 산출물은 `dist/v0.1.0/`에 생성됩니다. 스크립트는 최종 파일을
만들기 전에 앱 버전, 빌드 번호, 아키텍처, Hardened Runtime 서명, DMG
내용과 SHA-256 체크섬을 검증합니다.

로컬 권한 상태를 더 안정적으로 테스트하려면 Apple 개발팀을 지정해 프로젝트를 생성하세요.

```bash
cd SeaLegs
SEALEGS_DEVELOPMENT_TEAM="<TEAM_ID>" ruby Scripts/generate_xcodeproj.rb
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
```

## 테스트

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' test
```

## 로컬 실행

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/SeaLegs-*/Build/Products/Debug/SeaLegs.app
```

실행 후 메뉴바의 SeaLegs 아이콘에서 Settings를 열 수 있습니다. 처음에는 `Show Feature Demo`를 눌러 중앙 점, 조준선, 수평선 가이드, 대시보드 프레임, 가상 코, 주변부 프레임이 잘 보이는지 확인하세요.

## 화면 기록 권한 문제 해결

적응형 모드가 동작하지 않거나 화면 기록 권한이 계속 `Not Granted`로 보이면:

1. SeaLegs Settings > Adaptive에서 `Request Access`를 누릅니다.
2. System Settings > Privacy & Security > Screen Recording에서 SeaLegs를 켭니다.
3. macOS가 요구하면 SeaLegs를 종료하고 다시 실행합니다.
4. Settings > Adaptive로 돌아와 `Refresh`를 누릅니다.

활성 캡처가 중단되면 SeaLegs는 기본 오버레이로 전환한 뒤 제한된 횟수만큼 자동으로 다시 시도합니다. Mac이 잠자기에서 깨어날 때도 활성 게임을 다시 확인하고 적용 가능한 경우 적응형 모드를 다시 시작합니다.

명시적인 ScreenCaptureKit 오류 없이 프레임 수신만 멈춰도 상태가 자동으로 `샘플 대기 중`으로 바뀝니다. 오버레이를 숨기면 적응형 캡처도 멈추며, 숨긴 상태에서 프로필 설정을 바꿔도 캡처가 임의로 다시 시작되지 않습니다.

개발 중 권한 상태가 꼬이면 아래 명령으로 초기화할 수 있습니다.

```bash
tccutil reset ScreenCapture com.dawncrow.SeaLegs
```

그 뒤 SeaLegs를 다시 열고 권한을 다시 요청하세요.

## 릴리즈와 공증

SeaLegs 0.x 다운로드는 Developer ID 서명과 Apple 공증 없이 배포합니다. 모든
릴리즈에는 위의 수동 Gatekeeper 설치 안내, SHA-256 체크섬과 빌드
매니페스트를 제공합니다. 정식 1.0 릴리즈는 Developer ID로 서명하고 Apple
공증을 받은 뒤 안정 버전으로 배포할 예정입니다.

릴리즈 절차는 [RELEASE.md](RELEASE.md)를 참고하세요.

## 오픈소스

SeaLegs는 MIT 라이선스로 공개할 수 있도록 준비되어 있습니다.

- 라이선스: [LICENSE](LICENSE)
- 기여 가이드: [CONTRIBUTING.md](CONTRIBUTING.md)
- 보안 정책: [SECURITY.md](SECURITY.md)
- 지원 정책: [SUPPORT.md](SUPPORT.md)
- 행동 강령: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 변경 기록: [CHANGELOG.md](CHANGELOG.md)
- 로드맵: [ROADMAP.md](ROADMAP.md)
- 아키텍처: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 개인정보 설계: [docs/PRIVACY.md](docs/PRIVACY.md)
- 개발 가이드: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)

## 아이콘 자산

- 앱 아이콘: `SeaLegs/SeaLegs/Assets.xcassets/AppIcon.appiconset`
- 메뉴바 아이콘: `SeaLegs/SeaLegs/Assets.xcassets/MenuBarIcon.imageset`
- Accent color: `SeaLegs/SeaLegs/Assets.xcassets/AccentColor.colorset`
- 생성 스크립트: `SeaLegs/Scripts/generate_app_icon.py`

아이콘을 다시 생성하려면:

```bash
cd SeaLegs
python3 Scripts/generate_app_icon.py
ruby Scripts/generate_xcodeproj.rb
```
