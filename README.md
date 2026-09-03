# FocusToggle

macOS 메뉴바 유틸리티. 아이콘 한 번 클릭하면 메뉴바 시계를 검은 오버레이로 가리고 방해금지모드(Focus/DND)를 켬. 다시 클릭하면 원복. VPN 아이콘처럼 메뉴바 아이콘 자체가 on/off 스위치.

## 기능

- **좌클릭**: 시계 가리기 + DND 켜기/끄기 토글
- **우클릭**: 설정 방법 안내, 종료
- **켤 때 종료 시간 설정(선택)**: 시:분 지정하면 그 시각에 자동으로 꺼지면서 전체화면 알림이 5초간 뜸
- 멀티 모니터 지원 (연결된 모든 화면에 오버레이)

## 요구사항

- macOS 12 (Monterey) 이상
- Shortcuts 앱에 `FocusOn`, `FocusOff`라는 이름으로 샷컷 2개 필요 (각각 "Set Focus" 액션 하나씩, On/Off). 앱 우클릭 → "설정 방법"에서 안내함
- 손쉬운 사용(Accessibility) 권한 — 시계 위치를 읽기 위함. 최초 실행 시 요청 프롬프트 뜸, 허용하면 앱이 자동 재시작됨

## 빌드 & 실행

```bash
swift build
swift run FocusToggle
```

더블클릭 가능한 `.app`으로 패키징:

```bash
./Scripts/build-app.sh
```

`FocusToggle.app`이 생성됨. 개인용 배포라 서명은 ad-hoc만 되어 있음 — 첫 실행은 Finder에서 우클릭 → 열기로 Gatekeeper 통과 필요.

## 테스트

```bash
swift test
```

순수 로직(`ToggleState`, `FocusAction`, `ClockOverlayGeometry`)만 단위 테스트함. AppKit/Accessibility/Shortcuts 실행은 실제 시스템 상태를 건드리므로 수동 검증 대상.

## 설계 문서

- [스펙](docs/superpowers/specs/2026-09-03-mac-focus-toggle-design.md)
- [구현 플랜](docs/superpowers/plans/2026-09-03-mac-focus-toggle.md)

## 알려진 한계

- 시계는 실제로 숨기는 게 아니라 검은 창으로 덮는 방식 (macOS 26 기준 시스템 API로 시계를 진짜 숨기는 방법이 없음 — Apple 자체 토글도 고장난 상태)
- 상태 영속화 없음, 재실행하면 항상 꺼진 상태로 시작
- Windows 버전은 별도 프로젝트, 아직 없음
