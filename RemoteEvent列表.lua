RemoteEvent列表 V1.0

命名说明
- 统一放在 ReplicatedStorage/Events/LabubuEvents
- 方向: C->S 客户端到服务端, S->C 服务端到客户端

结构参考
ReplicatedStorage
└── Events（Folder）/
    └── LabubuEvents（Folder）/
        ├── RequestInitData（RemoteEvent）
        ├── PushInitData（RemoteEvent）
        ├── RequestResync（RemoteEvent）
        ├── PushResync（RemoteEvent）
        ├── BuyConveyorEgg（RemoteEvent）
        ├── PlaceEgg（RemoteEvent）
        ├── OpenEgg（RemoteEvent）
        ├── OpenEggResult（RemoteEvent）
        ├── CollectPetCoins（RemoteEvent）
        ├── PetCoinsCollected（RemoteEvent）
        ├── DataDelta（RemoteEvent）
        ├── GoHome（RemoteEvent）
        └── ErrorHint（RemoteEvent）

事件清单
1. RequestInitData (C->S)
- 参数: ClientVersion(可选)
- 说明: 客户端已加载完成，请求初始化数据/版本
- 校验: 仅限玩家自身、频率限制

2. PushInitData (S->C)
- 参数: PlayerDataSnapshot, ServerTime, DataVersion
- 说明: 服务端推送玩家数据快照与时间同步

3. RequestResync (C->S)
- 参数: ClientVersion, Reason
- 说明: 客户端版本不一致/丢包时请求全量重同步
- 校验: 仅限玩家自身、频率限制

4. PushResync (S->C)
- 参数: PlayerDataSnapshot, ServerTime, DataVersion, Reason
- 说明: 服务端推送全量数据用于重同步

5. BuyConveyorEgg (C->S)
- 参数: EggUid
- 说明: 购买传送带上的蛋
- 校验: 归属(OwnerUserId)、距离、金币、蛋存在且未过期、冷却/防重

6. PlaceEgg (C->S)
- 参数: EggUid或CapsuleId, Position, Rotation(可选)
- 说明: 从背包放置到自家地板
- 校验: 归属、位置在自家范围/格位、无阻挡、占用检查、背包中存在、冷却/防重

7. OpenEgg (C->S)
- 参数: PlacedEggUid
- 说明: 开启已孵化的蛋
- 校验: 归属、孵化完成、蛋存在、冷却/防重

8. OpenEggResult (S->C)
- 参数: CapsuleId, FigurineId, IsNew, Rarity, PrevLevel, PrevExp, Level, Exp, MaxLevel
- 说明: 服务端返回开蛋结果与升级数据，用于抽卡翻面/升级进度表现

9. CollectPetCoins (C->S)
- 参数: PetId
- 说明: 点击牌子收取金币
- 校验: 归属、已解锁、冷却/防重

10. PetCoinsCollected (S->C)
- 参数: PetId, AddCoins, TotalCoins
- 说明: 收取结果回包

11. DataDelta (S->C)
- 参数: DeltaTable, BaseVersion, NewVersion
- 说明: 数据增量推送（金币/背包/宠物状态等）

12. GoHome (C->S)
- 参数: 无
- 说明: 客户端点击主界面Home按钮请求传送回基地出生点
- 校验: 归属(HomeSlot/OwnerUserId)、冷却/防刷(可选)

13. ErrorHint (S->C)
- 参数: Code, Message
- 说明: 统一错误提示

备注
- 所有随机与核心计算只在服务端
- 客户端不得直接修改任何核心数据
- DataVersion 用于增量同步，版本不一致应触发 RequestResync

