# 庄园预设交互

## 本轮：两步拾取 / 发电机煤油门槛 / 撬开三段式 / 木架挂东墙 / 玻璃半透明（2026-10-04）

### 拾取物：先看，再收（8 件统一，钥匙不例外）

用户定稿「B 两步，所有拾取物」。每一件带叙事文案的拾取物现在要**两次 F**：

| 次 | 动作键（提示行）| 发生什么 |
| --- | --- | --- |
| 第 1 次 | `interaction.inspect`「细看」 | 出该件的叙事文案；**不产生领取回执、不进背包、不动 revision**，物件留在原地 |
| 第 2 次 | `interaction.pickup`「拾取」 | 才 `claim_pickup` 进手记；**同一刻把文案从层上摘掉** |

- 没有文案的拾取物（例如演示立方体）仍然**一次 F 直接拾取**，形状未变 —— 闸门是「有没有话要说」，
  不是「是不是拾取物」。
- 文案消失**不靠计时器**：领走物品时清空，可断言、无竞态。（早先设想的「显示 N 秒自动淡出」已回退。）
- 实现分两层：
  - `application`：`PickupInteraction` 多一个 `_examined` 阶段与 `narration()`；
    `read()["caption_key"]` 仍是**提示行**要展示的键，`narration()` 才是**已经说过什么**。
  - `presentation/items`：`items/world/world_item.gd` 只跟 `narration()` 比较，且仅在
    `_captions != null` 时发布。
- **为什么两个字段要分开**：`PickupInteraction` 会被**任何** inventory 变化刷新（`changed` 连到每个
  handler），所以「某件物品被捡走」会让**所有** world item 刷新一次。若视图按 `read()` 的字段发布，
  每捡一件东西都会把**别的**物件那句文案重新打上屏幕。
- 独占契约不变：文案层每个节点 `MOUSE_FILTER_IGNORE`、不 `release_pointer()`、
  不 `set_ui_blocked(true)`（见下方「独占状态」小节）。

### 发电机：必须携带煤油罐才能启动

| 阶段 | 提示行 | 文案 |
| --- | --- | --- |
| 未检查（第 1 次 F）| `[F] 检查 · 发电机` | 出检查文案 `inspect.device.generator` |
| 已检查、**手上没有** `kerosene_bottle` | `[F] 启动 · 发电机` | 启动被拒，失败码 `GENERATOR_NEEDS_KEROSENE` → 提示行出 `interaction.need_kerosene`「似乎没有机油了呢」；**检查文案仍在屏上**（拒绝不是一次操作，`_operated` 不动、revision 不动）|
| 已检查、**携带** `kerosene_bottle` | `[F] 启动 · 发电机` | 正常启停，`Running` 灯亮，检查文案收起 |

- 判定走背包端口**只读**的 `holds()`：**不要求装备到手上**，**本轮不消耗煤油罐**
  （「倒进油箱」属推迟的供电进度，用户可随时改成消耗）。
- 门槛是**可选构造参数**（`DeviceInteraction(inventory, required_item_id, refused_code)`），
  不带参数时行为与从前逐字一致。

### 地窖入口撬开：三段式

| 段 | 行为 |
| --- | --- |
| 没带撬棍 | 拒绝，失败码 `PRY_NEEDS_CROWBAR` → `interaction.need_crowbar`「徒手好像打不开呢」；**不出**成功文案 |
| 携带撬棍、第 1 次 F | 盖板消失、挡楼梯口的碰撞层置 0，并出**成功文案** `interaction.pry.done`（三行，用户授权代写）|
| 再按 F | 入口已单向打开，不再占准星、返回 `ALREADY_UNLOCKED`，**不再重复成功文案** |

对象名 `interaction.pry.cellar = "通往地下的盖板"`、动作名 `interaction.pry = "撬开"`（均已定稿）。

### 医务柜玻璃：运行时覆盖材质，不动 `.glb`

- 交付模型的玻璃渲染不透明，柜里的日记看不见。**不改 `.glb`**：运行时把两个玻璃面的材质换成
  半透明覆盖材质。
- 两个玻璃网格**实测名字**：`Study_MedicalCabinet_Glass`、`Study_MedicalCabinet_Glass_001`
  （各 0.61 × 1.58 × 0.014 m，交付材质名 `DL_glass`）。
- 识别方式是**网格名前缀 或 材质名**，**不靠子节点下标**。
- 覆盖材质 `presentation/manor/cabinet_glass.tres`：`transparency = TRANSPARENCY_ALPHA`、
  `albedo_color = (0.72, 0.85, 0.86, 0.30)`、`depth_draw_mode = DEPTH_DRAW_DISABLED`（避免透明面互相
  遮挡）、`cull_mode = CULL_BACK`、`roughness = 0.08`、`metallic = 0.2`。
- **玻璃网格没有碰撞体**，所以不影响准星；解锁后「准星从柜子交接给日记」与「直接瞄柜里的日记」
  两条路径都成立。

### 地窖木架：挂在楼梯对面的东墙

- 用户要求「挂在地窖的墙上」并定稿「楼梯对面那面」。实测 `V4_Cellar_Stair` 占满西侧
  （`x -5.890..-4.410`），因此对面是**东墙 `x = -1.582`**。
- 两块板（模型 `items/models/single_wood_shelf.glb`）沿 z 排布、`SHELF_YAW = -PI/2`、
  板深**非等比放大 1.35×**（煤油罐 0.28 m 的瞄准体 + 0.235 m 方截面罐体所需的最小深度；
  详见 `docs/handoff.md`）。
- 地窖除发电机外的 6 件（铜线圈 / 绝缘带 / 手提灯 / 煤油罐 / 保险丝 / 扳手）**全部站到板面上**，
  坐标与离墙余量表见 `docs/handoff.md`；全模型 AABB 扫描 0 穿插。
- 实拍：`docs/captures/manor_props_cellar_shelf.png`（**地窖未加灯，道具很暗**）。

### 实拍

