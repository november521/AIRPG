# I1 对话界面本地化键清单

本文件只登记键名。**2026-10-04 已全部并入** `game/data/localization/zh_CN.json`（含后来新增的
`MODEL_EMPTY_CONTENT` / `MODEL_FINISH_INCOMPLETE` / `MODEL_REPLY_INVALID` 三个错误码键与
`dialogue.history.divider`）；此前正式构建里界面会显示键名，缺失翻译时的回退行为保留但不再触发。

## 固定界面文本

| 键 | 用途 |
| --- | --- |
| `dialogue.name.unknown` | 说话者姓名缺失翻译时的占位名 |
| `dialogue.you` | 历史面板中玩家发言的署名 |
| `dialogue.free_text.placeholder` | 自由输入框占位文本 |
| `dialogue.free_text.send` | 自由输入提交按钮 |
| `dialogue.free_text.rejected` | 本地输入被契约拒绝时的提示 |
| `dialogue.waiting` | 等待模型回应状态 |
| `dialogue.paused` | 不可重试失败后的暂停状态（后附稳定错误码） |
| `dialogue.cancelled` | 请求已取消状态 |
| `dialogue.failed.generic` | 可重试失败的通用说明（后附稳定错误码） |
| `dialogue.retry` | 重试按钮 |
| `dialogue.skip` | 跳过渐进文字播放按钮 |
| `dialogue.back` | 失败/暂停/取消状态下的返回按钮 |
| `dialogue.portrait.missing` | 缺失立绘占位说明 |
| `dialogue.history.toggle` | 打开历史记录面板按钮 |
| `dialogue.history.title` | 历史记录面板标题 |
| `dialogue.history.close` | 关闭历史记录面板按钮 |

## 稳定错误码文本

以下键的 `{code}` 为 `ModelTransportContract` 冻结的稳定错误码。缺失时界面回退为
`dialogue.failed.generic (code)`，不会把供应商原始错误文本展示给玩家。

| 键 | 对应错误码 |
| --- | --- |
| `dialogue.error.AI_NOT_CONFIGURED` | `AI_NOT_CONFIGURED` |
| `dialogue.error.MODEL_TIMEOUT` | `MODEL_TIMEOUT` |
| `dialogue.error.MODEL_TRANSPORT_ERROR` | `MODEL_TRANSPORT_ERROR` |
| `dialogue.error.MODEL_RESPONSE_INVALID` | `MODEL_RESPONSE_INVALID` |
| `dialogue.error.KNOWLEDGE_SCOPE_VIOLATION` | `KNOWLEDGE_SCOPE_VIOLATION` |
| `dialogue.error.REQUEST_CANCELLED` | `REQUEST_CANCELLED` |
| `dialogue.error.REQUEST_STALE` | `REQUEST_STALE` |

## 不提供的键

- 不登记任何《死光》台词、人物名或正式内容文本；`npc.*` 与选项文本来自对话用例的已验证回复。
- 不登记等待动画、立绘资源路径或音效键；这些属于美术/声音集成波次。
