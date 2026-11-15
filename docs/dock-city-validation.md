# Dock City 추적 모드 검증

눈 방향 벡터 추가 후 전체 검증은 Linux debug/release 각 68개 성공입니다.
아래 31개는 도시 전환 당시 기록이며, 현행 눈 기능과 Mac 검증 절차는 [적설 검증](snow-validation.md)을 참고하세요.

## 현재 구현

자체 Dock 및 SpacesKit/SkyLight 실행 경로는 제거했습니다.
본 앱은 SystemDockAXReader → TrackedCityLayout → TrackedCityPanel/CityScene 경로만 사용합니다.
독립 진단용 overlay-probe는 도시를 렌더링하지 않으며 별도 제품으로 유지합니다.

## Linux 검증

Swift 6.0.3, x86_64 Linux에서 모델 테스트 31개가 통과했습니다.
기존 opt-in 데모 생성 도우미 1개는 환경변수가 없으면 동작하지 않으므로 실질 검증은 30개입니다.
추가한 테스트는 실제 아이콘 중심 정렬, 좌우 회전, 음수 화면 좌표, 화면 클리핑,
숨겨짐·불완전 좌표, 앱 URL JSON 호환성, 같은 활성 앱의 재정렬,
기존 도시 설정 이전 및 백업 복구를 포함합니다.

```bash
export PATH="/workspace/toolchains/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
export SWIFT_MODULECACHE_PATH=/workspace/toolchains/module-cache
export CLANG_MODULE_CACHE_PATH=/workspace/toolchains/clang-cache
export XDG_CACHE_HOME=/workspace/toolchains/cache
swift test --jobs 4 \
  --cache-path /workspace/toolchains/package-cache \
  --config-path /workspace/toolchains/package-config \
  --security-path /workspace/toolchains/package-security
```

Linux는 AppKit 코드를 타입 검사하거나 실제 Dock을 실행하지 않습니다.
Swift 문법 검사 성공은 네이티브 빌드 성공의 증거가 아닙니다.

## 실제 Mac 필수 검증 — 미실행

GUI 로그인 세션에서 이전 Dock City를 종료한 뒤 실행합니다.

```bash
swift build --jobs 4
swift test --jobs 4
./scripts/make-app.sh app release
codesign --verify --strict --verbose=2 'build/Dock City.app'
open 'build/Dock City.app'
```

- 접근성 미승인: 안내 Settings만 열리고 도시·별도 Dock이 나타나지 않아야 합니다.
- 승인: 자동으로 실제 Dock 위에 건물이 정렬되어야 합니다.
- 권한 철회: 다음 추적 주기에 도시가 숨겨져야 합니다.
- 실제 Dock 클릭·우클릭·드래그: macOS가 기존대로 처리해야 합니다.
- 아이콘 순서·크기·확대 변경: 건물 중심이 따라야 합니다.
- 하단·좌측·우측과 Retina·음수 좌표 보조 화면: 정렬과 방향을 확인합니다.
- 자동 숨김·전체화면·Spaces 전환: Dock이 없는 곳에 도시가 남으면 실패입니다.
- Dock 종료·재시작: 새 PID를 찾아 복구해야 합니다. 앱이 Dock을 재시작하지는 않습니다.
- 화면 연결·분리·잠자기·깨우기: 이전 화면의 패널이 남으면 실패입니다.
- 앱 실행·활성화·종료: URL로 식별된 건물의 상태가 바뀌어야 합니다.
- 기존 설정: 첫 활성 항목의 도시 설정을 가져오고 자체 Dock 창은 생성하지 않아야 합니다.
- 저전력·동작 줄이기·일시정지·재개·종료·재실행을 확인합니다.
- 로그인 실행: macOS 승인 상태와 실제 로그인 후 시작을 확인합니다.

macOS 전용 패널 테스트는 입력 통과/포커스 속성과 수명 관리를 확인합니다.
실제 입력 통과와 시각 품질은 위 수동 검증이 필요합니다.
CG 창 정보가 없거나 AX 결과가 오래되면 도시를 숨기는 것이 현재 보수적 동작입니다.