| 文件 | 内容 |
| --- | --- |
| `docs/captures/manor_props_kitchen.png` | 厨房台面上的收音机，提示行 `[F] 细看 · 收音机` |
| `docs/captures/manor_props_cellar_shelf.png` | 东墙上的木架与架上道具，提示行 `[F] 细看 · 手提灯` |

本轮 C-MI1：10 扇门的开关和三个占位物品的拾取。开发与正式剧情内容仍分离。
角色原型内存 v2 及设计理由见 ADR 0008。

## 试玩步骤

打开主 game/project.godot，F5 → 开始游戏 → 死光 → 进入庄园原型。

1. 出生在侧门外，门初始关闭。走近后用准星对准门扇，看到「[F] 开门 · 侧门」后按 F。
2. 进入走廊；转身对准已打开的门叶或附近的扩大射线目标再按 F 关闭。门应平滑旋转、关闭后挡路，打开后恢复通行；动画期间不能重复触发。
3. 站在门扇将要经过的位置尝试关闭；应提示后退，门和状态保持不变。
4. 侧门走廊地面上有绿色补给立方体。稍微低头、走近、对准，按 F；物品消失。
5. E → 随身物品，未使用/丢弃前补给应从 3 增至 5。连续按/按住 F 不重复增加。
6. 接待室另有工具 +1，B 到地窖可找到关键物品 +1。关键物品沿用不可丢弃规则。
7. 远离目标、隔墙、打开 E 面板或 Esc 释放鼠标时不能交互；关闭面板/单击后恢复。
8. 背包演示重置不恢复已拾取立方体；R/B 不重置门和拾取。F1 返回再进入才新建整个会话。
9. 接待室壁炉前的地板上有一只金属箱。对准它按 F：浮现第一段观察文字；再按一次 F：箱子被拿到手上并浮现第二段；第三次 F：箱子回到原处、文字消失。全程鼠标保持捕获，背包里**不会**出现这件东西。V4 模型里原本烘焙在壁炉边的静态铅箱已由启动流程在运行时移除。
10. 接待室地上的钱包：第一次 F 浮现第一段；第二次 F 取出照片——屏幕正中显示人脸大图、浮现第二段，照片也拿在手上；第三次 F「收进笔记本」，照片进「随身物品」，钱包回到地面。之后再看钱包只有两段：细看（仍是第一段文字）→ 放回原地，**不会**再出现照片和第二段文字。
11. 书房（大房间东侧角落，x≈7.56、z≈-0.29）的**医务柜**：柜子锁着。没有钥匙也没有撬棍时对准它按 F 只会出现「上锁了。用什么办法打开呢？」，柜子保持上锁，柜里的日记**瞄不到**。捡到钥匙（接待室地面 `(-5.20, -0.025, 1.60)`，正对通往走廊的门口）或撬棍后再按 F：开锁成功，提示行从「[F] 开锁 · 医务柜」换成「[F] 细看 · 医生日记」，准星这时才落到柜里的日记上。开锁**不消耗**钥匙或撬棍。
12. 柜里的医生日记（隔着玻璃能看到位置但**看不到本体**，见下）：F → 引言（「日记的大部分页面是空的……」）；F → 日记到手、合着的皮面换成**摊开的新模型**，浮现第一段；F → 第二段；F → 第三段；F → 「收进笔记本」，日记进「随身物品」，摊开本收回柜里、皮面重新合上。收进之后再看它只剩两段：摊开重读第一段 → 摊开但**没有正文** → 合上回柜，永远不会第二次进袋。
13. 本轮的十件道具见下一节：八件可拾取（拾到时各自浮现一段文案，提示行仍是「[F] 拾取 · ⋯」）、厨房灶台旁的收音机（只可观察、**不进背包**）、地窖里的发电机组（第一次 F 是「[F] 检查 · 发电机」+ 检查文案，之后才是启停）。
14. **地窖入口**（艾米莉亚书房地板上的盖板，`x ≈ -5.15, z ≈ -9.9`）：准星对上去是「[F] 撬开 · 地窖入口盖板」。**没带撬棍**时按 F 被拒，提示行出现「需要撬棍。」，盖板与它的碰撞一动不动。**背包里有撬棍**（不必拿在手上）时按 F：盖板消失、挡住楼梯口的那块碰撞体退到 0 层，脚下的楼梯井就露出来了，可以自己走下去（也可以继续用 B 快捷键，那是保留的开发捷径）。撬开后入口不再占准星，再按 F 也不会重复触发。

按 F 没提示时，将准星对准门扇附近或立方体而非门框/墙壁，并靠近到 2.4 米内。
已兼容主工作区新增 NPC 问候：门/物品命中时优先，否则继续原 F 交谈；交谈中不能开关门或拾取。
门在约 0.42 秒内平滑旋转，射线目标随门叶一起转动，物理门叶保持较薄的实际阻挡范围；游戏用庄园模型的十个门把手已移除，无音效。当前用有限次 actor 形状采样检查玩家/NPC，不承担小型物体的完整连续扫掠模拟。

紧贴门扇（角色胶囊停在门叶面上，间隙约 2 毫米）时按 F 仍然开门：净空只把「扫掠过程中新增的接触」算作阻挡，本来就靠在门叶上的人不再否决开启——这正是走到门前最常见的姿势。反向依旧严格：门叶停下时若还压着人，或有人站在门叶将要经过的位置，返回 `DOOR_BLOCKED` 并提示后退；关闭方向不享受该容忍，行为与以前一致。回归见 `tests/manor/test_manor.gd`（十扇门紧贴开门，以及有人站在扫掠弧内仍然阻挡）。

当前模型为 V4：门叶在模型里是**关闭**姿态、摆幅写在铰链元数据（`angle_open_deg`），
`manor_interactions._door` 会据此绑定；V3 那种“门叶自带打开姿态”的模型仍然支持。
V4 还把地窖做成空房间 + 斜坡，楼梯口被 17 块可撬地板盖住（元数据 `required_tool: crowbar`）：
地板视觉与它的独立碰撞体 `V4_PryFloorCollision` 已交付，`ManorWalkCollision` 在该处留洞，
但**撬棍交互尚未实现**，运行时地窖只能靠 B 键捷径进入；接该功能时需要新的交互类型、
处理器与失败路径测试，不能靠场景名推断。

