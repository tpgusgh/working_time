# Mac 포커스 토글 — 설계 문서

## 목적

macOS용 메뉴바 유틸리티. 한 번 클릭하면 메뉴바 시계를 숨기고 방해금지모드(Focus/DND)를 켜서, 작업 중 시간 확인하거나 알림에 정신 팔리는 걸 막음. 다시 클릭하면 둘 다 원상복구. VPN 아이콘 방식: 메뉴바 아이콘 자체가 on/off 스위치.

Windows 버전(카카오톡/디스코드 알림 차단)은 별도의 다음 단계 서브 프로젝트임 — 여기 범위 아님.

## 아키텍처

Swift Package 단일 타깃(executable, AppKit), Xcode 프로젝트 없음, Electron 없음. 앱 전체가 상태 2개짜리 메뉴바 status item임.

- `Sources/FocusToggle/main.swift` — 앱 진입점, `LSUIElement` 설정한 `NSApplication` (Dock 아이콘 없음, 창 없음).
- `Sources/FocusToggle/StatusItemController.swift` — `NSStatusItem` 소유, `isOn: Bool` 상태 추적, 상태별 아이콘 렌더링, 좌클릭은 토글로, 우클릭은 컨텍스트 메뉴로 라우팅. 토글 시 `ClockOverlayController`와 `FocusActionRunner` 둘 다 구동.
- `Sources/FocusToggle/FocusActions.swift` — DND 켜고 끄는 `shortcuts run` 셸 실행만 담당 (시계는 더 이상 셸 명령어로 안 건드림 — 아래 참고).
- `Sources/FocusToggle/ClockOverlayController.swift` — 시계를 실제로 안 건드리고, 그 위에 검은 오버레이 창을 띄워 시각적으로 가리는 방식.

### 시계 숨기기: 방식이 통째로 바뀜 (스파이크로 검증)

원래 계획(`defaults write` + `killall`)은 이 머신의 macOS 26 (Tahoe)에서 실제로 작동 안 함 — Apple 자체 공식 토글도 고장난, 알려진 OS 회귀 버그임 (Apple Community, righttotimelessness.com 등에서 확인). `ControlCenter` 프로세스가 재시작되자마자 값을 도로 덮어씀. 서드파티 메뉴바 관리 도구(Ice 등, macOS 26 전용으로 새로 만든 것 포함)도 시스템 시계는 못 건드림 — 시계가 일반 앱이 만드는 `NSStatusItem`이 아니라 `ControlCenter`가 직접 그리는 항목이라 화면 캡처+오버레이 트릭도 안 먹힘.

실제로 작동하는 방식(라이브 스파이크로 검증됨): 시계를 안 건드리고, 그 위에 시각적으로 덮어씌우는 테두리 없는 검은 `NSWindow`를 띄움.
1. Accessibility API(`AXUIElement`, 손쉬운 사용 권한 필요)로 `ControlCenter` 프로세스의 메뉴바 아이템 중 `AXIdentifier == "com.apple.menuextra.clock"`인 항목을 찾아 위치(`position`)와 크기(`size`)를 읽음. 이 식별자는 로케일 안 타서 안정적임(한국어 macOS에서 "시계"로 보여도 identifier는 동일).
2. 그 프레임 위에, 창 레벨을 `CGShieldingWindowLevel()`(메뉴바보다 위, 화면 잠금 오버레이가 쓰는 것과 같은 레벨)로 설정한 검은 배경 `borderless` 창을 `orderFrontRegardless()`로 띄움. `ignoresMouseEvents = true`라 클릭은 그대로 밑으로 통과.
3. **멀티 모니터**: macOS는 화면마다 별도 메뉴바를 그리는데(디스플레이별 분리된 Spaces가 기본값), AX로는 주 화면(primary screen) 시계 위치만 잡힘. 다른 화면들은 "오른쪽 끝에서부터의 거리"가 동일하다고 가정하고 그 오프셋을 옮겨서 각 화면(`NSScreen.screens` 전체 순회)에 오버레이를 하나씩 띄움. 라이브로 2개 모니터에서 테스트해서 확인함 — 단, 해상도/스케일 차이가 크면 시계 텍스트 폭이 화면마다 살짝 달라질 수 있어 오버레이가 딱 맞지 않을 수 있음 (아래 "알려진 한계" 참고).

영속화 레이어 없음: 매 실행마다 상태는 `false`로 시작. 실제 OS 상태(DND가 이미 켜져 있는지 등) 읽어오지 않음 — 아이콘은 이 앱이 마지막으로 설정한 값을 반영할 뿐, 시스템 실제 상태 아님. 개인용 도구라 이 정도면 충분함. 나중에 시스템 상태와 맞춰야 할 필요 생기면 그건 그때 따로 설계할 진짜 기능이고, 지금 풀 문제 아님.

## 동작

**켜질 때** (`isOn: false → true`):
1. `ClockOverlayController.show()` — 연결된 모든 화면에 검은 오버레이 창을 즉시 띄움 (메인 스레드, 순수 UI 작업이라 빠름).
2. `shortcuts run "FocusOn"` (백그라운드 큐).
3. 아이콘이 채워진/강조 상태로 전환.

**꺼질 때** (`isOn: true → false`):
1. `ClockOverlayController.hide()` — 오버레이 창들 닫음.
2. `shortcuts run "FocusOff"` (백그라운드 큐).
3. 아이콘이 윤곽선/기본 상태로 전환.

(수정 이력: 처음엔 `defaults write com.apple.controlcenter Clock` 트릭을 계획했으나 이 머신엔 그 키가 없었고, 고친 `"NSStatusItem VisibleCC Clock"` 키도 macOS 26에서 `ControlCenter`가 즉시 덮어써서 결국 안 먹힌다는 걸 라이브 테스트로 확인함. 오버레이 창 방식으로 완전히 교체함 — 위 "시계 숨기기" 섹션 참고.)

