# 音频素材清单与入库说明

> **范围**：只描述 [`game/audio/`](../game/audio/) 下的内容。
> 本次任务**只新增文件**：`game/audio/**` 与本文档。**没有修改** `project.godot`、任何脚本、场景或既有文档，
> 也**没有**建立 Music/SFX/UI 音频总线（留给接入任务）。没有 commit / push。

## 0. 结论速览

| 项 | 结果 |
| --- | --- |
| 入库文件数 | **40** 个 OGG（`.import` 侧车另计 40 个） |
| 合计体积 | **5.54 MB**（目标 ≤ 20 MB，余量充足） |
| 采样率 / 声道 | 全部 44100 Hz / 立体声（原因见 §6.1） |
| 许可 | **全部 CC0，无例外**（见 §3） |
| 循环素材 | **7** 个已在 `.import` 里 `loop=true`、`loop_offset=0`（见 §4.5） |
| 一次性音效 | 33 个，`loop=false` |
| 编码器 | ffmpeg **原生实验性 Vorbis**（本机既无 `libvorbis` 也无 `oggenc`），音乐 `-q:a 6`、音效 `-q:a 5` |
| 源文件 | 全部保留在 `artifacts\audio_raw\`，便于日后用 `libvorbis` 重编 |

体积分布：music 4.87 MB ·
ambience 0.26 MB ·
sfx 0.36 MB ·
ui 0.05 MB

## 1. 仓库布局与逐文件清单

```
game/audio/
├── music/      5 轨背景音乐（全部循环）
├── ambience/   1 个环境层：radio_static（循环）
├── sfx/       25 个（其中 generator_loop 循环，其余一次性）
└── ui/         9 个界面音（一次性，非 3D）
```

| # | 目标文件 | 时长 (s) | 体积 (KB) | 循环 | 许可 |
| --- | --- | --- | --- | :-: | :-: |
| 1 | [`game/audio/music/mus_blackout.ogg`](../game/audio/music/mus_blackout.ogg) | 51.001 | 986.1 | **是** | CC0 |
| 2 | [`game/audio/music/mus_captains_log.ogg`](../game/audio/music/mus_captains_log.ogg) | 56.001 | 1516.4 | **是** | CC0 |
| 3 | [`game/audio/music/mus_dread_low.ogg`](../game/audio/music/mus_dread_low.ogg) | 57.001 | 874.3 | **是** | CC0 |
| 4 | [`game/audio/music/mus_finale.ogg`](../game/audio/music/mus_finale.ogg) | 49.001 | 531.0 | **是** | CC0 |
| 5 | [`game/audio/music/mus_infestation.ogg`](../game/audio/music/mus_infestation.ogg) | 45.000 | 1080.5 | **是** | CC0 |
| 6 | [`game/audio/ambience/radio_static.ogg`](../game/audio/ambience/radio_static.ogg) | 10.501 | 261.8 | **是** | CC0 |
| 7 | [`game/audio/sfx/door_close.ogg`](../game/audio/sfx/door_close.ogg) | 0.509 | 10.5 | 否 | CC0 |
| 8 | [`game/audio/sfx/door_creak.ogg`](../game/audio/sfx/door_creak.ogg) | 1.013 | 14.4 | 否 | CC0 |
| 9 | [`game/audio/sfx/door_open.ogg`](../game/audio/sfx/door_open.ogg) | 0.565 | 11.2 | 否 | CC0 |
| 10 | [`game/audio/sfx/footstep_stone_01.ogg`](../game/audio/sfx/footstep_stone_01.ogg) | 0.155 | 6.7 | 否 | CC0 |
| 11 | [`game/audio/sfx/footstep_stone_02.ogg`](../game/audio/sfx/footstep_stone_02.ogg) | 0.171 | 7.3 | 否 | CC0 |
| 12 | [`game/audio/sfx/footstep_stone_03.ogg`](../game/audio/sfx/footstep_stone_03.ogg) | 0.329 | 9.4 | 否 | CC0 |
| 13 | [`game/audio/sfx/footstep_stone_04.ogg`](../game/audio/sfx/footstep_stone_04.ogg) | 0.350 | 9.1 | 否 | CC0 |
| 14 | [`game/audio/sfx/footstep_stone_05.ogg`](../game/audio/sfx/footstep_stone_05.ogg) | 0.315 | 9.3 | 否 | CC0 |
| 15 | [`game/audio/sfx/footstep_stone_06.ogg`](../game/audio/sfx/footstep_stone_06.ogg) | 0.248 | 8.3 | 否 | CC0 |
| 16 | [`game/audio/sfx/footstep_wet_01.ogg`](../game/audio/sfx/footstep_wet_01.ogg) | 0.255 | 8.9 | 否 | CC0 |
| 17 | [`game/audio/sfx/footstep_wet_02.ogg`](../game/audio/sfx/footstep_wet_02.ogg) | 0.370 | 11.6 | 否 | CC0 |
| 18 | [`game/audio/sfx/footstep_wet_03.ogg`](../game/audio/sfx/footstep_wet_03.ogg) | 0.360 | 10.8 | 否 | CC0 |
| 19 | [`game/audio/sfx/footstep_wood_01.ogg`](../game/audio/sfx/footstep_wood_01.ogg) | 0.215 | 5.6 | 否 | CC0 |
| 20 | [`game/audio/sfx/footstep_wood_02.ogg`](../game/audio/sfx/footstep_wood_02.ogg) | 0.225 | 6.4 | 否 | CC0 |
| 21 | [`game/audio/sfx/footstep_wood_03.ogg`](../game/audio/sfx/footstep_wood_03.ogg) | 0.151 | 5.6 | 否 | CC0 |
| 22 | [`game/audio/sfx/footstep_wood_04.ogg`](../game/audio/sfx/footstep_wood_04.ogg) | 0.245 | 6.4 | 否 | CC0 |
| 23 | [`game/audio/sfx/generator_crank.ogg`](../game/audio/sfx/generator_crank.ogg) | 1.840 | 40.4 | 否 | CC0 |
| 24 | [`game/audio/sfx/generator_loop.ogg`](../game/audio/sfx/generator_loop.ogg) | 3.082 | 18.8 | **是** | CC0 |
| 25 | [`game/audio/sfx/lock_close.ogg`](../game/audio/sfx/lock_close.ogg) | 0.599 | 15.3 | 否 | CC0 |
| 26 | [`game/audio/sfx/lock_open.ogg`](../game/audio/sfx/lock_open.ogg) | 0.534 | 14.7 | 否 | CC0 |
| 27 | [`game/audio/sfx/pickup_item.ogg`](../game/audio/sfx/pickup_item.ogg) | 0.573 | 15.0 | 否 | CC0 |
| 28 | [`game/audio/sfx/pour_kerosene.ogg`](../game/audio/sfx/pour_kerosene.ogg) | 4.001 | 89.4 | 否 | CC0 |
| 29 | [`game/audio/sfx/pry_metal.ogg`](../game/audio/sfx/pry_metal.ogg) | 0.804 | 12.4 | 否 | CC0 |
| 30 | [`game/audio/sfx/pry_wood.ogg`](../game/audio/sfx/pry_wood.ogg) | 0.295 | 8.3 | 否 | CC0 |
| 31 | [`game/audio/sfx/put_item.ogg`](../game/audio/sfx/put_item.ogg) | 0.450 | 13.4 | 否 | CC0 |
| 32 | [`game/audio/ui/cancel.ogg`](../game/audio/ui/cancel.ogg) | 0.495 | 6.6 | 否 | CC0 |
| 33 | [`game/audio/ui/click_01.ogg`](../game/audio/ui/click_01.ogg) | 0.094 | 3.9 | 否 | CC0 |
| 34 | [`game/audio/ui/click_02.ogg`](../game/audio/ui/click_02.ogg) | 0.094 | 4.0 | 否 | CC0 |
| 35 | [`game/audio/ui/click_03.ogg`](../game/audio/ui/click_03.ogg) | 0.115 | 4.6 | 否 | CC0 |
| 36 | [`game/audio/ui/confirm.ogg`](../game/audio/ui/confirm.ogg) | 0.295 | 4.8 | 否 | CC0 |
| 37 | [`game/audio/ui/menu_back.ogg`](../game/audio/ui/menu_back.ogg) | 0.094 | 4.6 | 否 | CC0 |
| 38 | [`game/audio/ui/menu_click.ogg`](../game/audio/ui/menu_click.ogg) | 0.094 | 5.2 | 否 | CC0 |
| 39 | [`game/audio/ui/menu_start.ogg`](../game/audio/ui/menu_start.ogg) | 0.311 | 11.9 | 否 | CC0 |
| 40 | [`game/audio/ui/switch.ogg`](../game/audio/ui/switch.ogg) | 0.504 | 5.8 | 否 | CC0 |

## 2. 完整对照表：目标文件 → 源文件 → 原始页面 URL → 作者 → 许可

### 2.1 背景音乐 `music/`

源：**Ambience Pack 1 — Sci Fi Horror**（5 个 mp3），页面
<https://opengameart.org/content/ambience-pack-1-sci-fi-horror>，作者 **Joth**，许可 **CC0**
（页面原文：*"5 dark sci fi ambience tracks, all fully loopable coming in at ~1:00 each"*）。

| 目标文件 | 源文件（artifacts/audio_raw/music/） | 源时长 | 采用区间 | 交叉淡化 | 输出时长 | 体积 |
| --- | --- | --- | --- | --- | --- | --- |
| `music/mus_blackout.ogg` | `Cage of the Cryptid.mp3` | 58.90 s | 4.00–57.00 s | 2.0 s | 51.00 s | 986 KB |
| `music/mus_captains_log.ogg` | `Final Captain's Log.mp3` | 58.93 s | 0.00–58.00 s | 2.0 s | 56.00 s | 1516 KB |
| `music/mus_dread_low.ogg` | `The Depths of Hell.mp3` | 59.06 s | 0.00–59.00 s | 2.0 s | 57.00 s | 874 KB |
| `music/mus_finale.ogg` | `The Surreal Truth.mp3` | 54.52 s | 0.00–51.00 s | 2.0 s | 49.00 s | 531 KB |
| `music/mus_infestation.ogg` | `Infestation in the Control Room.mp3` | 47.65 s | 0.00–47.00 s | 2.0 s | 45.00 s | 1080 KB |

