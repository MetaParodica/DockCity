# 눈 이외의 프로그램 창 장식 조사

조사일: 2026-11-12. 대상은 다른 앱의 창 바깥을 꾸미는 macOS 14+ 기능입니다.
오픈소스 검색 → 코드·라이선스 확인 → 구현 가능성 평가 순서로 조사했습니다.
이 문서는 조사 결과이며 해당 기능을 DockCity에 구현하거나 외부 코드를 도입하지 않았습니다.

## 핵심 판단

창 좌표·전후 순서와 별도 클릭 통과 오버레이를 공유하면 눈 외에도 다양한 장식이 가능합니다.
가장 직접적인 실물 근거는 **RainDesktop의 물·캐릭터**, **SnowDesk의 조명·반딧불·낙엽**,
**Window Sweaters의 니트 테두리**, **MacPenguins의 창 위 보행**입니다.
식물·덩굴·매달린 소품도 이 구조로 구현할 수 있지만, 조사한 바탕화면 정원 위젯을
‘이미 타 앱 창에 부착되는 구현’으로 해석해서는 안 됩니다.

아래의 ‘직접 근거’는 해당 기능의 유사 코드가 있다는 뜻입니다.
‘확장 제안’은 기존 원리를 창에 적용하는 설계 판단이며 완성 구현을 검증했다는 뜻이 아닙니다.

## 기능별 가능성

| 기능 | 동작 예시 | 근거 수준 | 상대 난도와 주요 과제 |
| --- | --- | --- | --- |
| 테두리 스킨 | 니트·나무·액자·픽셀·네온 프레임, 앱별 색상 | 직접: Window Sweaters, JankyBorders, Alan | 낮음~중간. 일반 외부 오버레이로 가능하나 창 겹침·메뉴·모서리·좌표 검증 필요 |
| 포커스 반응 | 활성 창만 은은한 발광, 비활성 창은 흐리게, 앱 전환 시 짧은 강조 | 직접: 위 테두리 프로젝트 | 낮음~중간. AX 포커스와 기하 추적. 밝기 변화·애니메이션 강도 제한 |
| 조명줄·가랜드 | 창 상단 전구, 양 끝 고정 줄, 이동 후 흔들림 | 직접: SnowDesk의 창별 전구. Snowy의 줄 물리. 창 이동 반응은 확장 | 중간. 고정점·줄 길이·처짐/스프링·가림 처리 |
| 매달린 소품 | 풍경·간판·태그·별·리본이 창 이동 시 관성으로 흔들림 | 확장: 기존 줄 물리와 창 추적 조합 | 중간. 감쇠 진자/스프링, 순간이동·최소화 때 초기화 |
| 식물·덩굴 | 창 모서리에서 잎이 자라고 가지가 창틀을 따라 뻗음, 이동하면 흔들림 | 부분 직접: 정원 성장 모델. 타 앱 창 부착은 확장 | 중간. 창 로컬 좌표·성장 단계·가지 곡선·사용 공간 제한 |
| 화분·선반·새 둥지 | 창 위 모서리에 작은 물체, 크기 변경 시 자리 재배치 | 확장: 식물 렌더링과 창 표면 모델 | 낮음~중간. 장식끼리 충돌·좁은 창·가림·최소 크기 |
| 창 위 캐릭터 | 고양이·새·시민이 걷기·앉기·졸기, 가장자리에서 점프/낙하 | 직접: RainDesktop, MacPenguins, iPenguins | 중간~높음. 지지면 추적·상태 머신·전경 가림. 실제 코드가 없는 행동은 별도 개발 |
| 빗방울·물줄기 | 상단에 떨어져 튀고 측면을 따라 흘러 아래로 떨어짐 | 직접: RainDesktop | 높음. 모서리 충돌·물방울 부착·입자 상한·가림 셰이더 |
| 물결·수조·물고기 | 창 아래 작은 물결/수조, 움직임에 따른 출렁임 | 부분 직접: RainDesktop의 화면 수면·물고기. 창별 수조는 확장 | 높음. 파동·물체 경계·움직이는 물높이·성능 |
| 낙엽·꽃잎·나비·반딧불 | 창 가장자리에서 날리거나 모여듦, 커서 접근 시 흩어짐 | 직접: SnowDesk의 낙엽·반딧불. 창별 방출·꽃잎·나비는 확장 | 중간. 화면 전체 효과를 창별 영역/고정점에 연결해야 함 |
| 리사이즈 반응 | 액자가 늘어나고 장식이 탄성 있게 따라감, 이동 시 벡터 잔상·작은 파티클 | 확장: 창 기하 변화와 애니메이션 | 중간. 타 앱 실제 창은 변형하지 않고 장식에만 적용 |
| 상태·시간 장식 | 창 모서리의 작은 시계, 타이머 링, 수동 배지, 앱별 테마 | 확장: 외부 오버레이와 로컬 타이머 | 낮음~중간. 실제 작업 진행률·통화·문서 내용은 별도 API 없이는 알 수 없음 |
| 창 위 작은 마을 | 기존 도시 건물·시민을 창 상단 선반에 배치 | 확장: DockCity CityScene 재활용 | 중간~높음. 일반 창 추적·가림 계층이 필요하며 기존 Dock 레이아웃 그대로 쓰지는 못함 |

