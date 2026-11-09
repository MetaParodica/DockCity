# Dock City

> A living miniature city built around your macOS Dock.

Dockman의 독립형 Dock에 앱 상태에 반응하는 Pixel Town을 추가한 macOS 14+ 앱입니다.
**현재는 구현된 개발 버전입니다. macOS 빌드·GUI 실행 검증은 아직 필요합니다.**
Linux에서 모델 테스트와 문법 검사를 실행했으며, AppKit 타입 검사나 `.app` 생성이 완료됐다고 주장하지 않습니다.

## 구현

- Finder 물류센터, Safari 유리탑, Music 공연장, Terminal 서버센터, Calendar 시계탑 등 11개 스킨.
- 기존 Dock 셀의 실제 중심 좌표를 공유하는 CALayer 도시. 별도 Dock 순서나 실행 로직이 없습니다.
- 기존 NSWorkspace 모니터의 초기 상태와 실행·종료·활성화 이벤트를 사용한 창문 조명과 강조.
- 클릭을 무시하는 투명 자식 NSPanel. Dock 창의 디스플레이·Spaces 및 자동 숨김 정책과 연결됩니다.
- 보도, 도로, 가로등, 화분, 시민 3색, 자동차, 배달 차량. 활성 앱 변경 시 대표 시민과 배달 차량이 이동합니다.
- 시스템 시간 07:00~17:59 주간 / 18:00~06:59 야간 및 수동 선택, 현재 시간을 표시하는 시계탑.
- 크기, 조명, 앱별 스킨·팔레트, 인구·차량 수, FPS, 동작 줄이기, 저전력, 비표시 시 일시정지 설정.
- 외부 이미지·폰트·오디오 없이 코드로 만든 그래픽. 새로운 데이터 수집이나 외부 통신은 없습니다.

## Mac에서 빌드 및 실행

macOS 14 이상과 **Xcode 26 / Swift 6.2 이상**을 권장합니다.
원본의 macOS 26 `NSGlassEffectView`를 가용성 검사 아래 사용하므로 최신 SDK가 필요합니다.
배포 대상은 macOS 14이며 이전 OS에서는 기존 frosted 스타일로 폴백합니다.

저장소 루트에서 실제 Mac의 GUI 로그인 세션으로 실행하세요.

```bash
xcodebuild -version
swift --version
swift build --jobs 4
swift test --jobs 4
swift run dockman-spike --once
./scripts/make-app.sh app release
open 'build/Dock City.app'
```

패키징은 `build/Dock City.app`을 만들고 개발용 ad-hoc 서명을 확인합니다.
기존 빌드는 `build/previous-app.XXXXXX`에 보존합니다.
Developer ID 서명과 notarization은 포함하지 않습니다.
실행 후 메뉴 막대의 건물 아이콘 → Settings → Dock 선택에서 도시를 조절합니다.
Launch at Login은 기존 General 설정을 사용합니다.

## 데이터와 권한

- Bundle ID: `com.metaparodica.DockCity`
- 설정: `~/Library/Application Support/com.metaparodica.DockCity/config.json` 및 `.bak`
- URL: `dockcity://toggle?dock=Dock%201`
- 기존 Dockman 설정을 읽거나 덮어쓰지 않습니다. 기존 `dockman://` 명령은 내부 파싱만 유지하고 URL 핸들러는 등록하지 않습니다.
- 접근성 권한은 창 소환 기능을 사용자가 켤 때만 요청합니다. 도시와 앱 실행에는 필요하지 않습니다.
- macOS 기본 Dock은 변경하지 않습니다. 원본 숨김 유틸리티는 보존하되 UI와 시작 경로에서 호출하지 않습니다.
- Spaces는 원본 SkyLight 비공개 API와 기능 감지·폴백을 유지합니다. SIP 변경은 필요하지 않습니다.

## 구조와 출처

원본: [OSPK/Dockman](https://github.com/OSPK/Dockman),
commit `507398cbab2ead1f36c6f209d40f35a2ad1e9386`.
Git 이력을 가져온 `dock-city` 브랜치에서 개발했습니다. 원본 MIT [LICENSE](LICENSE)와 저작권을 유지합니다.
Docky 코드나 자산은 사용하지 않았습니다. [원본 README](docs/upstream-readme.md)와 기존 `docs/`를 보존합니다.

| 파일 / 모듈 | 역할 |
| --- | --- |
| `Sources/ConfigKit/CitySettings.swift` | 스킨·팔레트·시간대·밀도·전력 설정 |
| `Sources/CityKit/CitySimulation.swift` | 앱 상태 판정과 시민·차량 상태 머신 |
| `Sources/DockKit/DockContentView.swift` | 기존 셀 좌표 공개, 많은 항목의 stack 압축 |
| `Sources/DockKit/CityScene.swift` | 캐시된 CALayer 픽셀아트·조명·시계·인구 렌더링 |
| `Sources/DockKit/CityPanel.swift` | 클릭 통과, 위치·회전, 타이머 및 저전력 |
| `Sources/DockKit/DockController.swift` | Dock·도시 창의 수명, Spaces 및 표시 동기화 |
| `Sources/Dockman/CitySettingsView.swift` | 기존 JSON 저장·reconcile 경로를 사용하는 설정 |
| `scripts/make-app.sh` | 앱 명칭·독립 Bundle ID·개발용 서명 패키징 |

기존 `SpacesKit`, `BindingResolver`, `DockPanel`, `DockItemCell`, `RunningZone`,
`AppActivityMonitor`, `ConfigStore`와 앱 실행·드래그·컨텍스트 메뉴를 재사용합니다.
원본에는 `DockLayerRenderer`라는 클래스가 없으므로 실제 `DockContentView`를 확장했습니다.

## 검증과 제한

[검증 기록 및 Mac 수동 테스트](docs/dock-city-validation.md)를 참고하세요.
macOS CI를 추가했지만 GitHub에 푸시하거나 실행하지는 않았습니다.
Linux `swift test`는 ConfigKit/CityKit만 빌드하며 DockKit/SpacesKit 테스트는 macOS에 유지됩니다.

GUI 품질, 상단/세로 Dock 회전, 여러 화면과 Spaces, 전체 회귀 및 macOS 14 호환성은 미검증입니다.
내장 스킨·팔레트만 지원하며 임의 이미지 가져오기는 없습니다.
눈 효과, 계정, 외부 서버, 날씨, 음악 분석은 범위에 포함하지 않습니다.
실제 Mac에서 아래 검증을 완료하기 전에는 v1.0 완료로 간주하지 마세요.