## 观察对象：接待室壁炉旁的金属箱（2026-10-03）

`manor.inspect.silver_urn` 是第一个**只可交互、不可拾取**的对象。它立在接待室壁炉前的地板上
（`(-7.26, -0.025, 0.90)`，节点 `rotation.y = PI/2`，长边平行西墙）。它没有领取回执、
不进「随身物品」，也永远不会从世界里消失。

| 层 | 本轮实现 |
| --- | --- |
| domain | `domain/exploration/inspect_state.gd`：`stage` 加单调 revision；`advance()` 在最后一段之后回绕到 0，所以「放回原地」不是第二份状态。段数不再写死：默认仍是三段（0 地面 / 1 已读 / 2 手持），多段对象（日记）自带段数与「从第几段起在手上」 |
| application | `application/exploration/interactions/inspect_interaction.gd` 实现既有 Handler：`read()` 返回恒为真的 `available`、`stage`、`revision`、`name_key`、`action_key`、`caption_key`；**完全不接触 `PickupInventory`**，因此结构上不可能产生领取回执 |
| presentation | `presentation/manor/inspect_object_view.gd` 只按 stage 搬动网格（地面原位 ↔ `Camera/HandSocket`）并驱动 `presentation/manor/inspect_caption.gd`；`inspect_caption.gd` 的每个节点都是 `MOUSE_FILTER_IGNORE` |
| bootstrap | `manor_interactions._place_inspect()` 显式登记稳定 ID、处理器、射线目标与本地化键；`_remove_lead_casket()` 在运行时移除 V4 模型里烘焙的静态 `Clue_LeadCasket` |

三次 F 依次是 `interaction.inspect`（细看，浮现第一段）→ `interaction.hold_to_look`
（拿在手上，浮现第二段）→ `interaction.put_back`（放回原地，清空文字）。文字键由用例给出
（`inspect.silver_urn.floor` / `inspect.silver_urn.held`），视图只负责显示，不写死文案。

### 独占状态：观察中必须能无条件退出来（2026-10-03）

手持观察阶段有一条**独立于准星**的输入通路，否则玩家一转头就再也放不回东西——这是实测到的
设计缺陷：网格被搬到手上，而射线目标 `Target` 还留在地面上，`read_focus()` 一旦为空，
F 就没有落点（旧实现还会掉进「和 NPC 交谈」分支）。

Handler 协议因此多了一个虚函数：

```gdscript
## 基类默认 false。为真时该目标独占玩家操作。
func exclusive() -> bool
```

`inspect_interaction.gd` 在状态说「现在在手上」时返回 true（`state.held()`；默认三段的 metal box /
钱包就是 `stage == STAGE_HELD`，多段的日记是在手的每一段）。`InteractionService` 相应新增：

- `read_exclusive() -> Dictionary`：返回当前独占目标的只读视图（`{}` 表示没有），含
  `target_id` / `revision` / `action_key` / `name_key`。处理器保持登记顺序，因此结果确定。
- `interact_exclusive(expected_revision) -> Result`：**唯一一条跳过 `_observe()` 的通路**。
  玩家已经拿着这个东西，再要求射线命中它的世界目标正是本条要消除的陷阱。其余守卫
  （`INTERACTION_DISABLED` / `INTERACTION_BUSY` / `TARGET_UNAVAILABLE`）照旧。

`bootstrap/manor_play.gd` 在独占期间：**移动冻结**（向 walk session 喂零向量，而不是
`set_ui_blocked(true)`——后者会让 `walk_input.active()` 变假，同时杀掉转视角与 F）、**转视角照旧**、
**R/B 快捷位移停用**、**交谈键停用**、交互键一律走 `interact_exclusive()`。
`interaction_hud` 在独占期间始终显示 `action_key`/`name_key`，所以「放回原地」这行提示
不会因为玩家看向别处而消失。

注意 `walk_input.blocked()` 是只读查询，专门用来断言「冻结移动不是靠屏蔽 UI 实现的」。

两条与既有契约一致的约束：

- **观察文字不释放鼠标、不 `set_ui_blocked(true)`。** 它只是一个忽略鼠标的 HUD 叠加层，
  鼠标捕获与 `walk_input.active()` 完全不受影响，所以「按住 F 推进三段」与门/拾取一样，
  只在鼠标保持捕获时可用。
- **射线目标留在原地。** 手持时只有网格挂到手上，`Target`(StaticBody3D, layer 8) 不动，
  因此箱子总能被重新对准并放回原处，也不需要第二套碰撞体或第二份摆放状态。

### 第二个观察对象：接待室地上的钱包 + 夹层里的照片（2026-10-03）

`manor.inspect.wallet` 复用同一套 stage，但**出行的不是整件物体**：三次 F 依次是
`interaction.inspect`（细看，浮现 `inspect.wallet.floor`）→ `interaction.take_photo`
（取出照片：钱包留在原地，`Model/Reveal` 挂到 `Camera/HandSocket`，浮现 `inspect.wallet.held`，
同时屏幕正中显示人脸大图）→ `interaction.keep_photo`（收进笔记本：照片进背包，钱包回地面）。
它同样不把**钱包**放进「随身物品」；进背包的是照片这件独立物品 `polaroid_photo`。