## 오픈소스에서 확인한 근거

### RainDesktop — 물과 창 위 캐릭터의 우선 참고

- 저장소: https://github.com/gonzaroman/RainDesktop
- 읽은 커밋: `28f82c8d66044fa96df38bf301ba4b66838f0918`
- [LICENSE](https://github.com/gonzaroman/RainDesktop/blob/28f82c8d66044fa96df38bf301ba4b66838f0918/LICENSE): MIT.
- [RainSimulation.swift](https://github.com/gonzaroman/RainDesktop/blob/28f82c8d66044fa96df38bf301ba4b66838f0918/Sources/RainSimulation.swift):
  창에 부착된 물방울·상단/측면 물줄기·튀는 입자를 구분하고, 창 이동에 맞춰 부착 좌표를 갱신합니다.
- [Creatures.swift](https://github.com/gonzaroman/RainDesktop/blob/28f82c8d66044fa96df38bf301ba4b66838f0918/Sources/Creatures.swift):
  `walking(window:offset:)` 상태, 앞 창의 가림 판정, 착지·낙하 동작을 확인했습니다.
- [RainRenderer.swift](https://github.com/gonzaroman/RainDesktop/blob/28f82c8d66044fa96df38bf301ba4b66838f0918/Sources/RainRenderer.swift):
  각 도형의 depth까지 앞 창을 검사하고 `discard_fragment()`로 가립니다. 둥근 사각형 거리 함수도 있습니다.
- [WindowTracker.swift](https://github.com/gonzaroman/RainDesktop/blob/28f82c8d66044fa96df38bf301ba4b66838f0918/Sources/WindowTracker.swift):
  CG 창 목록 조회, 기본 10Hz/변화 감지 후 60Hz, 최대 32개 창 제한을 확인했습니다.
- 위 수치는 해당 프로젝트 구현입니다. DockCity에서도 같은 성능·호환성을 보장한다는 뜻이 아닙니다.

### SnowDesk — 조명과 비눈 계절 효과

- 커밋: `9b0053dbf63d384a36bddf9eea100b979474be24`, MIT.
- [snow/decor.go](https://github.com/iystoychev/snowdesk/blob/9b0053dbf63d384a36bddf9eea100b979474be24/snow/decor.go):
  창 상단의 처진 전선과 전구, 보이는 상단 구간만 그리는 조건, 커서 반짝임, 성에를 확인했습니다.
  전구는 왼쪽 창 제어 버튼을 피하도록 여백을 둡니다. 현재 전선은 처짐 함수이며 완전한 줄 물리와는 다릅니다.
- [snow/extras.go](https://github.com/iystoychev/snowdesk/blob/9b0053dbf63d384a36bddf9eea100b979474be24/snow/extras.go):
  반딧불의 배회·커서 회피, 낙엽 회전, 유성 효과를 확인했습니다.
  이 효과들은 화면 공간 효과이며 전부가 특정 창에 붙어 있는 것은 아닙니다.
- `snow/decor_test.go`, `snow/extras_test.go`에는 가림·조명·반딧불·낙엽 관련 테스트가 있습니다.
  이번 조사에서는 실행하지 않았습니다.

### Snowy — 매달린 줄의 물리 참고

- 커밋: `21de47d8f7c29e925f98b01074fcd95176ef805f`, MIT. 일부 음원은 별도 취급.
- [HangingLights.swift](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Sources/Snowy/HangingLights.swift),
  [LightString.swift](https://github.com/soloiaros/snowy-mac/blob/21de47d8f7c29e925f98b01074fcd95176ef805f/Sources/Snowy/LightString.swift):
  고정점·물체 가장자리 연결, 줄 갱신·바람·커서 자극·동작 줄이기 경로를 확인했습니다.
- 현재 object 연결은 프로젝트의 장면 객체·위젯·아이콘 등의 모델입니다.
  이 코드를 그대로 사용하면 모든 타 앱 창에 자동 부착된다고 판단하지 않았습니다.

### MacPenguins / iPenguins — 창 위 생물의 행동 참고

- [MacPenguins](https://github.com/MonkeyIsNull/MacPenguins/tree/fcab74ea5de73b92875718effafbf5b1d0823086):
  GPL-2.0, 코드·스프라이트 모두 조건 확인 필요.
  `Sources/SimpleWindowManager.swift`, `SimpleCollision.swift`, `SimplePenguin.swift`에서
  CG 창 조회, 창 상단 지지면, 창 ID 연결, 걷기·텀블링·낙하·독서 상태를 확인했습니다.
  README는 기어오르기·풍선 이동 등을 미구현으로 명시합니다.
  `BasicRenderer.swift`는 높은 창 레벨과 `makeKeyAndOrderFront`를 사용하므로
  DockCity의 비활성·입력 통과 정책에 그대로 복사할 기본안은 아닙니다.
- [iPenguins](https://github.com/MartinStoffel/iPenguins/tree/ab1cfe2a71bcc5214cea8da751a0aa15f67c54ba):
  GPL-2.0, Swift/AppKit 포트. README는 더 많은 행동과 화면 녹화 권한 요구를 명시합니다.
  `Platform/Permissions.swift`의 `CGPreflightScreenCaptureAccess`/권한 요청 경로도 확인했습니다.
  기하만 사용하는 다른 프로젝트와 요구가 달라, 모든 창 장식이 무권한이라고 일반화할 수 없습니다.

### 테두리 프로젝트 — UX와 최소 구현 참고

- [Window Sweaters](https://github.com/saragordic/window-sweaters/tree/6fc58112ba8f93cabef80b23f2735b3c0533db46):
  GPL-3.0, 앱별 니트 테두리. 비공개 SLS/SLSTransaction 의존 확인.
- [JankyBorders](https://github.com/FelixKratz/JankyBorders/tree/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e):
  GPL-3.0, 창별 색상 테두리와 비공개 WindowServer 연동.
- [Alan](https://github.com/tylerhall/Alan/tree/ebdaad76a07b3f31e99b11f6e13da5e16dac8e84): MIT.
  `Alan/FocusHighlighter.swift`, `HighlightWindow.swift`에서 AX 기반 포커스 창 조회와
  마우스 통과 외부 테두리를 확인했습니다. README도 실용 제품보다 실험적 프로젝트라고 설명합니다.
  AXFrame 사용과 복수 화면 좌표 변환 등은 독립 검증·수정 없이 가져오지 않습니다.
- [limelight](https://github.com/cmacrae/limelight/tree/b4e2ee3feeafe8c10050d5839af8695f70b3baf1): MIT.
  오래된 C99 샘플. `src/main.c`에서 SLS 비공개 호출을 확인했으므로 라이선스만으로 기본 채택하지 않습니다.

### 식물 프로젝트 — 성장 모델과 창 부착을 구분

- [WindowGarden](https://github.com/GabrielMu2006/WindowGarden/tree/8c172e7498c1a1ea28d1ec24181459ab64b84118): MIT.
  `Sources/GardenCore/GardenCore.swift`에 사용 시간 기반 성장·식물 단계 모델이 있습니다.
  README와 구조상 **WidgetKit 바탕화면 위젯**이며 타 앱 창틀 부착 구현이 아닙니다.
- [plant-wallpaper](https://github.com/ChrisJDiMarco/plant-wallpaper/tree/45bc1c5cb22ab8d3dff3fe39a9aa93c47a6c26ae):
  바탕화면 식물·상호작용·배경 관리 코드. 조사한 checkout에서 LICENSE/COPYING/NOTICE 파일을 찾지 못했습니다.
  직접 코드 도입 후보에서 제외하며, 창별 식물 장식의 완성 사례로도 간주하지 않습니다.

## 어려운 부분과 권한

- 기본 원리는 **다른 앱의 창을 수정하는 것**이 아니라 **그 주변에 별도 그래픽을 그리는 것**입니다.
  기존 창 자체의 외형·제목 막대·실제 모양·앱 내용을 임의로 바꾸는 기능은 같은 범위가 아닙니다.
- 화면 픽셀을 쓰지 않는 CG 기하·벡터/스프라이트 오버레이는 우선 경로입니다.
  원본 화면을 왜곡하는 진짜 굴절·실시간 창 내용 미러링·내용 기반 테마는 캡처/별도 권한·성능 문제가 추가됩니다.
- 활성 창과 창 수명 추적을 AX로 보강하면 접근성 권한이 필요합니다.
  마이크 반응에는 별도 오디오 입력 경로/권한이 필요하며, 음악 정보를 자동 추측할 수는 없습니다.
- 장식 레이어는 클릭·창 이동·닫기 버튼·메뉴를 방해하지 않아야 합니다.
  클릭 가능한 펫·배지 편집은 별도 편집 모드나 좁은 히트 영역으로 제한하는 것이 적절합니다.
- 창 겹침, 팝업, 전체화면, 최소화, Spaces, Stage Manager, 여러 화면·Retina가 핵심 검증 대상입니다.
  공개 API만으로 타 프로세스 창에 내 창을 완벽히 자식 결합한다고 가정하지 않습니다.
- 스프라이트 애니메이션·조명은 상대적으로 작게 시작할 수 있습니다.
  물 시뮬레이션·많은 입자·화면 전체 블러는 렌더링/WindowServer 비용을 측정해야 합니다.

## DockCity에 적합한 우선순위

1. **창 모서리 화분 + 작은 새/시민**: 기존 픽셀 도시와 통일하기 좋습니다. 화분 부착은 새 구현입니다.
2. **앱별 픽셀/목재/니트 프레임과 포커스 조명**: 정적 버전부터 시작하고 동작을 추가할 수 있습니다.
3. **전구·가랜드·매달린 간판**: 창 이동 반응을 보여주면서 물보다 적은 물리 모델로 시작할 수 있습니다.
4. **창 상단을 걷는 캐릭터와 점프**: RainDesktop의 MIT 구현을 먼저 검토하고 직접 제작 스프라이트를 사용합니다.
5. **비·물줄기·작은 수조**: 구현 근거는 충분하지만 가림과 성능 때문에 후속 단계가 적절합니다.

이 순위는 개발 제안이며 사용자가 기능을 선택한 결과가 아닙니다.
창 추적·앱/창별 장식 설정·가림·수명·전력 정책을 공통 기반으로 만들면 각 효과를 독립적으로 추가할 수 있습니다.

## 검증 수준

이번에는 GitHub 검색, 위 고정 커밋의 README/라이선스 및 명시한 소스 경로를 조사했습니다.
프로젝트의 로컬 설치 스크립트와 macOS 바이너리는 실행하지 않았습니다.
macOS GUI·권한·실제 성능은 미검증이며, 저자의 수치를 DockCity의 보장 수치로 인용하지 않습니다.
이전 보고서의 Snowy JavaScript 테스트 21개는 이번 비눈 기능의 검증 결과가 아닙니다.
제품 소스·의존성·환경 설정은 이번 조사에서 변경하지 않았습니다.
