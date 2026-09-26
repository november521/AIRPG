# 契约与版本

## 当前已实现 API

所有路径相对 `game/`。GDScript 通过显式 preload 类型协作，外部 JSON 的 Variant 只在边界校验器中处理。

| 契约 | 输入 / 输出 | 不变量 |
| --- | --- | --- |
| `shared/result.gd` | `success(value)` / `failure(code, issues)` | ok 为 false 时调用者不得使用 value；code 为稳定技术标识 |
| `ContentValidator.validate` | pack Variant + 受信 Schema → Result | 全部验证后返回深拷贝；不执行条件或推进状态 |
| `Conditions.matches` | 条件数组 + flags → bool | 全部条件与关系；未知格式/flag 返回 false |
| `StateStore.configure` | Dictionary<String, bool> → Result | 仅可初始化一次；失败不修改状态 |
| `StateStore.snapshot` | → `{revision: int, flags: Dictionary}` | 深拷贝 |
| `StateStore.commit` | 预期版本 + 非空布尔更新 → Result(snapshot) | 仅预声明键；全验证、全提交；版本不匹配拒绝 |
| `SessionService` | `read_state()` / `diagnostics()` | UI 只读入口，尚无剧情用例命令 |
| `ModelProvider.start` | request_id + 已隔离上下文 → Result | 同步失败不会发终止信号；接受后才开始异步信号协议 |
| `ModelProvider` 信号 | raw_delta(id, chunk)、completed(id, Dictionary)、failed(id, code) | 每个已接受请求恰有一个终止信号；raw_delta 不等于已验证台词 |
| `ModelProvider.cancel` | request_id | 后续适配器须实现幂等取消；已完成请求无操作，正在执行者发 failed(id, REQUEST_CANCELLED) 一次 |
| `SaveRepository` | write_snapshot(slot, Dictionary) / read_snapshot(slot) | 本次只有接口与内存测试适配器，无生产保存功能 |
| `RandomSource` | roll(sides)、capture()、restore(checkpoint) | 独立会话源；非法参数/检查点不推进 RNG |
| `SceneRouter` | configure(host, routes)、navigate(id) → Result(Node) | 节点移除后延迟释放；无效路由保留旧视图 |

Result 的公开属性是值协议，不是强不可变类型。领域状态和内容边界自行深拷贝；不能凭借 Result 自动获得隔离。
当前基类端口返回 NOT_IMPLEMENTED；模型默认适配器返回 AI_NOT_CONFIGURED。不得忽略 ok 并继续当成功使用。
请求字典的完整业务 DTO 在对话工作包冻结；端口接口稳定并不代表 AI 数据契约或知识隔离已经实现。

## JSON Schema 子集

运行时支持：`type`、`required`、`properties`、`additionalProperties`（布尔或 Schema）、`items`、`enum`、`const`、`minLength`、`pattern`、`minimum`、`maximum`、`maxItems`、`maxProperties`。
`$schema`、`title`、`description` 仅元数据。最多递归 32 层。Schema 文件由代码评审管理，不能由模型或外部第三方提供。
JSON 数字的整数校验接受有限、无小数的浮点解析结果，拒绝布尔值冒充整数。
该校验器不是完整 JSON Schema 2020-12 实现；使用新关键字必须先增加验证器和测试，或换成明确锁定版本的完整实现。

## 内容目录 v1

`data/schemas/content_pack.schema.json` 是机器契约。根对象必须包含：

- `schema_version`：当前 1。
- `pack_id`：稳定命名空间 ID；`content_version`：作者定义的内容修订号。
- `locale`：当前仅 zh_CN。
- `flags`：预声明布尔标记与初始值。
- `localization`：供定义引用的文本表。
- `definitions`：带 id、kind、text_key、references、conditions 的元数据目录。

kind 覆盖角色、场景、节点、线索、话题、规则和事实。它目前只表示目录类型，不意味着已经实现该种业务定义。
所有 ID 在单个包中唯一，引用限于当前包。多包组合、按种类强类型引用、角色权限等需要后续契约，不能假定当前已支持。
条件只支持 `{flag, equals}` 的布尔合取。后续数值技能条件要新增明确操作类型，禁止自由表达式。
界面固定文本位于 `data/localization/zh_CN.json`；内容文本目录与界面文本分开维护，当前内容包为空。

## 后续契约的评审顺序

1. 内容团队先确认被授权的内容输入；数据/架构岗位确定专用定义和 ID。
2. 规则岗位依据已确认公式定义 check 请求/结果与 RNG 事务检查点。
3. 对话/AI 岗位一起定义上下文 DTO、请求生命周期、响应 DTO、验证片段、取消/重试语义。
4. 状态与存档岗位定义完整会话快照、保存资格、版本迁移、内容版本绑定。
5. 消费者使用独立假实现并行开发；真实适配器通过同一契约测试后接入。

所有契约变更都应列出消费者、兼容方式、测试夹具和迁移策略。没有实现的端口不能作为“功能已完成”的证据。
