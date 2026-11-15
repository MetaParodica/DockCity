# Dock City 개발 인수인계

기준: 2026-11-12. 이 문서는 현재 작업 트리의 상태를 기록합니다.
기준 커밋은 `fff8baade365ebb9761c89611cbd72230796fd37`이며 아래 전환 작업은 아직 커밋되지 않았습니다.

## 확정된 제품 방향

- 실제 macOS Dock을 추적하는 장식 앱으로 개발합니다.
- 자체 Dock 생성 기능은 제거했습니다. 선택 가능한 대체 모드도 만들지 않습니다.
- 아이콘 실행·재정렬·드래그·컨텍스트 메뉴는 macOS가 처리합니다.
- 접근성 미승인, 불완전/오래된 좌표, Dock 부재 시 도시를 숨깁니다.
- Dock 환경설정을 바꾸거나 Dock을 종료하지 않습니다.
- SkyLight/SpacesKit와 자체 Dock 제어 URL 경로는 제거했습니다.
- `docs/01`~`docs/09`의 자체 Dock 설계는 과거 기록입니다. 이를 근거로 제거 기능을 복원하지 마세요.

## 현재 코드

| 경로 | 역할 |
| --- | --- |
| `Sources/DockKit/SystemDockAXReader.swift` | Dock AX 항목 좌표·역할·앱 URL 및 CG 창 정보 읽기 |
| `Sources/DockKit/SystemDockCityTracker.swift` | 직렬 비동기 추적, 응답 유효성, 권한·PID·화면 수명 관리 |
| `Sources/CityKit/TrackedCityLayout.swift` | 하단/좌우 좌표 변환, 화면 선택·클리핑·숨김 판단 |
| `Sources/DockKit/TrackedCityPanel.swift` | 클릭 통과·비활성 장식 패널과 렌더링 주기 |
| `Sources/DockKit/CityScene.swift` | 도시 그래픽·건물·조명·시민·차량 |
| `Sources/Dockman/AppDelegate.swift` | 추적 전용 앱·설정 저장·로그인 실행·메뉴 |
| `Sources/Dockman/TrackingSettingsView.swift` | 실제 Dock 추적 상태·권한 및 도시 설정 |
| `Sources/ConfigKit/ConfigModels.swift` | v3 전역 도시 설정과 이전 문서 디코딩 |

기존 `DockModel` 등은 과거 설정을 읽고 보존하기 위한 데이터 타입입니다.
실행 가능한 자체 Dock 구현은 남겨두지 않았습니다.
전역 도시 설정이 없으면 첫 활성 Dock, 없으면 첫 Dock의 도시 설정을 가져옵니다.
설정 위치는 `~/Library/Application Support/com.metaparodica.DockCity/config.json`입니다.

## 작업 환경과 검증

각 클라우드 작업은 이미 격리되어 있습니다. `/workspace/DockCity`의 기존 checkout을 사용하고
명시적 요청 없이 Git worktree를 만들지 마세요. 기존 변경과 삭제·새 파일을 모두 보존하세요.

Linux 툴체인과 캐시는 `/workspace/toolchains`에 유지됩니다.

```bash
cd /workspace/DockCity
export PATH="/workspace/toolchains/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
export SWIFT_MODULECACHE_PATH=/workspace/toolchains/module-cache
export CLANG_MODULE_CACHE_PATH=/workspace/toolchains/clang-cache
export XDG_CACHE_HOME=/workspace/toolchains/cache
swift test --jobs 4 \
  --cache-path /workspace/toolchains/package-cache \
  --config-path /workspace/toolchains/package-config \
  --security-path /workspace/toolchains/package-security
swift build -c release --jobs 4 \
  --cache-path /workspace/toolchains/package-cache \
  --config-path /workspace/toolchains/package-config \
  --security-path /workspace/toolchains/package-security
```

도시 전환 당시 검증은 Linux XCTest 31개 성공이었습니다. 눈 기능 추가 후 현재 검증은
방향 벡터 추가 후 Linux debug 68개 및 release 68개 성공, 각 실패 0개입니다. 이 중 opt-in 데모 도우미 1개는 기본 실행에서 동작하지 않습니다.
Linux 릴리스 모델 빌드, Swift 소스 파싱, 셸 문법 및 `git diff --check`도 통과했습니다.
이는 macOS 실행 검증이 아닙니다. AppKit 타입 검사·권한·입력 통과·화면 정렬은 미검증입니다.
전체 Mac 확인 절차는 [검증 목록](dock-city-validation.md)을 따르세요.
Mac에서는 `swift build`, `swift test`, `./scripts/make-app.sh app release` 후 실제 GUI에서 실행합니다.
별도 `probe` 제품은 좌표 진단용입니다. 제거된 `dockman-spike`를 실행하지 마세요.

## 추가 구현: 창과 Dock 적설

눈 기능 구현 요청에 따라 SnowCore, SnowOverlayController, 설정/UI와 테스트를 추가했습니다.
스키마는 v4이며, 도시와 눈 설정은 독립적입니다. 이전 v3 설명은 도시 전환의 이력입니다.
일반 창 상단·실제 Dock 윗면 적설, 느린 이동 시 운반, 빠른 이동/리사이즈/창 소멸 시 이탈과
중력 낙하를 구현했습니다. 좌/우 Dock은 실제 상단 모서리에 쌓입니다.
SnowFallVector와 SnowDirectionControl에서 화살표 방향·길이를 설정합니다.
설정 벡터는 360도 강설 방향·속도, 파편의 초기 바람에 적용되며 중력은 아래로 유지됩니다.
실제 macOS 검증은 아직 필요합니다.
현행 절차는 [적설 검증](snow-validation.md)을 따르세요.

## 조사 기록: 프로그램 창 장식

사용자가 제안한 예시는 창 위에 눈이 쌓이고 창을 움직이면 눈이 관성·중력에 따라 떨어지는 효과입니다.
오픈소스 우선 조사를 마쳤으며, 이후 눈 적층 기능을 먼저 구현하기로 요청받았습니다.
조사 결과는 [창 장식 오픈소스 조사](window-effects-research.md)를 참고하세요.
눈 이외의 테두리·식물·조명·캐릭터·물 효과는 [후속 조사](non-snow-window-effects.md)에 정리했습니다.

우선 후보는 MIT의 `soloiaros/snowy-mac`과 `iystoychev/snowdesk`입니다.
사용자는 개인 사용을 전제로 라이선스만으로 후보를 제외하지 않도록 지시했습니다.
원본 라이선스·출처는 보존하고, 비공개 API 의존과 통합 비용은 기술적 판단에 포함합니다.
외부 이미지·음원·런타임 의존성은 추가하지 않았습니다. SnowDesk의 설계 참고와 MIT 출처를
THIRD_PARTY_NOTICES.md에 기록했습니다.

환경 초안 저장과 실제 코드/파일 스냅샷 publication은 별개입니다.
사용자가 요청하지 않은 publish·push·외부 메시지 발송을 하지 마세요.
