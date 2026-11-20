# 실제 Dock 좌표 진단 프로브

`DockCityOverlayProbe`는 독립 진단 도구로 유지합니다.
도시 렌더러와 분리해 AX 좌표·구분선·휴지통·입력 통과를 대조할 수 있어 현재 진단에도 유용합니다.
본 앱의 대체 실행 모드는 아닙니다. 설정 저장이나 Dock 변경을 하지 않습니다.

## Mac에서 실행

기존 Dock City와 프로브를 메뉴에서 종료한 뒤 한 번에 하나만 실행합니다.

```bash
bash scripts/make-app.sh probe release
open 'build/Dock City Overlay Probe.app'
```

Bundle ID는 `com.metaparodica.DockCity.overlayProbe`입니다.
본 앱과 별도로 손쉬운 사용 승인이 필요하며 사용자가 시스템 설정에서 직접 승인합니다.

터미널에서 번들 내부 실행 파일을 직접 실행하면 부모 프로세스의 TCC 주체로 판정되어 실패한 사용자 사례가 있습니다.
같은 앱 번들을 LaunchServices로 실행하고 출력을 파일로 받습니다.

```bash
open -W -n --stdout /tmp/dock-city-probe-once.jsonl 'build/Dock City Overlay Probe.app' --args --once
cat /tmp/dock-city-probe-once.jsonl
```

`--once`는 창 없이 한 번 읽고 종료합니다. 대화형 오버레이와 변화 로그는 다음처럼 실행한 뒤 메뉴에서 종료합니다.

```bash
open -W -n --stdout /tmp/dock-city-probe-changes.jsonl 'build/Dock City Overlay Probe.app' --args --log-changes --interval 0.2 --level 21
```

[고정 서명 안내](dock-city-validation.md#고정-로컬-서명)도 참고하세요.
`open -W` 종료 상태만으로 내부 성공을 판단하지 말고 출력의 권한·좌표 상태를 확인합니다.
도구 내부 `--once` 상태는 0=일부 좌표 유효, 2=권한 없음, 3=Dock 없음,
4=실패/불완전/유효 좌표 없음, 64=인자 오류입니다.

## 확인할 내용

- AX role/subrole과 실제 아이콘 사각형·오버레이 테두리를 대조합니다.
- 구분선·휴지통 미노출은 누락으로 기록하며 위치를 추측하지 않습니다.
- 오버레이 위 클릭·드래그·우클릭이 실제 Dock에서 처리되는지 확인합니다.
- 방향·확대·화면 이동·자동 숨김 시 좌표와 레벨 변화를 기록합니다.

AX 탐색과 폴링은 제한되며 읽기는 직렬 worker에서 실행됩니다.
항목 제목·역할·좌표와 Dock 창 정보가 로컬 표준 출력에 포함될 수 있습니다.
위 파일은 사용자 지정 로컬 로그이며 외부 전송은 없습니다.
종료 코드 0은 전체 시각·입력 검증 성공이 아닙니다. 현재 변경의 Mac 동작은 미확인입니다.