**为什么这样配三档主音乐**（依据是对 5 轨做的信号分析，不是听感臆测）：

| 指标 | 含义 | The Depths of Hell | Cage of the Cryptid | The Surreal Truth | Final Captain's Log | Infestation |
| --- | --- | :-: | :-: | :-: | :-: | :-: |
| 谱质心 | 越低越"沉" | **1272 Hz** | 1560 Hz | **1054 Hz** | 2733 Hz | 3648 Hz |
| 谱平坦度 | 越低越"音调化"、越高越"噪声化" | 0.044 | 0.188 | **0.039** | 0.457 | 0.532 |
| 音级集中度 | 越低越"无旋律" | 0.141 | **0.150** | 0.188 | 0.165 | 0.140 |
| 1 s 包络标准差 | 越小越"平铺可循环" | **4.1 dB** | 8.9 dB | 55.9 dB | 5.6 dB | 3.1 dB |
| 谱通量自相关峰 | 越大越有节拍 | 0.32 | 0.50 | **0.83** | **0.19** | 0.31 |

* `mus_dread_low.ogg` ← **The Depths of Hell**：质心低（1272 Hz）+ 平坦度极低（0.044，几乎纯音调）
  + 包络标准差小（4.1 dB，最"平"）+ 无节拍（0.32）。**最符合"低沉、无旋律、可无限铺底"的基准恐惧层。**
* `mus_blackout.ogg` ← **Cage of the Cryptid**：**前 4 秒有一个比其他部分响约 30 dB 的"断电"瞬态**，
  之后是一条安静长鸣（中位数 −43 dBFS）。这个"由响到静"的形态本身就是"停电"事件，
  所以用在 blackout 档；同时它的音级集中度最低（0.150），最不像旋律。
* `mus_finale.ogg` ← **The Surreal Truth**：**节拍周期性最强（0.83）**、**动态范围最宽（55.9 dB）**，
  是 5 轨里唯一有明确推进感的，用于 finale。它另外有 **4.38 s 的纯数字静音尾巴**（已裁掉）。
* 备用两轨：`mus_captains_log.ogg` ← Final Captain's Log（最亮、最有质感，无节拍）、
  `mus_infestation.ogg` ← Infestation in the Control Room（安静、稳定的噪声织体）。

> **命名偏差（需要你确认）**：任务表里把备用轨举例写成 `music/mus_surreal_truth.ogg`，但按上表
> *The Surreal Truth* 是 finale 的最佳候选，因此它进了 `mus_finale.ogg`，备用两轨改用按曲目气质命名的
> `mus_captains_log.ogg` / `mus_infestation.ogg`。若你更希望保留 `mus_surreal_truth.ogg` 这个名字，
> 改个文件名 + 重跑一次导入即可（内容不用重编）。

### 2.2 环境层 `ambience/`

| 目标文件 | 源文件 | 页面 URL | 作者 | 许可 | 采用区间 |
| --- | --- | --- | --- | :-: | --- |
| `ambience/radio_static.ogg` | `static/static1.wav`（120 s，42.3 MB） | <https://opengameart.org/content/frequency-static-sound-effects> | bretbernhoft | CC0 | t = 73–84 s，裁成 10.5 s 循环 |

页面原文：*"All files are available in the public domain and can be used freely without attribution."*
选 `static1.wav` 而不是 `static3.wav`：static1 是 −4.4 dBFS、static3 是 −0.8 dBFS，
static1 动态余量更大，且它的 1 s 包络在整段 120 s 内最平（±0.5 dB），取窗更好找。

### 2.3 音效 `sfx/`

来源见每行的"源文件"列，归属页面/作者/许可：

| 源前缀 | 页面 URL | 作者 | 许可 |
| --- | --- | --- | :-: |
| `packs/sfx_100_v2/` | <https://opengameart.org/content/100-cc0-sfx-2> | rubberduck | CC0 |
| `packs/doorset/` | <https://opengameart.org/content/door-open-door-close-set> | **qubodup** | CC0 |
| `machine/loop_generator_1.mp3` | <https://opengameart.org/content/generator-loop> | YCbCr | CC0 |
| `steps/` | <https://opengameart.org/content/footsteps-0> | GboxMikeFozzy | CC0 |
| `sfx100v2_air_01` + `sfx100v2_loop_water_01` | <https://opengameart.org/content/100-cc0-sfx-2> | rubberduck | CC0 |

| 目标文件 | 源文件（artifacts/audio_raw/） | 时长 (s) | 体积 (KB) | 说明 |
| --- | --- | --- | --- | --- |
| `sfx/door_close.ogg` | `packs/doorset/qubodup-DoorSet/ogg/qubodup-DoorClose07.ogg` | 0.509 | 10.5 |  |
| `sfx/door_creak.ogg` | `packs/doorset/qubodup-DoorSet/ogg/qubodup-DoorClose04.ogg` | 1.013 | 14.4 |  |
| `sfx/door_open.ogg` | `packs/doorset/qubodup-DoorSet/ogg/qubodup-DoorOpen05.ogg` | 0.565 | 11.2 |  |
| `sfx/footstep_stone_01.ogg` | `steps/01-footstep_0.ogg` | 0.155 | 6.7 |  |
| `sfx/footstep_stone_02.ogg` | `steps/02-footstep.ogg` | 0.171 | 7.3 |  |
| `sfx/footstep_stone_03.ogg` | `steps/03-footstep.ogg` | 0.329 | 9.4 |  |
| `sfx/footstep_stone_04.ogg` | `steps/04-footstep.ogg` | 0.350 | 9.1 |  |
| `sfx/footstep_stone_05.ogg` | `steps/05-footstep.ogg` | 0.315 | 9.3 |  |
| `sfx/footstep_stone_06.ogg` | `steps/06-footstep.ogg` | 0.248 | 8.3 |  |
| `sfx/footstep_wet_01.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wet_01.ogg` | 0.255 | 8.9 |  |
| `sfx/footstep_wet_02.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wet_02.ogg` | 0.370 | 11.6 |  |
| `sfx/footstep_wet_03.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wet_03.ogg` | 0.360 | 10.8 |  |
| `sfx/footstep_wood_01.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wood_01.ogg` | 0.215 | 5.6 |  |
| `sfx/footstep_wood_02.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wood_02.ogg` | 0.225 | 6.4 |  |
| `sfx/footstep_wood_03.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wood_03.ogg` | 0.151 | 5.6 |  |
| `sfx/footstep_wood_04.ogg` | `packs/sfx_100_v2/sfx100v2_footstep_wood_04.ogg` | 0.245 | 6.4 |  |
| `sfx/generator_crank.ogg` | `packs/sfx_100_v2/sfx100v2_loop_machine_03.ogg` | 1.840 | 40.4 |  |
| `sfx/generator_loop.ogg` | `machine/loop_generator_1.mp3` | 3.082 | 18.8 | f0=52.5701 Hz, 周期 19.022 ms, 162 个整周期, 起点 0.8102 s |
| `sfx/lock_close.ogg` | `packs\sfx_100_v2\sfx100v2_lock_open_01.ogg` | 0.599 | 15.3 | derived: sfx100v2_lock_open_01 pitched/slowed -2 semitones (DoorSet has no lock files) |
| `sfx/lock_open.ogg` | `packs\sfx_100_v2\sfx100v2_lock_open_01.ogg` | 0.534 | 14.7 | only real lock sound in the batch |
| `sfx/pickup_item.ogg` | `packs\sfx_100_v2\sfx100v2_items_01.ogg` | 0.573 | 15.0 |  |
| `sfx/pour_kerosene.ogg` | `packs/sfx_100_v2/sfx100v2_air_01.ogg + sfx100v2_loop_water_01.ogg` | 4.001 | 89.4 | amix 叠加（见 §5） |
| `sfx/pry_metal.ogg` | `packs\sfx_100_v2\sfx100v2_metal_hit_01.ogg` | 0.804 | 12.4 | longest of metal_hit_01/02 (0.811 s) |
| `sfx/pry_wood.ogg` | `packs\sfx_100_v2\sfx100v2_wood_hit_03.ogg` | 0.295 | 8.3 | longest of wood_hit_01/02/03 (0.469 s) |
| `sfx/put_item.ogg` | `packs\sfx_100_v2\sfx100v2_items_02.ogg` | 0.450 | 13.4 |  |

