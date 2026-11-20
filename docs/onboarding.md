# Dock City 개발 인수인계

기준: 2026-11-20(한국 시간). 기반 커밋 `4d05891d393a1bf28c945f95a7037027fa7fe8b7`에 대한 2차 피드백입니다.
아래 변경은 2026-11-20 사용자 요청으로 `main`에 게시하는 작업 범위입니다.
기존 원격 `dock-city` 브랜치는 보존합니다. macOS 네이티브 CI·실제 화면 검증은 별도로 확인해야 합니다.

## 제품 방향

실제 macOS Dock을 읽기 전용으로 추적합니다. 자체 Dock 생성 기능을 복원하지 마세요.
입력·포커스는 macOS Dock이 처리합니다. Dock 환경설정·TCC·보안 설정을 변경하거나 Dock을 종료하지 않습니다.
도시를 끄면 좌표 폴링을 중단합니다. 설정은 스키마 v5이며 이전 도시·로그인·백업을 보존합니다.
외부 통신·이미지·폰트·오디오·런타임 의존성을 추가하지 않았습니다.

## 2차 피드백 상태

| 항목 | 구현 | 남은 확인 |
| --- | --- | --- |
| A 자동 숨김 | JSONL 계측·분석기, 마지막 가시 좌표 캐시·선행 슬라이드 실험 | Mac 전후 ms 측정·타이밍 합의·동시성 확인 |
| B 제거·호환 | 폐기 기능의 소스·UI·타깃·테스트·관련 문서 삭제, v4 호환 테스트 | Mac 빌드 |
| E 실행/호버 | 실제 실행 알림 매칭·실제 아이콘 히트 판정·건물별 모션 | Mac 입력 통과·대상 확인 |
| E 끊김/간격 | 220ms 유예·슬라이드 중단점 유지·크기 변경의 전체 페이드 제거·간격 3→1pt | 원래 증상 재현·개선 측정 |
| E 라벨 | Dock 소유 창 관측·아래 레벨 비교 옵션 | 실제 라벨 식별 후 레벨 결정 |
| C 시각 | 결정적 변주·야간 색·밀도/크기·실제 구분선 광장·배경 선택 | 현재 빌드 외관 모두 미확인 |
| D 환경 | 선택적 고정 서명·LaunchServices 프로브 문서 | Mac 인증서·권한 유지 확인 |

선행 슬라이드는 `--predictive-dock`, 레벨 비교는 `--city-below-dock`으로만 활성화합니다.
기본 레벨은 Dock+1(사용자 Mac에서 21), 자동 숨김은 기존 AX 기반 표시입니다.
A와 라벨은 실측 전에 해결됐다고 선언하거나 수치를 추정하지 마세요.

## 코드 지도

| 경로 | 역할 |
| --- | --- |
| `Sources/DockKit/SystemDockAXReader.swift` | Dock AX 및 Dock 창 읽기 |
| `Sources/DockKit/SystemDockCityTracker.swift` | 직렬 읽기·캐시·수명·마우스 위치 샘플링 |
| `Sources/DockKit/DockDiagnostics.swift` | opt-in 표준 출력 계측; 제목 없음 |
| `Sources/DockKit/DockMotionPreferences.swift` | 모션 키 읽기 전용 참조 |
| `Sources/CityKit/DockPresentation.swift` | 일시 누락 유예·중단 가능한 슬라이드 |
| `Sources/CityKit/CityInteraction.swift` | 실행 이벤트·히트 판정·고정 해시 |
| `Sources/DockKit/TrackedCityPanel.swift` | 입력 통과 패널·렌더링 |
| `Sources/DockKit/CityScene.swift` | 도시 그래픽·건물별 모션 |
| `Sources/DockKit/AppActivityMonitor.swift` | 앱 상태와 실제 실행 알림 |
| `Sources/ConfigKit` / `Sources/Dockman` | 설정·백업 / 메뉴·설정 UI·로그인 |

과거 DockModel은 이전 데이터 보존용입니다. `docs/01`~`docs/09`는 현행 명세가 아닙니다.

## 클라우드 검증

`/workspace/DockCity`의 기존 checkout을 사용합니다. 현재 환경은 Linux x86_64와 Swift 6.0.3이며 AppKit/Xcode가 없습니다.

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
swift test -c release --jobs 4 \
  --cache-path /workspace/toolchains/package-cache \
  --config-path /workspace/toolchains/package-config \
  --security-path /workspace/toolchains/package-security
node --test scripts/summarize-dock-trace.test.mjs
```

모델 테스트 debug/release 각 41개와 분석기 2개를 확인합니다.
기존 opt-in 데모 도우미 1개는 기본 실행에서 실제 출력을 생성하지 않습니다.
Linux 파싱은 AppKit 타입 검사가 아니며 기존 커밋의 Mac 성공은 이번 변경의 검증 증거가 아닙니다.
[전체 검증](dock-city-validation.md), [지연 측정](dock-motion-diagnostics.md),
[좌표 프로브](system-dock-prototype.md)를 따르세요.

사용자 요청 없이 worktree 생성·push·환경 publish·외부 메시지를 수행하지 마세요.
