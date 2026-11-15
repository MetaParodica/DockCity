# 프로그램 창 장식: 오픈소스 우선 조사

후속 조사: [눈 이외의 창 장식 기능](non-snow-window-effects.md).

조사일: 2026-11-12. 대상: 다른 프로그램의 창 바깥을 장식하는 macOS 14+ 앱.
요청 예시: 창 위 적설, 창 이동 시 관성에 따른 이탈과 중력 낙하.
이번 작업은 조사와 인수인계 기록이며 제품에 창 장식 기능을 추가하지 않았습니다.

## 결론

요청 효과는 기술적으로 가능합니다. macOS에서 유사 효과를 구현한 공개 소스와 테스트를 확인했습니다.
창의 실제 콘텐츠를 변경하는 대신 창 좌표를 추적하는 별도 클릭 통과 오버레이에 눈을 그리는 방식입니다.
가장 가까운 후보는 **Snowy(MIT, Swift/Metal)**와 **SnowDesk(MIT, Go/Objective-C/Metal)**입니다.
독립 물리 모델과 렌더러가 이미 존재하므로 새 엔진부터 설계하기 전에 재사용 범위를 평가할 수 있습니다.
단, 이 Linux 환경에서 해당 macOS 앱을 실행하거나 성능·권한 동작을 검증하지는 않았습니다.

## 탐색 방법과 범위

GitHub 저장소 검색에서 `macos snow window`, `desktop snow language:Swift`,
`snow windows accumulate`, `macos window decoration`, `xsnow linux`를 조회했습니다.
결과에서 실제 구현 저장소를 checkout하고 README, LICENSE, 추적·렌더링·물리 소스와 테스트를 읽었습니다.
GitHub 검색에 429가 한 번 발생한 뒤 추가 검색을 반복하지 않고 확보한 저장소를 조사했습니다.
따라서 인터넷 전체를 망라하거나 유사 프로젝트 부재를 입증하는 조사는 아닙니다.
조사용 checkout은 `/tmp/dockcity-research-*`이며 제품 의존성으로 등록하지 않았습니다.
아래 커밋은 이번에 실제 읽은 소스의 기준입니다. 링크는 변경되지 않는 커밋에 고정했습니다.

## 우선 후보

### 1. Snowy — 가장 가까운 Swift 후보

- 저장소: https://github.com/soloiaros/snowy-mac
- 커밋: `21de47d8f7c29e925f98b01074fcd95176ef805f`
- macOS 14+, Swift 6 패키지, AppKit/Metal. 별도 SnowCore와 단위 테스트가 있습니다.
- 창·위젯·하단 Dock 위 적설, 이동 지지면의 눈 이동/충돌, 지지면 소멸 시 낙하, 바람·쓸기 기능이 있습니다.
- [창 추적](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Sources/Snowy/WindowTracker.swift):
  `CGWindowListCopyWindowInfo`로 전체 목록을 읽고, 드래그 대상만 `CGWindowListCreateDescriptionFromArray`로 갱신합니다.
  기본 유휴 조회 0.5초, 드래그 대상 약 30Hz, 드래그 중 전체 재탐색 0.1초이며 읽기 중첩을 차단합니다.
- [이동 충돌 모델](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Sources/SnowCore/BodyMotion.swift),
  [장면/지지면 갱신](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Sources/SnowCore/SnowSimulation%2BScene.swift),
  [지지면 소멸 테스트](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Tests/SnowCoreTests/RemovedSupportTests.swift)를 확인했습니다.
- [라이선스](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/LICENSE): MIT.
  README는 사용자 제공 음원을 MIT 대상에서 제외합니다. 코드와 에셋의 사용 범위를 따로 확인해야 합니다.
- 적용 판단: Swift 물리 코어와 장면 모델의 부분 재사용을 우선 검토합니다.
  앱 전체를 가져오면 Sparkle, 업데이트, 장면 편집기 등 이번 범위와 무관한 기능도 함께 들어옵니다.
  Dock 폭 추정·하단만 지원하는 자체 제약은 DockCity의 AX 기반 실측 경로로 대체할 수 있습니다.
- 한계: 창 모서리·특수 창 형태·일부 Dock 형태는 추정값입니다. README의 동작/성능 설명은 우리 환경에서 검증하지 않았습니다.

### 2. SnowDesk — 요청한 ‘흔들어 떨어뜨리기’의 직접 참고