挑选用的是可复现的量化规则，不是手感：

* **关门/开门/吱呀（qubodup DoorSet）**：对 18 个文件逐个测谱质心与 20 ms 包络调制指数。
  `door_open` / `door_close` 取各自类别里**质心最低**的（=最"重"的门）：
  DoorOpen05（2423 Hz）、DoorClose07（1956 Hz）；
  `door_creak` 取**< 6 kHz 范围内调制指数最高**的（=最"吱呀"）：DoorClose04（2.07）。
* **撬木板 / 撬金属**：各取该类里**时长最长**的一条（信息量最大）：
  `wood_hit_03`（0.469 s 源）、`metal_hit_01`（0.811 s 源）。可选叠加方案见 §8 末尾。
* **发电机启动**：`sfx100v2_loop_machine_*` 里**最短**的一条 = `loop_machine_03`（1.84 s）。
* **上锁 `lock_close.ogg`**：⚠️ **DoorSet 里根本没有 lock/unlock 文件** —— 该页面的标签含
  `lock / unlock / lockpicking`，但 7z 里只有 `DoorOpen01-08` + `DoorClose01-10`。
  所以 `lock_open.ogg` 用 `sfx100v2_lock_open_01.ogg`（本批唯一真正的锁具音），
  `lock_close.ogg` 是**同一条降 2 个半音并放慢**（`asetrate=44100*0.8908987`）得到的派生变体，
  让开/上锁听起来像"同一把锁"。若你更想要一条独立的机械"落闩"声，
  改指向 `sfx100v2_switch_01.ogg` 即可（见 §8 备选）。
* **脚步**：木地板 4 条、石材/走廊 6 条（真实录音）、潮湿/室外 3 条，各自内部电平已统一，
  可直接做随机池。

### 2.4 界面音 `ui/`

| 源包 | 页面 URL | 作者 | 许可 |
| --- | --- | --- | :-: |
| Kenney Interface Sounds（100 个） | <https://kenney.nl/assets/interface-sounds> | Kenney | CC0 |
| Kenney UI Audio（50 个） | <https://kenney.nl/assets/ui-audio> | Kenney | CC0 |

两个包内附的 `License.txt` 都明确写了 CC0（*"License: (Creative Commons Zero, CC0)"*）。
抓到的直链（Python urllib，正则取自页面 HTML）：

* `https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip`（834,536 B）
* `https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip`（411,949 B）

| 目标文件 | 源文件（artifacts/audio_raw/kenney/） | 时长 (s) | 体积 (KB) | 挑选依据 |
| --- | --- | --- | --- | --- |
| `ui/cancel.ogg` | `kenney\interface_sounds\Audio\error_005.ogg` | 0.495 | 6.6 | lowest-centroid error (dull = negative, not a harsh buzz) |
| `ui/click_01.ogg` | `kenney\interface_sounds\Audio\click_002.ogg` | 0.094 | 3.9 | shortest interface click |
| `ui/click_02.ogg` | `kenney\interface_sounds\Audio\click_005.ogg` | 0.094 | 4.0 | median-duration interface click |
| `ui/click_03.ogg` | `kenney\interface_sounds\Audio\click_001.ogg` | 0.115 | 4.6 | longest interface click |
| `ui/confirm.ogg` | `kenney\interface_sounds\Audio\confirmation_001.ogg` | 0.295 | 4.8 | lowest-centroid confirmation (warm = affirmative) |
| `ui/menu_back.ogg` | `kenney\ui_audio\Audio\click2.ogg` | 0.094 | 4.6 | lowest-centroid UI Audio click -> lower pitch = 'back' |
| `ui/menu_click.ogg` | `kenney\ui_audio\Audio\click5.ogg` | 0.094 | 5.2 | median-centroid UI Audio click (neutral) |
| `ui/menu_start.ogg` | `kenney\ui_audio\Audio\switch11.ogg` | 0.311 | 11.9 | lowest-centroid UI Audio switch >=0.15 s = weightiest, and synthetic/neutral (no wood or metal impact) |
| `ui/switch.ogg` | `kenney\interface_sounds\Audio\switch_003.ogg` | 0.504 | 5.8 | longest interface switch (most substantial toggle) |

按任务要求，**菜单音全部取自 Kenney UI Audio**（更短、更干净、**合成中性**，没有木头/金属撞击的材质暗示），
游戏内 UI 音取自 Interface Sounds。挑选规则（在**去静音后**的时长上计算，因为若干 Kenney 文件带长数字补白）：

* `click_01/02/03`：Interface Sounds `click_*` 里**最短 / 中位 / 最长**，得到三个层次。
* `confirm`：`confirmation_*` 里**谱质心最低**（最暖 = 肯定）。
* `cancel`：`error_*` 里**谱质心最低**（最闷 = 否定，避免刺耳啸叫）。
* `switch`：Interface Sounds `switch_*` 里**最长**（最"实"的拨动）。
* `menu_click`：UI Audio `click*` 里**质心中位**。
* `menu_back`：UI Audio `click*` 里**质心最低**（音高更低 = "返回"）。
* `menu_start`：UI Audio `switch*` 里**时长 ≥0.15 s 且质心最低**（最有"决定"的重量感）。

> 补充：任务文档提醒"Kenney 这套是 2012 年素材，采样率可能偏低"。**实测全部是 44100 Hz / 立体声**，
> 无需重采样，也不存在音质落差。

## 3. 许可结论

**本批入库的 40 个文件全部是 CC0。没有任何一件例外，也没有发现意外情况。**

已逐个打开页面核实（作者 + 许可字段）：

| # | 素材 | 作者 | 许可 | 页面 |
| --- | --- | --- | :-: | --- |
| 1 | Ambience Pack 1 — Sci Fi Horror（5 轨音乐） | Joth | CC0 | <https://opengameart.org/content/ambience-pack-1-sci-fi-horror> |
| 2 | 100 CC0 SFX #2（`sfx_100_v2.zip`） | rubberduck | CC0 | <https://opengameart.org/content/100-cc0-sfx-2> |
| 3 | Generator (loop) | YCbCr | CC0 | <https://opengameart.org/content/generator-loop> |
| 4 | Door Open, Door Close Set | qubodup | CC0 | <https://opengameart.org/content/door-open-door-close-set> |
| 5 | Footsteps | GboxMikeFozzy | CC0 | <https://opengameart.org/content/footsteps-0> |
| 6 | Frequency Static Sound Effects | bretbernhoft | CC0 | <https://opengameart.org/content/frequency-static-sound-effects> |
| 7 | Kenney Interface Sounds | Kenney | CC0 | <https://kenney.nl/assets/interface-sounds> |
| 8 | Kenney UI Audio | Kenney | CC0 | <https://kenney.nl/assets/ui-audio> |

### 3.1 被排除的非 CC0 素材（确认未使用）

* **Page Flips** —— 许可为 **CC-BY-SA**（传染性），原清单第 7 项列为"CC0 / CC-BY-SA ⚠️"。
  **本批完全没有使用它**：`pickup_item.ogg` / `put_item.ogg` 只用了 CC0 的
  `sfx100v2_items_01/02.ogg`，没有纸/薄物层。
* **Ambient Evil (Juhani Junkala)** —— **CC-BY 4.0 + OGA-BY 3.0，必须署名**。**未使用**。
* **Static2–10** —— 同一 CC0 包内的其他 9 个 wav，未入库（体积大且不需要）。

### 3.2 署名建议

CC0 不要求署名，但有两位作者值得记进将来的 `CREDITS.md`：

* **qubodup**（DoorSet）—— 页面 `Attribution Instructions:` 一栏就写着 `qubodup`，
  即作者虽然给了 CC0 仍希望被署名。
* **Kenney**（两个 UI 包）—— License.txt 写 *"Credit (Kenney or www.kenney.nl) would be nice but is not mandatory."*

