# AGENTS.md — 이 프로젝트에서의 작업 규칙

## 진행 방식 (필수 준수)

- **모든 응답은 한국어**로 한다.
- 한 번 시작한 작업은 **사용자가 확인할 때까지 끝내지 않는다.** 출력이 끊겼다면 즉시 이어서 완료한다.
- 구현이 끝나면 반드시 아래 순서로 마무리하고 **사용자의 명시적 승인("진행해" 등) 없이는 다음 작업을 임의로 시작하지 않는다**:
  1. 스모크 테스트 실행 (`godot --headless res://tests/*_smoke.tscn`)
  2. 결과 보고 — 무엇을 했는지, 어떻게 검증했는지(테스트 표)
  3. 게임 창 실행 후 **사용자가 무엇을 확인해야 하는지** 명시
  4. 대기 — 피드백 없이 다음 단계 진행 금지
- 테스트 실패·에러·한계는 숨기지 않고 그대로 보고한다.
- 커밋·푸시 요청 시 **기본적으로 작업 트리의 모든 변경사항(미커밋·untracked 포함)을 커밋에 포함**한다. 특정 파일을 걸러 내거나 제외하려면 사용자 명시 지시가 있을 때만. `AGENTS.md` 자체도 문서 수정이라 커밋 대상이다.
- 수치 조정 요청(각도, 속도, 내구도 등)은 적용 후 재검증까지 해야 완료로 본다.
- **사용자가 요청하지 않은 콘텐츠를 임의로 추가하지 않는다**(무기·컨테이너·아이템·적·맵 요소 등). 현재 게임에 존재하는 콘텐츠 범위는 `wiki/REQUIREMENT.md`가 기준이며, 추가·변경은 반드시 사용자 승인을 받는다.

## 기술 참고

- Godot 4.7.2 / GDScript / Forward+. 전체 계획은 `PLAN.md` 참조.
- 새 `class_name` 추가 시 반드시 `godot --headless --import`로 전역 클래스 캐시 갱신 후 테스트.
- `.tres` 파일은 UTF-8 **BOM 없이** 저장할 것.
- Kenney 에셋(CC0)은 `assets/` 하위에 팩명 폴더로 유지.
- 물리 레이어: 1 world / 2 player / 3 zombie / 4 interactable / 5 projectile.

## 디버그 실행 (필수 준수)

- **디버그 콘솔**: `autoload/debug_console.gd`. **`--debug-console` 인자로만 활성화**된다(`--debug`·`--console`도 동일). 인자 없이 실행하면 `/` 키 콘솔이 뜨지 않는다.
- `debug.ps1`(Windows) / `debug.sh`(Linux·macOS)는 `--debug-console --verbose`를 포함한 디버그 실행 래퍼다. 게임 내 **`/` 키**로 콘솔 토글.
- 디버그 무한 대기 방지: `--headless` 단독(GDScript) 실행은 `--path`·씬 없이 autoload가 로드되지 않는다. autoload(ItemDB·InventoryManager 등)가 필요한 검증은 **씬 기반 스모크 테스트**(`res://tests/*_smoke.tscn`)로 실행한다. `_ready`에서 `get_tree().quit()`가 headless에서 안 끝나 강제 kill로 이어질 수 있으니, 씬 종료는 `call_deferred("quit")` 또는 스모크 패턴(프레임 대기 후 quit)을 사용한다.
- 임시 `.gd`/`.tscn`의 untyped 값에 `:=` 타입 추론을 쓰면 파스 에러가 나므로 명시 타입을 붙인다(예: `var is_wpn: bool = item.is_weapon()`).

## 웹 빌드 호환성 (필수 준수)

- 배포 대상이 **웹(GitHub Pages)**이므로, 모든 변경은 웹 빌드에서도 동작함을 전제로 한다. 에디터(F5)에서만 확인하고 넘어가지 않는다.
- **폰트**: `SystemFont`는 웹에서 미동작(기본 폰트 폴백은 Latin/Greek/Cyrillic 전용 → 한글 미표시). 한글/다국어 표시는 번들 FontFile(`assets/fonts/NotoSansKR-Regular.otf`)을 쓴다. 새 UI·Label3D 씬에 SystemFont 사용 금지.
- **파일 시스템**: 익스포트하면 `*.tres`는 `*.tres.remap` 파일명으로 저장된다. `DirAccess` 목록에서 확장자(`.tres` 등)를 그대로 검사하면 전부 누락된다. `.remap`을 벗긴 뒤 **원래 경로로 `load()`** 한다(`autoload/item_db.gd`, `autoload/upgrade_manager.gd` 패턴). 스모크 테스트는 소스 기준이라 이 버그를 못 잡으므로, 리소스 디렉터리 스캔을 도입·수정하면 **PCK 프로브**(`--headless --main-pack`으로 익스포트 산출물 로드)로 재확인할 것.
- **렌더러**: 웹은 Compatibility(WebGL 2.0)로 동작한다. Forward+ 전용 렌더링 기능/셰이더는 웹에서 지원되지 않으므로 호환성을 확인한다.
- **스레드**: 웹 익스포트는 single-thread(`variant/thread_support=false`)다. `Thread`·`WorkerThreadPool` 사용을 피하고, 써야 하면 웹 폴백이 필수다.
- 새 기능/수정은 커밋·푸시 → GitHub Actions 재배포 → `https://m00nlygreat.github.io/dead-block/`에서 동작 확인까지 마쳐야 완료로 본다.
- 커밋·푸시 요청 시 **오프라인 빌드(Windows 데스크톱 익스포트)도 `builds/win64`에 함께 생성**한다.

## 위키 관리

- 이 저장소의 간단한 위키는 `wiki/`에 둔다.
- 위키 문서는 한국어로 짧고 명확하게 작성한다.
- `wiki/REQUIREMENT.md`는 현재 요구사항 요약의 유지본이다. 요구사항을 정리하거나 갱신할 때 이 파일을 함께 관리한다.
- `wiki/LOG.md`에는 프로젝트 관련 중대 결정사항, 새로 알아낸 사실, 방향 변경을 시간순으로 남긴다.
- 원본 자료 폴더는 사용자가 요청하지 않는 한 수정하지 않는다.
