# 庄园建模导入（V3 → V4）

工作包 A-MANOR（模型导入）与 C-MI2（门净空）之后的模型线；负责人本任务，独立对抗复核待分配。
本文记录当前游戏使用的庄园模型来源、导出取舍、与游戏契约的对应关系，以及 V4 相对 V3 的变化。

## 当前资产

- 分支：`feature/manor-v3-scene`（worktree `.tools/worktrees/manor-v3`，基线 `8b22604c`）。
- 当前模型：`game/presentation/manor/manor.glb`，来自
  `output/manor_v4/manor_repaired_v4.blend`（V4 修复版，Blender 5.2 打开并导出；
  该 blend 由另一轮工作从 V3 交付包重建，改动清单见 `output/manor_v4/changes.json`）。
- 历史模型：V3 交付包 `死光庄园_完整建模包_V3_20261003`（作者 Blender 4.5.14）已由 V4 取代，
  V3 导出记录保留在 git 历史与本文件早期版本中。

## 导出流程

`scripts/assets/export_manor.py` 把交付的 .blend 转成游戏用 GLB，源文件只读（导出前后校验 sha256）：

```powershell
& "D:\SteamLibrary\steamapps\common\Blender\blender.exe" -b --factory-startup `
    --python scripts/assets/export_manor.py -- `
    --source "output/manor_v4/manor_repaired_v4.blend" `
    --target game/presentation/manor/manor.glb `
    --report output/manor_v4/export_report.json
```

导出取舍（脚本内为常量，改模型前先读 `docs/adr/0008-scoped-interactions.md`）：

- 保留 `MS_01`–`MS_10` 结构、`Furniture`、`Props`、`V3_Architecture`、`V3_UpperDecor`、
  `V3_Exterior`，以及 V4 新增的 `V4_EmptyCellar`、`V4_ConcealedEntrance`。
  屋顶、天花板、上半墙在 .blend 里只是为剖切预览而隐藏，游戏与既有导出一样保留这些结构。
- 排除 `MS_11_Lights_Cameras`、`V3_Lighting`、`V3_Cameras`、`MS_12_Plan_Labels`、
  `MS_13_Roof_Source`、`V4_Collision_Optional` 与场景级的评审灯光/相机：
  行走场景自带灯光，作者光照、相机与平面标注不属于游戏资产。
- 十个 `_BrassHandle` 门把手不进视觉也不进走行网格（ADR 0008 要求移除）。
- 一个 `ManorWalkCollision-colonly` 承载走行网格：结构集合（跳过楼梯踏步、门槛、地板条）
  加三条连续坡道——侧门、前廊两条手工坡道，以及取自交付包的
  `V4_CellarRamp-colonly` 平滑地窖坡道。
- 可撬地板（`V4_PryFloorboards`，17 块板 + 3 根托条）**不进入**走行网格，改由独立的
  `V4_PryFloorCollision-colonly` 承担碰撞：走行网格在该处留洞，将来撬开时删掉这块
  碰撞体连同视觉根即可露出楼梯——这正是 V4 元数据里写的 `on_open` 约定。

## V4 相对 V3 的变化（游戏侧已同步）

