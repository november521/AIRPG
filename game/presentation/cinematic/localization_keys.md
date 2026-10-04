# 开场动画本地化键

已并入 `game/data/localization/zh_CN.json`（2026-10-04）。

| 键 | 用途 |
| --- | --- |
| `cutscene.skip` | 跳过开场按钮文本 |
| `cutscene.hint` | 跳过方式与自动继续的提示行 |

缺失翻译时界面回退显示键名，不阻断播放；`tests/cinematic/test_opening_cutscene.gd` 会检查这两个键
确实有翻译，而不是键名本身。