아이콘 갱신, 오버레이 show/hide는 메인 스레드에서 즉시 동기 실행. `shortcuts run` 셸 명령어만 백그라운드 큐(`DispatchQueue.global(qos: .userInitiated)`)로 분리함 — XPC 왕복으로 0.5~2초 걸릴 수 있어 메인 스레드를 막으면 클릭이 멈춘 것처럼 느껴짐.

## 최초 설정 (수동, 1회)

**Shortcuts**: 앱이 Shortcuts를 프로그램적으로 만들 수 없음. 사용자가 Shortcuts.app 열어서 `FocusOn`, `FocusOff`라는 이름으로 샷컷 2개를 직접 만들어야 함, 각각 "Set Focus" 액션 하나(On / Off)씩 포함. 우클릭 메뉴의 "설정 방법" 항목이 이 절차를 짧은 인앱 알림으로 보여주고, Shortcuts.app 열기 버튼도 제공.

**손쉬운 사용(Accessibility) 권한**: `ClockOverlayController`가 AX API로 시계 위치를 읽으려면 앱이 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 허용돼야 함. 최초 실행 시 `AXIsProcessTrustedWithOptions`로 권한 요청 프롬프트가 뜸(표준 TCC 플로우). 권한 없이 첫 클릭하면 시계 위치를 못 읽어 오버레이가 안 뜨는데, 이 경우도 조용히 실패하지 않고 시스템 설정 앱을 열어주는 안내를 띄움 (아래 "오류 처리" 참고).

## 오류 처리

**Shortcuts 실패**: `shortcuts run "FocusOn"`이 실패하면(예: 샷컷 아직 안 만들었을 때) `FocusActionRunner.run`이 각 명령어의 종료 코드를 확인해 `Bool`로 성공 여부를 반환함. 실패 시 `StatusItemController`가 메인 스레드로 돌아와 설정 안내 알림(`showSetupInstructions`)을 자동으로 띄움 — 우클릭 메뉴를 거치지 않아도 바로 확인 가능. 재시도는 안 함. 개인용 자동화 트리거일 뿐, 트랜잭션 보장이 필요한 시스템 아님.

**Accessibility 권한 없음**: `ClockOverlayController`가 `com.apple.menuextra.clock` AX 항목을 못 찾으면(권한 없음, 또는 어떤 이유로든 그 항목이 없을 때) 조용히 넘어가지 않고 시스템 설정의 손쉬운 사용 패널을 열어주는 안내 알림을 띄움. 이 경우 DND(Shortcuts) 쪽은 정상 진행 — 시계 오버레이만 못 뜨는 거고 나머지 기능은 안 죽음.

## 알려진 한계

- **시계 숨김 = 실제로 숨기는 게 아니라 덮어씌우는 것.** 오버레이가 시계 프레임과 정확히 안 맞으면(화면 회전, 디스플레이 배치 변경, macOS가 메뉴바 아이템 순서/폭을 바꾸는 업데이트 등) 시계 일부가 삐져나올 수 있음. `overlayPadding` 상수로 여유값 조절 가능 (ponytail: 계산해서 맞추는 대신 여유값 넣는 방식 — 필요하면 값 키우면 됨).
- **멀티 모니터 오프셋은 근사치.** 화면마다 시계 위치를 직접 재는 게 아니라 "주 화면 기준 오른쪽 끝에서부터의 거리가 같다"고 가정하고 계산함. 화면 간 해상도/스케일 차이가 크면 시계 텍스트 렌더 폭이 달라져서 오버레이가 살짝 안 맞을 수 있음 — 라이브 테스트에서 확인된 현상, `overlayPadding`으로 흡수.
- **`com.apple.menuextra.clock` AX identifier가 macOS 업데이트로 바뀔 가능성.** 지금은 안정적으로 확인됐지만 비공식 세부사항이라 나중에 깨질 수 있음. 별도 대응책 없음 — 깨지면 그때 고침.

## 배포

개인용, 서명 없음:
- `swift build -c release`로 바이너리 생성.
- 짧은 셸 스크립트가 이를 `FocusToggle.app`으로 감쌈 (`LSUIElement = true` 넣은 Info.plist, 바이너리 복사) — 더블클릭 실행 / 로그인 항목 추가 가능하게.
- 첫 실행은 Gatekeeper 통과 위해 우클릭 → 열기 1회 필요.

## 명시적으로 범위 아님

- 실제 시스템 DND/시계 상태 읽기.
- 재실행 간 상태 영속화.
- 로그인 시 자동 실행 (사용자가 시스템 설정에서 직접 추가 가능).
- 전역 키보드 단축키.
- Windows 쪽 작업 전부.
- 켜져 있는 동안 디스플레이 배치/해상도가 바뀌는 경우 오버레이 위치 실시간 재계산 (다시 껐다 켜면 새 위치로 다시 뜸 — 그걸로 충분).

## 테스트

`ToggleState`, `FocusAction`은 기존대로 순수 로직이라 단위 테스트함. 오버레이 위치 계산도 `ClockOverlayController`에서 AppKit 창 생성 로직과 분리한 순수 함수(`ClockOverlayGeometry.overlayFrame(forScreen:primaryScreenFrame:clockFrame:padding:)`)로 빼서 단위 테스트함 — AX/AppKit 없이 좌표 변환 수식만 검증. 실제 창 띄우기, AX 권한, Shortcuts 실행은 여전히 수동 검증임: 클릭해서 오버레이 뜨는지, Focus 켜지는지 확인, 다시 클릭해서 원복되는지 확인.