| 变更 | 内容 | 游戏侧对应 |
| --- | --- | --- |
| 地窖重做 | 旧地窖（发电机、配电柜、工作台、16 级踏步、挡土墙）全部移除，改为空房间 + 平滑斜坡；地面由 -2.72 变为 -3.23，下行方向由向南改为向北 | `CELLAR_SPAWN` → `(-3.6, -3.19, -7.4)`；地窖补给点 → `(-2.9, -2.99, -9.5)`；`manor_room_map` 新增按高度判定的坡道区；MANOR 地窖用例改走 V4 自己的验证路线 |
| 可撬地板 | 楼梯口被 17 块可撬地板 + 3 根托条盖住（`closed_by_default`，`required_tool: crowbar`），撬开后才露出楼梯 | 碰撞已按上节拆成独立碰撞体；**撬棍交互本身尚未实现**，地窖在游戏里暂时只能走 B 键捷径进入 |
| 对称门 | 十扇门重建为无把手、正反一致的叶片与内嵌门板，并携带 `closed_angle_rad`、`angle_open_deg`、`raycast_both_sides`、`door_leaf_thickness_m` 等元数据 | `manor_interactions._door` 改为按模型自述姿态绑定（见下） |
| 表面分层 | 天花板下降 14 mm，基础与毛地板移到板面之下 | 无代码影响；走行网格按既有规则跳过地板条、使用毛地板 |
| 材质 | 程序砖材质换成 V3 已打包的 `DL_brick`；贴图由 36 张减为 34 张（移除 copper） | 抽取贴图按 34 张同步，删除 2 张残留 |

**门姿态绑定**：V3 把门叶做成“已打开”姿态，游戏用清单里的关闭角；V4 把门叶做成“关闭”姿态并
把摆幅写进元数据。`manor_interactions._door` 因此按 `angle_open_deg` 是否存在分支：有元数据时
以模型的自带姿态为关闭姿态、摆幅取元数据（76°/82°），无元数据时沿用旧约定。开门方向仍由
`_open_yaw_for_player` 按玩家所在侧选择，保证“紧贴门也能开门”。

**走行网格门叶预算**：V4 的走行网格把十扇关闭门叶连同内嵌门板一起烘进去，运行时
`imported_door_collision` 仍按门叶包围盒剔除，每扇门 540–726 面，因此
`MAX_FACES_PER_DOOR` 由 550 调整为 900（`MIN` 仍为 200，保留下限以继续防错配）。

## 验证

固定引擎 4.7.2.stable.official.ed1daf0bf，全部在 worktree 内：

- 架构检查 131 个源/场景文件通过、3 项负向用例通过（删除临时诊断后为 128）。
- `--editor --import` 退出码 0；`manor.glb` 82.1 MiB，5251 视觉对象、130.7 万三角面、
  61 材质、34 内嵌贴图、69 204 走行碰撞三角面、10 个铰链、10 个门叶、0 把手、0 灯光/相机节点。
- `res://tests/run_tests.gd`：`AIRPG_TESTS: 379 checks, 0 failures`
  （BASE 95 / ARCHIVE 62 / MANOR 118 / NPC_RIG 12 / CHARACTER 38 / INTERACTION 54）。
  MANOR 新增/改写：十个门叶存在 + 运行时剔除接受走行网格、十扇门紧贴开门、有人站在开启弧
  仍阻挡、关闭地板盖住楼梯口、撬开后坡道上下行、新地窖地面承重。
- `--quit-after 5` 出现 `AIRPG_BOOT_READY`；真实窗口（RTX 4060 / OpenGL 兼容）截图
  `artifacts/manor_v4/game_hall_v4.png` 显示 V4 走廊、关闭门扇与交互提示正常。
- `./scripts/verify.ps1` 仍只被本机既有的根证书读取失败挡住（空工程同样复现），
  其余判定未放宽；详见 `docs/handoff.md` 对应条目。

## 已知限制与复核重点

- 可撬地板只有资产与碰撞，**没有撬棍交互**：地窖走行、补给与线索在运行时暂不可达，
  只能靠 B 键捷径；接撬棍工作包时需要新增交互类型、处理器与失败路径测试。
- 走行网格仍是单一凹多边形，撬开后无法局部移除，因此地板碰撞才单独拆出；
  若将来要支持“重新盖上”，需要可开关的碰撞体而不是一次性删除。
- 未做 LOD、合批、显存与帧率验收；5253 个节点、130 万三角面的绘制调用仍是主要风险。
- 家具、道具、墙面与庭院装饰无碰撞；室外新增石路不在走行网格内。
- 未做导出包、低配机器与不同 DPI 验收；独立对抗复核待分配。