| 层 | 泛化点 |
| --- | --- |
| domain | `inspect_state.gd`：三段 stage + 回绕，另加一个「已被取走」标记；`empty_out()` 是它自己的、单独计一次 revision 的变更 |
| application | `inspect_interaction.gd` 的动作键改成构造参数（默认仍是金属箱那三个键），并可与「已取空时用的第二组键」分开；caption keys 亦然。只有显式 `enable_keep()` 过的对象才会碰 `PickupInventory`，两个对象不再共用提示 |
| presentation | `inspect_object_view.gd`：①**地面分支复原完整 `Transform3D`**（position + basis），不再清零旋转——导入网格的 origin 可能离可见几何几十米，清零会把物体搬到场景另一头；②`travelling_node` 决定哪个节点去手上（金属箱是自己的 `Model`，钱包是 `Model/Reveal`）；③节点回位时还原到**原始父节点**；④`reveal` 只在给了 reveal stage 时存在；⑤新增 `photo_center_view.gd` 的居中大图层 |
| bootstrap | `_place_inspect()` 显式传入 caption keys、action keys、出行节点、reveal stage、取空后的第二组 action keys 与人脸贴图；钱包不再走 `_place_item`，并在 `build()` 里 `enable_keep()` 到背包端口 |

落点 `WALLET_POSITION = (-6.5, -0.025, 2.0)`：接待室该处地面实测 `y = -0.025`，而
`wallet.glb` 场景里 authored 的 `Model` 变换（纯 −90°X 旋转 + 补偿性 origin 偏移，无缩放）已把
可见网格底面放到节点原点上，所以根节点直接站在地面上。**该 authored 变换不得改动**：换成带缩放
的矩阵会让网格飞到离原点 41 m 处（逐顶点 A/B 实测），这正是初版踩过的坑。`Target` 是抬到
钱包上方的瞄准柱体（`0.6 × 0.8 × 0.6`），因为俯视地面小物时射线太陡，紧贴地面的盒子实测打不到。
照片姿态由实测解出（见 `docs/handoff.md`），不靠猜朝向与比例。

### 取走照片之后：钱包只剩两段（2026-10-03）

用户要求：从钱包里拿出照片后**照片直接展示在屏幕正中央**、人脸全貌可见，并且照片**可拾取**、
**能放进调查笔记**；抽出后**再按一次 F 是把照片收进笔记本**，钱包同时回到地面；此后钱包**变空**。

| 行为 | 实现 |
| --- | --- |
| 照片成为真正的物品 | `items/data/polaroid_photo.tres`（`kind = key`，因此进背包即受保护、不可丢弃）+ 世界/手持场景；`bootstrap/character_preview.gd` 注册 `polaroid_photo`，于是它出现在手记的「随身物品」里 |
| 入袋只能走既有端口 | `inspect_interaction.enable_keep(inventory, source_id, item_id, quantity)` 注入 `PickupInventory`；stage 2 的 `execute()` 先查 revision，再 `claim_pickup()`，**领取被拒就原样返回、stage 一步不动**（原子性：不会出现「东西给了、状态没变」或反过来） |
| 钱包变空 | `inspect_state.empty_out()` 置位「已被取走」并把 stage 放回地面；此后 `advance()` 走 `0 → 1 → 0`，永远不会再回到 stage 2，因此既不再独占玩家操作，也不会再显示第二段文字 |
| 第二段文字不再出现 | caption keys 仍是同一张三段表（`["", floor, held]`），但已取空时 stage 只能到 1，`held` 那一格永远不可达 |
| 居中大图 | `presentation/manor/photo_center_view.gd`：`CanvasLayer` + `Control`，只用屏幕高度的中间一半（`anchor 0.25 ~ 0.75`）+ `TextureRect.EXPAND_IGNORE_SIZE` / `STRETCH_KEEP_ASPECT_CENTERED`，所以任何窗口比例下都**居中且不拉伸**。全部节点 `MOUSE_FILTER_IGNORE`；**不 `release_pointer()`、不 `set_ui_blocked(true)`**，与观察文字同一契约 |
| 提示不被压住 | 大图所在 `CanvasLayer.layer = 0`，低于 HUD 与文字层的 1：照片盖住屏幕中部，而「[F] 收进笔记本」这行提示必须仍然读得到 |

人脸贴图 `items/models/polaroid_photo_face.jpg` 是**裁切产物**：`polaroid_photo_0.jpg` 是一张
2048×2048 的 **2×2 图集**（四个象限是宝丽来的不同面），整张贴图直接上屏会出现四个面板，所以只取
右上象限、旋转 180° 后裁 `(230,170)-(950,1024)`。裁好的图由 bootstrap 显式 `preload` 后**注入**
给 presentation：presentation 层不允许引用 `items/` 下的资源（架构门禁按依赖方向检查）。

### 手部位姿是量出来的，不是推的（2026-10-03）

`polaroid_photo.glb` 里可见卡片是 7.2 × 8.8 × 0.4 **单位**的平板，卡片中心离它自己节点原点
6.4 单位，而模型的一个单位是**厘米**（钱包等其他 `.glb` 是米）。上一轮把「0.35 缩放后约 0.095 m」
当成了米制，于是钱包里那张照片实际渲染成 **2.5 × 3.1 m**、手上那张接近 5.7 m。
本轮按逐顶点 PCA 量出卡片自己的三个轴（短边 / 长边 / 正面法线）与中心，再用它们构造手上的
`Transform3D`（长边朝上、正面朝眼睛），得到 9 × 11 cm、位于眼前 0.30 m、眼下 6 cm 的一张卡片；
`polaroid_photo_held.tscn` / `polaroid_photo_world.tscn` 的 `Model` 变换用同一套实测数字（世界场景
是正面朝上平放，底面落在节点原点）。**同一处顺带修掉金属箱**：`reveal` 只在给了 reveal stage 时
才存在，此前金属箱把 `Model` 同时当成 reveal，导致它在手上被设成不可见、并且套用了照片的手部位姿
（缩放到眼后 3.58 m）——现在它回到自己的 `BOX_HAND_POSITION` 并照常显示。


## 上锁的医务柜 + 柜里的医生日记（2026-10-03）

交付的 V4 模型在书房桌上烘焙了一个静态日记件 `Clue_DoctorDiary`。它和静态铅箱一样由启动流程
**在运行时移除**（`.glb` 二进制不动），取而代之的是三件新东西：一个**上锁容器**、一个**观察对象**、
以及把两者接起来的准星交接。

