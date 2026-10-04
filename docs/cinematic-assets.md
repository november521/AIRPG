# 影视素材（开场动画）

本文件记录工程里视频素材的来源与转码方式。当前只有一条：《死光》开场动画。

## deadlight_opening.ogv

| 项 | 值 |
| --- | --- |
| 文件 | `game/presentation/cinematic/deadlight_opening.ogv` |
| 来源 | 用户提供的 `死光开场动画.mp4`（2026-10-03，3.7 MB） |
| 内容 | 《死光》开场，20.07 秒，1280×720，24 fps |
| 转码 | H.264 + AAC → **Ogg Theora (q6) + Vorbis (q4)**，3.9 MB |
| 播放 | `presentation/cinematic/opening_cutscene.gd` 用 `VideoStreamPlayer` 播；Godot 4 只支持 Theora |

**授权状态未确认**：影片由用户提供，工程不掌握其版权信息。对外分发或上架前必须由用户确认授权；
`docs/adr/0014-deadlight-opening-cutscene.md` 记录了这次接入的决策与失败开放（fail-open）取舍。

## 复现转码

需要含 `libtheora` 与 `libvorbis` 的 ffmpeg（本项目未把它放进仓库；CI 不需要转码，因为 `.ogv`
已在仓库里）：

```powershell
ffmpeg -y -i "死光开场动画.mp4" -c:v libtheora -q:v 6 -c:a libvorbis -q:a 4 `
  -pix_fmt yuv420p game\presentation\cinematic\deadlight_opening.ogv
```

参数说明：`-q:v 6` 在 Theora 的 0–10 量级里偏高保真，20 秒 720p 约 3.9 MB；`-q:a 4` 是 Vorbis 的
常用音乐档位；`-pix_fmt yuv420p` 保证解码器与播放器的色度取样一致。

## 替换素材时要注意

- 保持文件名与路径不变即可，脚本用 `preload` 按路径引用，
  **不需要**提交 `deadlight_opening.ogv.uid`（仓库对非脚本资源不提交 uid，与 `game/audio/**` 一致）。
- 分辨率/时长变化不需要改代码：守护计时器按 `VideoStreamPlayer.get_stream_length() + 5 s` 自适
  应；只有换路径或换格式才需要动 `opening_cutscene.gd` 的 `OPENING` 常量。
- 若换成非 Theora 容器（如 WebM/MP4），Godot 内置播放器无法播放，必须再转码。
