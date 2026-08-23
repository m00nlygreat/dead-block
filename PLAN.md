# 프로젝트 계획서: "DEAD BLOCK" (가칭)

**탑다운 3D 좀비 아포칼립스 파밍 로그라이크**

- 엔진: Godot 4.7.2 (Forward+), GDScript
- 에셋: Kenney 무료 에셋 (전부 CC0)
- 문서 버전: 1.0 (2026-08-22 승인)

---

## 1. 게임 컨셉

- **한 줄 요약**: 좀비가 득실대는 도시에 들어가 물자를 털고 살아서 나오면 이긴다. 죽으면 처음부터.
- **핵심 루프**: `진입 → 파밍(수색/수집) → 좀비 조우·회피·전투 → 인벤 관리 → 탈출(추출) → 메타 성장 → 재도전`
- **파밍이 주력**: 전투보다 "무엇을 털고 어떻게 나올 것인가"의 판단이 중심. 수색은 시간이 걸리고 소음이 남 → 리스크/리턴 트레이드오프.
- **시점**: Camera3D를 피치 -85~-87° 로 고정한 3D 탑다운.

## 2. 기술 환경

| 항목 | 결정 |
|---|---|
| 엔진 | Godot 4.7.2, GDScript |
| 렌더러 | Forward+ (데스크톱) |
| 해상도 | 1920×1080, stretch = canvas_items |
| 물리 레이어 | 1:world / 2:player / 3:zombie / 4:interactable / 5:projectile |

**입력 맵**: WASD 이동, 마우스 조준·공격, E 상호작용(수색), Tab 인벤토리, Shift 달리기, R 리로드, Space 구르기, 휠 줌

## 3. Kenney 에셋 매핑 (전부 CC0 — 상업 이용 가능, 크레딧 불필요)

| 용도 | 팩 |
|---|---|
| 플레이어/좀비 | Blocky Characters (glTF, 애니메이션 포함, 색 변형으로 좀비 종류 구분) |
| 근접 무기/생존 도구 | Survival Kit (도끼·곡괭이 등, 애니메이션 포함) |
| 차량(추출존·거리) | Car Kit |
| 맵/건물 | City Kit (Suburban) + City Kit (Roads) + City Kit (Commercial) |
| 실내/수색 오브젝트 | Furniture Kit (선반·냉장고·서랍장 = 컨테이너) |
| 아이템 | Food Kit(식량), Furniture Kit(자원), Survival Kit(도구) |
| 분위기 소품 | Graveyard Kit |
| FX | Particle Pack |
| UI/아이콘 | UI Pack |
| 사운드 | Impact Sounds, Interface Sounds |

> ⚠ Kenney의 3D 총기 팩(Weapon Pack)은 현재 배포 중단 → **M3 전투는 근접 중심**으로 설계하고, 화기는 커스텀 저폴리 모델 또는 Blaster Kit 리텍스처로 M6 이후 검토.
> 전부 CC0. `assets/<팩명>/` 아래 정리 완료 (2026-08-22 기준 13팩).

## 4. 핵심 시스템 설계

### 4.1 카메라 (`scenes/player/camera_rig.tscn`)
- Node3D(플레이어 추종, lerp) → Camera3D `rotation.x = -86°`, 거리 9m, FOV 45
- 휠로 6~13m 줌.

### 4.2 맵 생성 (로그라이크 = 런마다 변경)
- 청크 기반 절차 생성: seed → 거리 격자 위에 건물 프리팹(주택/상가/병원 등 5~6종) 배치 → 건물 내부에 방+컨테이너 자동 배치
- 구역 3단계 난이도: 주택가(식량) → 상업가(무기·부품) → 병원·연구소(희귀 아이템)
- 탈출 차량(추출존) 을 맵 외곽 1~2곳에 배치. 도착해야 파밍한 물자가 확정.
- 충돌: 건물 프리팹에 StaticBody3D 내장. NavigationRegion3D는 청크 단위 베이크.

### 4.3 파밍 시스템 ★핵심★
- `Interactable` 공용 인터페이스: 쓰레기통·선반·냉장고·트렁크·시체·자판기
- 수색 = 홀드 E, 1.5~2.5초 진행바, 완료 시 NoiseEvent 발생(반경 8m 좀비 어그로)
- `LootTable.tres` (Resource): `{item_id, weight, qty_min/max}` 배열, 희귀도 5단계(common→legendary)
- 컨테이너는 런당 1회. 희귀 컨테이너(금고·의료함)는 열쇠/도구 필요

