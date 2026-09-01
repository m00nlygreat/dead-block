class_name UpgradeData
extends Resource

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var max_level := 5
@export var weight := 10.0
## 기본 구매가(코인). 보유 단계마다 ×(단계+1)로 증가
@export var cost := 10
## 플레이어 적용 규칙 식별자(Player.apply_upgrade 참조)
@export var effect_id := ""
## 레벨별 적용값(인덱스 = 습득 차수 - 1)
@export var values: Array[float] = []
