# 个性化推荐：第 1 阶段数据基础

本阶段只建立可信的数据结构与统一收藏数据源，尚未接入推荐算法或 AI 偏好分析。

## 数据库 v10

- 通过 `RecommendationSchema.migrate` 增量增加 `usage_sessions`、`usage_feedback`、`preference_profiles`。
- 原 `usage_records` 增加 `session_id`、`source`、`status`；原 `smell_moment_record` 增加 `session_id`、`source`、`duration_seconds`。
- `moment_usage_records` 保存收藏与单风扇记录的精确关联，不再使用不存在的 `usage_record_ids` 字段或字符串模糊匹配。
- 开启外键约束。删除收藏会删除关联，但不删除使用记录；删除使用记录也不会删除收藏的气味快照。
- 旧使用记录标为 `legacy_unknown`，不推断会话、用户归属或硬件执行结果。
- 会话创建、开始即落库、异常恢复、组合分段及完整反馈写入在第 2 阶段实施。本阶段新增会话表不自动生成历史会话。

## 气味瞬间迁移

SQLite 是新收藏、列表与删除的唯一数据源。启动时导入 SharedPreferences 的 `smell_memories`，原内容保留为备份，不再双写。

仅当 SQLite 中存在唯一、尚未匹配、文本字段一致且创建时间位于旧记录之后 5 秒以内的记录时，认定为旧版双写副本。保留该 SQLite 记录的 ID、评分与配方。其他记录只导入可解析的标题、场景、表情、笔记和时间，并标记 `legacy_preferences`；不导入旧版写死的配方与时长。不能解析的内容仍留在原备份中。

`legacy_moment_imports` 在同一事务中保存每条导入凭据；删除收藏后凭据保留，后续启动不会恢复已删除收藏。无法确定的重复记录不会强行合并。旧版仅从 SharedPreferences 删除、但仍留在 SQLite 的记录没有删除凭据，无法追溯其删除意图。

## 数据可信度

- 新普通使用来源暂为 `app_command_unverified`；状态名不代表硬件确认。
- 新模拟使用及由其产生的收藏标为 `test`，从现有气味库、AI 个人气味库和关怀输入中排除。旧版模拟记录没有来源标记，无法可靠自动识别。
- 有使用记录关联的收藏暂标为 `linked_usage_unverified`；关联不证明这些气味曾同时使用。
- 收藏时长按已结束使用区间的并集计算，不累加并行风扇时间；测试、未结束、逆序区间及无记录时显示“未记录”。
- 收藏保存与关联写入在同一事务；关联记录缺失或保存失败会报告失败。

## 验证

运行 `flutter test test/data_foundation_test.dart`。Windows 环境沿用项目现有 sqlite3 system 配置，需要让 `sqlite3.dll` 位于进程可搜索路径。本机验证使用已有 Python 安装附带的 DLL，没有下载或修改数据库依赖。

覆盖新建数据库、v9 升级、结构重复执行、外键、评分范围、准确关联、并行时长、保存失败回滚、旧收藏去重、删除不复活及旧文本保留。测试使用独立临时数据库，不打开用户数据库或连接 BLE。

下一阶段先修复 BLE 失败记账、全部关闭与定时结束，再启用会话生命周期与五项反馈。