### 容器：`manor.cabinet.medical`

| 层 | 本轮实现 |
| --- | --- |
| domain | `domain/exploration/lock_state.gd`：`locked` 单调变成 `unlocked`，**不是 toggle**——开了就不会把玩家重新锁在外面。拒绝开启不改状态，拒绝只是一次失败的命令 |
| application | `application/exploration/interactions/unlock_interaction.gd`：`execute()` 先用背包端口的**只读** `holds()` 问一遍带没带表里列的工具（`manor_key` / `crowbar`），带齐才 `unlock()`，否则返回失败码 `CABINET_LOCKED`；**钥匙与撬棍都不消耗**。`read()` 在开着的时候返回 `available = false`，容器从此不再占用准星 |
| presentation | `presentation/manor/locked_object_view.gd` + `medical_cabinet.tscn`：只负责两件事——容器自己的射线目标层（开=0 / 关=8）、柜内对象的目标层（开=8 / 关=0）。它不持有状态，只读 handler |
| bootstrap | `manor_items.gd` 的 `CABINET_*` 表与 `place_cabinet()`；日记先放置，柜子最后放置并把日记的 `Target` 交给视图 |
| 文案 | 拒绝的措辞走**既有失败码通道**：`interaction_hud.show_result("CABINET_LOCKED")` → `interaction.cabinet_locked`「上锁了。用什么办法打开呢？」，与 `DOOR_BLOCKED` 同一范式 |

**「打开」为什么只是状态 + 文案**：实测医务柜由 45 个**平级** `MeshInstance3D` 组成（4 根竖框、
4 根横档、2 块玻璃、2 个把手、5 层隔板、2 块侧板、1 块背板、12 瓶 + 12 塞），**没有门枢节点、
没有抽屉节点、没有任何分组**——每块门板都是若干独立网格拼的。没有可整体旋转或平移的节点，
所以按用户许可**只做状态切换 + 文案 + 准星交接，不硬造动画**。

顺带实测到的两条硬事实：
- 书房该处地面逐点实测 **y = −0.025**；柜子根节点在 `(7.56, 0.0, −0.29)`、`rotation.y = 180°`，
  网格 AABB `x 6.845..8.275`、`y 0.025..2.0125`、`z −0.548..−0.105`，背面贴北墙与东墙。
- 交付的**玻璃材质渲染出来是不透明的**（把玻璃与背板临时隐藏后重渲染，柜内立刻可见，证明不是摆放问题），
  所以正常游戏里看不到柜内的日记；「柜子已开」只由提示行与文案表达。

### 观察对象：`manor.inspect.doctor_diary`

日记放**柜内中层隔板**上（隔板顶面实测 y = 1.0325，台面 x 6.85..8.27、z −0.475..−0.105；
皮面实测 0.253 × 0.046 × 0.329 m，四边都在台面内且没有穿出玻璃）。
`doctor_diary_world.tscn` 的 `Target` 出厂就是 `collision_layer = 0`：**锁在柜里时瞄不到**，
开锁那一刻由柜子的视图改成 8。物品定义 `doctor_diary.tres` 不动——进笔记本仍然靠 `claim_pickup`。
它**不再是**地面拾取物：`manor.pickup.doctor_diary` 这个来源已删掉，同一件东西不会既能直接捡又能观察。

| 层 | 泛化点 |
| --- | --- |
| domain | `inspect_state.gd` 不再写死三段：`_init(stage_count, empty_stage_count, held_from, empty_held_from)`（默认值与原来三段逐字一致）；新增 `held()` 与 `hands_over()` |
| application | `inspect_interaction.gd`：交出内容的时机改成「state 说这是最后一段」，于是日记可以读到第 4 段才进笔记本；`exclusive()` 改成 `state.held()`，**在手不止一段的对象每一段都独占**；新增「取空后的 caption keys」 |
| presentation | `inspect_object_view.gd`：在不在手上由 handler 的 `held` 标志决定（不再比 stage 数字）；`hidden_unless_held` 让出行节点平时不可见；`stowed_node` 指出**出行时让位的那一件**（日记的合上皮面），所以不会同时出现两本日记；手部位姿按名字取（`whole` / `photo` / `book`），三套数字都在 presentation 里实测得到 |

阶段表（`DIARY_*` 常量）：`0 合着（柜里）→ 1 引言 → 2 摊开+第一段 → 3 第二段 → 4 第三段 →（F）收进笔记本 → 0`。
**取空后的两段循环**（用户留给我定，这里定稿）：`0 合着、无正文 → 1 摊开、重读第一段 → 2 摊开、无正文 → 0`；
第 1、2 步都在手上（独占成立、移动冻结照旧），第二三段不再出现，也不会第二次进袋。
用户给出的三段正文（含「骨灰」二字）逐字进 `zh_CN.json`：`inspect.doctor_diary.page1` / `page2` / `page3`。
**「不得出现骨灰/尸骨/棺材」这条约束只挂在金属箱那两段文案上**（`inspect.silver_urn.*`），
日记正文不受它约束——见 `docs/handoff.md` 顶部。

新模型 `items/models/medieval_open_book.glb` 已导入（`.import` + 3 张贴图）。实测：根节点无变换，
网格 2.0 × 1.558 × 0.2525 **模型单位**、页面朝自身 +Z、书脊沿自身 x 轴、原点在摊开页面的中心——
所以手部位姿是「实测比例 × 绕 x 轴 −30° 的倾角 × 眼下 15 cm、眼前 48 cm」，
摊开后约 0.40 × 0.31 m，正好是一本 0.253 × 0.329 m 皮面摊开后的两页。

## 十件庄园道具：落点、拾取文案、收音机与发电机（2026-10-03）

用户一次给了十件道具的位置与逐字文案。落点表与放置函数在**新文件** `bootstrap/manor_props.gd`
（`manor_items.gd` 已到 206 行，本轮按「职责」再拆：`manor_items.gd` 只留落点契约与观察对象，
十件道具连同发电机、收音机、文案层搬进 `manor_props.gd`；`manor_interactions.build()` 调
`Props.place_props()`）。**文案全部逐字进 `zh_CN.json`，不改写、不合并行。**

