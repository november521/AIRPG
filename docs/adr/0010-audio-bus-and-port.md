# ADR 0010：音频总线与语义音频端口

状态：已实现第一遍接线。日期：2026-10-04。分支 `feature/manor-props-v4`。

## 背景与决定

**决定一：总线路由是工程级共享契约，落在资源里，不落在代码里。**
`project.godot` 的 `audio/buses/default_bus_layout` 指向
[`game/infrastructure/audio/default_bus_layout.tres`](../../game/infrastructure/audio/default_bus_layout.tres)：

| 总线 | 索引 | 音量 | send | 本轮用途 |
| --- | :-: | --- | --- | --- |
| `Master` | 0 | 0 dB | — | 玩家总音量 |
| `Music` | 1 | −6 dB | Master | 背景音乐（三档可切换，本轮默认 `dread_low`） |
| `Ambience` | 2 | −9 dB | Master | 非 3D 环境铺底层（本轮**保留未用**，见下） |
| `SFX` | 3 | −2 dB | Master | 世界内一次性音效 **与两个 3D 循环源**（发电机、收音机） |
| `UI` | 4 | −4 dB | Master | 菜单与界面音，含菜单专用音色库 |
| `Voice` | 5 | 0 dB | Master | 预留，本轮无录音 |

音量是混音起点而不是母带决定：音乐/环境素材已做响度归一（−18 / −24 LUFS），一次性音效做峰值归一
（−3 dBFS），所以床层在这里被压下去、瞬态保留余量。玩家可分别调 Music / Ambience / SFX / UI 四条。
**在 Master 上做「1926 年质感」（高通 200 Hz + 低通 5 kHz）本轮不做**，记为可选后续：它会影响全部素材，
包括尚未接线的 Voice，应在有主观试听条件时单独一轮做，并配一条可开关的总线效果。

**决定二：为什么 UI 走非 3D，为什么发电机与收音机是 3D。**

* UI / 菜单音（`ui/*`、`menu/*`）用 `AudioStreamPlayer`（非 3D）。理由不是省事：
  (1) 界面反馈没有世界位置——「笔记本打开」既不发生在某面墙前，也不该随玩家转身而在左右耳之间移动；
  (2) 3D 播放器会按距离衰减，而菜单与 HUD 在时间上早于/独立于玩家位置，用 3D 只会得到「有时听不见」；
  (3) 3D 声源会被墙体与门遮挡（本项目 3D 源不启用遮挡，但仍有距离衰减），界面反馈必须恒定可闻；
  (4) 独立 `UI` 总线让「玩家把音效调小」不会把确认/取消音一起调没。
* 发电机与收音机用 `AudioStreamPlayer3D`，且**挂在机器自己的节点上**（`GeneratorView` / 收音机
  `InspectView` 的 `attach_loop(kind, self)`）。理由：
  (1) 声源是机器，机器有位置；离开地窖后发电机的低鸣必须随距离衰减，否则整栋房子音量相同，
      「地窖里有一台在跑的机器」这条空间信息就丢了；
  (2) 声像随玩家位置变化，玩家能在不看的情况下判断自己离发电机多远；
  (3) 机器被移动（本轮的摆放都是实测坐标，后续可能改）时声源跟着走，不需要第二份坐标表。
  停机是**淡出**（0.75 s 到 −60 dB 再停），不是硬切：机器瞬停是引擎最容易暴露人工感的地方。

**决定三：音频是一个语义端口 + 一个适配器，不是 Autoload。**
见 `application/ports/audio_port.gd`（只声明 `play_ui(kind)`、`play_sfx(kind, position)`、
`set_music(tier)`、`set_ambience(kind, on)`、`attach_loop(kind, host)`，默认全部静音）与
`infrastructure/audio/godot_audio.gd`（唯一出现 `AudioServer`/`AudioStreamPlayer`/总线名/文件名的
地方）。**调用方永远只说游戏事件**，「哪条素材、哪条总线、第几个样本」由
`infrastructure/audio/audio_library.gd` 解析。