其余（Joth / rubberduck / YCbCr / GboxMikeFozzy / bretbernhoft）页面均未提出署名期望。

## 4. 循环点是怎么定的

### 4.1 通用方法：交叉淡化循环（crossfade loop）

对一个长度为 N 的片段 x，取交叉淡化长度 C，输出长度 M = N − C：

```
out[i] = x[M+i]·cos(t) + x[i]·sin(t)      i ∈ [0, C),  t = (π/2)·i/C     ← 头部，把尾巴折进来
out[i] = x[i]                             i ∈ [C, M)                     ← 主体，逐样本原样
```

关键性质：`out[M-1] = x[M-1]`，而 `out[0] = x[M]`——**这两个是原素材里相邻的样本**，
所以"播放到结尾再回到开头"这一步在波形上是逐样本连续的，**物理上不可能产生咔哒声**。
`cos/sin` 是等功率权重，用于**互不相关**的素材（环境长鸣、噪声），能在淡化过程中保持总功率不变。

### 4.2 音乐：先找"稳定段"，再交叉淡化

5 轨 mp3 虽然作者说 "fully loopable"，但它们**并不是无缝循环素材**：都有淡入/淡出甚至纯静音尾巴。
所以流程是：

1. 裁掉首尾**数字静音**（< −80 dBFS，保留 5 ms）。
2. 检测 **T = 一次性前奏瞬态的结束**：1 s 包络中最后一次超过 `中位数 + 8 dB` 的位置。
3. 检测 **F = 尾部淡出的开始**：最后一个仍在 `中位数 − 8 dB` 以内的 1 s 块。
4. 对 **[T, F) 这段"稳定床"**做 C = 2.0 s 的等功率交叉淡化循环，循环外的前奏与淡出**丢弃**。

实测结果（`seam-step ×` = 环绕处的样本跳变 / 该信号自身的平均逐样本跳变；**≈1 表示无法区分于正常波形运动，即无咔哒**）：

| 目标 | 采用稳定段 | 丢弃 | 交叉淡化 | 输出 | 环绕跳变比 | LUFS 变化 |
| --- | --- | --- | --- | --- | :-: | --- | --- |
| `mus/blackout` | 4.00–57.00 s | 前奏 4.0 s / 尾巴 1.9 s | 2.0 s | 51.00 s | **×0.49** | -40.44 → -20.32 |
| `mus/captains_log` | 0.00–58.00 s | 前奏 0.0 s / 尾巴 0.9 s | 2.0 s | 56.00 s | **×0.56** | -22.0 → -18.0 |
| `mus/dread_low` | 0.00–59.00 s | 前奏 0.0 s / 尾巴 0.1 s | 2.0 s | 57.00 s | **×1.05** | -21.91 → -18.0 |
| `mus/finale` | 0.00–51.00 s | 前奏 0.0 s / 尾巴 3.5 s | 2.0 s | 49.00 s | **×0.55** | -26.48 → -18.0 |
| `mus/infestation` | 0.00–47.00 s | 前奏 0.0 s / 尾巴 0.6 s | 2.0 s | 45.00 s | **×0.34** | -42.02 → -19.63 |

* `mus_blackout.ogg` 丢掉了前 4.0 s 的"断电"瞬态（−22 dBFS，比其余部分高约 30 dB）以及尾部 1.9 s。
  这是有意的：一个每 51 秒重现一次的 −22 dBFS 爆音不适合做恐惧铺底。**若你要那个断电音，
  它是源文件 `Cage of the Cryptid.mp3` 的 0–4 s，可单独做成一次性音效。**
* `mus_finale.ogg` 丢掉了 3.5 s 淡出（源文件另有 4.38 s 纯数字静音，已在第 1 步裁掉）。
* 另 3 轨几乎没有可丢的内容（丢弃量 ≤ 1 s）。
* **`loop_offset = 0` 的理由**：交叉淡化循环的环绕点本来就在缓冲区第 0 个样本上，
  且已由构造保证逐样本连续，所以**不需要**用 `loop_offset` 去对齐——填 0 就是正确的对齐值。

### 4.3 `generator_loop.ogg`：相位对齐 + 线性交叉淡化

源 `machine/loop_generator_1.mp3` 只有 5.436 s、低频马达声，**作者明确说原生不循环**。
做法（先分析再合成）：

1. **测基频**：对整段做 FFT，再用**谐波乘积谱（HPS）**确认基频，抛物线插值细化 →
   **f0 = 52.5701 Hz**，周期 = **19.022 ms**（838.88 样本）。
2. **候选循环长度**：只取**整数个周期** `L_k = round(k / f0 · 44100)`，k = 3…199。
   整数个周期意味着环绕两侧**天然同相位**，这是避免相位跳变的前提。
3. **对每个 L_k 搜索最佳起点 O**，评分函数是
   `E(O, L) = RMS( x[O : O+20ms] − x[O+L : O+L+20ms] )`。
   这个量的物理含义是："环绕之后听到的那一小段，和环绕之前那一刻本该自然延续的那一小段，
   是不是同一个东西"。
4. **选取规则**：在 `L ≥ 3.0 s` 的候选里取 `E` 归一化后最小者 → **k = 162**，
   `O = 35728` 样本（**0.8102 s**），`L = 135899` 样本（**3.0816 s**）。
   （20 ms 窗口内的归一化失配 0.147；作为对比，随机取两段的期望值约为 1.41。）
5. **首尾补白**：实测这段素材**没有**静音补白（20 ms 包络首块 −13.4 dB、末块 −13.8 dB，
   全程 min −17.1 / max −10.4 dB），所以没有"裁补白"这一步要做；要重建的只是循环接缝。
   注意它确有约 ±1.2 dB 的自然幅度起伏，这正是需要按第 3 步匹配包络的原因。
6. **接缝处理用"线性"交叉淡化（不是等功率）**，长度 = **3 个整周期（2517 样本 = 57.1 ms）**。
   理由：交叉的两段是**高度相关**的同相位马达声，
   `cos/sin` 等功率权重会把两份同相信号相加、鼓出最多 +3 dB；线性权重 `(1−t, t)` 之和恒为 1，
   对同相素材正好等于原信号，不会鼓包。

**实测接缝**：环绕处样本跳变 **0.000892**，该信号自身平均逐样本跳变 0.002375 →
**比值 0.376**（远小于 1）。即环绕处的"跳变"比正常波形运动还小，**不存在咔哒**。

> 说明一下为什么不采用"纯剪切"方案：纯剪切时环绕误差由素材自身能否回到起点决定，
> 实测最佳归一化失配 0.147，环绕跳变比达 **4.55**（约 −33 dBFS 的台阶），会有轻微 tick。
> 改用相位对齐 + 线性交叉淡化后降到 0.376。

### 4.4 `radio_static.ogg`

`static1.wav` 是 120 s / 44.1 kHz / 立体声 / 32-bit，**42.3 MB**（原文件绝不能进仓库）。
扫描 1 s 块包络后，取**块间方差最小**的 11 s 窗口（**t = 73–84 s**，块电平 −3.9…−4.8 dB），
再用 C = 0.5 s 的等功率交叉淡化 → **10.5 s 循环**，落盘仅 262 KB。

### 4.5 循环标志与 `loop_offset`

7 个循环素材的 `.import` 侧车已设为：

```ini
loop=true
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
```

其余 33 个保持 `loop=false`。已用 Godot 本身逐个 `load()` 回读确认（见 §10），
`AudioStreamOggVorbis` 的 `loop` / `loop_offset` 与预期完全一致。

## 5. 倒煤油的混音参数

`sfx/pour_kerosene.ogg` 由两层叠加而成（任务要求：气流 + 液体，比单一液体声更像倒油）：

```
ffmpeg -stream_loop -1 -i sfx100v2_air_01.ogg -i sfx100v2_loop_water_01.ogg   -filter_complex "    [0:a]aresample=44100,pan=mono|c0=0.5*c0+0.5*c1,volume=0.85,atrim=0:4.0,asetpts=N/SR/TB[a];    [1:a]aresample=44100,pan=mono|c0=0.5*c0+0.5*c1,volume=0.75,atrim=0:4.0,asetpts=N/SR/TB[b];    [a][b]amix=inputs=2:duration=longest:normalize=0,    afade=t=in:st=0:d=0.12,afade=t=out:st=3.4:d=0.6[out]"   -map "[out]" -ac 1 -ar 44100 -c:a pcm_s16le pour_kerosene.wav
```

