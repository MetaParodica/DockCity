# Dock City

> A living miniature city following your existing macOS Dock.

Dock City는 실제 macOS Dock을 읽기 전용으로 추적하는 도시 장식 앱입니다.
앱 실행·클릭·드래그·우클릭은 macOS가 처리하고 도시 패널은 입력과 포커스를 받지 않습니다.
[개발 인수인계](docs/onboarding.md)와 [검증 절차](docs/dock-city-validation.md)를 참고하세요.

## 동작

- 실제 AX 아이콘 좌표·역할·앱 URL을 읽어 하단·좌측·우측 Dock의 건물을 정렬합니다.
- 앱별 스킨 11종과 미지정 앱의 고정 해시 변주, 주야간 조명·시민·차량·시계를 표시합니다.
- 실제 앱 실행과 아이콘 호버 시 해당 건물만 움직입니다. 동작 줄이기에서는 생략합니다.
- 실제 AX 구분선 위치에 보행 공간을 표시합니다. 반투명 하늘이 기본이며 완전 투명도 선택합니다.
- 숨김·오래된 좌표에서는 도시를 숨깁니다. 일시적인 좌표 누락은 최대 220ms 유예합니다.
- 권한·PID·화면·Space·잠자기 변화 시 캐시를 폐기합니다. 도시 일시정지 시 AX 폴링을 중단합니다.
- Dock 환경설정·보안 설정을 변경하거나 Dock을 종료하지 않습니다.

## Mac에서 실행

macOS 14 이상, Swift 6 이상, 실제 GUI 로그인 세션이 필요합니다.

```bash
bash scripts/verify-macos.sh
open 'build/Dock City.app'
```

Settings의 **Allow Accessibility access**를 선택하고 시스템 설정 → 개인정보 보호 및 보안 →
손쉬운 사용에서 Dock City를 승인하세요. 승인 후 자동으로 재시도합니다.
서명이 달라지면 재승인이 필요할 수 있습니다. [고정 서명 안내](docs/dock-city-validation.md#고정-로컬-서명)를 참고하세요.

메뉴 막대에서 Settings, 일시정지·재개, 종료를 선택합니다.
도시 크기·배경·주야간·조명·인구·차량·FPS·절전·앱별 스킨과 색상을 설정할 수 있습니다.
Dock 위치·크기·확대·자동 숨김은 macOS 설정에서 변경합니다.

## 진단과 실험 옵션

`--diagnose-dock`은 가장자리 감지·AX 읽기·Dock 창·도시 표시 시점을 표준 출력에 기록합니다.
`--predictive-dock`은 마지막 실제 가시 좌표로 선행 슬라이드를 시도합니다.
`--city-below-dock`은 라벨 겹침 비교용으로 도시를 Dock 바로 아래 레벨에 배치합니다.
두 실험 옵션은 기본으로 꺼져 있습니다. [실측·비교 방법](docs/dock-motion-diagnostics.md)을 참고하세요.

## 설정과 검증

Bundle ID는 `com.metaparodica.DockCity`이며 설정은
`~/Library/Application Support/com.metaparodica.DockCity/config.json`, 이전 파일은 `.bak`입니다.
스키마 v5는 이전 문서의 알 수 없는 키를 무시하고 도시·로그인 설정을 보존합니다.
전역 도시 설정이 없으면 첫 활성 Dock, 없으면 첫 항목의 도시 설정을 가져옵니다.
기존 Dock 목록은 데이터 호환용으로만 보존합니다. 별도 Dock 창은 만들지 않습니다.
외부 통신·이미지·폰트·음원을 추가하지 않습니다.

이번 변경의 Linux 모델 테스트는 debug/release 각 41개, 진단 분석기 테스트는 2개입니다.
**이번 변경의 macOS 네이티브 빌드·GUI·지연 개선 수치는 미검증**입니다.
사용자가 보고한 이전 커밋 `4d05891`의 Mac 검증 성공과 구분합니다.
[독립 좌표 프로브](docs/system-dock-prototype.md)는 진단용으로 유지합니다.

## 출처

원본 [OSPK/Dockman](https://github.com/OSPK/Dockman)의 Git 이력과 MIT [LICENSE](LICENSE)를 유지합니다.
`docs/01`~`docs/09`는 과거 자체 Dock 구조 기록입니다. 현재 동작은 이 README를 기준으로 합니다.
