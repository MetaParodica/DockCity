# Dock City

> A living miniature city following your existing macOS Dock.

개발 인수인계는 [온보딩](docs/onboarding.md), 다음 기능 후보는 [창 장식 오픈소스 조사](docs/window-effects-research.md)를 참고하세요.

Dock City는 **실제 macOS Dock을 추적하는 도시 장식 앱**입니다.
자체 Dock 생성, 별도 아이콘, 앱 실행·재정렬·폴더 스택, Spaces 고정 기능은 제거했습니다.
앱 실행과 클릭·드래그·우클릭은 기존 macOS Dock이 처리합니다.

**창과 Dock 적설**을 추가했습니다. 일반 창 상단과 실제 Dock의 윗면에 눈이 쌓이고,
창을 빠르게 이동하거나 크기를 바꾸면 눈이 떨어집니다. 도시와 독립적으로 설정할 수 있습니다.
방향 화살표를 드래그해 강설의 360도 방향과 속도를 설정할 수 있습니다.
하단 Dock은 위쪽 테두리, 좌·우 Dock은 상단 모서리에 쌓입니다.
[눈 기능과 검증 절차](docs/snow-validation.md)를 참고하세요. macOS 실행은 아직 미검증입니다.

## 동작

- 접근성 API의 실제 항목 좌표·역할·앱 URL을 읽고 도시 건물을 정렬합니다.
- 하단·좌측·우측 Dock, 아이콘 크기·확대·순서 변화와 화면 이동을 추적합니다.
- 도시 패널은 Dock의 화면 안쪽에 배치되며 포커스와 마우스 입력을 받지 않습니다.
- 실제 앱 URL과 실행 상태를 연결해 11개 스킨, 조명, 시민·차량, 시계와 주야간을 표시합니다.
- Dock이 숨겨지거나 좌표가 불완전하거나 오래되면 도시를 숨깁니다. 절전·화면 잠자기 및 권한 철회도 처리합니다.
- Dock 재시작 시 새 PID를 찾아 다시 추적합니다. 비동기 읽기는 직렬화하고 오래된 응답은 버립니다.
- Dock 환경설정을 변경하거나 Dock 프로세스를 종료하지 않습니다. SkyLight 비공개 API를 사용하지 않습니다.

## Mac에서 실행

macOS 14 이상과 Swift 6 이상을 지원 대상으로 합니다. 실제 GUI 로그인 세션이 필요합니다.

```bash
swift build --jobs 4
swift test --jobs 4
./scripts/make-app.sh app release
open 'build/Dock City.app'
```

첫 실행에서 Settings 창이 열리면 **Allow Accessibility access**를 선택하고
시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Dock City를 승인하세요.
권한 없이 자체 Dock을 생성하는 대체 경로는 없습니다. 승인 후 추적을 자동 재시도합니다.
서명이 달라지면 macOS에서 접근성 승인을 다시 확인해야 할 수 있습니다.

메뉴 막대의 건물 아이콘에서 Settings, 도시 일시정지·재개, 종료를 선택할 수 있습니다.
도시 크기·주야간·조명·인구·차량·FPS·저전력·앱별 스킨과 색상을 설정할 수 있습니다.
Dock 위치·크기·확대·자동 숨김·아이콘 목록은 macOS 설정과 실제 Dock에서 변경하세요.

## 설정과 기존 데이터

- Bundle ID: `com.metaparodica.DockCity`
- 설정: `~/Library/Application Support/com.metaparodica.DockCity/config.json` 및 `.bak`
- 스키마 v4는 전역 도시 설정과 독립적인 눈 설정을 사용합니다.
- 이전 설정은 첫 번째 활성 Dock의 도시 설정을 가져오며, 모두 비활성일 때는 첫 항목을 사용합니다.
- 기존 Dock 목록은 데이터 호환성을 위해 보존하지만 표시·실행하지 않습니다.
- 기존 `dockcity://` 자체 Dock 제어 명령과 창 소환 기능은 제거했습니다.
- 접근성 정보는 로컬에서만 사용하며 외부로 전송하지 않습니다.

## 검증

Linux에서는 ConfigKit·CityKit의 설정 이전, 앱 상태, 시민 시뮬레이션,
실제 Dock 좌표 변환·클리핑·숨김 판단을 테스트합니다. macOS 테스트에는 장식 패널의
입력 통과 설정, 포커스 정책 및 추적기 시작·종료 검사가 추가됩니다.

현재 Linux 자동 검증은 통과했습니다. **macOS 네이티브 빌드와 실제 클릭 통과·GUI 품질은 미검증**입니다.
AX가 낡은 좌표를 반환하거나 CG 창 정보를 제공하지 않으면 도시가 일시적으로 숨겨질 수 있습니다.
Dock 항목에 앱 URL이 없으면 이름으로 앱을 추측하지 않고 기본 건물로 표시합니다.
성공적인 실제 Mac 검증 전에는 배포 완료로 간주하지 않습니다.
[검증 목록](docs/dock-city-validation.md)과 [독립 좌표 진단 도구](docs/system-dock-prototype.md)를 참고하세요.

## 출처

원본 [OSPK/Dockman](https://github.com/OSPK/Dockman)의 Git 이력과 MIT [LICENSE](LICENSE)를 유지합니다.
원본 자체 Dock 구현은 추적 방식 전환으로 제거되었으며 Git 이력에서 확인할 수 있습니다.
`docs/01`~`docs/09`는 원본 구조·로드맵에 대한 과거 기록입니다. 현재 동작은 이 README를 기준으로 합니다.
