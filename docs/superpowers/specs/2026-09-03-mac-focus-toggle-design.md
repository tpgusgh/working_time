# Mac 포커스 토글 — 설계 문서

## 목적

macOS용 메뉴바 유틸리티. 한 번 클릭하면 메뉴바 시계를 숨기고 방해금지모드(Focus/DND)를 켜서, 작업 중 시간 확인하거나 알림에 정신 팔리는 걸 막음. 다시 클릭하면 둘 다 원상복구. VPN 아이콘 방식: 메뉴바 아이콘 자체가 on/off 스위치.

Windows 버전(카카오톡/디스코드 알림 차단)은 별도의 다음 단계 서브 프로젝트임 — 여기 범위 아님.

## 아키텍처

Swift Package 단일 타깃(executable, AppKit), Xcode 프로젝트 없음, Electron 없음. 앱 전체가 상태 2개짜리 메뉴바 status item임.

- `Sources/FocusToggle/main.swift` — 앱 진입점, `LSUIElement` 설정한 `NSApplication` (Dock 아이콘 없음, 창 없음).
- `Sources/FocusToggle/StatusItemController.swift` — `NSStatusItem` 소유, `isOn: Bool` 상태 추적, 상태별 아이콘 렌더링, 좌클릭은 토글로, 우클릭은 컨텍스트 메뉴로 라우팅.
- `Sources/FocusToggle/FocusActions.swift` — 상태 전환 2가지를 위해 `defaults`, `killall`, `shortcuts run` 셸 실행.

영속화 레이어 없음: 매 실행마다 상태는 `false`로 시작. 실제 OS 상태(DND가 이미 켜져 있는지 등) 읽어오지 않음 — 아이콘은 이 앱이 마지막으로 설정한 값을 반영할 뿐, 시스템 실제 상태 아님. 개인용 도구라 이 정도면 충분함. 나중에 시스템 상태와 맞춰야 할 필요 생기면 그건 그때 따로 설계할 진짜 기능이고, 지금 풀 문제 아님.

## 동작

**켜질 때** (`isOn: false → true`):
1. `defaults write com.apple.controlcenter "NSStatusItem VisibleCC Clock" -int 0 && killall ControlCenter`
2. `shortcuts run "FocusOn"`
3. 아이콘이 채워진/강조 상태로 전환.

**꺼질 때** (`isOn: true → false`):
1. `defaults write com.apple.controlcenter "NSStatusItem VisibleCC Clock" -int 1 && killall ControlCenter`
2. `shortcuts run "FocusOff"`
3. 아이콘이 윤곽선/기본 상태로 전환.

(최종 리뷰에서 수정됨: 원래 `Clock` 키는 이 머신에 존재하지 않았고, 실제 키는 `"NSStatusItem VisibleCC Clock"`이며 값 타입이 bool이 아니라 int임. 메뉴바 시계는 `SystemUIServer`가 아니라 `ControlCenter`가 그림 — Big Sur 이후 사실.)

아이콘 갱신은 클릭 핸들러에서 즉시 동기 실행하지만, 셸 명령어 실행(`FocusActionRunner.run`)은 백그라운드 큐(`DispatchQueue.global(qos: .userInitiated)`)로 분리함 — `shortcuts run`이 XPC 왕복으로 0.5~2초 걸릴 수 있어 메인 스레드를 막으면 클릭이 멈춘 것처럼 느껴짐 (최종 리뷰에서 수정됨).

## 최초 설정 (수동, 1회)

앱이 Shortcuts를 프로그램적으로 만들 수 없음. 사용자가 Shortcuts.app 열어서 `FocusOn`, `FocusOff`라는 이름으로 샷컷 2개를 직접 만들어야 함, 각각 "Set Focus" 액션 하나(On / Off)씩 포함. 우클릭 메뉴의 "설정 방법" 항목이 이 절차를 짧은 인앱 알림으로 보여주고, Shortcuts.app 열기 버튼도 제공.

## 오류 처리

`shortcuts run "FocusOn"`이 실패하면(예: 샷컷 아직 안 만들었을 때) `FocusActionRunner.run`이 각 명령어의 종료 코드를 확인해 `Bool`로 성공 여부를 반환함. 실패 시 `StatusItemController`가 메인 스레드로 돌아와 설정 안내 알림(`showSetupInstructions`)을 자동으로 띄움 — 우클릭 메뉴를 거치지 않아도 바로 확인 가능 (최종 리뷰에서 수정됨: 이전엔 macOS가 자체 오류를 띄운다고 가정했지만 실제로는 앱이 아무 피드백도 주지 않는 무음 실패였음). 재시도는 안 하고, 시계 숨김 단계 롤백도 안 함(`defaults write`엔 의미 있는 롤백이 없음 — 그냥 다시 클릭하면 됨). 개인용 자동화 트리거일 뿐, 트랜잭션 보장이 필요한 시스템 아님.

## 알려진 한계

`defaults write com.apple.controlcenter Clock -bool false`는 비공식 Control Center 설정값임. macOS 업데이트로 작동 멈출 수 있음. 별도 대응책 없음 — 깨지면 깨지는 거고, 그때 고침 (ponytail: 받아들인 한계, 지금 풀 문제 아님).

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

## 테스트

여기엔 단위 테스트 가치 있는 비즈니스 로직이 없음 — 불리언 하나로 게이트된 셸 명령어 3개뿐. 검증은 수동임: 한 번 클릭해서 시계 숨겨지고 Focus 켜지는지 확인, 다시 클릭해서 둘 다 원복되는지 확인. `demo()`/self-check 스크립트 없음 — Shortcuts 2개가 미리 만들어진 실제 macOS 세션 없이는 검증할 로직 분기가 없음.