* `application` / `presentation` / `domain` / `shared` 层不出现任何音频引擎节点：端口是纯值契约
  （`String` / `Vector3` / 基类 `Node` 作为宿主），状态变化由各视图观察并调用端口。
* 依赖由 `bootstrap` 注入：`bootstrap/manor_play.gd` 组装庄园会话的运行时（
  `bootstrap/manor_soundscape.gd`），`bootstrap/main.gd` 组装外壳菜单的运行时，再由
  `bootstrap/manor_items.gd` / `manor_props.gd` / `manor_interactions.gd` 逐个对象接线。
* **两个运行时实例是刻意的**：庄园的实例挂在庄园场景下，退出庄园时音乐、机器循环与其淡出一起消失；
  外壳实例只服务菜单。端口与总线布局共享，实例不共享——没有 Autoload，也没有跨场景单例状态。
* 没有新增 Autoload、没有 `class_name`、没有运行期 `load()`：40 条素材在 library 里 `preload`，
  因此「端口有的 kind 库里没有」或「文件缺失」都在编译/加载期就暴露，而不是开门那一刻变哑。

**决定四：门禁新增一个数据目录白名单。** `scripts/check_architecture.ps1` 的 `infrastructure`
允许依赖里加入 `audio`。这是**新增数据目录**而不是放宽既有规则：`game/audio/` 只有入库的 OGG 与
`.import` 侧车、没有任何代码，唯一能命名它的是音频适配器；其他层仍然只能通过语义端口发声。

## 事件接线表（本轮第一遍 12 项）

| # | 事件 | 端口 kind | 素材 | 接线点 | 3D/总线 |
| :-: | --- | --- | --- | --- | --- |
| 1 | 背景音乐 | `set_music("dread_low"/"blackout"/"finale")` | `mus_dread_low` / `mus_blackout` / `mus_finale` | `manor_soundscape.begin`（进入庄园） | 非 3D / Music，双播放器交叉淡化 |
| 2 | 拿 / 放物品 | `sfx.pickup` / `sfx.put` | `pickup_item` / `put_item` | `PickupView._refresh`（领取回执翻转）/ `manor_play._drop_item_in_world` | 3D / SFX |
| 3 | 发电机运行 | `loop.generator` | `generator_loop`（loop=true） | `GeneratorView.attach_audio` + `_refresh` 的 running 翻转 | 3D 挂发电机 / SFX，停机淡出 |
| 4 | 开关门 | `sfx.door_open` / `sfx.door_close` | `door_open`+`door_creak` / `door_close`+`door_creak` | `DoorView._refresh` 的 open 翻转 | 3D / SFX |
| 5 | 走路 | `sfx.footstep_wood` / `_stone` / `_wet` | 4 / 6 / 3 条随机池 | `manor_soundscape.walked`（`StepCadence` + `GroundSurfaceProbe`） | 3D / SFX，音高 ±5% |
| 6 | 撬棍撬地窖 | `sfx.pry_wood` + `sfx.pry_metal` | `pry_wood` + `pry_metal` | `PryEntranceView._refresh` 的开合翻转 | 3D / SFX |
| 7 | 从钱包拿出照片 | `sfx.pickup` | `pickup_item` | `InspectView._refresh`（`pose == POSE_PHOTO_CARD` 且 held 翻转） | 3D / SFX |
| 8 | 收音机频率静电 | `loop.radio_static` | `radio_static`（loop=true） | `InspectView.attach_appliance` + `_refresh` 的 stage≥1 | 3D 挂收音机 / SFX |
| 9 | 钥匙开医务柜 | `sfx.lock_open` | `lock_open` | `LockedObjectView._refresh` 的开锁翻转 | 3D / SFX |
| 10 | 给发电机加油 | `sfx.pour_kerosene`（+ `sfx.generator_crank`） | `pour_kerosene` / `generator_crank` | `GeneratorView._refresh`：启动成功且 `requires` 非空 | 3D / SFX |
| 11 | 界面点按 | `ui.click` / `ui.confirm` / `ui.cancel` / `ui.switch` | `click_01..03` 池 / `confirm` / `cancel` / `switch` | 准星换目标、笔记本选择/确认/拒绝/开合 | 非 3D / UI |
| 12 | 菜单按钮 | `menu.start` / `menu.click` / `menu.back` | `menu_start` / `menu_click` / `menu_back` | 主菜单「开始/退出」、档案「选卡/进入/返回」 | 非 3D / UI |