| # | 物品 | 落点（世界坐标） | 支撑面（实测） | 拾取 |
| --- | --- | --- | --- | --- |
| 1 | 撬棍 `manor.pickup.crowbar` | `(5.60, 0.3799, 3.40)` | 前门廊石板 `y = 0.020` | 可 |
| 2 | 钥匙 `manor.pickup.manor_key` | `(-5.20, -0.025, 1.60)` | 接待室地板 `y = -0.025` | 可 |
| 3 | 铜线圈 `manor.pickup.copper_wire_coil` | `(-5.35, -1.73, -6.05)` | 地窖地面 `-3.23` + 1.50 m（货架上层） | 可 |
| 4 | 绝缘带 `manor.pickup.electrical_tape` | `(-4.55, -1.78, -6.05)` | `-3.23` + 1.45 m（工具墙） | 可 |
| 5 | 手提灯 `manor.pickup.lantern` | `(-3.15, -1.63, -6.05)` | `-3.23` + 1.60 m（挂钩） | 可 |
| 6 | 煤油罐 `manor.pickup.kerosene_bottle` | `(-1.80, -3.23, -6.20)` | 地窖地面（东南角） | 可 |
| 7 | 保险丝 `manor.pickup.fuse` | `(-5.35, -2.93, -6.05)` | `-3.23` + 0.30 m（小盒顶） | 可 |
| 8 | 扳手 `manor.pickup.wrench` | `(-3.85, -2.08, -6.14)` | `-3.23` + 1.15 m（工具墙），`rotation.x = -PI/2` 竖挂 | 可 |
| 9 | 收音机 `manor.inspect.radio` | `(1.50, 1.0477, 7.35)` | 厨房南柜台面 `y = 0.9425`，灶台西侧 0.53 m | **不可** |
| 10 | 发电机 `manor.device.generator` | `(-3.20, -3.1967, -10.65)` | 地窖地面 `-3.23`（机座低 0.0333） | 可启停 |

### 落点是怎么量的（不是照抄别处的数字）

- 逐点射线实测：地窖地面在 `x -5.90..-1.58, z -12.6..-5.9` 平坦为 **-3.23**（斜坡带
  `x -5.85..-4.60` 只在 `z -10.20..-7.45` 抬升，最高 0.22 m，六件地窖道具全在这条带以外或以南）；
  前门廊石板顶面 **0.020**；厨房/接待室木地板走行面 **-0.025**；厨房南柜台面 **0.9425**。
- **接待室有地毯**：`Reception_Rug` 顶面 `0.0245`、覆盖 `x -6.92..-3.25, z 2.92..6.44`。
  钥匙因此摆在**地毯以外**的 `z = 1.60`，沿用金属箱/钱包同一套 `-0.025` 地面高度，
  不会陷进地毯 5 cm。
- **道具自带原点偏移**：撬棍网格最低点在自身原点**下方 0.3599**（斜放姿态），
  所以落地高度是 `0.020 + 0.3599`；收音机模型原点在机身中心（底面低 0.105238），
  发电机机座低 0.033332。这三件不能用「节点 y = 支撑面」直接摆。
- 十件都做过**全模型 AABB 相交检查**（5167 个网格）：除「撬棍压石板、收音机压台面、
  发电机机座压地板」这三处正常接触外**没有任何穿插**。

### 与描述的偏差（模型里没有的东西不硬造）

- **地窖是空房间**：只有地面、四墙、楼梯与斜坡，**没有货架、没有工具墙、没有挂钩、没有小盒**。
  第 3～8 件因此沿**南墙**按合理高度与间距布置（同一条墙上 0.7～0.8 m 间距，1.15～1.60 m 高），
  这是「按描述就近摆放」的舞台化处理，**不是真家具**；煤油罐按「地面角落」放在东南角地上，
  保险丝按「与工具同区的小盒」放在货架层下方 0.30 m 处。
- **前门外没有草坪**：正门（`MS_MainEntry_Hinge`，`x ≈ 3.27`）通向的是**带屋檐的门廊**，
  石板台面 `y = 0.020`；真正的草地低 0.48 m、在门廊边缘以外。撬棍因此放在门廊石板上
  （仍是「前门外」），文案里的「草坪」按原文保留不动。
- **没有「发电机房」**：V4 地窖是一整间。发电机长轴沿房间长向（南北）摆放，4.67 m 机身
  放进 6.7 m 房间，北侧留 0.18 m、南侧留 0.30 m、东墙走道 0.84 m、到斜坡带 0.63 m，
  2.57 m 高低于 2.94 m 净高；机身中心 `(-3.20, -10.65)` 覆盖地窖几何中心，即「发电机房中心」。
  它原来在院子里（`(-11.0, -0.427, -7.0)`），本轮搬进地窖。
- **灰色立方体挪位**：地窖中央原本放着演示用补给立方体 `manor.pickup.cellar_token`，
  现在正好在发电机机壳里（机壳南面 `z = -7.752`），已移到机壳正前方 `(-2.9, -2.99, -7.0)`。

### 拾取文案：一个可选的 `caption_key` + 一层不消失的文字

`PickupInteraction` 多了一个**可选注入**的 `caption_key`（默认空串 = 沉默），
`read()` 把它当只读字段发出来；文字层由 bootstrap 建一次：

| 层 | 本轮实现 |
| --- | --- |
| application | `pickup_interaction.gd` 的 `_init(..., caption_key = "")` 与 `caption_key()`；`read()` 增加 `caption_key`，仍然**不渲染任何东西** |
| presentation | 新 `presentation/manor/narrative_caption.gd`：`CanvasLayer` + 既有 `inspect_caption.gd`，**每个节点 `MOUSE_FILTER_IGNORE`**、不 `release_pointer()`、不 `set_ui_blocked(true)`，所以鼠标保持捕获、移动与 F 全不受影响。它挂在场景里而不是挂在被拾起的节点上——**领取回执会把那个节点 `queue_free()`**，文案必须活得比它久 |
| items | `items/world/world_item.gd` 只做一件事：发现「本来在、现在没了」这一跳时，把 `read().caption_key` 交给文字层。文字层没注入、或键为空，就什么都不发生 |
| bootstrap | `manor_props.place_props()` 先建文字层（名字 `NarrativeCaption`）再摆道具，逐件传自己的键 |

