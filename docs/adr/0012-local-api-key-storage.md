# ADR 0012：本机保存 API Key（项目之外）

日期：2026-10-04。状态：已实施（本机验证，未推送）。工作包：AI 凭据本地持久化 / 负责人本任务 /
独立对抗复核待分配。依据 PRD §17.2（“个人原型阶段本地配置 API 密钥”“密钥只能保存在项目之外的本机配置
或环境变量中”）、AGENTS.md（密钥只能从项目外本机配置/环境变量读取，不得放入 res://、上下文、日志或导出包）；
用户要求“把 apikey 保存在本地，不然重启一次配置一次太麻烦”。

## 背景

此前 `runtime_model_configuration.gd` 只把凭据放在进程内存里（ADR 0009 的记录：运行内存配置，
不做持久化）。单机试玩每次启动都要重新粘贴 Key，实际使用中很容易忘记配置，从而落到“固定问候”降级路径，
反而让玩家以为 AI 对话坏了。

## 决定

1. 新增 `infrastructure/ai/local_credential_store.gd`：唯一接触凭据文件的适配器，默认路径
   `user://ai_credentials.json`。`user://` 在 Windows 上是 `%APPDATA%\Godot\app_userdata\AIRPG\`，
   **在 res:// 之外、在仓库之外、不进入导出包**，符合 PRD 与 AGENTS.md 的“项目外本机配置”。
2. 文件内容为 `{schema_version, endpoint_url, model, api_key}`，读取时严格校验：字段精确匹配、
   类型正确、非空、长度上限（endpoint 2048 / model 128 / key 512）、拒绝控制字符；不合法即失败关闭，
   绝不部分采用。写入是 best-effort：写不进去只影响“下次不用重填”，不阻止本次配置成功。
3. 端口 `ModelConfiguration` 增加 `restore()` 与 `configure_stored(endpoint, model)`：
   组合根在启动时调用 `restore()`；设置面板里 Key 留空表示“沿用已保存的密钥”，方便只换模型或地址。
4. 断开（`clear()`）同时删除内存凭据与本机文件。
5. 诊断字典只增加布尔 `stored`，不含 Key；`AIRPG_NPC_AI` 等日志标记也不含 Key。
6. `.gitignore` 增加 `ai_credentials.json` 兜底规则：即使有人把它复制进项目目录也不会被提交。

## 已知风险与取舍（明确接受）

- 文件是**明文**，任何能访问该 Windows 账户的人都能读取；Godot 没有内置钥匙串，
  自行加密只会把明文密钥移到同一个文件旁边，不构成真正的保护。
- 本机备份、云同步（OneDrive 等）或恶意软件可能带走该文件；撤销手段是在服务商侧轮换/吊销 Key，
  或点“断开”删除本机文件。
- 因此该方案只适用于**个人原型**。分发前必须改为服务端转发（PRD §17.2 已有此要求），
  届时本机文件应随实现一起移除。
- 凭据仍不进 `res://`、不进存档、不进日志、不进导出包；测试只使用临时文件名并在结束时清理。

## 兼容性

- 端口新增方法都有默认 `NOT_IMPLEMENTED` 实现，旧适配器不受影响；测试夹具无需改动。
- `ModelConnectionService.configure` 在 Key 为空且适配器支持 `configure_stored` 时走“沿用已保存密钥”，
  否则行为与之前一致。
- 设置面板文案改为说明本机保存与删除方式；`ai.settings.key_hint` 改为“留空则沿用已保存的密钥”。

## 验证

`AIRPG_TESTS: 111 项 NPC-AI`（其中新增 11 项：缺失文件、写入/读回、重启后 `restore` 成功、
诊断不含 Key、Key 留空复用、损坏文件失败关闭、控制字符拒收、断开删除文件）。全量聚合与三步等价验证
（架构、导入、启动标记）随本轮记录。未使用真实 Key：测试用合成字符串，且不写进最终交付物。
