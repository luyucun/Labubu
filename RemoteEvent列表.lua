RemoteEvent列表 V1.2

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
        ├── RequestCoinPurchase（RemoteEvent）
        ├── RequestOutputMultiplierPurchase（RemoteEvent）
        ├── RequestPotionPurchase（RemoteEvent）
        ├── RequestPotionAction（RemoteEvent）
        ├── PushPotionState（RemoteEvent）
        ├── RequestStarterPackPurchase（RemoteEvent）
        ├── PushStarterPackState（RemoteEvent）
        ├── PushStarterPackReward（RemoteEvent）
        ├── PushGuideState（RemoteEvent）
        ├── BuyConveyorEgg（RemoteEvent）
        ├── PushConveyorEggSpawn（RemoteEvent）
        ├── PushConveyorEggRemove（RemoteEvent）
        ├── PlaceEgg（RemoteEvent）
        ├── OpenEgg（RemoteEvent）
        ├── OpenEggResult（RemoteEvent）
        ├── NotifyGachaFinished（RemoteEvent）
        ├── NotifyCameraFocusExit（RemoteEvent）
        ├── CollectPetCoins（RemoteEvent）
        ├── PetCoinsCollected（RemoteEvent）
        ├── DataDelta（RemoteEvent）
        ├── GoHome（RemoteEvent）
        ├── UpdateAudioSettings（RemoteEvent）
        ├── PlaySfx（RemoteEvent）
        ├── RequestGlobalLeaderboard（RemoteEvent）
        ├── PushGlobalLeaderboard（RemoteEvent）
        ├── RequestProgressionData（RemoteEvent）
        ├── PushProgressionData（RemoteEvent）
        ├── RequestProgressionClaim（RemoteEvent）
        ├── PushProgressionClaimed（RemoteEvent）
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

9. NotifyGachaFinished (C->S)
- 参数: FigurineId
- 说明: 客户端抽卡动画结束通知，用于新卡升台与镜头聚焦
- 校验: 仅限玩家自身、频率限制(可选)

10. NotifyCameraFocusExit (C->S)
- 参数: 无
- 说明: 客户端退出手办镜头锁定通知，用于触发引导领取金币

11. CollectPetCoins (C->S)
- 参数: PetId
- 说明: 点击牌子收取金币
- 校验: 归属、已解锁、冷却/防重

12. PetCoinsCollected (S->C)
- 参数: PetId, AddCoins, TotalCoins
- 说明: 收取结果回包

13. DataDelta (S->C)
- 参数: DeltaTable, BaseVersion, NewVersion
- 说明: 数据增量推送（金币/背包/宠物状态等）

14. GoHome (C->S)
- 参数: 无
- 说明: 客户端点击主界面Home按钮请求传送回基地出生点
- 校验: 归属(HomeSlot/OwnerUserId)、冷却/防刷(可选)

15. ErrorHint (S->C)
- 参数: Code, Message
- 说明: 统一错误提示

16. UpdateAudioSettings (C->S)
- 参数: MusicEnabled, SfxEnabled
- 说明: 客户端设置BGM/音效开关，服务端记录并同步属性
- 校验: 仅限玩家自身、频率限制(可选)

17. PlaySfx (S->C)
- 参数: Kind
- 说明: 服务端通知客户端播放音效（Collect/Unlock）

18. RequestGlobalLeaderboard (C->S)
- 参数: 无
- 说明: 客户端请求全局排行榜列表

19. PushGlobalLeaderboard (S->C)
- 参数: List, NextRefreshTime
- 说明: 服务端推送全局排行榜列表与下一次刷新时间戳

20. RequestCoinPurchase (C->S)
- 参数: ProductId
- 说明: 主界面CoinAdd按钮请求购买开发者商品
- 校验: 仅限玩家自身、产速阈值、频率限制

21. RequestOutputMultiplierPurchase (C->S)
- 参数: 无
- 说明: DoubleForever按钮请求购买产速倍率
- 校验: 仅限玩家自身、线性购买、频率限制

22. RequestProgressionData (C->S)
- 参数: 无
- 说明: 客户端请求养成/成就进度数据
- 校验: 仅限玩家自身、频率限制

23. PushProgressionData (S->C)
- 参数: Payload={IsFull, Entries[{Id, Progress, Target, Completed, Claimed, CanClaim}], HasClaimable}
- 说明: 服务端推送养成/成就进度列表（全量或增量）

24. RequestProgressionClaim (C->S)
- 参数: AchievementId
- 说明: 客户端请求领取成就钻石奖励
- 校验: 仅限玩家自身、已达成且未领取、频率限制

25. PushProgressionClaimed (S->C)
- 参数: AchievementId, DiamondReward, TotalDiamonds
- 说明: 服务端确认领取成功并返回钻石奖励数与当前钻石余额

26. RequestPotionPurchase (C->S)
- 参数: PotionId
- 说明: 请求购买药水开发者商品（RbxButton）
- 校验: 仅限玩家自身、频率限制

27. RequestPotionAction (C->S)
- 参数: PotionId, Action("Buy"/"Use")
- 说明: 钻石购买药水或使用药水
- 校验: 仅限玩家自身、钻石/数量校验、频率限制

28. PushPotionState (S->C)
- 参数: Payload={Counts, EndTimes, ServerTime}
- 说明: 服务端推送药水数量与倒计时状态

29. PushGuideState (S->C)
- 参数: Payload={Step, ShowTips, Text, ShowFinger, FingerCapsuleId}
- 说明: 服务端推送新手引导状态与提示文本/手指提示显示

30. RequestStarterPackPurchase (C->S)
- 参数: 无
- 说明: 客户端请求购买新手礼包通行证

31. PushStarterPackState (S->C)
- 参数: Payload={Purchased}
- 说明: 服务端推送新手礼包购买状态

32. PushStarterPackReward (S->C)
- 参数: Rewards[{Id, Count}]
- 说明: 服务端推送新手礼包奖励展示

33. PushConveyorEggSpawn (S->C)
- 参数: Payload={Uid, CapsuleId, Rarity, Quality, Price, OpenSeconds, MoveTime}
- 说明: 服务端推送本次传送带盲盒生成数据，客户端本地创建与移动表现

34. PushConveyorEggRemove (S->C)
- 参数: Uid
- 说明: 服务端通知客户端移除传送带盲盒（过期/被购买）

备注
- 所有随机与核心计算只在服务端
- 客户端不得直接修改任何核心数据
- DataVersion 用于增量同步，版本不一致应触发 RequestResync