**为什么 `door_creak` 是「门的两条 kind 的备选 take」而不是第 3 个 kind**：这栋房子的门有时给一声吱呀
而不是一次干净的转动。把它做成两个 kind 各自的池（各自 2 个变体），门就只声明「我开了」，随机池在
适配器里决定听见的是哪一版——与脚步池同一套机制，端口表面不增加事件。

## 已知取舍与未做

1. **`Ambience` 总线本轮没有源。** 任务 §2.1 明确「发电机、收音机走 SFX」，而 `ambience/radio_static`
   是收音机上的 3D 源，所以它落在 `SFX`；本轮没有任何非 3D 环境铺底层素材。总线与端口都留着，
   将来加一条环境床只需在 library 里加一个 kind（`set_ambience` 会自动给它建非 3D 播放器）。
   **若更希望收音机静电走 Ambience 总线，这是一个 kind 的 bus 字段改动，请确认。**
2. **`sfx.lock_close` 已映射但本轮没有触发点**：医务柜是一次性单向状态（`LockState` 没有回锁），
   撬开的地窖同理，所以「落锁/关锁」在本轮没有可达事件。素材与 kind 都已就位，接一个可上锁容器即可用。
3. **全部素材是立体声（双单声道）**，因为本机原生 vorbis 编码器只接受 2 声道。`AudioStreamPlayer3D`
   能播，但空间化比单声道粗糙：立体声源不做方向性衰减处理，声像基本由距离与听者朝向决定。
   这是**已知折衷**，重出单声道的方法与命令写在 [`docs/audio-assets.md`](../audio-assets.md) §6.3
   （拿到 `libvorbis`/`oggenc` 后重编并重跑 `--import`、重写 7 个循环侧车）。
4. **没有主观试听。** 音量、`unit_size` / `max_distance`（发电机的可闻半径 6–26 m、收音机 4–16 m、
   脚步 3–12 m）、脚步池的「像不像同一个人走路」都只能靠耳朵定稿；本轮的数值是可辩护的起点，
   不是混音结论。
5. **音乐三档只有第一档会到达**：`set_music` 的交叉淡化（1.6 s，双播放器）已实现并测试，但停电档与
   终局档的触发点在剧情里，本轮不猜。

## 消费者、兼容与迁移

消费者是庄园里的拾取/观察/设备/门的视图、笔记本 HUD、主菜单与故事档案页，以及
`application/exploration/step_cadence.gd`（纯步频累加器）。既有契约未改：`AudioStream` 素材、总线布局与
端口都是新增；`project.godot` 只新增 `[audio]` 一节，没有 `[autoload]`。旧场景（未注入端口）行为不变：
端口的默认实现全部静音，所以任何未接线的视图既不会崩也不会出声。

## 验证夹具

`game/tests/audio/test_audio.gd`（141 checks，标记 `AIRPG_AUDIO_TESTS`）分三层：
契约（端口 kind ↔ library ↔ 总线布局 ↔ 循环标志 ↔ 菜单不得用材质音）、
适配器（真实 `GodotAudio` 在 headless 树里跑：脚步池/音高抖动、UI 池与非 3D、
循环绑定与淡出、音乐交叉淡化）、
接线（庄园 + 12 个视图 + 笔记本 + 菜单，用 `tests/doubles/recording_audio.gd` 记录决议而不发声）。
`-- interaction` 过滤会同时跑交互套件与音频套件，`-- audio` 可单跑。
**没有任何断言依赖音频设备**；素材本身在 headless（Dummy 驱动）下加载与播放均无错误。