- 저장소: https://github.com/iystoychev/snowdesk
- 커밋: `9b0053dbf63d384a36bddf9eea100b979474be24`
- [물리 소스](https://github.com/iystoychev/snowdesk/blob/9b0053dbf63d384a36bddf9eea100b979474be24/snow/sim.go):
  창 상단을 높이 열 배열로 관리하고, 앞 창의 가림 영역을 제외합니다.
  창 속도가 350pt/s를 넘는 상태가 0.2초 유지되면 눈과 고드름을 이탈시킵니다.
  눈 입자에는 창 속도의 일부와 중력을 적용합니다. 이 수치는 해당 프로젝트의 연출 파라미터입니다.
  여러 창의 동시 이동·화면 이탈을 이용해 Spaces 전환과 사용자 fling을 구분하는 코드도 있습니다.
- [macOS 연결](https://github.com/iystoychev/snowdesk/blob/9b0053dbf63d384a36bddf9eea100b979474be24/overlay_darwin.m):
  CG 창 목록과 단일 클릭 통과 Metal 오버레이 사용. 일반 창을 전후 순서로 처리합니다.
- [라이선스](https://github.com/iystoychev/snowdesk/blob/9b0053dbf63d384a36bddf9eea100b979474be24/LICENSE): MIT.
- 적용 판단: 적층/이탈/Spaces 오인 방지 알고리즘을 검토할 가치가 큽니다.
  Go/cgo 실행 구조를 그대로 추가하기보다는 필요한 부분의 Swift 이전 여부를 평가합니다.
- 한계: README 기준 주 화면만 지원, Dock 폭은 추정, 측면 Dock 적설 미지원.
  README의 CPU/WindowServer 사용 수치는 저자의 측정이며 DockCity의 예상 성능 수치로 인용하지 않습니다.

### 3. 추가 후보와 제외 사유

| 프로젝트 | 확인한 근거 | 라이선스/판단 |
| --- | --- | --- |
| [Window Sweaters](https://github.com/saragordic/window-sweaters/tree/6fc58112ba8f93cabef80b23f2735b3c0533db46) | 창별 니트 테두리·앱별 테마. `src/border.c`에 SLS/SLSTransaction 호출 확인 | GPL-3.0, JankyBorders 기반. 창 장식 UX 참고. 기본 통합 후보에서 제외 |
| [JankyBorders](https://github.com/FelixKratz/JankyBorders/tree/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e) | 창별 장식과 전후 순서 연동. `src/border.c`, `src/windows.c`에 SkyLight 호출 | GPL-3.0·비공개 API 의존. 현재 공개 API 방향과 다름 |
| [Snowpuff](https://github.com/ehroz1/Snowpuff/tree/b2d5abe76027cafd4be45d6b136089fe436539ac) | `Sources/Snowpuff/WindowTracker.swift`의 CG 추적, `core/src/simulation.rs`의 이동/이탈·물리 | MIT. Swift+Rust FFI라 Swift 단독 후보보다 통합 비용 큼 |
| [Snow Desktop](https://github.com/blazeNibirus/Snow-Desktop/tree/b6e8a20bb6cd98d67ea279d40f1b7898ca8057c4) | `Sources/SnowCore/SnowEngine.swift`에 관성·가장자리 이탈·중력, WindowTracker에 가림 계산 | 이번 checkout에서 LICENSE/COPYING 파일과 README 라이선스 선언을 찾지 못함. 허용 범위 확인 전 코드 복사 제외 |
| [AXSwift](https://github.com/tmandry/AXSwift/tree/e18a18453d135ad45809a384ee5139e05ea52def) | `Sources/Observer.swift`의 AXObserver와 notification 등록·해제 | MIT. 선택적 AX 이동/크기 알림 참고. 읽은 HEAD는 2021년 커밋으로 최신 SDK 호환성 별도 확인 |
| [Hammerspoon](https://github.com/Hammerspoon/hammerspoon/tree/23e387e2805a9890066366e0ac96c71b27f0cfd5) | `Hammerspoon/HSuicore.m`, `extensions/axuielement/observer.m`의 AX observer 구현 | 루트 MIT. 창 수명·이벤트 처리 참고. 전체 런타임 도입 불필요 |
| [snowflakes](https://github.com/abakan21/snowflakes/tree/ac4598c1ada735cb35a85266e3e1d092bf40a036) | 이번 checkout은 README와 LICENSE뿐 | MIT지만 재사용할 구현 없음 |
| [Plash](https://github.com/sindresorhus/Plash/tree/79728c9717d69e165b4eea587af2897278732d42) | README가 더 이상 오픈소스가 아니라고 명시 | 현재 공개 구현 후보에서 제외 |

GPL 코드를 MIT 프로젝트에 복사·결합하면 배포 조건 검토가 필요합니다.
이번에는 라이선스 선언과 API 의존을 확인했으며, 제3자 코드를 제품에 복사하지 않았습니다.

## 기술적으로 가능한 효과

| 효과 | 가능성 | 필요한 요소와 한계 |
| --- | --- | --- |
| 창 상단 눈 적층·눈 처마 | 높음 | 창 사각형, 상단 높이 배열, 모서리 테이퍼, 전경 창 마스킹 |
| 이동 시 눈의 지연·흔들림·낙하 | 높음 | 위치 변화로 속도/가속도 추정, 부착 상태와 자유 낙하 상태 분리 |
| 창 크기 변경 시 눈 일부 붕괴 | 높음 | 지지면 재표본화, 잘려나간 재료를 입자로 방출 |
| 아래 창·Dock 위 재적층 | 가능, 난도 증가 | 이동 충돌과 가림, 낙하 재료량 보존, 다중 지지면 |
| 고드름·빗방울·낙엽·꽃잎 | 높음 | 같은 창 표면 모델에 다른 부착/방출·입자 규칙 적용 |
| 조명줄·니트/픽셀 테두리·덩굴 | 높음~중간 | 별도 오버레이, 앱별 테마, 곡선/스프링 연출. 완벽한 창 순서 추종은 별도 문제 |
| 임의 형태 창·구멍·정확한 모서리 충돌 | 제한적 | 공개 메타데이터는 주로 사각형. 정확한 실루엣은 확보되지 않음 |
| 다른 앱 콘텐츠·실제 타이틀바 자체 변경 | 기본 방식으로 부적합 | 외부 장식으로는 가능하나 타 앱 뷰 계층의 직접 변경과는 다름 |

이 평가는 소스 조사에 기반한 구현 가능성입니다. 우리 앱의 구현 완료나 모든 macOS 버전에서의 성공을 뜻하지 않습니다.

## DockCity에 권하는 구조

1. **창 관측 계층**: 공개 CG 창 목록으로 PID·window ID·bounds·alpha·layer·전후 순서를 읽습니다.
   창 제목·화면 이미지 없이 일반 창의 기하를 처리하는 공개 소스가 있습니다.
   OS별 메타데이터 가용성은 실제 Mac에서 확인하고 누락된 값에 의존하지 않습니다.
   기존 Dock AX 권한은 유지하며, 필요할 때만 AXObserver 이동·크기·닫힘 알림을 보강합니다.
2. **지지면/가림 계층**: 창마다 상단 선분을 만들고 앞 창에 가려진 구간을 잘라냅니다.
   창 사라짐을 즉시 닫힘으로 처리하지 않습니다. 최소화·Spaces 이동·숨김과 구분해야 합니다.
   window ID는 실행 중 식별자이므로 장기 저장 키로 사용하지 않습니다.
3. **물리 코어**: 우선 상단 1차원 높이 배열과 제한된 낙하 입자로 시작합니다.
   부착 눈은 창 로컬 좌표, 이탈 눈은 화면 좌표로 전환합니다.
   이동량과 시간으로 속도/가속도를 추정하고 잡음을 완화해 이탈을 결정합니다.
   일정 시간 간격의 중력 적분과 입자/면적/작업량 상한을 둡니다.
4. **렌더링 계층**: 소수 장식에는 CALayer, 다량 눈에는 화면별 투명 Metal 오버레이를 검토합니다.
   클릭 통과·비활성 정책을 유지합니다. 화면 전체 오버레이는 앞 창까지 덮으므로 소프트웨어 가림 계산이 필수입니다.
   공개 API만으로 다른 프로세스의 창에 내 패널을 자식 창처럼 완벽히 결합한다고 가정하지 않습니다.
5. **수명/전력 계층**: 유휴에는 낮은 추적 빈도, 드래그 대상만 빠른 갱신, 화면 잠자기·전체화면·잠금 시 중단합니다.
   여러 화면과 Retina 좌표 변환, Stage Manager/Mission Control의 임시 변환을 구분해야 합니다.

기존 DockCity의 도시용 CALayer 렌더러는 재사용 가능하지만, 자유 낙하·외부 창 가림 엔진은 새 기능입니다.
첫 실험은 ‘창 상단에 눈 쌓기 → 느린 이동 시 유지 → 빠른 이동/리사이즈 시 이탈 → 중력 낙하’로 한정하는 것이 적절합니다.
그 결과를 보고 아래 창과 Dock 재적층, 창별 테마 및 추가 계절 효과를 확장합니다.

## 이번에 실제 검증한 것

- 위 저장소의 고정 커밋, 라이선스 파일 및 관련 소스를 확인했습니다.
- Snowy의 별도 브라우저 구현에서 `node --test website/tests/snow-engine.test.js website/tests/window-geometry.test.js`를 실행했습니다.
- 결과: **21개 성공, 실패 0개, skip 0개**. 이동 창과 눈의 충돌, 지지면 소멸 후 낙하, 가림, 자원 상한 등을 포함합니다.
- 이 결과는 **JavaScript 모델 테스트**이며 Swift/Metal 구현 또는 macOS 창 추적을 실행한 결과가 아닙니다.
- 다른 후보의 macOS 앱·네이티브 테스트는 실행하지 않았습니다. 저자가 제시한 성능 수치와 권한 주장은 독립 검증 전입니다.

다음 구현 전에 실제 Mac에서 창 기하의 공개 API 가용성, 클릭 통과, 창 겹침, 드래그 지연,
Spaces·Stage Manager·여러 화면·최소화·닫힘을 작은 실험으로 확인해야 합니다.