文案**不淡出、不需要按键关闭**，一直留到**下一件拾取替换它**（用户给的两种做法里选了后者：
可断言、不引入计时器竞态）。已拾取的节点会被释放，文字层不会。

### 收音机：观察对象，但只有一段

`manor.inspect.radio` 用既有 `inspect_state` / `inspect_interaction` / `inspect_object_view` 范式，
但只有**两段循环**：`0 无文字 → F → 1 阶段一文案 → F → 0`，**没有「拿在手上」这一层**
（`InspectState.new(2, 2, 99, 99)`：`held_from` 设在所有段数之后，`held()` 永远为假）。
它**完全不碰 `PickupInventory`**（没有 `enable_keep()`），所以背包里永远不会出现 `radio`。
新场景 `items/world/radio_inspect.tscn`（根脚本就是 `inspect_object_view.gd`）+
`items/data/radio_view.tres`；原来的 `items/data/radio.tres` 与 `radio_world.tscn` 不动，
`manor.pickup.radio` 这个来源已删除，同一件东西不会既能捡又能观察。
**供电进度本轮不做**：收音机固定停在阶段一，没有第二阶段。

### 发电机：第一次 F 是检查

`DeviceState` 增加一个**可选**的闸门（`_init(initially_running, gated = false)`，默认与旧行为逐字一致）：
`inspect()` 是它自己的、单独计一次 revision 的变更，`toggle()` 在闸门未开时返回 `NOT_INSPECTED`。
`DeviceInteraction` 多一个可选 `inspect_caption_key`，于是：

- 未检查：提示行 `interaction.device.inspect`「[F] 检查 · 发电机」，`caption_key` 为空；
- 检查后未启停：文案层显示 `inspect.device.generator`（检查文案），提示行变「[F] 启动 · 发电机」；
- 启停之后：文案收起，回到原有 `interaction.device.start` / `interaction.device.stop` 状态机与
  `Running` 指示灯、机身抖动视觉，**一字未改**。

旧的 `DeviceInteraction`/`DeviceState` 用法（不带键、不带闸门）行为不变，`test_interactions.gd`
里那几条纯用例仍然按原样通过。

## 地窖入口：用撬棍撬开盖板（2026-10-03）

用户要求「地窖门要设置成可交互的形式，交互方法是使用撬棍撬开」。V4 模型**本来就是为这件事预留的**
（导出说明写着 `required_tool: crowbar`、`closed_by_default`）：楼梯口在走行网格里**已经是一个洞**，
模型另外给了两件东西盖住它——

- `V4_PryFloorboards`：17 块盖板 + 3 根托条，**世界 AABB `x -5.946..-4.354`、`y -0.085..0.0`、
  `z -11.497..-8.283`**（逐子件实测：20 个子节点，每块板 1.592 × 0.042 × 0.179）。
- `V4_PryFloorCollision-colonly`：一个在**碰撞层 1** 上的 `StaticBody3D`，实测它挡住的洞口是
  **`x -5.8..-4.6`、`z -11.2..-8.4`**；把它停用后，同一位置的射线落到 `y -0.23`（洞口远端）
  到 `-2.41`（近端）的斜坡上——也就是通向地窖的那条坡道。

所以**撬开 = 停止绘制 `V4_PryFloorboards` + 把 `V4_PryFloorCollision` 的碰撞层置 0**。
**不改 `.glb` 二进制，也不动 `ManorWalkCollision`。**

| 层 | 本轮实现 |
| --- | --- |
| domain | 复用 `domain/exploration/lock_state.gd`：`locked → unlocked` 单向、一次 revision。撬开是**一次性的**，没有回头路，所以第二次命令既不会再盖上盖板，也不会把楼梯井藏回去 |
| application | 复用 `application/exploration/interactions/unlock_interaction.gd`，新增**可选**的 `refused_code` 构造参数（默认仍是 `CABINET_LOCKED`，医务柜行为不变）。判定只问背包端口的只读 `holds("crowbar")`：**带在身上就算，不要求先装备**，且撬棍**不消耗** |
| presentation | 新 `presentation/manor/pry_entrance_view.gd`（无 `.tscn`，与 `door_view` 一样直接 `new()`）：只读 handler，然后 `boards.visible = not open` 与 `blocker.collision_layer = 0 if open else 原值`。它不持有状态，也不自己判断「有没有撬棍」 |
| bootstrap | `manor_items.place_pry_entrance()`：在模型里找这两件模型自带的节点并交给视图；**碰撞体本身就是射线目标**（`bindings[blocker] = PRY_ID`），所以「露出洞口」和「入口不再占准星」是同一件事。缺任一件时 `build()` 直接返回 `MANOR_PRY_BINDING_MISSING` |
| 文案 | 动作名 `interaction.pry = 撬开`；缺工具的拒绝走**既有失败码通道**（`UnlockInteraction` 返回 `PRY_NEEDS_CROWBAR` → `interaction_hud` 映射到 `interaction.need_crowbar`「需要撬棍。」），与 `DOOR_BLOCKED` / `CABINET_LOCKED` 同一范式 |

### ⚠ 文案是占位，等用户给定稿

- `interaction.need_crowbar = "需要撬棍。"` ——**用户明确说了这是占位文案**，不是正式剧情文案。
- 入口的对象名 `interaction.pry.cellar = "地窖入口盖板"` 也是本轮为了提示行能显示而取的**描述性占位**，
  用户没有给过。`interaction.pry = "撬开"` 是用户指定的动作名。

