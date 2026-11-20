# Dock City 검증

이번 변경의 Linux Swift 6.0.3 모델 테스트는 debug/release 각 41개, Node 분석기 테스트는 2개입니다.
실행 이벤트·호버·좌표 변환·유예·중단/재개·설정 이전과 백업을 검사합니다.
기존 opt-in 데모 도우미 1개는 기본 실행에서 출력하지 않습니다.
Linux 소스 파싱은 AppKit 타입 검사나 실제 Mac 실행 증거가 아닙니다.

사용자가 보고한 macOS 27.2 / Xcode 27.2 / Swift 6.4.2의 기존 커밋 `4d05891` 검증은 성공입니다.
**이번 변경의 Mac 네이티브 빌드와 아래 GUI 검증은 미실행**입니다.

## Mac 자동 검증

```bash
bash scripts/verify-macos.sh
node --test scripts/summarize-dock-trace.test.mjs
open 'build/Dock City.app'
```

첫 명령은 debug 빌드·debug/release XCTest·앱 패키징·서명 검증을 수행합니다.
Node는 분석기 개발/사용에만 필요하며 앱 의존성이 아닙니다.
macOS CI에도 분석기 테스트·프로브 패키징을 포함합니다. 이번 실행에서 CI 결과는 확인하지 않았습니다.

## 실제 GUI 검증 — 모두 미확인

| 범위 | 확인할 동작 |
| --- | --- |
| 권한/입력 | 미승인 안내·승인 후 재시도·철회 숨김; 클릭·우클릭·드래그 통과·포커스 불변 |
| A 자동 숨김 | 기본/실험 각 10회 이상 기록, 전후 ms와 시각적 동시 등장·숨김 |
| A 캐시 | 첫 실행 AX 폴백, 앱 추가/삭제·방향·크기·PID·화면·Space 변경 후 잘못된 위치 없음 |
| E 실행 | 새로 실행한 앱 건물만 모션; 초기 실행 상태·활성화·종료에 실행 모션 없음 |
| E 호버 | 실제 아이콘의 건물만 반응, 이탈 시 복귀; 구분선·폴더·휴지통 무시 |
| E 끊김 | 확대 상태로 양 끝·모서리 반복 이동, geometry 로그와 증상 대조 |
| E 간격 | 크기·확대 변경에도 1pt 간격; 도로·지붕 잘림 없음 |
| E 라벨 | 실제 라벨 창 식별 후 레벨 비교; 일반 앱 앞 표시·전체화면·입력 통과 |
| C 시각 | 11종·고정 변주·야간 색; 시민/차량 크기·좁은 Dock 밀도·도로 그림자 |
| C 배경/광장 | 반투명/투명 선택, 실제 AX 구분선 위치에만 보행 공간 |
| 화면/수명 | 하단·좌우·Retina·음수 좌표·전체화면·Space·화면 연결/분리·잠자기/복귀 |
| 절전 | 앱/시스템 저전력·동작 줄이기에서 슬라이드 즉시 완료·건물 모션 생략 |
| 설정/로그인 | 이전 문서·저장·백업 복구·로그인 설정과 실제 로그인 시작 |
| 일시정지 | 도시 숨김·AX 폴링 중단; 재개·종료·재실행 |

상단 Dock은 macOS 기본 Dock 지원 방향이 아니므로 구현하지 않았습니다.
[프로브](system-dock-prototype.md)와 [자동 숨김/라벨 측정](dock-motion-diagnostics.md)을 참고하세요.

## 고정 로컬 서명

기본은 기존 ad-hoc 서명입니다. 사용자가 Keychain Access의 Certificate Assistant 등에서 코드 서명용
인증서·개인 키를 만들거나 기존 Apple 개발 서명 ID를 준비합니다.
자체 인증서의 코드 서명 신뢰 설정이 필요하면 사용자가 Keychain에서 직접 설정합니다.

```bash
security find-identity -v -p codesigning
DOCKCITY_SIGN_IDENTITY='인증서 이름 또는 SHA-1' bash scripts/make-app.sh app release
DOCKCITY_SIGN_IDENTITY='인증서 이름 또는 SHA-1' bash scripts/verify-macos.sh
```

스크립트는 선택한 ID로 서명·strict 검증 후 designated requirement를 출력합니다.
잘못된 ID에서는 실패하며 ad-hoc으로 대체하지 않습니다.
같은 인증서·Bundle ID·설치 경로를 유지하면 권한 주체 안정에 도움이 될 수 있으나 TCC 승인은 보장하지 않습니다.
새 인증서 적용 후 최초 승인이 필요할 수 있습니다.
인증서 생성·신뢰 변경·접근성 승인·`tccutil reset`은 스크립트나 에이전트가 실행하지 않습니다.
