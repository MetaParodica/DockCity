# 자동 숨김·모션·라벨 진단

현재 환경은 Linux이므로 실제 Dock 지연과 라벨 레벨을 측정하지 못했습니다.
아래는 실제 Mac에서 실행할 절차입니다. 수치가 없는 상태에서 개선이나 라벨 해결을 확정하지 않습니다.

## 같은 조건에서 비교

패키징과 접근성 승인 후 기존 앱을 메뉴에서 종료합니다. 실행 전 Dock이 완전히 숨겨지기를 기다립니다.
로깅 부하가 같도록 기본/실험 모두 진단을 켭니다. `open -W`는 앱 종료까지 기다립니다.

```bash
open -W -n --stdout /tmp/dock-city-baseline.jsonl 'build/Dock City.app' --args --diagnose-dock
```

마우스 가장자리 진입·Dock 밖 이탈을 10회 이상 반복하고, 확대와 양 끝 이동은 별도로 반복합니다.
앱 종료 후 분석합니다.

```bash
node scripts/summarize-dock-trace.mjs /tmp/dock-city-baseline.jsonl
```

기준 로그를 검토한 뒤 실험 옵션을 비교합니다. 첫 가시 좌표를 얻기 전에는 선행 표시하지 않습니다.

```bash
open -W -n --stdout /tmp/dock-city-predictive.jsonl 'build/Dock City.app' --args --diagnose-dock --predictive-dock
node scripts/summarize-dock-trace.mjs /tmp/dock-city-predictive.jsonl
```

위 실행은 이번 빌드의 옵션 OFF/ON 비교입니다. 이전 커밋과 정확히 비교하려면 이전 코드에도 동일 계측을 적용한
별도 빌드가 필요합니다. 옵션 OFF 결과를 기존 커밋의 실측값으로 대신하지 않습니다.

## 로그와 한계

| 기록 | 의미 |
| --- | --- |
| `pointer_edge_enter_sampled` | Dock 방향 가장자리에서 샘플링한 마우스 진입 |
| `ax_read_start` / `ax_snapshot.read_ms` | 읽기 시작 / 결과 전달까지 소요 시간 |
| `ax_snapshot` | AXList·Dock 창 사각형, 전체 AX 좌표의 화면 내 여부, 불완전 여부 |
| `dock_owned_windows_unclassified` | Dock PID 소유 창의 PID·레벨·사각형; 제목 없음 |
| `city_order_front/out` | 패널 order 요청 뒤 가시 상태 |
| `city_first_visible_geometry` | 표시 중인 패널 사각형이 화면과 처음 겹침 |
| `geometry_unavailable` | 숨김 판정·유예·선행 표시 유지 여부 |
| `predictive_reveal/hide` | 실험 시작과 채택한 예상 시간 |

분석기 `dock_ms`, `ax_ms`, `city_ms`, `order_front_ms`는 샘플링된 가장자리 진입부터의 차이입니다.
`null`은 미관측입니다. `max_read_ms`는 해당 구간의 읽기 지연이며 표시 지연과 다릅니다.
Dock/AX는 읽기 완료 시점의 관측이므로 WindowServer 애니메이션의 정확한 시작 시각이 아닙니다.
도시 기하도 합성 완료나 실제 픽셀 표시를 측정하지 않습니다. 영상과 시각 관찰로 동시성을 함께 확인합니다.

마우스는 `NSEvent.mouseLocation`을 타이머에서 읽으며 전역 이벤트 모니터나 추가 입력 권한을 쓰지 않습니다.
기본 샘플 주기는 품질에 따라 약 16.7~66.7ms, 실험은 약 16.7ms, 절전은 약 100ms입니다.
일반 AX 폴링은 100ms(절전 400ms), 실험 표시 중에는 최대 60Hz이며 직렬 읽기 속도에 제한됩니다.
진단의 추가 Dock 창 조회와 출력에도 비용이 있으므로 같은 조건으로 비교합니다.

현재 실제 결과:

| 항목 | 기준 | 실험 |
| --- | --- | --- |
| 가장자리 → Dock 관측 | 미측정 | 미측정 |
| 가장자리 → AX 화면 내 | 미측정 | 미측정 |
| 가장자리 → 도시 기하 표시 | 미측정 | 미측정 |
| 최대/중앙 지연·끊김 | 미측정 | 미측정 |

## 실험 정책

`--predictive-dock`은 자동 숨김일 때만 마지막 실제 화면 내 좌표를 사용합니다.
캐시는 최대 5분이며 PID·방향·아이콘 구성/크기·화면·Space·권한 변화에서 폐기합니다.
캐시가 없으면 AX 경로로 폴백합니다. Dock 영역 이탈 때 내려가고 재진입 시 현재 진행점에서 되돌립니다.
누락 좌표는 최대 220ms 유지하지만 권한·화면·PID 무효화는 즉시 숨깁니다.
동작 줄이기/저전력에서는 즉시 표시·숨김이며 일반 Dock에는 예측을 적용하지 않습니다.

`autohide-delay`와 `autohide-time-modifier`는 읽기만 합니다. 공개 모션 계약이 아니므로
현재 값→초 변환과 곡선은 근사입니다. 키가 없으면 지연 0.2초·길이 0.5초를 **실험 추정값**으로 쓰며
`uses_estimated_defaults`에 표시합니다. macOS 27.2의 검증된 기본값이 아닙니다.
실측 후 타이밍을 합의하기 전 기본 활성화하지 않습니다.

## 앱 이름 라벨 겹침

호버 전/후 Dock 소유 창의 새 레벨·사각형을 비교합니다. Dock 소유라는 이유만으로 라벨이라 단정하지 않습니다.
CG 정보가 제한되면 미확인으로 기록합니다. CG는 좌상단, 마우스/패널은 Cocoa 좌하단 좌표입니다.

기본 레벨은 Dock+1(사용자 Mac에서 21)입니다.

| 후보 | 장점 | 확인할 위험 |
| --- | --- | --- |
| Dock−1에 배치 | Dock/라벨이 위에 표시될 가능성, 호버 때 순서 변경 없음 | 일반 앱·전체화면·다른 Dock 창과의 실제 겹침 |
| 호버 동안 라벨 뒤로 순서 조정 | 평소 기존 레벨 유지 가능 | 라벨 식별 실패·깜빡임·복귀 관리·동일 레벨 조건 |

첫 안만 비교 옵션을 제공하며 두 번째 안은 관측 없이 구현하지 않았습니다.

```bash
open -W -n --stdout /tmp/dock-city-level.jsonl 'build/Dock City.app' --args --diagnose-dock --city-below-dock
```

일반 앱 앞 표시·라벨 가림·전체화면·클릭 통과를 확인한 뒤 최종 레벨을 결정합니다.
현재 실제 라벨 레벨과 두 안의 시각 결과는 미확인입니다.
