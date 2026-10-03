# 开始界面美术：目标图第一轮接入

日期：2026-09-27。依据用户最后提供的金属 Logo / 金色轨道 / 黑金烟雾目标图。
本轮为渐进美术升级的第一版，未宣称逐像素复刻或最终美术验收。

## 整幅雨夜庄园封面（2026-10-03，当前版本）

用户给出新的封面效果图，要求“把游戏封面页变成这个图片，保持原有交互不变”。
本轮把封面换成整幅 1672×941 雨夜庄园图（庄园窗灯、满月、雨、湿路与关闸），
菜单交互、焦点/悬停过渡、导航与退出信号、开场/离场时序全部未改。

图层变化：

- 新增 `art/cover_night_gate.png`：用户效果图本体。图内自带 AIRPG 字标与
  “开始游戏 / 设置 / 退出游戏”文字，因此先用局部背景估计把这九字、装饰细线、
  菱形和文字下方光带从底图抹掉，再让真实菜单在同一位置绘制本地化文字与柔光，
  避免出现重影。抹除只影响菜单所在的三小块区域，其余像素与原图一致
  （整图平均最大通道差 1.83/255，主要来自重采样）。
- 新增 `art/cover_logo_shine.png`：从同一张图裁出的字标区域 (145,183)–(772,456)，
  alpha 由亮度推出，用原 `foil_shine.gdshader` 承载扫光，使金属字标保留原有的
  缓慢反光动效；因为贴合在同一像素位置上，不扫光时画面与底图完全一致。
- 场景删除 `Smoke`、`Atmosphere`、`FateSigil`、`InnerOrbit`、`CrossingOrbit`、
  `DottedOrbit`、`Logo`、`CelestialLights` 节点；旧材质、旧底图与 `fate_sigil.gd`
  仍留在 art/ 目录，随时可回退上一版。
- `menu_theme.tres` 字体 42 未变；`menu_entry.tscn` 最小宽度由 480 改为 240，
  使柔光细线长度与封面图原有的装饰线对齐。

真实图形窗口截图（1920×1080，OpenGL 兼容 / Intel Iris Xe）已与用户效果图
按 50% 叠加核对：背景、庄园、月亮与道路完全重合，无重影；三行文字中心
落在效果图对应位置 1–3 px 以内。字体沿用系统衬线回退，与效果图里的字形
不逐像素相同。

## 已接入图层（2026-09-27 版本，保留可回退）

- airpg_gold_v2.png：1942×809 RGBA，透明金属字标。使用内置 image_gen 依据目标图
  制作的美术版本，保留 A 中心星形和长弧识别特征；并非原 Logo 的逐像素金属化。
  原始 airpg_logo.png 与旧材质保留，可回退。
- smoke_gold_v1.png：1672×941，无菜单文字、轨道或 Logo 的烟雾底图。
- smoke_flow.gdshader：复用烟雾底图作三层不同尺度、方向和速度的有界流动；
  边缘减弱位移、中央减弱叠层、亮度缓慢呼吸，不采用叠加增亮。
- fate_sigil.gd + engraving.gdshader：独立几何椭圆、点线轨迹、中轴、上下星形、
  水平细线及菱形；固定框架与三个旋转层分离，几何不每帧重建。
- celestial_lights.gdshader：5 个缓慢沿外轨道运行的光点、上下星芒、3 处错峰反光。
- atmosphere.gdshader：36 个独立漂浮光点，分为远层 18 / 中层 12 / 近层 6 个，
  异速漂移、缓慢明灭、循环边缘淡入淡出。背景素材本身还包含少量绘制的光点。
- foil_shine.gdshader：保留美术图 RGBA，在金属亮面上增加弱扫光。
- menu_halo.gdshader：柔光、左右细线、菱形、文字下方光带；沿用 250 ms 焦点过渡。

所有美术资产归属 game/presentation/menu/art；场景显式引用，走标准 Godot 导入与
资源打包。原生成文件保留在本机生成目录，游戏不依赖该目录。

## 构图与可调参数

画布仍为 1920×1080 等比缩放。Logo 区域 (410,154)–(1510,612)，保持原生成
资产约 2.4:1 比例；轨道区域 (500,62)–(1420,704)；菜单起点 y=750，
行高 72、间距 14，字体 42。菜单仍为开始游戏、设置、退出游戏。

当前烟雾 exposure=0.82、drift_strength=0.018、motion_speed=1.0、
depth_strength=0.7；轨道 opacity=0.72。
这些值遵循用户最新效果图，比此前“10%–25% 弱印记”版本更明亮。
外轨道光点角速度 0.014 rad/s；Logo 扫光参数 0.052 UV/s，
反光强度 0.095、局部微光强度 0.025；特效只使用视觉时钟，不读取剧情状态或消耗会话随机源。

## 动态增强第二轮（2026-09-27，待用户检查）

粒子维持 36 个循环上限，近层半径更大且更柔和，远层更慢更细；速度与横向
摆幅随深度分层，采用固定视觉种子。上下两极、五个轨道光点分别慢速错峰明灭，
三个 Logo 反光点延长淡入淡出。金属字标增加沿亮面移动的弱微光，扫光约每
31 秒完成一个周期；透明度、字形、配色和菜单交互不变，没有全屏闪光。

