# 庄园 V3 模型接入（2026-10-03）

工作包 A-MANOR-V3 / 负责人本任务 / 独立对抗复核待分配。
用户交付《死光庄园_完整建模包_V3_20261003》并要求替换主工程原有庄园建模场景，
同时限定先不影响主 game 工作区：本轮全部改动位于独立 worktree
`.tools/worktrees/manor-v3`（分支 `feature/manor-v3-scene`，基线 `8b22604c`）。

## 交付来源与既有契约

- 源文件：`死光庄园_完整建模包_V3_20261003/manor_v3/manor_furnished_v3.blend`
  （Blender 4.5.14 LTS 制作，sha256 `1026844475f00669d681444a2ab7009c21c2e5fe4913f8c159b2fa820962d821`）。
- 交付包自述：5404 对象 / 5113 网格 / 334308 基础三角面 / 96 材质 / 38 张打包贴图；
  包内没有可用的游戏 GLB，也没有碰撞、导航、LOD 或性能验证。
- 既有契约（不得随美术资产变更）：十扇门的铰链空物体名、`ManorWalkCollision-colonly`
  走行网格、Blender `(x, y, z) -> Godot (x, z, -y)` 坐标映射、侧门/地窖/门廊三条走行坡道。
  这些都是 ADR 0008 与 `presentation/manor/world.tscn`、`bootstrap/manor_interactions.gd`
  已经依赖的接口，本轮不修改。

## 导出流程

`scripts/assets/export_manor_v3.py` 把交付的 .blend 转成游戏用 GLB，并以只读方式对待源文件
（不保存 .blend，导出前后校验 sha256）：

```powershell
& "D:\SteamLibrary\steamapps\common\Blender\blender.exe" -b --factory-startup `
    --python scripts/assets/export_manor_v3.py -- `
    --source "<解压目录>\manor_v3\manor_furnished_v3.blend" `
    --target game/presentation/manor/manor.glb `
    --report output/manor_v3/export_report.json
```

本机 Blender 为 5.2.2 LTS（Steam 版），交付包作者使用 4.5.14 LTS；导出结果已与本包
`preview_overview.png` 逐项目视比对（见下）。

导出取舍：

- 保留 `MS_01`–`MS_10` 结构、`Furniture`、`Props`、`V3_Architecture`、`V3_UpperDecor`、
  `V3_Exterior`；屋顶、天花板、上半墙和上墙装饰在 .blend 中只是为剖切预览而隐藏，
  游戏场景与既有导出一样保留这些结构。
- 排除 `MS_11_Lights_Cameras`、`V3_Lighting`、`V3_Cameras`、`MS_12_Plan_Labels`、
  `MS_13_Roof_Source`：行走场景自带灯光，作者灯光/相机与平面标注不属于游戏资产。
- 十个 `_BrassHandle` 门把手不进视觉、也不进走行网格（ADR 0008 要求把手移除）。
- 走行碰撞只取结构集合 `MS_01`–`MS_06`、`MS_08`–`MS_10`，跳过楼梯踏步、门槛、地板条，
  再补上三条连续坡道；家具、道具和墙面装饰不参与碰撞。
- 应用倒角/加权法线修饰器（用户选定完整保真档）：边缘高光与作者渲染一致，
  代价是三角面与体积约为不应用修饰器的 2.8 倍。

导出结果（`artifacts/manor_v3/export_report.json`）：

| 项 | 数值 |
| --- | --- |
| GLB 体积 | 86 058 980 字节（82.1 MiB） |
| 视觉对象 / 网格 | 5329 / 5096 |
| 三角面 | 1 328 904 |
| 材质 / 内嵌贴图 | 77 / 36（19 组 basecolor+normal，512×512） |
| 走行碰撞三角面 | 60 756（结构 613 个网格 + 3 条坡道） |
| 门铰链 | 10 个，名称与既有清单完全一致 |
| 灯光 / 相机节点 | 0 |

## Godot 侧改动

- `game/presentation/manor/manor.glb` 由新导出整体替换；`world.tscn`、走行、交互、
  房间识别、NPC 与物品代码都未改（它们只依赖上表列出的稳定契约）。
