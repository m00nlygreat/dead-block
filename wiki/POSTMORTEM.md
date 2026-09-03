---
role: "개발 중 겪은 문제와 근본 원인, 해결 과정의 회고 기록"
usage: "오래 걸린 버그나 재발 가능성이 큰 함정을 해결하면 원인·시행착오·정착한 해법을 남긴다. 다음에 비슷한 문제가 나왔을 때 되풀이하지 않기 위한 목적."
---

# POSTMORTEM

## 2026-09-02 (소음 디스크가 바닥에 안 보임 — 렌더링 깊이/GDScript 함정)

### 요구
플레이어 중심 소음 차트를 **반투명 채워진 원(디스크)** 로 그리되, **사람(플레이어/좀비) → 디스크 → 바닥** 순서로 보이게. 어떤 바닥에서도 디스크가 보여야 함.

### 시행착오 (모두 실패)
1. **원주 벽(원기둥 테두리)+지면 링** → 겹침·여러 층으로 보임.
2. **ImmediateMesh 중심-원주 삼각형 팬** → 매 프레임 `clear_surfaces()` 후 재생성하니 삼각형이 프레임과 어긋나 **피자 조각처럼 깨짐**.
3. **ImmediateMesh 대신 단일 CylinderMesh + `scale`로 반지름 제어** → 깨짐은 해결(메시 재생성 제거). 단, **`no_depth_test=false`면 불투명 지면에 묻혀 어떤 높이로 올려도 안 보임**. `no_depth_test=true`면 항상 보이지만 **사람까지 덮음**(사람이 디스크에 가려짐).
4. **Y를 올리기(0.04→0.15)** 만으로는 해결 안 됨 — 높이 문제가 아니라 **알파 블렌딩 투명 오브젝트의 깊이 특성** 때문.

### 근본 원인 (codex exec 지능 활용으로 파악)
- 단일 깊이 버퍼는 픽셀이 "바닥인지 사람인지"를 구분하지 못한다. `no_depth_test`를 켜면 바닥도 사람도 전부 덮는다.
- 올바른 정답은 **"깊이 테스트는 켜되, 깊이 쓰기는 끄기"**:
  - `no_depth_test = false` (깊이 테스트 켬) → 디스크가 바닥보다 살짝 위에 있으면 **바닥은 테스트에서 탈락**되어 디스크가 바닥 위에 보임.
  - `depth_draw_mode = DEPTH_DRAW_DISABLED` (깊이 쓰기 끔) → 디스크가 깊이 버퍼에 안 쓰이므로 **사람이 그 위에 있으면 사람의 깊이가 우선** → 사람이 디스크를 정상 가림.
  - 이 설정으로 **사람 → 디스크 → 바닥** 순서가 정확히 성립.

### 두 번째 함정 (층별 바닥)
- 디스크 위치를 `global_position = Vector3(x, 0.0, z)`로 **월드 Y=0에 하드코딩** → 플레이어가 Y>0인 층에 서면 디스크가 그 바닥 아래에 깔려 안 보임. 가장 낮은 층에서만 보임.
- 해결: 디스크 Y를 **플레이어 발치 Y + GROUND_Y**로 따라가게 변경.
  ```gdscript
  global_position = Vector3(
      player.global_position.x,
      player.global_position.y + GROUND_Y,
      player.global_position.z
  )
  ```

### 정착한 해법 (최종)
- 고정 단위 **CylinderMesh**(반지름 1)를 한 번 생성, `scale.x = scale.z = 반지름`으로 매 프레임 갱신 → 깨짐 없는 매끈한 원.
- 재질: `unshaded + transparency(alpha) + no_depth_test=false + depth_draw_mode=DISABLED + cull_mode=CULL_DISABLED`.
- 위치: 플레이어 발치 Y + GROUND_Y(0.15)를 따라감.

### 교훈
- 3D 반투명 오버레이를 "바닥 위엔 보이고 특정 오브젝트는 가리지 않게" 하려면 **깊이 쓰기(그리기)만 끄고 테스트는 유지**하는 것이 정석. `no_depth_test`는 성급한 선택.
- **절차적/다층 월드에서 오버레이 Y는 특정 리터럴이 아니라 대상 발치를 따라야** 한다.
- `render_priority`는 **투명 객체 간 순서만** 조정하지, 깊이 테스트 결과를 뒤집지 못함(depth testing overrules priority).
- codex exec(OpenAI Codex)를 Godot 렌더링 이론 질의에 활용해 근본 원인을 규명 — 단발 삽질 반복을 줄이는 데 유효.