| 参数 | 值 | 理由 |
| --- | --- | --- |
| air 层 | `sfx100v2_air_01`，`volume=0.85`，`-stream_loop -1` 循环到 4 s | 气流是"倒"的主体，稍响 |
| water 层 | `sfx100v2_loop_water_01`，`volume=0.75`，`atrim 0..4 s` | 液体声垫底，稍轻 |
| `amix` | `inputs=2:duration=longest:normalize=0` | **`normalize=0` 关键**：否则 ffmpeg 会按输入数自动衰减（−6 dB），两层都变闷 |
| 包络 | `afade in 0.12 s`，`afade out st=3.4 d=0.6` | 让 4 s 的倒液有起有落，不像截断 |
| 声道 | 下混单声道 | 见 §6.1 |
| 末级 | 峰值归一化到 −3 dBFS | 见 §7 |

输出 4.001 s，89.4 KB，峰值 −2.99 dBFS。

## 6. 编码器说明：原生实验性 Vorbis，以及踩到的三个坑

### 6.1 本机没有 `libvorbis`

ffmpeg 4.4.5（`C:\Users\Lenovo\AppData\Local\kzip_sogou\ffmpeg.exe`）的编码器列表里
**只有 `vorbis`（原生实验性，标记 `A..X..`）**，没有 `libvorbis`；系统里也没有 `oggenc`。
而 Godot 4.7.2 **没有 `AudioStreamOggOpus`**（本次实测 `ClassDB.class_exists("AudioStreamOggOpus")` 返回 **false**），
所以也不能用 `libopus` 绕开。因此：

```
-c:a vorbis -strict experimental -q:a 6     # 音乐
-c:a vorbis -strict experimental -q:a 5     # 音效 / UI
```

**这个编码器有三个实测缺陷，都会影响产物，处理办法如下：**

| # | 现象 | 实测证据 | 处理 |
| --- | --- | --- | --- |
| 1 | **只支持恰好 2 声道**，单声道直接报错 | `Current FFmpeg Vorbis encoder only supports 2 channels.`，`enc_rc=1` | 所有单声道素材先 `pan=stereo\|c0=c0\|c1=c1` 变成**双单声道**（L=R）再编。**代价：全部 40 个文件都是立体声**；`AudioStreamPlayer3D` 对立体声的空间化不如单声道精确。 |
| 2 | **输入 ≤ 1024 帧（≈23 ms）时输出零个音频包**（文件能打开但完全没声音） | 512 / 1024 帧 → 解码 0 帧；1536 帧 → 1024 帧 | 编码前若源短于 **0.093 s** 则用 `apad=whole_dur=0.093` 补尾静音。受影响的是 `ui/click_01/click_02`（Kenney 源本身只有 12/19 ms）。 |
| 3 | **`loudnorm` 两遍法（`linear=true`）在极安静素材上会退回动态模式并写出超长文件** | `mus_blackout_norm.wav` 变成 **222 s**（应为 51 s）、`mus_infestation_norm.wav` 变成 196 s（应为 45 s），**4.35 倍** | 改用"只测量、再用单个静态 `volume` 增益"的归一化（§7）。静态增益**不可能**改变时长。 |

> 缺陷 2 的补充：`ui/click_01/click_02` 因补齐静音而变长到 0.094 s（真正的咔哒声仍在开头）。
> 一次性 UI 音多 80 ms 尾巴无副作用；若在意，可换用更长的 Kenney click。

### 6.2 关于"内容是否被削掉"的核实

ffmpeg 解码回 PCM 时会比源**少 12–1012 个样本**，看起来像丢内容。为确认这不是真的丢失，
直接解析了每个 Ogg 的 **page granule position**（Vorbis 的权威长度字段）：

* 全部 40 个文件的 `max_granule ≥ 源帧数`（差值 +7…+60 样本，是补齐到 Vorbis 块边界的舍入）。
* **没有任何一个文件 granule 短于源**，即**音频内容完整**。
* Godot 也是按 granule 取长度：回读 `mus_dread_low.ogg` 得 `len=57.0006 s`（源 57.0000 s）。
* 结论：交叉淡化循环的**逐样本连续环绕性质没有被编码破坏**，不需要额外补偿。

### 6.3 日后用 `libvorbis` 重编的方法

源文件全部保留在 `D:\AIRPG\artifacts\audio_raw\`（音乐、脚步、静电、两个包的解包结果）。
拿到带 `libvorbis` 的 ffmpeg（或 `oggenc`）后：

```bash
# 单声道素材（脚步/门/锁/发电机/倒液）——可真正得到单声道，体积还能再降约一半
ffmpeg -i game/audio/sfx/door_open.ogg -ac 1 -c:a libvorbis -q:a 5 door_open.ogg