仅调整三个已有着色器，无新增素材、脚本或 UID。架构检查通过（89 文件），
资源导入完成；真实 GPU 预览日志 motion2-preview.engine.log 含 AIRPG_BOOT_READY，
未见错误。没有运行测试套件、像素对比或性能验收；风险仍为细小高光在不同 DPI
下的闪烁、长时间观感、全屏粒子着色器开销。静态烟雾底图自带的光点不会单独漂浮。
已打开预览供用户检查；尚未合并主项目，必须等待用户明确反馈后才处理合并。

## 动态增强第一轮（2026-09-27）

范围仅为云雾和轨道，保留上移后的 Logo、菜单排版、既有粒子与反光节奏。
FateSigil 保留外环、中轴、两极及水平装饰。InnerOrbit / CrossingOrbit /
DottedOrbit 复用同一几何脚本的分层枚举，各自持有独立材质；角速度依次为
0.022 / -0.016 / 0.012 rad/s。顶点在归一化轨道坐标内旋转后映射回
920×642 框架，避免长轴旋转后撞入菜单；这是二维投影动效，不是三维天体模拟。
没有增加每帧 CPU 重绘、计时器、全局服务或游戏状态依赖。

云雾每像素由原先一次纹理采样改为三次，远/近层取同一素材的不同尺度，
并进行错向流动。深度混合采用归一化权重，保护中心文字区域；这仍是二维
素材的层叠流动，不是真实体积烟雾。motion_speed=0 可单独冻结云雾，
各轨道 angular_speed=0 可单独停止旋转；尚无玩家减弱动效设置或全局截图时钟。

开发侧检查：89 个源/场景文件的架构检查通过；固定引擎资源导入和实际 GPU
短暂启动完成，motion-import.engine.log / motion-startup.engine.log 无错误，
后者包含 AIRPG_BOOT_READY。首次受限环境启动无法写引擎缓存，授权后重跑完成。
没有运行完整测试或视觉回归，未声称像素还原达标。独立复核重点：长期旋转的
舒适度、细线闪烁、边缘采样、不同窗口比例、低配 GPU 开销及长时间运行。

本轮未新增音效、音乐或游戏功能。设置仍按用户要求点击无操作。

## 生成方式与完整提示词

方式：内置 image_gen；两次独立素材生成，未使用 CLI 或项目 API 密钥。
输入均为用户最后提供的目标效果图，角色为视觉参考/素材提取目标。

### 透明金属 Logo

```text
Use case: background-extraction. Asset type: actual transparent PNG game title sprite for AIRPG. Input Image 1 is the user's final approved design reference. Extract/recreate ONLY the large central metallic wordmark "AIRPG" from that image onto a genuinely transparent alpha background. Preserve the exact ornate A with four-point star through its center, the long sweeping lower flourish, and the I R P G serif shapes and their spacing. Match the reference's dimensional beveled gold: ivory-gold lit faces, amber-gold bevels, deep bronze inset edges, polished directional reflections and fine subtle patina. The logo is the whole asset, not a mockup. Wide landscape canvas about 2.4:1. Center the complete logo with 5 percent transparent padding, no cropping. NO orbit circles, no separate stars, no menu, no Chinese characters, no smoke, no particles, no rectangle, no black backdrop, no checkerboard baked into pixels, no watermark. Preserve the full A star and all sweeping tails. Text exactly AIRPG once.
```

保存：game/presentation/menu/art/airpg_gold_v2.png。
已检查像素格式为 32bpp ARGB，空白角落 alpha=0。

### 烟雾底图

```text
Use case: precise-object-edit. Asset type: actual 16:9 background plate for a layered Godot game title screen. Input Image 1 is the final approved visual reference. Produce ONLY its atmospheric background: black void with dark warm bronze/amber/gold wisps of fine volumetric smoke sweeping diagonally around a calm black central region. Remove ALL typography, logo, buttons, menus, orbit circles, geometric lines, diamond ornaments and star symbols. Keep the reference's elegant warm gold smoke palette and irregular fine tendrils with a few softly luminous eddies, edges mostly black. Calm upper-central space for a separately rendered title and dark lower-central space for live UI. NO text of any kind, no letters, no border, no symbols, no watermark. Use a small number of tiny subdued dust specks only, most particles will be rendered at runtime. Full bleed widescreen 16:9, richly detailed fine smoke, NOT orange fire or a bright cloud wall.
```

保存：game/presentation/menu/art/smoke_gold_v1.png。

## 交接与后续细化

已完成固定引擎资源导入、架构静态检查（89 个源/场景文件）和真实图形窗口预览；
启动日志无脚本、纹理、着色器错误。日志位于 artifacts/launch.engine.log。
本轮未运行完整测试、导出验证、低配性能测试或独立对抗验收。

后续可在本图层结构上细调轨道反光位置、烟雾明暗、字体和动画节奏。
生成 Logo 与目标图字形存在微小差别；要做到精确轮廓应进一步美术修订，
不能将本轮描述为原始 Logo 字节完全一致。QA 重点关注透明边缘、打包资源、
非 16:9 留边、不同 DPI、特效开销和退出时动画释放。