用户给稿后只需改 `zh_CN.json` 这两条（必要时连键名），代码与测试里只有
`interaction_hud.gd` 的一条 `code → key` 映射与测试里的一条断言需要同步。

### 保留与不复用

- **B 快捷键仍然保留**：`manor_play.visit_cellar()`（B 键直接传送到地窖）是开发捷径，本轮**没有删除**，
  撬开后两条路都能进地窖。
- **`Reception_Prybar` 与入口无关**：接待室那件是装饰模型件，本交互**不引用任何模型里的撬棍**，
  只判定背包里的物品 `crowbar`（`manor.pickup.crowbar` 从门廊拾取，`unlock_interaction` 也用它开医务柜）。
- 撬开前后的实拍：`docs/captures/manor_props_pry_shut.png`（提示行「[F] 撬开 · 地窖入口盖板」）与
  `docs/captures/manor_props_pry_open.png`（盖板消失，透过洞口能看到地窖的坡道、道具标签与发电机机身）。

## 新增交互的接入位置

| 层 | 本轮职责 | 新类型如何扩展 |
| --- | --- | --- |
| domain | DoorState；CharacterState 领取回执 | 在所属领域定义权威状态与完整候选验证 |
| application | InteractionService；独立 Door/Pickup Handler | 实现 Handler.read/execute/dispose；仅提交业务命令 |
| ports / infrastructure | 射线探测、门净空、背包领取端口 | 替换物理/设备实现，不让业务依赖场景树 |
| presentation | 门姿态、物品显示与通用提示 HUD | 从用例读取状态，不自行改变可拾取性或数量 |
| bootstrap | manor_interactions 的目标清单和显式注入 | 登记稳定 ID、处理器、碰撞绑定与本地化键 |

read 返回 available、revision、name_key、action_key，以及类型需要的只读展示字段。
execute(expected_revision) 返回 Result；失败无副作用，changed 只通知刷新。
观察类 Handler 默认**完全不接触** `PickupInventory`，所以观察对象结构上不可能产生领取回执；
只有 bootstrap 显式 `enable_keep()` 过的对象才会在手持阶段领取，且领取与 stage 变更属于同一次提交。
dispose 释放订阅，InteractionService.close 封闭本会话。一个物品实例一个稳定 source_id，
同种物品可以对应多个来源，数量叠加但每个来源仅领取一次。不能用场景节点名或物品名充当来源 ID。

目前清单位于 bootstrap 原型夹具，不是可执行 JSON 插件系统；未来外部内容配置需专用版本化 Schema，
拒绝未知字段与引用，不能把脚本路径、表达式或万能效果字典交给内容执行。
正式 NPC 对话、线索、锁钥等跨领域或异步交互仍需要各自契约与授权内容。

## 声音：交互事件怎么变成音效（2026-10-04）

音频不是交互的一部分，而是交互结果的**观察者**：`application` 层的处理器（Door/Pickup/Unlock/Device/
Inspect）**一行都没改**，也不知道有声音存在。每个视图订阅自己处理器的 `changed`，比较状态翻转后
调用语义端口（`application/ports/audio_port.gd`），由基础设施适配器决定素材、总线与播放器。

| 交互 | 谁在听 | 端口 kind | 触发条件（不是「按下 F」，而是状态真的翻转） |
| --- | --- | --- | --- |
| 领取拾取物 | `PickupView`（含运行时丢弃物） | `sfx.pickup` | 回执从未领取变已领取；**读文案那一步不响** |
| 丢弃物品 | `bootstrap/manor_play.gd` | `sfx.put` | 物品真的落进世界时 |
| 开关门 | `DoorView` | `sfx.door_open` / `sfx.door_close` | `open` 翻转；被净空判断拒绝时**不响** |
| 解锁医务柜 | `LockedObjectView` | `sfx.lock_open` | 锁打开那一次（单向状态，不会重复） |
| 撬地窖 | `PryEntranceView` | `sfx.pry_wood` + `sfx.pry_metal` | 盖板真的让开时；缺撬棍的拒绝不响 |
| 发电机启停 | `GeneratorView` | `loop.generator`（3D 挂机器）+ `sfx.generator_crank` | `running` 翻转；停机是淡出 |
| 发电机加油 | `GeneratorView` | `sfx.pour_kerosene` | 启动成功**且**处理器 `read().requires` 非空，即煤油门槛真被满足 |
| 收音机开机 | 收音机 `InspectView` | `loop.radio_static` + `ui.switch` | stage 从 0 走到 1（第一次查看） |
| 观察对象拿出照片 | 钱包 `InspectView` | `sfx.pickup` | `held` 翻转且 pose 是照片卡（只有钱包是） |
| 走路 | `bootstrap/manor_soundscape.gd` | `sfx.footstep_*` | 走过的距离够一步（0.78 m）**且**脚下 1.2 m 内有地面；材质由房间决定 |
| 准星换目标 | `manor_soundscape` | `ui.click` | 焦点 target_id 变化时（每帧刷新不会重复响） |
| 笔记本 | `presentation/character/character_hud.gd` | `ui.switch` / `ui.click` / `ui.confirm` / `ui.cancel` | 开合、选择条目、指令成功 / 被拒；丢弃走世界的 `sfx.put`，笔记本本身静音 |

「拒绝不响」是本轮的一致规则：被净空、缺撬棍、缺煤油的失败命令**不产生音频事件**，因为失败不是操作。
理由、总线划分与 3D/非 3D 的取舍见 [ADR 0010](adr/0010-audio-bus-and-port.md)；
assets 与接线清单见 [docs/audio-assets.md](audio-assets.md) §12。

## 自动检查入口

PowerShell 7：`./scripts/verify.ps1 -Godot D:/Godot/Godot_v4.7.2-stable_win64_console.exe`。
统一入口已登记 INTERACTION_TESTS，包含纯应用失败路径和真实场景物理用例；检查完成标记与错误输出。
本轮验收状态以 docs/handoff.md 为准，测试存在不等于已通过。