# 音乐 / 环境层（保持立体声），逐条按原参数重编，然后重跑导入并重新置 loop=true
ffmpeg -i <中间 wav> -c:a libvorbis -q:a 6 mus_dread_low.ogg
```

**重编后必须重做两件事**：（1）跑一次 `--import`；（2）把 7 个循环素材的 `.import` 里
`loop=true` 重新写上（导入会以 `loop=false` 重建侧车）。
重建用的所有中间 WAV 与确定性脚本在 `D:\AIRPG\artifacts\audio_build\`。

## 7. 电平策略

| 类别 | 策略 | 实测结果 |
| --- | --- | --- |
| `music/` | EBU R128 测量 → 单个静态增益到 I = −18 LUFS，同时不越过 TP = −1.5 dBTP | −18.0 / −18.0 / −18.0 / −20.32 / −19.63 LUFS（后两条受真峰值上限约束，无法再加） |
| `ambience/` | 同上，目标 I = −24 LUFS（作背景层） | −24.0 LUFS，峰值 −14.5 dBFS |
| `sfx/` | **峰值归一化到 −3 dBFS** | 全部 −2.2…−4.4 dBFS（Vorbis 编解码过冲内） |
| `ui/` | 峰值归一化到 −3 dBFS | 全部 ≈ −2.8…−3.2 dBFS |
| `generator_loop` | 单独留更大余量：峰值 **−6 dBFS** | 因为它是会长期铺底的长鸣 |

一次性音效用峰值归一化而不是响度归一化：瞬态音的感知响度主要来自峰值，
且**各音效之间的相对轻重应由玩家/总线侧决定**（门 vs 点击不该同响度）。
音乐用响度归一化，是因为 5 轨原始响度差 13 dB 以上，作为可互换的铺底必须对齐。

**没有任何文件削顶**：全部样本峰值 ≤ −1.30 dBFS，真峰值 ≤ −1.32 dBTP。

## 8. 未入库的可选素材全清单（供后续接入参考）

任务要求"暂时用不到的先不要入库，但附上完整可选清单"。除下面列出的，其余源素材都未进仓库。

| category | files (not shipped unless marked **SHIPPED**) | durations (s) |
| --- | --- | --- |
| `air` (3) | **SHIPPED** `sfx100v2_air_01.ogg`, `sfx100v2_air_02.ogg`, `sfx100v2_air_03.ogg` | 2.64, 1.11, 0.28 |
| `door` (5) | `sfx100v2_door_01.ogg`, `sfx100v2_door_02.ogg`, `sfx100v2_door_03.ogg`, `sfx100v2_door_04.ogg`, `sfx100v2_door_05.ogg` | 0.41, 0.30, 0.75, 0.20, 0.31 |
| `footstep` (2) | `sfx100v2_footstep_01.ogg`, `sfx100v2_footstep_02.ogg` | 0.42, 0.36 |
| `footstep_wet` (3) | **SHIPPED** `sfx100v2_footstep_wet_01.ogg`, **SHIPPED** `sfx100v2_footstep_wet_02.ogg`, **SHIPPED** `sfx100v2_footstep_wet_03.ogg` | 0.28, 0.40, 0.39 |
| `footstep_wood` (4) | **SHIPPED** `sfx100v2_footstep_wood_01.ogg`, **SHIPPED** `sfx100v2_footstep_wood_02.ogg`, **SHIPPED** `sfx100v2_footstep_wood_03.ogg`, **SHIPPED** `sfx100v2_footstep_wood_04.ogg` | 0.26, 0.25, 0.26, 0.37 |
| `glass` (6) | `sfx100v2_glass_01.ogg`, `sfx100v2_glass_02.ogg`, `sfx100v2_glass_03.ogg`, `sfx100v2_glass_04.ogg`, `sfx100v2_glass_05.ogg`, `sfx100v2_glass_06.ogg` | 0.36, 0.67, 0.61, 0.24, 0.55, 0.40 |
| `hit` (3) | `sfx100v2_hit_01.ogg`, `sfx100v2_hit_02.ogg`, `sfx100v2_hit_03.ogg` | 0.48, 0.46, 0.22 |
| `items` (2) | **SHIPPED** `sfx100v2_items_01.ogg`, **SHIPPED** `sfx100v2_items_02.ogg` | 0.57, 0.51 |
| `lock_open` (1) | **SHIPPED** `sfx100v2_lock_open_01.ogg` | 0.64 |
| `loop_ambient` (4) | `sfx100v2_loop_ambient_01.ogg`, `sfx100v2_loop_ambient_02.ogg`, `sfx100v2_loop_ambient_03.ogg`, `sfx100v2_loop_ambient_04.ogg` | 10.09, 3.00, 3.51, 10.12 |
| `loop_construction_site` (1) | `sfx100v2_loop_construction_site.ogg` | 14.52 |
| `loop_highway` (1) | `sfx100v2_loop_highway.ogg` | 16.67 |
| `loop_machine` (4) | `sfx100v2_loop_machine_01.ogg`, `sfx100v2_loop_machine_02.ogg`, **SHIPPED** `sfx100v2_loop_machine_03.ogg`, `sfx100v2_loop_machine_04.ogg` | 7.56, 10.65, 1.84, 4.58 |
| `loop_water` (3) | **SHIPPED** `sfx100v2_loop_water_01.ogg`, `sfx100v2_loop_water_02.ogg`, `sfx100v2_loop_water_03.ogg` | 6.37, 8.73, 9.71 |
| `metal` (6) | `sfx100v2_metal_01.ogg`, `sfx100v2_metal_02.ogg`, `sfx100v2_metal_03.ogg`, `sfx100v2_metal_04.ogg`, `sfx100v2_metal_05.ogg`, `sfx100v2_metal_06.ogg` | 0.58, 0.32, 0.29, 0.38, 0.48, 0.29 |
| `metal_hit` (2) | **SHIPPED** `sfx100v2_metal_hit_01.ogg`, `sfx100v2_metal_hit_02.ogg` | 0.81, 0.21 |
| `misc` (37) | `sfx100v2_misc_01.ogg`, `sfx100v2_misc_02.ogg`, `sfx100v2_misc_03.ogg`, `sfx100v2_misc_04.ogg`, `sfx100v2_misc_05.ogg`, `sfx100v2_misc_06.ogg`, `sfx100v2_misc_07.ogg`, `sfx100v2_misc_08.ogg`, `sfx100v2_misc_09.ogg`, `sfx100v2_misc_10.ogg`, `sfx100v2_misc_11.ogg`, `sfx100v2_misc_12.ogg`, `sfx100v2_misc_13.ogg`, `sfx100v2_misc_14.ogg`, `sfx100v2_misc_15.ogg`, `sfx100v2_misc_16.ogg`, `sfx100v2_misc_17.ogg`, `sfx100v2_misc_18.ogg`, `sfx100v2_misc_19.ogg`, `sfx100v2_misc_20.ogg`, `sfx100v2_misc_21.ogg`, `sfx100v2_misc_22.ogg`, `sfx100v2_misc_23.ogg`, `sfx100v2_misc_24.ogg`, `sfx100v2_misc_25.ogg`, `sfx100v2_misc_26.ogg`, `sfx100v2_misc_27.ogg`, `sfx100v2_misc_28.ogg`, `sfx100v2_misc_29.ogg`, `sfx100v2_misc_30.ogg`, `sfx100v2_misc_31.ogg`, `sfx100v2_misc_32.ogg`, `sfx100v2_misc_33.ogg`, `sfx100v2_misc_34.ogg`, `sfx100v2_misc_35.ogg`, `sfx100v2_misc_36.ogg`, `sfx100v2_misc_37.ogg` | 0.26, 0.81, 0.93, 0.46, 0.54, 0.38, 0.18, 0.27, 0.67, 1.06, 0.36, 2.47, 0.67, 0.37, 0.53, 0.80, 0.43, 0.51, 0.47, 0.33, 1.41, 3.22, 0.69, 0.69, 0.75, 0.34, 0.34, 2.04, 0.33, 0.31, 0.28, 0.60, 0.62, 0.82, 0.76, 0.45, 4.85 |
| `stones` (3) | `sfx100v2_stones_01.ogg`, `sfx100v2_stones_02.ogg`, `sfx100v2_stones_03.ogg` | 0.49, 0.56, 0.53 |
| `switch` (2) | **SHIPPED** `sfx100v2_switch_01.ogg`, `sfx100v2_switch_02.ogg` | 0.23, 0.23 |
| `thunder` (1) | `sfx100v2_thunder_01.ogg` | 5.26 |
| `wood` (4) | `sfx100v2_wood_01.ogg`, `sfx100v2_wood_02.ogg`, `sfx100v2_wood_03.ogg`, `sfx100v2_wood_04.ogg` | 0.53, 0.45, 0.68, 0.23 |
| `wood_hit` (3) | `sfx100v2_wood_hit_01.ogg`, `sfx100v2_wood_hit_02.ogg`, **SHIPPED** `sfx100v2_wood_hit_03.ogg` | 0.35, 0.36, 0.47 |

| file | duration (s) | shipped as |
| --- | --- | --- |
| `qubodup-DoorClose01.ogg` | 1.00 | — |
| `qubodup-DoorClose02.ogg` | 1.00 | — |
| `qubodup-DoorClose03.ogg` | 1.00 | — |
| `qubodup-DoorClose04.ogg` | 1.00 | `sfx/door_creak.ogg` |
| `qubodup-DoorClose05.ogg` | 1.00 | — |
| `qubodup-DoorClose06.ogg` | 1.00 | — |
| `qubodup-DoorClose07.ogg` | 1.00 | `sfx/door_close.ogg` |
| `qubodup-DoorClose08.ogg` | 1.00 | — |
| `qubodup-DoorClose09.ogg` | 1.00 | — |
| `qubodup-DoorClose10.ogg` | 1.00 | — |
| `qubodup-DoorOpen01.ogg` | 1.00 | — |
| `qubodup-DoorOpen02.ogg` | 1.00 | — |
| `qubodup-DoorOpen03.ogg` | 1.00 | — |
| `qubodup-DoorOpen04.ogg` | 1.00 | — |
| `qubodup-DoorOpen05.ogg` | 1.00 | `sfx/door_open.ogg` |
| `qubodup-DoorOpen06.ogg` | 1.00 | — |
| `qubodup-DoorOpen07.ogg` | 1.00 | — |
| `qubodup-DoorOpen08.ogg` | 1.00 | — |

**Kenney Interface Sounds** — `interface_sounds`

| file | duration (s) | shipped as |
| --- | --- | --- |
| `back_001.ogg` | 0.064 | — |
| `back_002.ogg` | 0.070 | — |
| `back_003.ogg` | 0.093 | — |
| `back_004.ogg` | 0.073 | — |
| `bong_001.ogg` | 0.123 | — |
| `click_001.ogg` | 0.100 | `ui/click_03.ogg` |
| `click_002.ogg` | 0.010 | `ui/click_01.ogg` |
| `click_003.ogg` | 0.010 | — |
| `click_004.ogg` | 0.010 | — |
| `click_005.ogg` | 0.010 | `ui/click_02.ogg` |
| `close_001.ogg` | 0.148 | — |
| `close_002.ogg` | 0.314 | — |
| `close_003.ogg` | 0.314 | — |
| `close_004.ogg` | 0.323 | — |
| `confirmation_001.ogg` | 0.290 | `ui/confirm.ogg` |
| `confirmation_002.ogg` | 0.539 | — |
| `confirmation_003.ogg` | 0.322 | — |
| `confirmation_004.ogg` | 0.490 | — |
| `drop_001.ogg` | 0.110 | — |
| `drop_002.ogg` | 0.191 | — |
| `drop_003.ogg` | 0.191 | — |
| `drop_004.ogg` | 0.287 | — |
| `error_001.ogg` | 0.165 | — |
| `error_002.ogg` | 0.165 | — |
| `error_003.ogg` | 0.533 | — |
| `error_004.ogg` | 0.103 | — |
| `error_005.ogg` | 0.500 | `ui/cancel.ogg` |
| `error_006.ogg` | 0.500 | — |
| `error_007.ogg` | 0.192 | — |
| `error_008.ogg` | 0.139 | — |
| `glass_001.ogg` | 0.278 | — |
| `glass_002.ogg` | 0.125 | — |
| `glass_003.ogg` | 0.124 | — |
| `glass_004.ogg` | 0.692 | — |
| `glass_005.ogg` | 0.111 | — |
| `glass_006.ogg` | 0.111 | — |
| `glitch_001.ogg` | 0.020 | — |
| `glitch_002.ogg` | 0.030 | — |
| `glitch_003.ogg` | 0.010 | — |
| `glitch_004.ogg` | 0.023 | — |
| `maximize_001.ogg` | 0.258 | — |
| `maximize_002.ogg` | 0.258 | — |
| `maximize_003.ogg` | 0.212 | — |
| `maximize_004.ogg` | 0.418 | — |
| `maximize_005.ogg` | 0.526 | — |
| `maximize_006.ogg` | 0.380 | — |
| `maximize_007.ogg` | 0.186 | — |
| `maximize_008.ogg` | 0.225 | — |
| `maximize_009.ogg` | 0.225 | — |
| `minimize_001.ogg` | 0.258 | — |
| `minimize_002.ogg` | 0.258 | — |
| `minimize_003.ogg` | 0.212 | — |
| `minimize_004.ogg` | 0.418 | — |
| `minimize_005.ogg` | 0.526 | — |
| `minimize_006.ogg` | 0.380 | — |
| `minimize_007.ogg` | 0.186 | — |
| `minimize_008.ogg` | 0.225 | — |
| `minimize_009.ogg` | 0.225 | — |
| `open_001.ogg` | 0.148 | — |
| `open_002.ogg` | 0.314 | — |
| `open_003.ogg` | 0.314 | — |
| `open_004.ogg` | 0.323 | — |
| `pluck_001.ogg` | 0.102 | — |
| `pluck_002.ogg` | 0.165 | — |
| `question_001.ogg` | 0.491 | — |
| `question_002.ogg` | 0.333 | — |
| `question_003.ogg` | 0.332 | — |
| `question_004.ogg` | 0.332 | — |
| `scratch_001.ogg` | 0.139 | — |
| `scratch_002.ogg` | 0.139 | — |
| `scratch_003.ogg` | 0.123 | — |
| `scratch_004.ogg` | 0.325 | — |
| `scratch_005.ogg` | 0.325 | — |
| `scroll_001.ogg` | 1.000 | — |
| `scroll_002.ogg` | 1.000 | — |
| `scroll_003.ogg` | 1.000 | — |
| `scroll_004.ogg` | 1.000 | — |
| `scroll_005.ogg` | 1.000 | — |
| `select_001.ogg` | 0.043 | — |
| `select_002.ogg` | 0.043 | — |
| `select_003.ogg` | 0.383 | — |
| `select_004.ogg` | 0.383 | — |
| `select_005.ogg` | 0.383 | — |
| `select_006.ogg` | 1.944 | — |
| `select_007.ogg` | 0.047 | — |
| `select_008.ogg` | 0.047 | — |
| `switch_001.ogg` | 0.618 | — |
| `switch_002.ogg` | 0.611 | — |
| `switch_003.ogg` | 0.500 | `ui/switch.ogg` |
| `switch_004.ogg` | 0.500 | — |
| `switch_005.ogg` | 0.612 | — |
| `switch_006.ogg` | 0.611 | — |
| `switch_007.ogg` | 0.614 | — |
| `tick_001.ogg` | 0.023 | — |
| `tick_002.ogg` | 0.023 | — |
| `tick_004.ogg` | 0.055 | — |
| `toggle_001.ogg` | 0.139 | — |
| `toggle_002.ogg` | 0.139 | — |
| `toggle_003.ogg` | 0.139 | — |
| `toggle_004.ogg` | 0.066 | — |

**Kenney UI Audio** — `ui_audio`

| file | duration (s) | shipped as |
| --- | --- | --- |
| `click1.ogg` | 0.094 | — |
| `click2.ogg` | 0.056 | `ui/menu_back.ogg` |
| `click3.ogg` | 0.086 | — |
| `click4.ogg` | 0.037 | — |
| `click5.ogg` | 0.032 | `ui/menu_click.ogg` |
| `mouseclick1.ogg` | 0.059 | — |
| `mouserelease1.ogg` | 0.069 | — |
| `rollover1.ogg` | 0.227 | — |
| `rollover2.ogg` | 0.057 | — |
| `rollover3.ogg` | 0.069 | — |
| `rollover4.ogg` | 0.113 | — |
| `rollover5.ogg` | 0.112 | — |
| `rollover6.ogg` | 0.174 | — |
| `switch1.ogg` | 0.315 | — |
| `switch10.ogg` | 0.367 | — |
| `switch11.ogg` | 0.297 | `ui/menu_start.ogg` |
| `switch12.ogg` | 0.054 | — |
| `switch13.ogg` | 0.028 | — |
| `switch14.ogg` | 0.033 | — |
| `switch15.ogg` | 0.256 | — |
| `switch16.ogg` | 0.359 | — |
| `switch17.ogg` | 0.333 | — |
| `switch18.ogg` | 0.435 | — |
| `switch19.ogg` | 0.384 | — |
| `switch2.ogg` | 0.297 | — |
| `switch20.ogg` | 0.359 | — |
| `switch21.ogg` | 0.410 | — |
| `switch22.ogg` | 0.359 | — |
| `switch23.ogg` | 0.384 | — |
| `switch24.ogg` | 0.282 | — |
| `switch25.ogg` | 0.384 | — |
| `switch26.ogg` | 0.230 | — |
| `switch27.ogg` | 0.282 | — |
| `switch28.ogg` | 0.205 | — |
| `switch29.ogg` | 0.307 | — |
| `switch3.ogg` | 0.367 | — |
| `switch30.ogg` | 0.359 | — |
| `switch31.ogg` | 0.435 | — |
| `switch32.ogg` | 0.435 | — |
| `switch33.ogg` | 0.512 | — |
| `switch34.ogg` | 0.461 | — |
| `switch35.ogg` | 0.333 | — |
| `switch36.ogg` | 0.307 | — |
| `switch37.ogg` | 0.307 | — |
| `switch38.ogg` | 0.424 | — |
| `switch4.ogg` | 0.420 | — |
| `switch5.ogg` | 0.315 | — |
| `switch6.ogg` | 0.350 | — |
| `switch7.ogg` | 0.192 | — |
| `switch8.ogg` | 0.332 | — |
| `switch9.ogg` | 0.262 | — |

**steps/ and static/**

| file | duration (s) | shipped as |
| --- | --- | --- |
| `steps/01-footstep_0.ogg` | 0.154 | `sfx/footstep_stone_01.ogg` |
| `steps/02-footstep.ogg` | 0.169 | `sfx/footstep_stone_02.ogg` |
| `steps/03-footstep.ogg` | 0.317 | `sfx/footstep_stone_03.ogg` |
| `steps/04-footstep.ogg` | 0.333 | `sfx/footstep_stone_04.ogg` |
| `steps/05-footstep.ogg` | 0.314 | `sfx/footstep_stone_05.ogg` |
| `steps/06-footstep.ogg` | 0.246 | `sfx/footstep_stone_06.ogg` |
| `static/static1.wav` | 120.0 | `ambience/radio_static.ogg` (window 73–84 s) |
| `static/static3.wav` | 120.0 | — (unused, quieter-noise alternative) |

### 8.1 如果要把"撬"做得更狠：可选叠加方案

`pry_wood.ogg` / `pry_metal.ogg` 目前各是**单条**素材（对应任务里"挑一个"）。若后续觉得力度不够，
可用**时间错开**（不会相位抵消）的两层叠加，做成"先受力、后断裂"的两段式：

```bash
# 撬木板：wood_hit_01 之后 70 ms 接 wood_hit_03
ffmpeg -i sfx100v2_wood_hit_01.ogg -i sfx100v2_wood_hit_03.ogg -filter_complex   "[0:a]aresample=44100,pan=mono|c0=0.5*c0+0.5*c1,volume=0.9[a];   [1:a]aresample=44100,pan=mono|c0=0.5*c0+0.5*c1,volume=0.8,adelay=70|70[b];   [a][b]amix=inputs=2:duration=longest:normalize=0[out]" -map "[out]" -ac 1 -ar 44100   -c:a pcm_s16le pry_wood.wav
```

### 8.2 其他现成替代

* **上锁声**：`sfx100v2_switch_01.ogg`（0.227 s，机械落闩）——比当前的降调变体更"独立"。
* **开门/关门/吱呀**：DoorSet 另有 15 条未用（见上表），可扩成随机池。
* **脚步**：`sfx100v2_footstep_01/02.ogg`（通用脚步 2 条）未用；石材 6 条已全用。
* **收音机静电**：`static3.wav` 未用，可做第二条静电层（更亮更响）。
* **环境循环**：`sfx100v2_loop_ambient_01..04`、`loop_construction_site`、`loop_highway` 未用。
* **玻璃**：`sfx100v2_glass_01..06` 未用（动画 B 加油站袭击可用）。
* **雷声**：`sfx100v2_thunder_01.ogg` 未用（三级雷声可用它做音量/低通/混响三档）。
* **纸/薄物**：本批**刻意**避开 Page Flips（CC-BY-SA，见 §3.1）。

## 9. 接入建议（本次未执行，留给接入任务）

1. **总线**：当前工程只有 `Master` 一条总线（已回读确认）。建议建
   `Master → Music / Ambience / SFX / UI`。任务明确要求音频总线稍后由接入任务做，所以本次**没有**碰 `project.godot`。
2. **3D 与非 3D**：`footstep_*`、`door_*`、`lock_*`、`pry_*`、`generator_loop` 都是空间音源，
   挂 `AudioStreamPlayer3D`；`ui/*`、`music/*`、`ambience/radio_static` 挂非 3D 的 `AudioStreamPlayer`。
3. **⚠️ 全部文件是立体声**（编码器限制，§6.1）。`AudioStreamPlayer3D` 能播但空间化不如单声道精确。
   若这一点不可接受，就需要用 `libvorbis` 重出单声道版本（§6.3）。
4. **脚步随机池**：`footstep_wood_01..04`、`footstep_stone_01..06`、`footstep_wet_01..03`
   同族内电平已统一，可直接随机抽取 + 音高 ±5% 微调。
5. **循环素材**：`loop=true` 已设好，直接用即可；`loop_offset` 全为 0（§4.2 已说明理由）。
6. **`mus_blackout` 的断电瞬态**：当前循环里没有它（§4.2）。若要在停电时放那一下，
   需要从源 mp3 另做一条一次性音效。

## 10. 验证记录

全部在本机实测，不是推断：

| 检查 | 方法 | 结果 |
| --- | --- | --- |
| 导入 | `Godot_v4.7.2-stable_win64_console.exe --headless --path ...\game --import --log-file <路径>` | exit 0；40 个 `.import` 侧车生成；无 `SCRIPT ERROR`（仅有本机既有的 `Failed to read the root certificate store` 噪声） |
| 载入 + 循环标志 | 临时 GDScript（`extends SceneTree`）逐个 `load()` 回读 `loop` / `loop_offset` / `get_length()` | **40 个文件全部 `AudioStreamOggVorbis`，7 个循环素材 `loop=true`、`loop_offset=0.0`，其余 33 个 `loop=false`；problems=0** |
| `AudioStreamOggOpus` 是否存在 | `ClassDB.class_exists("AudioStreamOggOpus")` | **false**（证实任务给的前提，因此全程不用 Opus） |
| 内容完整性 | 解析每个 Ogg 的 page granule position，与编码输入 WAV 的帧数比较 | 40/40 `granule ≥ 源帧数`（+7…+60 样本舍入），**无内容丢失** |
| 波形保真 | 解码每个 `.ogg`，与编码输入 WAV 逐样本求相关系数 | **0.9945 – 0.9999**（`lock_close` 为降调派生，豁免） |
| 电平 / 削顶 | `volumedetect` + `loudnorm` 测量 | 无文件 ≥ −0.05 dBFS；真峰值最高 −1.32 dBTP |
| 采样率 | 全部探测 | 40/40 = 44100 Hz |
| 循环接缝 | `abs(out[0] − out[M−1])` / 信号自身逐样本跳变 RMS | 音乐 ×0.34…×1.05；`generator_loop` ×0.376 |

## 11. 明确未做 / 不确定的地方

1. **没有做主观试听。** 全程用信号度量（谱质心、包络、自相关、相关系数）选材，
   所有挑选规则都写在 §2 里可复现。**音色是否"对味"最终仍需人来听一遍。**
2. **`lock_close.ogg` 是派生变体**，不是独立录制的落锁声（DoorSet 没有锁具文件，§2.3）。
3. **任务表里的 `music/mus_surreal_truth.ogg` 这个名字没有采用**（见 §2.1 的命名偏差说明）。
4. **全部素材是立体声**，因为本机编码器不支持单声道（§6.1）。3D 空间化会略打折扣。
5. **4 个极短的 UI click 被补了静音**，时长变成 0.094 s（§6.1 缺陷 2）。
6. **没有建立音频总线**，`project.godot` 一字未改（任务要求）。
7. **`generator_loop` 的循环长度只有 3.08 s**，循环周期较短；源素材总共才 5.436 s，
   在"接缝无缝"的约束下这是能找到的最长优质环（备选 k=197 → 3.75 s，但接缝失配差 27%）。
8. **音乐的三档映射（dread_low / blackout / finale）是依据信号特征做的推断**，
   不是从原作剧情反推的；如果 PRD 对这三档有更具体的气质要求，可以按 §2.1 的表重新分配。

> §11.6 已于 2026-10-04 由接线任务推翻：总线已建立、`project.godot` 已新增 `[audio]` 一节。
> 本文档 §1–§10 仍是那批素材的入库记录，未改动。

## 12. 接入结果（2026-10-04，接线任务补充）

本节由**音频接入任务**追加，记录这批素材被接到哪里、哪些还没接。素材本身未改动、未重编。

**总线**：`Master → Music(−6 dB) / Ambience(−9 dB) / SFX(−2 dB) / UI(−4 dB) / Voice(0 dB)`，
布局资源 `game/infrastructure/audio/default_bus_layout.tres`，理由与分层见
[ADR 0010](adr/0010-audio-bus-and-port.md)。

| 素材 | 接入的 kind | 接线点 |
| --- | --- | --- |
| `music/mus_dread_low` / `mus_blackout` / `mus_finale` | `music.*` 三档 | 进庄园播第一档；另两档可切换（交叉淡化已实现） |
| `sfx/pickup_item` | `sfx.pickup` | 领取回执翻转；以及「从钱包抽出照片」那一步 |
| `sfx/put_item` | `sfx.put` | 从笔记本丢弃、物品落进世界 |
| `sfx/generator_loop` | `loop.generator` | 发电机自身节点上的 3D 循环，随启停，停机淡出 |
| `sfx/generator_crank` | `sfx.generator_crank` | 发电机启动成功那一下 |
| `sfx/pour_kerosene` | `sfx.pour_kerosene` | 启动成功**且**煤油门槛被满足 |
| `sfx/door_open` / `door_close` / `door_creak` | `sfx.door_open` / `sfx.door_close` | 门的开合翻转；`door_creak` 是两种 kind 各自的备选 take |
| `sfx/footstep_wood_01..04` | `sfx.footstep_wood` | 木地板房间；4 条随机池 + 音高 ±5% |
| `sfx/footstep_stone_01..06` | `sfx.footstep_stone` | 地窖 / 地窖楼梯 / 卫生间；6 条池 |
| `sfx/footstep_wet_01..03` | `sfx.footstep_wet` | 门廊 / 室外；3 条池 |
| `sfx/pry_wood` + `sfx/pry_metal` | `sfx.pry_wood` / `sfx.pry_metal` | 撬开地窖盖板那一刻，两条同时 |
| `sfx/lock_open` | `sfx.lock_open` | 钥匙解锁医务柜 |
| `ambience/radio_static` | `loop.radio_static` | 收音机自身节点上的 3D 循环，第一次查看（开机）后长响 |
| `ui/click_01..03` | `ui.click` | 准星换目标（3 条池） |
| `ui/confirm` / `ui/cancel` / `ui/switch` | `ui.confirm` / `ui.cancel` / `ui.switch` | 笔记本指令成功 / 被拒 / 开关（含收音机开机） |
| `ui/menu_start` / `menu_click` / `menu_back` | `menu.*` | 主菜单与故事档案按钮 |

**尚未接入**：

* `sfx/lock_close`——已映射到 `sfx.lock_close`，但本轮没有任何「落锁/回锁」事件可接：医务柜与地窖
  都是一次性单向状态。接一个可上锁容器即可用。
* `Ambience` 总线本轮没有源：任务把发电机与收音机都划给 `SFX`（3D 空间音源），而 `ambience/`
  下唯一入库的 `radio_static` 就是收音机上的 3D 源。将来要铺非 3D 环境床，只需在
  `audio_library.gd` 加一个 kind，`set_ambience` 会自动给它建非 3D 播放器。
* §8 里其余未入库素材（`loop_ambient_*`、`thunder`、`glass`、`metal`、`misc` 等）仍未入库、未接线。

**已知折衷（立体声）**：这批 40 个文件全部是**立体声（双单声道）**，因为本机原生 vorbis 编码器只接受
2 声道（§6.1）。`AudioStreamPlayer3D` 能正常播放，但空间化不如单声道精确——立体声源不做方向性处理，
声像基本只由距离与听者朝向决定。这是本轮明确接受的折衷；重出单声道的方法与命令见 §6.3
（拿到带 `libvorbis` 的 ffmpeg 或 `oggenc` → `-ac 1 -c:a libvorbis` → 重跑 `--import` →
重写 7 个循环素材 `.import` 里的 `loop=true`），重编后**只需改 `audio_library.gd` 一处**，
因为 kind → 文件、总线、3D/非 3D 的解析全在那张表里。

**验证**：`game/tests/audio/test_audio.gd`（141 checks，标记 `AIRPG_AUDIO_TESTS`）覆盖契约
（端口 kind ↔ 词表 ↔ 总线 ↔ 循环标志 ↔ 菜单不得用材质音）、真实适配器（headless 树里的池/音高/
循环/淡出/交叉淡化）与接线（庄园 + 视图 + 笔记本 + 菜单，用记录型端口而非音频设备）。
素材在 headless（Dummy 驱动）下加载与播放均无错误。