### 4.4 아이템/인벤토리
- `ItemData.tres`: id, 이름, 타입(무기/소모품/자원/부품/키), 스탯, 무게, 아이콘
- 인벤토리: 무게제 슬롯 20칸, 퀵슬롯 4개
- 제작: 간단 레시피 5~8개 (밴디지=천+소독약, 몰로토프=병+천+연료 등)

### 4.5 전투
- 근접: Area3D 스윙 / 화기: RayCast3D 즉발 + 탄약 소모 + 대량 소음
- 무기 내구도 존재 → 예비 무기를 들고 다닐지 선택
- 피격: 넉백 + 머티리얼 플래시

### 4.6 좀비 AI (유한상태머신)
- `IDLE → WANDER → CHASE(인지) → ATTACK`
- 인지 규칙: 시야(반경 10m, 시야각 100°, 가림 판정) + 소음(NoiseSystem 이벤트 구독)
- NoiseSystem(오토로드): emit_noise(pos, radius, priority) → 주변 좀비 investigate
- 종류: 일반 · 빠름 · 탱크 (Blocky Characters 색/스케일 변형)
- 성능 목표: 동시 활성 50마리, 화면 밖 좀비 tick 주기 낮춤

### 4.7 생존 스탯 & 런 구조
- HP / 허기(감소 시 회복력 저하) / 스테미나(달리기)
- 사망 시: 런 중 수집물 전부 소실, 메타 재화(스크랩)만 보존
- 허브 씬: 스크랩으로 영구 업그레이드(12~15개 퍼크)

## 5. 프로젝트 구조

```
res://
├─ assets/            # kenney 팩 원본
├─ autoload/          # game_state.gd, inventory_manager.gd, noise_system.gd, item_db.gd
├─ scenes/
│  ├─ core/           # main_menu, hub, run_root
│  ├─ player/         # player.tscn, camera_rig.tscn
│  ├─ zombie/         # zombie_base + 변형 3종
│  ├─ world/          # map_gen, chunk_*, building_*, prop_containers
│  ├─ items/          # item_pickup, loot_container
│  └─ ui/             # hud, inventory_ui, loot_progress, meta_upgrade
├─ resources/
│  ├─ items/*.tres    # ItemData
│  └─ loot_tables/*.tres
└─ scripts/
```

## 6. 마일스톤

| 단계 | 내용 | 검증 기준 |
|---|---|---|
| M0 셋업 | Godot 프로젝트 생성, Kenney 에셋 임포트, 입력맵, 폴더 구조 | 에셋이 씬에 올라가고 빌드 OK |
| M1 이동/카메라 | 8방향 이동+애님, -86° 탑다운 카메라, 마우스 조준 회전, 줌 | 부드러운 탑다운 조작감 |
| M2 파밍 코어 | 컨테이너 상호작용+진행바, LootTable, 인벤토리 UI, 줍기/버리기 | 털고 담는 루프 완성 |
| M3 좀비/전투 | FSM AI, 소음 시스템, 근접+화기 전투, 피격/사망 | 소음에 좀비가 몰려오는지 |
| M4 맵 생성 | 청크 절차 배치, 충돌, 네비베이크, 추출존 | 런마다 다른 맵에서 플레이 |
| M5 런 사이클 | 허브, 메타 업그레이드, 사망→재시작, 구역 난이도 | 반복 플레이 동기 확보 |
| M6 폴리싱 | 사운드/FX, HUD 마감, 밸런스, 최적화 | 안정 60fps @ 좀비 50 |

**현재 위치: M0~M3 완료 (스모크 테스트 통과), 다음 M4 절차적 맵 생성**

## 7. 리스크 & 대응

1. Blocky Characters 애님 임포트 문제 → M1 초기에 애님 트리 확인, 실패 시 코드 기반 애님 대체
2. 좀비 다수 성능 → NavigationAgent 대신 steer+separation 혼합, 오프스크린 저빈도 tick
3. 탑다운에서 아이템 식별성 → 바닥 아이템은 Sprite3D 빌보드 아이콘 병용
4. 스코프 관리 → 멀티플레이·보스·날씨 전부 보류. 파밍 루프 검증이 1차 관문