- 该 GLB 的导入参数保持 `gltf/embedded_image_handling=1`（抽取贴图），因此 Godot 会把
  36 张内嵌贴图落成同级文件 `manor_*_{basecolor,normal}.png`；这些是场景依赖，必须一起提交。
- 同时删除旧 GLB 抽取出来的 11 张 `manor_Godot_MS_*.png` 及 11 个 `.import`：
  它们只被被替换的 `manor.glb` 引用，`*.tscn`/`*.tres` 中 0 引用。
  需要整体回退时用 `git checkout <旧提交> -- game/presentation/manor` 一并恢复。

## 验证

全部在 worktree 内运行，固定引擎 4.7.2.stable.official.ed1daf0bf。

- 静态检查：`check_architecture.ps1` 128 个源/场景文件通过；3 项架构负向用例通过。
- 资源导入：`--headless --editor --import` 退出码 0，12.5 s 完成，生成 39.8 MiB
  `manor.glb-*.scn` 与 36 张抽取贴图 `manor_*_{basecolor,normal}.png`。
- 行为测试：`--headless --script res://tests/run_tests.gd` 退出码 0，
  `AIRPG_TESTS: 354 checks, 0 failures`（BASE 95 / ARCHIVE 62 / MANOR 93 /
  NPC_RIG 12 / CHARACTER 38 / INTERACTION 54）。MANOR 与 INTERACTION 套件会实例化
  真实 `manor_play.tscn`，其中打印 `AIRPG_STRUCTURE_WALK_READY`，说明十扇门绑定、
  `ManorWalkCollision` 门叶剔除与拾取目标在新模型上仍然成立。
- 启动：`--quit-after 5` 退出码 0 并出现 `AIRPG_BOOT_READY`。
- GLB 结构自检（本地未入库脚本，随 artifacts 保留）：10 个铰链、10 个门叶、
  `ManorWalkCollision-colonly` 齐全，把手 0、灯光/相机节点 0。
- 视觉验证：把导出的 GLB 重新导入 Blender 渲染，房间、家具、木地板、地毯、窗与石材
  外观与交付包 `preview_overview.png` 一致；另用真实窗口（RTX 4060 / OpenGL 兼容）
  运行 `tests/manor/capture_main.gd` 截取游戏内走廊视图，模型、光照与 HUD 正常。
- `./scripts/verify.ps1` 未原样跑通：它在 import 步骤因本机既有的
  `ERROR: Failed to read the root certificate store.`（`os_windows.cpp:2582`）
  触发错误输出判定而中止。该行与本仓库内容无关——用一个只有 `project.godot` 的空工程
  执行同样的 `--editor --import` 会复现同一行；空工程对照结果记录在本轮工作区日志中。
  本轮按 `docs/handoff.md` 既有做法用逻辑等价驱动执行三步（相同参数、相同错误正则与
  完成标记，仅登记该环境行），未放宽任何其他判定。

## 已知限制与复核重点

- 首次导入事故：第一轮三步验证时，import 步骤曾有一个 Godot 进程卡死（单线程空转、
  日志文件被独占、无新写入），当时未定位到原因就已中断会话；残留进程被强制结束后，
  删除 `game/.godot` 重新导入即恢复正常（12.5 s，可重复）。复核时若要重跑，
  先确认没有残留 Godot 进程占用 `game/.godot`。
- 未做 LOD、合批与运行性能验证：5330 个节点、133 万三角面、5244 个网格实例是
  本轮导入的真实规模，逐帧绘制调用是主要风险，不是三角面。Godot 侧使用的
  `meshes/generate_lods=true` 只是自动 LOD，不等于已验收的性能预算。
- 家具、道具、墙面装饰与室外庭院装饰没有碰撞，玩家可以穿过它们；只有结构、
  窗、门和三条坡道参与走行。V3 新增的室外石砌小路不在碰撞内。
- 作者灯光与相机关闭后，室内照明仍依赖 `world.tscn` 现有人工点光；
  若房间观感偏暗，属于场景灯光调整，不是模型导出缺陷。
- 未在导出包、低配机器、不同 DPI 上验证；未运行独立对抗复核。
- 交付包内 `scripts/fix_*.py`、`review_render.py` 未执行，其记录的家具遮挡与地毯
  修订不在本轮资产内。
