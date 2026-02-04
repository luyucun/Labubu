策划案V1.0 整体游戏玩法介绍

概述：
1.这是一款基于roblox开发的游戏，核心玩法是：一个服务器房间有多个玩家，每个玩家有自己的基地，玩家可以在自己的基地游玩自己的游戏内容
2.每个玩家都有一个Home，每个Home下都有一个传送带，传送带上每X秒都会自动产出一个蛋，蛋有不同的Id，每个蛋都会配置一个出现权重，每次生成蛋时，根据权重值，随机一个概率，确定本次生成的蛋的Id
3.不同的蛋有对应的金币价格，蛋刷新出现在传送蛋上后，从头随着传送带被传送至末端，到了末端后自动消失，就这样源源不断地不断产出蛋
4.蛋在传送带上时，玩家可以花费金币购买蛋，注意：玩家只能购买自己家传送带上产出地蛋，不能购买其他玩家地传送带地蛋
5.玩家购买蛋后蛋出现在背包中，玩家将蛋放置在自家地地板上，蛋进入孵化倒计时，每个蛋都有自己地孵化倒计时，蛋孵化倒计时结束后进入可开启状态，玩家可选择与蛋交互，从而触发打开蛋地过程
6.每个蛋都会对应一个卡池，这个蛋打开后只会产出对应卡池里面地宠物，这个卡池下的不同宠物都有对应的权重，每次打开蛋时，根据卡池中不同的蛋的权重，来决定本地开启这个蛋获得的宠物是什么
7.游戏设定中，有不同品质的宠物，每个品质下又有多个不同ID的宠物。
8.每个玩家的家中，都有一套图鉴系统，也就是多个展示牌，每个牌子对应一个特定id的宠物，当玩家未获得过这个宠物时，对应的牌子是“未开启”状态，如果玩家获得过这个宠物了，那这个牌子变成“已开启”状态
9.每个宠物都会配置一个基础的金币产出速度，每秒产出一次，比如某个宠物金币产出速度是10金币每秒，也就是每秒会产出10点金币，当这个宠物变成已开启状态后，就会不断自动产出金币，玩家可以点击这个宠物对应的牌子，来收取已经产出的金币，收取后金币清零重新开始积累
10.宠物有等级概念，消耗多个同id的宠物，可以给该宠物进行升级，比如1级的A宠物玩家获得后，又开启多个蛋，获得了多个A宠物，那么当数量达到A宠物1级升2级的数量时，宠物就会升级成功
11.宠物有品阶概念，比如初级品阶/中级品阶/高级品阶，当玩家获得了A宠物的初级品阶，后面又通过打开蛋获得了一个中级品阶的A宠物，那这个牌子的宠物的品阶就变为当前最高的品阶
12，一个卡牌的金币产出速度是跟等级和品质以及品阶相关的，大概公式可能是：金币产出速度=基础产速*（1+（当前等级 - 1）*品质系数）*品阶系数，这个公式只是在做框架设计时供理解，实际公式需要在后续的具体需求中去实现
13.只要玩家在线，这个卡牌产出的金币就可以一直累加，如果玩家离线，那么上线时，需要判断玩家的离线时间，如果超出了最高的产出累计时间，那最多只给最高累计时间的金币，比如每秒产速100金币，最多积累5分钟，玩家离线了3小时，那么上线后玩家最多获得30000金币


术语统一：盲盒=蛋=Capsule，手办=Figurine/宠物

正式需求：

策划案V1.1 玩家家园分配与玩家数据架构

家园分配：

1.我的游戏中，设定服务器人数上限为8人，也就是同服务器最多同时容纳8个玩家
2.每个玩家都有一个家园，每个玩家只能和自己家园中的各种道具或者交互物进行交互
3.在我的Workspace下，有个叫Home的文件夹，其下分别有Player01到Player08共8个文件夹，每个文件夹就代表一个家园的内容
4.以Player01举例，玩家加入游戏时，如果把玩家分配到了Player01这个家园，那么在Player01下有个SpawnLocation，这就是这个玩家的基础出生点
5.每次进入游戏系统分配玩家的家园是家园几，然后去家园文件夹下找玩家的出生点然后出生，并加载玩家的数据

基础数据：
1.金币：目前玩家的基础数据只设定金币这个维度
2.每个新玩家进入游戏时，都有一个基础金币，目前设定基础金币数值为500，这个需要创建一个GameConfig，在GameConfig中进行配置
3.金币数值是玩家的永久数值，需要保存在服务器

需求文档V1.2  金币数值显示与GM增减以及清零金币数值

1.在StarterGui - MainGui - CoinNum，这个textlabel，用于显示玩家当前的金币数值，格式默认为$xxxx,xxxx是金币数值
2.需要几个gm命令：增加指定数值金币/清除当前玩家的金币（注意只清除自己的而不是所有玩家，一定要注意！）
3.我希望后续的所有gm都放在一个脚本中，能够快速查询所有后续可用的gm命令


策划文档V1.3  盲盒（其实就是上面说的蛋，我们游戏中包装是盲盒）

概述：
传送带上会根据概率，不断生成盲盒，玩家可以购买盲盒来开启获得自己的手办（就是宠物，我们的游戏中包装上叫做手办）

盲盒的品质定义：
1.我们游戏中有多种盲盒，盲盒有品质定义，我们目前定义7种品质：
        a.品质1:Leaf
        b.品质2:Water
        c.品质3:Lunar
        d.品质4:Solar
        e.品质5:Flame
        f.品质6:Heart
        g.品质7:Celestial
我们在配置中就用1到5来表达从Leaf到Celestial


盲盒的稀有度定义：
1.每个盲盒还有稀有度定义，目前我们的稀有度分为：
    a.Common
    b.Light
    c.Gold
    d.Diamond
    e.Rainbow
我们在配置中就用1到5来表达从common到Rainbow

所以说：每个盲盒均有两个维度：品质与稀有度，比如某个盲盒，可能是品质leaf，稀有度Gold，也有可能是品质Lunar，稀有度Common

我的所有的盲盒模型全部放在ReplicatedStorage - Capsule下，在生成盲盒模型时，根据配置的盲盒名字去路径下找对应名字的盲盒即可

盲盒价格：
1.每个盲盒在传送带上出现时，玩家可花费金币去购买这个盲盒，所以每个盲盒有自己对应的金币价格
2.如果金币不足，则购买盲盒会失败，如果金币数量充足，则扣除对应数量的金币，移除盲盒，将盲盒移除出

盲盒购买：
玩家靠近盲盒，要在盲盒上出现游戏默认的交互键，文本内容为Buy，就系统默认的那个“E”键交互的格式，交互时间是0.1秒即可完成交互，玩家按E键或者点击按钮即可完成购买，要在交互键上显示出这个盲盒的价格，格式是$xxx


盲盒购买完成：
1.盲盒购买成功后，会出现在玩家默认的背包中（暂时使用默认的背包即可）

盲盒拿起：
1.玩家可以点击背包中的盲盒，把盲盒放置在地上。
2.放在地上的盲盒无法再被拿起来

盲盒开启倒计时：
1.每个盲盒均会配置一个开启倒计时，当盲盒被放置在地上后，会立刻开始开启倒计时，倒计时结束后，玩家与盲盒交互，可打开盲盒
2.这个版本我们只做到倒计时结束即可，与盲盒交互的逻辑以及具体的倒计时ui逻辑都下个版本再做
3，我们在配置表中的开启时间配置填的是秒

盲盒出现：
1.每个玩家家园中，都有一个叫ConveyorBelt的文件夹，这是我们的传送带的文件夹
2.ConveyorBelt文件夹下有个叫Start的Part，以Player01举例，每次蛋出现时，就在这里出现，然后被传送走；文件夹下也有个叫End的Part，每次盲盒移动到End的位置，就移除盲盒（与End发生碰撞即视为到达）
3.在传送带上，每1秒刷新一个盲盒，每次刷新时根据权重概率确定本次刷新的盲盒是什么即可

我们的盲盒初始开发版本的配置是：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）
1001	Leaf	1	1	Leaf	120	10
1002	Water	2	2	Water	140	15
1003	Lunar	3	1	Lunar	160	20
1004	Solar	4	2	Solar	180	25
1005	Flame	5	1	Flame	200	30
1006	Heart	6	2	Heart	220	35
1007	Celestial	7	1	Celestial	240	40


策划案V1.3.1 需求补充

需求补充：关于刷新盲盒的概率的

1.我们需要新启动一张配置表，里面会配置多套盲盒的刷新池子，在不同阶段，根据玩家的状态决定刷新盲盒时，从哪套刷新池子中去刷新盲盒
2.当前阶段开发默认使用1号刷新池的刷新方案即可

配置表初版是：
Id	刷新池编号	盲盒id	权重
10001	1	1001	30
10002	1	1002	20
10003	1	1003	8
10004	1	1004	6
10005	1	1005	4
10006	1	1006	2
10007	1	1007	1

策划案V1.4 关于盲盒的打开逻辑

1.每个盲盒都都提前配置的打开时间倒计时
2.当盲盒放在地上后，会自动进入打开倒计时，等倒计时结束后，盲盒变成可打开状态
3.可打开的盲盒，需要在盲盒上继续出现交互按钮，文本是Open，点击需要长按，点击即可打开盲盒
4.打开成功后，盲盒从地上消失

注意：这个版本只先做到打开盲盒成功这一步，具体打开获得什么的逻辑，后面版本做

策划文档V1.5  关于手办

概述
1.我们的游戏中，打开盲盒，可以获得手办，获得的手办是随机的，从对应的池子中根据权重确定获得的结果
2.每个盲盒对应不同的池子，都走单独的配置，所以我会给盲盒的配置表中加入对应的池子的id配置

关于手办：
1.有多种不同的手办，每个手办均有自己的独立id
2.每个手办均有其基础的金币产出速度，按秒来进行计算
3.每个手办均有其名字，在配置表中会进行配置
4.每个手办均有其模型资源形象，所有的模型路径都会放在ReplicatedStorage - LBB这个文件夹下，我会在配置表中配置手办对应的模型名字，直接去这个路径下找即可
5.每个品质都有其品质，和盲盒品质分类一样：
        a.品质1:Leaf
        b.品质2:Water
        c.品质3:Lunar
        d.品质4:Solar
        e.品质5:Flame
        f.品质6:Heart
        g.品质7:Celestial
6.每个手办也有其稀有度，和盲盒的稀有度对应：
    a.Common
    b.Light
    c.Gold
    d.Diamond
    e.Rainbow
7.每个布布都有对应的展台路径，这里我们会进行配置，对应下方的布布获得后出现在家园的哪个展台上


以上是一些关于手办的基础定义，这个版本我们主要是要配合盲盒来做手办的获得，以下是具体逻辑：

1.新增一张手办表，用来定义基础的手办信息：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径
10001	绿叶布布1	10	1	1	LBB01	ShowCase/Green/Position1
10002	绿叶布布2	12	1	1	LBB01	ShowCase/Green/Position2
10003	绿叶布布3	14	1	1	LBB01	ShowCase/Green/Position3
10004	绿叶布布4	16	1	1	LBB01	ShowCase/Green/Position4
10005	绿叶布布5	18	1	1	LBB01	ShowCase/Green/Position5
10006	绿叶布布6	20	1	1	LBB01	ShowCase/Green/Position6
10007	绿叶布布7	22	1	1	LBB01	ShowCase/Green/Position7
10008	绿叶布布8	24	1	1	LBB01	ShowCase/Green/Position8
10009	绿叶布布9	26	1	1	LBB01	ShowCase/Green/Position9
20001	水布布1	50	2	1	LBB01	ShowCase/Blue/Position1
20002	水布布2	55	2	1	LBB01	ShowCase/Blue/Position2
20003	水布布3	60	2	1	LBB01	ShowCase/Blue/Position3
20004	水布布4	65	2	1	LBB01	ShowCase/Blue/Position4
20005	水布布5	70	2	1	LBB01	ShowCase/Blue/Position5
20006	水布布6	75	2	1	LBB01	ShowCase/Blue/Position6
20007	水布布7	80	2	1	LBB01	ShowCase/Blue/Position7
20008	水布布8	85	2	1	LBB01	ShowCase/Blue/Position8
20009	水布布9	90	2	1	LBB01	ShowCase/Blue/Position9



2.新增一张卡池表，所有的卡池汇总在这里，盲盒开启时根据自己对应的卡池id来这里寻找卡池

卡池id	手办id	刷新权重
卡池id	手办id	刷新权重
9001	10001	20
9001	10002	20
9001	10003	20
9001	10004	20
9001	10005	20
9001	10006	20
9001	10007	20
9001	10008	20
9001	10009	20
9002	20001	20
9002	20002	20
9002	20003	20
9002	20004	20
9002	20005	20
9002	20006	20
9002	20007	20
9002	20008	20
9002	20009	20



3.修改盲盒表，加入了盲盒对应卡池id的配置

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）		盲盒对应卡池
1001	Leaf	1	1	Leaf	120	10		9001
1002	Water	2	2	Water	140	15		9002
1003	Lunar	3	1	Lunar	160	20		9001
1004	Solar	4	2	Solar	180	25		9002
1005	Flame	5	1	Flame	200	30		9001
1006	Heart	6	2	Heart	220	35		9002
1007	Celestial	7	1	Celestial	240	40		9002


4.关于手办获得：

    a.手办获得后，会在玩家家园的对应展台上出现手办模型，我们下面是以家园1举例，其他家园一样的逻辑
    b.Workspace - Home - Player01是家园1，在Player01下有个叫ShowCase的文件夹，下面有多个文件夹，每个文件夹下放着我们的展台，比如ShowCase - Green - Position1就是一个展台
    c.当一个手办玩家以前没有，现在拥有之后，就让这个手办模型放在对应的展台模型上，手办表有配置的展台模型路径

5.手办获得后，立刻开始不断产出金币

这个版本目前只开发到上述内容即可，剩下的内容我们下个版本继续做，抽出相同的bubu先不处理，后续我们做升级逻辑，这个版本先不处理


策划文档V1.6 关于金币产出/金币获取/金币产出上限

概述：现在的金币产出都是自动增加到玩家账户的，我希望的是，玩家能够通过手动操作领取金币而不是自动发放

详细规则：

1.手办获得后，产出的金币，积累在自身上，不是直接添加的玩家的账户
2.玩家需要通过碰撞手办对应的领取按钮模型，才能领取金币完成。每个手办都有一个单独对应的领取按钮，在手办表中配置路径即可
3.金币产出上限按时间累计，默认最多累计3小时（10800秒），超过3小时不领取就暂停产出，领取后重新开始累计

举例：某个手办产出速度是10金币每秒，那么1分钟累计产出了600金币，这些金币都是待领取状态，玩家触碰这个手办对应的领取按钮，才立刻把待领取的金币领取到自己账户

关于领取按钮的路径：

1.我的每个家园中，都有一套领取按钮模型，我们接下来以Player01的家园为例来进行需求讲解：
    a.Workspace - Home - Player01 - ClaimButton - ButtonBlue - Button1这是其中一个按钮的路径，Button1是一个Part，玩家触碰这个part即可触发对应手办的金币领取。注意这里要做触碰限制，比如0.5秒内最多触发一次领取，并且持续触碰的情况下只算触碰了一次，比如玩家站在这个part上，就算只触发1次，必须离开再过来，才算触碰第二次
    b.我在每个手办的触碰按钮字段下配置对应的领取按钮的路径，我的配置路径会配置到ClaimButton下的路径，比如我配置：ButtonBlue/Button1这个按钮就是去按Workspace - Home - Player01 - ClaimButton - ButtonBlue - Button1这个路径去找这个按钮

更新我的手办配置表为：

id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径
10001	绿叶布布1	10	1	1	LBB01	ShowCase/Green/Position1	ButtonGreen/Button1
10002	绿叶布布2	12	1	1	LBB01	ShowCase/Green/Position2	ButtonGreen/Button2
10003	绿叶布布3	14	1	1	LBB01	ShowCase/Green/Position3	ButtonGreen/Button3
10004	绿叶布布4	16	1	1	LBB01	ShowCase/Green/Position4	ButtonGreen/Button4
10005	绿叶布布5	18	1	1	LBB01	ShowCase/Green/Position5	ButtonGreen/Button5
10006	绿叶布布6	20	1	1	LBB01	ShowCase/Green/Position6	ButtonGreen/Button6
10007	绿叶布布7	22	1	1	LBB01	ShowCase/Green/Position7	ButtonGreen/Button7
10008	绿叶布布8	24	1	1	LBB01	ShowCase/Green/Position8	ButtonGreen/Button8
10009	绿叶布布9	26	1	1	LBB01	ShowCase/Green/Position9	ButtonGreen/Button9
20001	水布布1	50	2	1	LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
20002	水布布2	55	2	1	LBB01	ShowCase/Blue/Position2	ButtonBlue/Button2
20003	水布布3	60	2	1	LBB01	ShowCase/Blue/Position3	ButtonBlue/Button3
20004	水布布4	65	2	1	LBB01	ShowCase/Blue/Position4	ButtonBlue/Button4
20005	水布布5	70	2	1	LBB01	ShowCase/Blue/Position5	ButtonBlue/Button5
20006	水布布6	75	2	1	LBB01	ShowCase/Blue/Position6	ButtonBlue/Button6
20007	水布布7	80	2	1	LBB01	ShowCase/Blue/Position7	ButtonBlue/Button7
20008	水布布8	85	2	1	LBB01	ShowCase/Blue/Position8	ButtonBlue/Button8
20009	水布布9	90	2	1	LBB01	ShowCase/Blue/Position9	ButtonBlue/Button9


关于手办信息的显示：

我们之前配置了每个手办对应的展台模型路径，在每个展台模型路径下，均有一个叫Platform的Part，初始手办未获得时，设定Platform的Size为7, 1, 7，当手办获得后，需要在展台上出现时，需要把Platform的Size设定为：7, 5, 7
在手办出现的过程中，Platform的Size变化时，我们需要一个变化过程，2秒内，size 的Y轴尺寸从1变到5

关于ui信息的展示：
当Platform尺寸变化结束后，需要在Platform的上复制一份手办信息，具体逻辑是，去ReplicatedStorage - InfoPart下寻找一个叫Info的SurfaceGui并复制，复制到Platform上，出现的Face是Front

Info - Name是一个textlabel，用于展示手办的名字，Info - Money是一个Textlabel，用于展示手办的金币相关信息，具体格式是：$xxx/（$yyy/S），XXX是已经积累的金币数值，要实时变化，领取后清零，yyy是当前的金币产出速度数值，也要随着手办的升级来实时变化（升级逻辑后面做这里先留好接口）

我们游戏中的所有的金币数值显示，都需要遵循一套大数值显示规则，具体规则可以在我另一个项目中参考，项目路径是：D:\RobloxGame\Prison\prisongame，使用一样的规则即可


策划文档V1.7  关于一些数据统计

我们需要新增多个统计数据维度：

1.玩家历史总共的游戏时间，只要玩家在线，就自动增加这个时间，实时更新，玩家多次游玩后，数据都是不断增加的，需要作为玩家的永久数据去储存
2.玩家总共开启过的盲盒数量：玩家每开一个盲盒，就自动数值+1
3.玩家每个Id的盲盒的总开启数量也需要记录，上面一条是总数，这里的是每个ID盲盒的开启数量
4.玩家的当前总的金币产出速度，就是所有的手办的当前的产出速度总和

我们需要把以上部分信息进行展示，暂时我做了个测试ui，用来暂时性的承载这些信息的显示，后面我会做正式的ui来显示界面

StarterGui -  TestInfo - Frame - CapsuleTotal，这是个textlabel，用于显示玩家的总共历史开启的盲盒总数
StarterGui -  TestInfo - Frame - OutoutSpeed，这是个textlabel，用于显示玩家当前的总产出速度，格式是：$xxx/S ，xxx是速度
StarterGui -  TestInfo - Frame - TimeTotal，这是个textlabel，用于显示玩家的总的游戏时间，格式xx:YY:ZZ,分别代表小时/分钟/秒

以上多个数据均是需要进行记录的数据，作为永久数据进行储存


策划文档V1.8 关于玩家信息显示

我们需要在玩家的基地显示出来玩家的信息，下面以Player01的家园为例子进行需求说明

1.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - PlayerIcon是一个imagelabel，用于显示这个基地所属玩家的头像
2.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - PlayerName是一个textlabel，用于显示玩家的名字
3.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - Speed是一个textlabel，用于显示玩家的当前总产出速度，这个我们已经在上一版做好了功能，显示数值即可，格式是$xxx/S,xxx是产出速度

当玩家离线这个基地释放后，需要将Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg的Visible属性改成False
只有有玩家的时候才把Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg的Visible属性改成true


策划文档 V1.9 关于镜头聚焦

我希望在玩家开到一个新的手办，触发手办台子升起的时候，有个具体的镜头效果

详细规则：

1.玩家触发新手办升起台子时，需要快速将玩家的镜头移动到正好对准这个台子，此时玩家无法操纵镜头
2.镜头对准台子等待台子升起完成后，停顿0.5秒，然后将镜头快速重置回玩家的常规镜头视角并解除锁定
3.镜头从玩家身上移动到目标点时，要快速移动过去，并且有缓动效果，不要硬切，把各个参数都留出来让我调整，并做好参数作用的说明


策划文档V2.0  手办升级

1.手办可以通过消耗同Id的手办来进行升级
2.一个同id 的手办相当于1点经验值，每级升至下一级所需要消耗的经验点数不同，走经验表进行配置
3.所有的手办都使用同一套升级表

我的升级表配置如下

等级	升至下级所需经验值
1	2
2	4
3	8
4	16
5	32
6	64
7	128
8	256
9	512
10	1024
11	2048
12	4096
13	8192
14	16384
15	32768
16	65536

当某个卡片到达最高级时，就算达到了升级所需要的经验值，也不再升级，就保持在最高级

具体的客户端逻辑是：

手办出现时会去复制ReplicatedStorage - InfoPart - Info，这里存放了信息模板
其中Info - Level - LevelText是一个textlabel，用于显示手办当前的等级信息，格式是：LV.xxx,其中xxx是等级数值
其中Info - Level - ProgressBar是一个imagelabel，用于显示升级进度，用ProgressBar的Size中的X轴的大小来控制进度条变化，大小是用的Scale，当Size是0就代表进度条为0，Size为1就表示进度条满了


策划文档V2.1  增加部分正式数值的配置

1.我们的盲盒表配置修改，改成：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池
1001	Leaf	1	1	LeafCommon	50 	8	99001
1002	Water	2	1	WaterCommon	1500 	40	99001
1003	Lunar	3	1	LunarCommon	20000 	140	99001
1004	Solar	4	1	SolarCommon	180000 	480	99001
1005	Flame	5	1	FlameCommon	1200000 	1800	99001
1006	Heart	6	1	HeartCommon	5000000 	6600	99001
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001
2001	Leaf	1	2	LeafLight	100 	9	99001
2002	Water	2	2	WaterLight	3000 	44	99001
2003	Lunar	3	2	LunarLight	40000 	154	99001
2004	Solar	4	2	SolarLight	360000 	528	99001
2005	Flame	5	2	FlameLight	2400000 	1980	99001
2006	Heart	6	2	HeartLight	10000000 	7260	99001
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001
3001	Leaf	1	3	LeafGold	300 	10	99001
3002	Water	2	3	WaterGold	9000 	50	99001
3003	Lunar	3	3	LunarGold	120000 	175	99001
3004	Solar	4	3	SolarGold	1080000 	600	99001
3005	Flame	5	3	FlameGold	7200000 	2250	99001
3006	Heart	6	3	HeartGold	30000000 	8250	99001
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001
4001	Leaf	1	4	LeafDiamond	750 	12	99001
4002	Water	2	4	WaterDiamond	22500 	58	99001
4003	Lunar	3	4	LunarDiamond	300000 	203	99001
4004	Solar	4	4	SolarDiamond	2700000 	696	99001
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001
5001	Leaf	1	5	LeafRainbow	2500 	14	99001
5002	Water	2	5	WaterRainbow	75000 	68	99001
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001
5004	Solar	4	5	SolarRainbow	9000000 	816	99001
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001


我们的盲盒刷新卡池修改为：

Id	刷新池编号	盲盒id	权重
10001	1	1001	20
10002	1	1002	20
10003	1	1003	20
10004	1	1004	20
10005	1	1005	20
10006	1	1006	20
10007	1	1007	20
10008	1	2001	20
10009	1	2002	20
10010	1	2003	20
10011	1	2004	20
10012	1	2005	20
10013	1	2006	20
10014	1	2007	20
10015	1	3001	20
10016	1	3002	20
10017	1	3003	20
10018	1	3004	20
10019	1	3005	20
10020	1	3006	20
10021	1	3007	20
10022	1	4001	20
10023	1	4002	20
10024	1	4003	20
10025	1	4004	20
10026	1	4005	20
10027	1	4006	20
10028	1	4007	20
10029	1	5001	20
10030	1	5002	20
10031	1	5003	20
10032	1	5004	20
10033	1	5005	20
10034	1	5006	20
10035	1	5007	20


我们的手办表修改为：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5

关于手办表，你需要做的改动是：我们的手办模型之前是只填了名字，现在我改成了：路径/名字，比如填：Leaf/LBB01，就是去ReplicatedStorage - LBB - Leaf下找LBB01，这个规则要改动，最好把字段名字从ModelName改成ModelResource或者你定个其他名字

我们的手办卡池表改成：
卡池id	手办id	刷新权重
99001	10001	20
99001	10002	20
99001	10003	20
99001	10004	20
99001	10005	20
99001	10006	20
99001	10007	20
99001	10008	20
99001	10009	20
99001	20001	20
99001	20002	20
99001	20003	20
99001	20004	20
99001	20005	20
99001	20006	20
99001	20007	20
99001	20008	20
99001	20009	20
99001	30001	20
99001	30002	20
99001	30003	20
99001	30004	20
99001	30005	20
99001	30006	20
99001	30007	20
99001	30008	20
99001	30009	20
99001	40001	20
99001	40002	20
99001	40003	20
99001	40004	20
99001	40005	20
99001	40006	20
99001	40007	20
99001	40008	20
99001	40009	20
99001	50001	20
99001	50002	20
99001	50003	20
99001	50004	20
99001	50005	20
99001	50006	20
99001	50007	20
99001	60001	20
99001	60002	20
99001	60003	20
99001	60004	20
99001	60005	20
99001	60006	20
99001	60007	20
99001	70001	20
99001	70002	20
99001	70003	20
99001	70004	20
99001	70005	20


我们的升级经验消耗表改成：
等级	升至下级所需经验值
1	2
2	3
3	5
4	8
5	12
6	18
7	26
8	38
9	55
10	80
11	115
12	165
13	235
14	335
15	455


策划文档V2.2 手办产速计算

概述：我们的手办存在等级/品质/稀有度三个维度，每个手办有自己的基础产速，我们设定一个公式来确定一个手办的最终产速

最终一个手办的产速公式是：最终金币产速=基础产速*稀有度系数*（1+（等级-1）*品质系数）

我们的不同品质的手办的品质系数是：

品质	升级系数 
1	0.05
2	0.08
3	0.12
4	0.18
5	0.25
6	0.35
7	0.5

不同稀有度的系数是：
稀有度	系数
1	1
2	1.25
3	1.8
4	2.6
5	4.6

我们的每个手办都有其品质是固定的，这个属性直接读表即可

关于稀有度的规则是这样的：
我们有不同稀有度的盲盒，比如有稀有度1品质1的盲盒，稀有度2品质1的盲盒，稀有度3品质1的盲盒，或者稀有度1品质3，或者稀有度4品质3的盲盒

相同品质的盲盒，开出的手办id是永远固定的，比如稀有度1品质1和稀有度3品质1的盲盒，都只能开出品质1的手办，卡池是固定的
但是稀有度1品质1的盲盒开出的手办稀有度都是1，稀有度2品质1的盲盒开出的手办稀有度都是2
当一个手办有更高稀有度出现时，将这个手办的稀有度改成更高的稀有度
比如10001这个手办，之前都是稀有度1里面开出来的，那这个手办当前的稀有度就是1，按稀有度1的参数计算，如果在稀有度3的盒子里开出了这个10001的手办，那我的这个手办的稀有度就变成3，产速计算时也按稀有度3的参数算


策划文档V2.3 盲盒开启进度条

每个盲盒都有开启倒计时，被放在地上后会开始倒计时，玩家需要看到倒计时进度

具体规则是：
1.盲盒被放到地上后，立刻去ReplicatedStorage下复制OpenProgresTemplate，挂载给地上这个盲盒模型，直接做盲盒的子节点
2.OpenProgresTemplate - Bg - Progressbar的Size（用scale大小）变化来表达进度变化。Size的X轴大小是0就代表倒计时刚开始，Size的X轴大小是1就代表倒计时结束
3.OpenProgresTemplate - Bg - Text是一个文本，倒计时在倒计时过程中，需要把文本内容改成：xx:yy，xx是分钟，yy是秒，根据我们的倒计时去转换成分秒即可，但是如果时间大于1小时，xx就是小时，yy就是分钟
4.如果倒计时完成后，需要把Text的文本改成Ready!


策划文档V2.4 完善一下数据表，给盲盒和手办加图标

这是修改后的手办表：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://17449975508
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://17449975508
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://17449975508
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://17449975508
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://17449975508
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://17449975508
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://17449975508
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://17449975508
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://17449975508
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://17449975508
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://17449975508
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://17449975508
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://17449975508
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://17449975508
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://17449975508
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://17449975508
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://17449975508
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://17449975508
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://17449975508
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://17449975508
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://17449975508
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://17449975508
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://17449975508
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://17449975508
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://17449975508
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://17449975508
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://17449975508
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://17449975508
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://17449975508
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://17449975508
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://17449975508
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://17449975508
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://17449975508
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://17449975508
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://17449975508
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://17449975508
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://17449975508
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://17449975508
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://17449975508
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://17449975508
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://17449975508
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://17449975508
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://17449975508
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://17449975508
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://17449975508
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://17449975508
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://17449975508
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://17449975508
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://17449975508
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://17449975508
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://17449975508
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://17449975508
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://17449975508
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://17449975508
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://17449975508


这是修改后的盲盒表：

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://98616255072587


策划文档V2.5 新的背包

概述：现在的背包用的是系统默认的背包，我们要改成我自制的背包ui

详细规则：
1.StarterGui - BackpackGui - BackpackFrame是我的背包页面，当玩家背包中的盲盒数大于等于1时，就显示出来（visible属性改成true），如果没有盲盒就改成false
2.BackpackGui - BackpackFrame - ItemListFrame - ArmyTemplate是盲盒信息模板，需要生成时，就复制一份出来，把visible属性改成True，并且更正对应的信息
3.ArmyTemplate - Icon是盲盒图标，用于显示盲盒的图标
4.ArmyTemplate - Number是textlabel，用于显示盲盒的数量，格式固定是：*x，x是该盲盒拥有的数量
5.点击背包中的任意一个盲盒，也可以触发拿到手里，这个逻辑和默认背包是一样的
6.新的背包系统不限制盲盒的拥有数量


策划文档V2.6 盲盒背包界面

我们的玩家购买了很多盲盒后，需要有一个统一查看的地方，现在是在背包中展示，但是我希望做一个ui，在ui中展示所有的盲盒

详细规则：

1.玩家点击StarterGui - MainGui - Bag这个按钮，打开盲盒背包界面（把StarterGui - Bag - BagBg的Visible属性改成True）
2.点击StarterGui - Bag - BagBg - Title - CloseButton按钮，关闭盲盒界面（把StarterGui - Bag - BagBg的Visible属性改成false）
3.StarterGui - Bag - BagBg - ScrollingFrame 是用来容纳所有我有的盲盒的列表，其中ScrollingFrame - CapsuleTemplate是盲盒信息模板，要生成盲盒信息时去复制CapsuleTemplate，并更改其信息，生成一个盲盒信息
4.CapsuleTemplate - Icon是盲盒的图标，CapsuleTemplate - Name是盲盒的名字，CapsuleTemplate - Number是盲盒的拥有数量
5.盲盒的排序按盲盒表中的id，Id越大，越排在前面


关于盲盒列表的筛选：

1.StarterGui - Bag - BagBg - TabList - ScrollingFrame下放了一些按钮，这些按钮主要是用来对盲盒的筛选
2.点击 TabList - ScrollingFrame - Leaf按钮，只显示所有品质1的盲盒
3.点击 TabList - ScrollingFrame - Water按钮，只显示所有品质2的盲盒
4.点击 TabList - ScrollingFrame - Lunar按钮，只显示所有品质3的盲盒
5.点击 TabList - ScrollingFrame - Solar按钮，只显示所有品质4的盲盒
6.点击 TabList - ScrollingFrame - Flame按钮，只显示所有品质5的盲盒
7.点击 TabList - ScrollingFrame - Heart按钮，只显示所有品质6的盲盒
8.点击 TabList - ScrollingFrame - Celestial按钮，只显示所有品质7的盲盒
9.点击 TabList - ScrollingFrame - Total按钮，显示所有盲盒
10.每次打开界面，默认是显示所有盲盒


策划文档V2.7 索引功能需求

概述：我们要做一个索引功能，类似于图鉴一样的逻辑，具体规则见下面

详细规则：

1.玩家点击StarterGui - MainGui - Index这个按钮，打开Index索引界面（把StarterGui - Index - IndexBg的Visible属性改成True）
2.玩家点击StarterGui - Index - IndexBg - Title - CloseButton按钮，关闭Index索引界面（把StarterGui - Index - IndexBg的Visible属性改成False）
3.我们的手办是分品质的，所以我们的索引界面，是要按品质来进行显示的，每个品质列表下只显示该品质的手办

4.StarterGui - Index - IndexBg - TabList - ScrollingFrame下有多个按钮，每个按钮分别对应各自品质的手办筛选，具体的逻辑是：

    a.ScrollingFrame - Leaf,对应品质1
    b.ScrollingFrame - Water,对应品质2
    c.ScrollingFrame - Lunar,对应品质3
    d.ScrollingFrame - Solar,对应品质4
    e.ScrollingFrame - Flame,对应品质5
    f.ScrollingFrame - Heart,对应品质6
    g.ScrollingFrame - Celestial,对应品质7

5.下面是详细的单个手办展示的信息规则：
    a.StarterGui - Index - IndexBg - InfoBg - ScrollingFrame是用于承载每个品质下所有手办信息的列表容器
    b.ScrollingFrame - FigurineTemplate是手办信息模板，要生成手办信息时，去复制一份FigurineTemplate，然后更改信息，即成为一个手办信息
    c.FigurineTemplate - Icon是手办图标，FigurineTemplate - Name是手办名字，根据手办数据生成对应信息即可
    d.这个Index列表中展示的是所有的手办，所以每次我更新了新的手办，列表里也要对应生成新的手办的信息，每次登录游戏后更新一轮数据即可，不用每次打开界面都去更新
    e.某个手办如果玩家已经获得了，就保持默认状态即可
    f.某个手办如果玩家没有获得，则需要把：FigurineTemplate - Name隐藏，把FigurineTemplate - Icon的ImageColor3的颜色改成纯黑（注意一定是ImageColor3属性），同时把FigurineTemplate - QuestionMark的Visible属性改成True

6.手办列表按表中的顺序从上到下排列即可
7.StarterGui - Index - IndexBg - InfoBg - CurrentNum是一个textlabel，用于显示当前这个品质玩家获得的手办数量，比如这个品质共9个手办，玩家获得了3个，就显示为3/9
8.StarterGui - Index - IndexBg - InfoBg - TotalNum是一个textlabel，用于所有手办玩家获情况，比如所有品质手办加起来共20个手办，玩家获得了3个，就显示为3/20
9.以上两个信息玩家每次打开界面时都需要实时更新数值状态


策划文档V2.8 检视功能

我们需要对我们的手办进行检视，具体的逻辑是

1.在Index界面，每个手办信息界面下，都有个按钮叫CheckIcon，比如InfoBg - ScrollingFrame - FigurineTemplate - CheckIcon
2.未解锁的手办，需要把CheckIcon的Visible属性设定为False，已经解锁的手办才设定为True
3.玩家点击CheckIcon按钮，触发对这个手办的检视，具体表现是：
    1）.关闭Index界面与Backpack界面
    2）.将StarterGui - Check - CheckBg的Visible属性改成True
    3）.在Check - CheckBg - ViewportFrame中加载我们的手办模型，每个手办模型都有配置的具体的模型名字
    4）.玩家点击Check - CheckBg - Exit按钮可以关闭检视界面，并再次自动打开Index界面，并且要回到刚才检视这个手办的那个定位位置
    5）.模型在界面上加载出来后，我们可以对模型进行检视，具体的检视的逻辑是：
        a.加载的模型需要确保能够正好显示在ViewportFrame中
        b.模型需要正对屏幕中心
        c.玩家可以通过拖动鼠标或者在手机屏幕上来回滑动触发对模型的检视
        d.比如我鼠标向右移动，模型就向右旋转，向左移动就向左旋转，向下移动就向下旋转
        e.但是注意：每个模型的检视都有旋转限制，比如朝某个方向最多旋转30度。
        f.具体的旋转跟随鼠标或者手指的效果我也不懂具体逻辑，你可以看下面这些图片，是竞品的检视效果，我们做成一样即可：
        图片分别是："D:\RobloxGame\Labubu\Labubu\默认状态.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向右滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向左滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向下滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向上滑动到极限.png"

策划文档V2.9  领取全部/自动领取与十倍领取

概述：我们需要在游戏内加入一些付费功能，分别是：一次性全部领取/一次性十倍领取所有金币/自动领取功能

接下来我们按Player01的家园举例，来进行需求说明

详细规则之领取全部：
1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - ClaimAll - Touch这个Part，触发对开发者道具：3514031081的购买
2.玩家购买成功后，领取当前所有的未领取的金币，注意是玩家基地中属于玩家的所有手办产出的未领取的金币，一次性全部领取
3.玩家进入游戏后，需要把Workspace - Home - Player01 - Base - ClaimAll - ClaimAll - CashNum的文本改成当前总共积累的未领取的金币总值，格式是$xxx，xxx是金币数值，这里也要用大数值逻辑来做
4.注意不要连续触发多次，玩家触碰后，一定要离开后再次触碰，才触发这个购买

详细规则之十倍全部领取：
1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - ClaimAllTen - Touch这个Part，触发对开发者道具：3514031237的购买
2.玩家购买成功后，领取当前所有的未领取的金币数值的十倍，注意是玩家基地中属于玩家的所有手办产出的未领取的金币的十倍，一次性全部领取，比如当前积累了100点金币，那领取的就是1000
3.玩家进入游戏后，需要把Workspace - Home - Player01 - Base - ClaimAllTen - CollectTen - Bg - CashNum文本改成当前总共积累的未领取的金币总值的10倍数值，格式是$xxx，xxx是金币数值，这里也要用大数值逻辑来做
4.注意不要连续触发多次，玩家触碰后，一定要离开后再次触碰，才触发这个购买

详细规则之自动领取：

1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - Auto - Touch这个Part，触发对通行证：1673138854的购买
2.玩家购买成功这个通行证后，会获得自动收集功能
3.在获得这个通行证后，需要把玩家家园内的ClaimAll和ClaimAllTen这两个Part都移除，让玩家无法再触发这俩开发者道具的购买
4.再获得这个通行证后，需要把玩家家园内的Workspace - Home - Player01 - Base - Auto - AutoCollect - Inactive的Visible属性改成False，将Workspace - Home - Player01 - Base - Auto - AutoCollect - Active的Visible属性改成True
5.注意：Workspace - Home - Player01 - Base - Auto - AutoCollect - Active - Collecting是一个班textlabel，当显示出来后，需要设定文本内容为Collecting，然后每0.7秒在文本后多加一个.，当达到三个点时，下一次清零重新从0个点开始，这样做出一个1/2/3个点来回循环的动态效果。
6.具体动态效果可以看这个项目：D:\RobloxGame\Prison\prisongame中关于自动挑战部分，在开战后的文本表现形式，也是在后面三个点不断循环

需要加的GM：加一个命令，让我能获得自动功能，也要能重置我的自动功能。当我获得了自动功能后要视为我购买成功了这个通行证。重置后视为我未购买

补充规则：盲盒放置数量限制
1.每个玩家家园内，地面最多可放置12个盲盒
2.倒计时中的盲盒，以及倒计时结束但未打开的盲盒，都占用名额
3.超过限制后无法放置到地上，并提示系统消息：Placement limit reached


策划文档V3.0  开盲盒结果表现

概述：我们需要在玩家开启盲盒后，给一个开盲盒过程表现，让玩家知道这次开的盲盒的结果是什么

详细规则：

1.玩家与盲盒交互开启盲盒后，需要先立刻弹出抽卡结果界面：
    a.将StarterGui - GachaResult - Result显示出来（之前的默认Visible属性是false，显示出来就是改成True）
    b.显示出来时，需要把StarterGui - GachaResult - Result - Cover的图片资源换成盲盒对应的展示图片（在盲盒表中会有配置）
    c.出现时，需要有从屏幕外面滑进来到目标位置，快速滑进来，可以从屏幕下方滑动出来。
    
    以上是开启动画的第一步：弹出盲盒背面
    下面是开启动画第二步：展示开启结果：
    a.StarterGui - GachaResult - Result滑动到目标位置后，停留0.5秒，然后做一个翻转动画（注意这个翻转是朝屏幕里翻转那种翻转，不是上下翻转，比如一个图片，以中轴线为中心，然后翻转，也就是始终竖着的那种翻转，希望你能明白）
    b.总体目标是翻转180度，看起来像翻面，当翻到90度时，需要立刻把StarterGui - GachaResult - Result - Cover隐藏起来，然后把StarterGui - GachaResult - Icon显示出来，这是手办图标，需要把StarterGui - GachaResult - Result - Name显示出来，这是手办名字，需要把StarterGui - GachaResult - Result - Rare显示出来，这是稀有度，需要把StarterGui - GachaResult - Result - Speed显示出来，这是基础产速
    c.以上几个内容显示出来的时候，需要把这几个对应的信息替换成手办的对应信息
    d.然后继续完成翻转，看起来是一个反面的过程
    e.在翻面完成后，如果这是一个全新的从未获得过的手办，在翻面完成后，需要把StarterGui - GachaResult - Result - NewTitle显示出来

    以上是开启动画的第三步，展示变化：
    1.如果是已经获得过的卡，则在翻转完成瞬间，需要把StarterGui - GachaResult - LevelUp显示出来
    2.LevelUp下也有Icon/Name/Rare/Speed这几个子节点，也要替换对应的信息
    3.在LevelUp - Bg - Progressbar是一个进度条，Size用X的Scale，当Size是0，就是进度条为0，如果Size是1就是进度条满。同时LevelUp - Bg - Text是等级信息，格式是Lv.x,x是等级数字
    4.当StarterGui - GachaResult - LevelUp显示出来后，需要立刻播进度条动画，进度条从当前进度线性变化到升级后的进度，在0.5秒内完成，在进度条动画播放完后，把等级文本更新成最新的等级文本
    5.当进度条动画播放完成后，也要把LevelUp - Speed的文本内容替换为最新的产出速度，这里是经过产速公式计算后的最终产出速度

    以上是开启动画的第三步，最后是第四步，共同消失：
    1.在升级动画播放完成后，Result和LevelUp共同向屏幕上方滑动，移出屏幕，完成整个开启动画的展示
    2.如果这是全新的卡，就不出现升级相关的内容（也就是第三步），展示完成后就向上移动移出屏幕即可

2.如果开的是新卡，在卡移动出屏幕后，在开始播放新手办获得时，台子升起来的镜头动画，所以流程是：展示封面 - 开启 - 展示结果 - 卡消失 - 播放镜头动画


我们需要在盲盒表中加入每个盲盒的展示图片字段信息，更新后的盲盒表是这样的：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://98616255072587	rbxassetid://98616255072587


需要同步为我更新盲盒配置表


策划文档V3.1  更新一版手办表 
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://106915271340222
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://105301091167285
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://92602393759769
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://77465737689764
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://128609371638881
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://77006643082762
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://97576907938982
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://100640430095892
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://107958283001957
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://73924471186576
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://97475868474045
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://94121257331073
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://80371625018349
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://131567376824995
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://98646372357977
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://131567376824995
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://120763170661369
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://87646054592825
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://116214626452083
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://133690692800448
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://77847158725505
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://100929113578714
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://77847158725505
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://98084586375258
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://81392569495246
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://107529498094392
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://107304908021027
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://123301796994352
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://135903948038055
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://137010302356268
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://133825497379267
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://78728521411560
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://98165717690396
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://133103323967935
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://71595524788019
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://132021136924285
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://81520307684372
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://90342220987736
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://73676714004019
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://108104612245462
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://121911610580026
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://107904367562204
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://98108287971614
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://129520383058807
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://125879099426075
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://131333015213094
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://136225094377885
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://112335648315899
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://84929220767434
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://136190154597023
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://137355628441296
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://105553650967188
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://83967828201151
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://135305551396163
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://78448815998112

以上是我更新后的手办表，需要你帮我更新配置

策划文档V3.2 关于镜头动画的一些调整

1.现在抽卡动画结束后，镜头时立刻对准目标开始播放动画，现在希望抽卡动画结束后的时间再延长一点再去对准目标播动画
2.在动画结束后，以前是立刻回到玩家镜头，现在需要修改为：镜头动画播放完后，保持结束状态，然后把StarterGui - Camera - Exit的Visivle属性改成True显示出来
3.玩家点击Exit按钮，立刻恢复玩家镜头，但是注意：是硬切，不要做之前的镜头线性返回的效果了

另外补充一个规则：玩家点击StarterGui - MainGui - Home按钮，立刻将玩家传送回基地出生位置

策划文档V3.3 补充关于index的功能

在我们的index界面中，有关于每个品质解锁了多少个的显示，现在我们在界面上增加了图标的展示功能
具体规则是：

1.玩家切换页签切换品质的时候，需要把StarterGui - Index - IndexBg - InfoBg - CurrentIcon的图片内容换成对应品质的图标

品质与对应的图标是：

品质1	leaf	rbxassetid://108955563208582
品质2	water	rbxassetid://133424751984403
品质3	lunar	rbxassetid://97174425150192
品质4	solar	rbxassetid://130407159333392
品质5	flame	rbxassetid://137727751536051
品质6	heart	rbxassetid://115976015958196
品质7	celestial	rbxassetid://110967078953865


策划文档V3.4 修改一下盲盒表相关的配置

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://120738172280657	rbxassetid://98616255072587


策划文档V3.5 关于背包信息的修改（BackpackGui）

在背包中出现的盲盒，需要补充这个盲盒的品质信息
StarterGui - BackpackGui - BackpackFrame - ItemListFrame - ArmyTemplate - Rare是品质信息
当这个盲盒的品质是最低的1（common）时，不显示
当盲盒品质是其他的品质时，需要把Rare的文本内容改成品质名字，并显示出来



策划文档V3.6 更新手办表信息

id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	Greyshade Sneak	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://106915271340222
10002	Starcharm Mechanic	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://105301091167285
10003	Minty Squint	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://92602393759769
10004	Pinecone Redtail	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://77465737689764
10005	Tiny Tiger Brave	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://128609371638881
10006	Bluefrost Cone	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://77006643082762
10007	Honeydoze	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://97576907938982
10008	Forest Basketling	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://100640430095892
10009	Berrybramble Bear	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://107958283001957
20001	Emerald Bonk	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://73924471186576
20002	Rainbow Drizzle	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://97475868474045
20003	Violet Giftling	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://94121257331073
20004	Frogleaf	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://80371625018349
20005	Rosehug	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://131567376824995
20006	Snowpuff	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://98646372357977
20007	Party Box Pop	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://131567376824995
20008	Splashring	116	2	1	Water/LBB08	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://120763170661369
20009	Seastar Chanter	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://87646054592825
30001	Pajama Snoozer	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://116214626452083
30002	Starseam Witchlet	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://133690692800448
30003	Nightclaw	285	3	1	Lunar/LBB03	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://77847158725505
30004	Halo Hymn	325	3	1	Lunar/LBB04	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://100929113578714
30005	Specs Scholar	370	3	1	Lunar/LBB05	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://77847158725505
30006	Wanderbow	420	3	1	Lunar/LBB06	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://98084586375258
30007	Prismfeather Sprite	480	3	1	Lunar/LBB07	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://81392569495246
30008	Greyshade Gentleman	550	3	1	Lunar/LBB08	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://107529498094392
30009	Pumpkin Ghast	630	3	1	Lunar/LBB09	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://107304908021027
40001	Sunblossom	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://123301796994352
40002	Flowercrown Bride	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://135903948038055
40003	Twinbasket Harvest	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://137010302356268
40004	Leafwing Dino	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://133825497379267
40005	Broomlet Witch	1600	4	1	Solar/LBB05	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://78728521411560
40006	Swinggiggle	1830	4	1	Solar/LBB06	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://98165717690396
40007	Vinewreath Wisher	2100	4	1	Solar/LBB07	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://133103323967935
40008	Lemon Pilot	2400	4	1	Solar/LBB08	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://71595524788019
40009	Cosmo Drifter	2750	4	1	Solar/LBB09	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://132021136924285
50001	Bombsnit	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://81520307684372
50002	Flamecrown Blade	3400	5	1	Flame/LBB02	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://90342220987736
50003	Blazefuzz King	3850	5	1	Flame/LBB03	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://73676714004019
50004	Roseveil Count	4350	5	1	Flame/LBB04	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://108104612245462
50005	Inferno Fanlord	4900	5	1	Flame/LBB05	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://121911610580026
50006	Neon Skater	5550	5	1	Flame/LBB06	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://107904367562204
50007	Crystal Seer	6300	5	1	Flame/LBB07	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://98108287971614
60001	Snowroll Buddy	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://129520383058807
60002	Bubbleballerina	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://125879099426075
60003	Seamoon Siren	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://131333015213094
60004	Butterglow Fairy	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://136225094377885
60005	Nurse Nuzzle	18000	6	1	Heart/LBB05	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://112335648315899
60006	Redflag Climber	20000	6	1	Heart/LBB06	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://84929220767434
60007	Sakura Fest	22300	6	1	Heart/LBB07	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://136190154597023
70001	Starfloat	33000	7	1	Celestial/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://137355628441296
70002	Thunder Sprout	38000	7	1	Celestial/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://105553650967188
70003	Whitewing Prayer	44000	7	1	Celestial/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://83967828201151
70004	Balloon Cakeling	51000	7	1	Celestial/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://135305551396163
70005	Rainbow Unicorn Knight	59000	7	1	Celestial/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://78448815998112


策划文档V3.7 关于Index界面的一些修改

我们补充以下规则：

1.我们的每个手办的图标在界面中显示时，因为每个手办都有其对应的品质，所以我们需要在Index界面上显示出手办信息时，展示对应的品质
2.展示对应的品质的时候，有个逻辑是：
    a.StarterGui - Index - IndexBg - InfoBg - ScrollingFrame - FigurineTemplate下有多个图片，分别对应我们的每个品质
    b.比如Flame/Celestial/Heart/Leaf/Lunar/Solar/Water等，每个的Visible属性都是false
    c.当一个手办信息生成时，需要根据这个手办的品质，决定把哪个图片显示出来，比如leaf的品质，就把Leaf图片显示出来

策划文档V3.8 关于Bag界面的一些修改

我们补充以下规则：
1.跟上述的Index界面一样，我们也需要给每个盲盒显示对应的背景。
2.StarterGui - Bag - BagBg - ScrollingFrame - CapsuleTemplate下有多个图片，分别对应我们的每个品质
3.比如Flame/Celestial/Heart/Leaf/Lunar/Solar/Water等，每个的Visible属性都是false
4.当一个盲盒信息生成时，需要根据这个盲盒的品质，决定把哪个图片显示出来，比如leaf的品质，就把Leaf图片显示出来

原来是StarterGui - Bag - BagBg - ScrollingFrame - CapsuleTemplate - Name原来是显示盲盒名字，现在改成：显示稀有度名字，和backpack里面的逻辑是一样的，如果是common就不显示，其他的显示稀有度的名字

策划文档V3.9 关于抽卡动画效果的规则补充

1.展示动画第一步，需要把StarterGui - GachaResult - Result - Cover的图标改成这个盲盒对应的图标，同时像上述V3.7和V3.8部分的逻辑一样，在StarterGui - GachaResult - Result下也有各个品质的图，需要把品质图显示出来
2.展示动画第二步（转换信息的时候），需要同步更改Icon/Name/Rare/Speed相关的信息，这些我都设定成了Visible默认False，展示出来时要改成True
3.同时LevelUp界面也是的，下面也有各个品质的图片，显示出来时，要把对应的品质的名字的图片显示出来


策划文档v4.0 音效逻辑

概述：
1.我们需要在游戏内加入bgm播放，默认bgm资源是：rbxassetid://85493154394720，进入游戏默认播放即可，循环默认播放
2.玩家触碰领金币按钮时播放音效：rbxassetid://307631257，在普通领取/一次全部领取/一次十倍领取成功时都播放这个音效
3.新手办解锁台子升起来时，播放rbxassetid://3072176098

另外需要做一个音效播放设置：

1.玩家点击StarterGui - TopRightGui - Bg - Options按钮，打开设置界面（StarterGui - Options - Bg的visible属性改成true）
2.玩家点击StarterGui - Options - Bg - Title - CloseButton按钮，关闭设置界面

3.共两个设置选项：Music和Sfx，Music控制BGM是否播放，Sfx控制音效是否播放。
    a.常规状态下，BGM和音效都是默认开启的，也就是播放状态
    b.玩家的音乐音效设置，要在下次登录的时候，保持这个状态，当然可以只记录在当前设备中即可，不用在服务端记录，如果在服务端记录也可以

4.以音效举例：Options - Bg - Music - CloseButton就是控制开关的按钮，CloseButton下有个叫Text的textlabel，用于显示当前音效播放状态，如果是开启播放，文本就是On，如果是关闭状态，文本就是Off
5.CloseButton下有个子节点是控制渐变的叫UIGradient，开启的状态下，渐变起始颜色是#55ff00，渐变终止颜色是#ffff00，关闭状态下渐变起始颜色是#cb000e，渐变终止颜色是#ff5d35，所以当玩家点击按钮切换状态时，也要同步修改按钮的状态


策划文档V4.1 好友金币加成

1.在金币产出时，需要判断：同服务器内是否有玩家的好友，如果有玩家的好友，则本次产出金币时需要有加成，每次产出时（也就是每秒金币产出），都需要根据当前的加成值来决定最终的产出数值
2.每有一个好友在服务器，产出数值+10%，比如有6个好友在同服务器，则加成数值是60%，比如金币产出速度是100/s，则本次产出值=100*（1+0.1*6）=160
3.计算屎如果出现了小数则向上取整，比如计算出结果是128.3，则视为产出129
4.玩家的同服好友数量变化时需要及时更新加成数值
5.玩家点击StarterGui - TopRightGui - Invite按钮，可以调出系统默认的邀请好友加入的页面

关于客户端规则是：StarterGui - MainGui - CoinBuff是一个textlabel用于显示当前的好友加成，格式是：Friends Bonus: +xx%，其中xx是加成数值，每当数值发生变化时都要及时更新内容。需要把+xx%改成黄色，其他内容保持默认颜色


策划文档V4.2 全局排行榜
概述：我们需要在游戏内添加一个全局的排行榜，注意区别于当前已经存在的单服务器内的内置排行榜

详细规则：

1.这个排行榜的面向对象是所有的游戏玩家而不是单指本服务器内的玩家
2.排行对象是玩家当前的总金币产速
3.每3分钟系统自动刷新排行榜
4.当两个玩家的产速相同时，谁先达到该产速，谁排在更靠前的位置
5.游戏上线后，到了更新时需要去拉取所有玩家的数据生成一份榜单不论玩家当前是否在线

关于界面规则是：

1.玩家点击StarterGui - TopRightGui - Bg - Learderboard - Button按钮可以打开排行榜界面（也就是把StarterGui - Leaderboard - Bg的visible属性改成true）
2.玩家点击StarterGui - Leaderboard - Bg - Title - CloseButton这个按钮可以关闭排行榜界面（也就是把StarterGui - Leaderboard - Bg的visible属性改成false）
3.StarterGui - Leaderboard - Bg - ScrollingFrame是我们的排行榜玩家信息展示列表容器，其子节点中放置排行榜的玩家信息，其中：
	a.Rank01是个Frame，固定用于展示榜单第一名的信息，其中Rank01下的子节点Avatar是一个imagelabel，用于展示玩家头像，Name是一个textlabel，用于展示玩家的名字，Power是一个textlabel，用于展示玩家的产速
	b.Rank02和Rank03和Rank01结构一样，分别用于固定展示第二名和第三名的信息
	c.第四名之后的所有玩家的信息走模板复制，在ScrollingFrame下有个叫RankTemplate的Frame,是用于承载第四名之后的玩家的信息的，当生成列表时，比如第四名的玩家就是复制一份RankTemplate，改成玩家的对应信息，第五名同样如此，然后生成对应的信息即可
	d.注意：RankTemplate的默认Visible是false，当复制出来一份信息时，要把复制出来的信息的visible属性改成true
	e.RankTemplate下的子节点Avatar是一个imagelabel，用于展示玩家头像，Name是一个textlabel，用于展示玩家的名字，Power是一个textlabel，用于展示玩家的战斗力，Rank是一个textlabel，用于显示玩家的名次

4.Leaderboard - Bg - Player是一个Frame，用于展示玩家自己的排名信息，Player下的子节点Avatar是一个imagelabel，用于展示玩家头像，Name是一个textlabel，用于展示玩家的名字，Power是一个textlabel，用于展示玩家的产速，Rank是一个textlabel，用于显示玩家的名次。
	a.注意，如果玩家的名次在20名开外比如98名，这里就统一都默认显示20+，只有在1到20名才显示当前的名次，比如18名就显示18，20名显示20，32名就显示20+

5.Leaderboard - Bg - CountDownTime是一个textlabel，用于显示排行榜刷新倒计时，格式固定为：Refreshes in: 00:00，显示为分:秒，在打开界面的时候需要实时更新

6.我们的排行榜榜单内只显示前20名玩家即可，超出20名的玩家就不出现在榜单中

7.点击CloseButton关闭按钮时，需要给按钮一个点击效果，游戏内通用的按钮点击效果即可


策划文档V4.3 付费开盲盒

我们游戏中当前盲盒在倒计时阶段时，不会出现交互按钮
我们需要改成：每个盲盒在倒计时阶段，也有交互按钮，与按钮交互可以直接触发对该盲盒对应的开发者商品的购买，购买完成后可以直接打开这个盲盒
注意：在玩家付款的瞬间如果盲盒已经倒计时结束，则不扣款，改成开启交互键，玩家再次点击可打开盲盒

下面是我更新后的盲盒表，其中新增了每个盲盒的开发者商品id字段：

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片	开发者商品id
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519967882
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://91134558890103	rbxassetid://98616255072587	3519968035
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://121158065949906	rbxassetid://98616255072587	3519968159
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://123720993696670	rbxassetid://98616255072587	3519968449
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://95224550415811	rbxassetid://98616255072587	3519968675
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://127841276677202	rbxassetid://98616255072587	3519968812
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://120738172280657	rbxassetid://98616255072587	3519968929
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519969700
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://91134558890103	rbxassetid://98616255072587	3519969830
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://121158065949906	rbxassetid://98616255072587	3519969998
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://123720993696670	rbxassetid://98616255072587	3519970139
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://95224550415811	rbxassetid://98616255072587	3519970259
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://127841276677202	rbxassetid://98616255072587	3519970376
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://120738172280657	rbxassetid://98616255072587	3519970446
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519971147
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://91134558890103	rbxassetid://98616255072587	3519971264
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://121158065949906	rbxassetid://98616255072587	3519971358
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://123720993696670	rbxassetid://98616255072587	3519971507
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://95224550415811	rbxassetid://98616255072587	3519971613
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://127841276677202	rbxassetid://98616255072587	3519971705
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://120738172280657	rbxassetid://98616255072587	3519971799
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519972281
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://91134558890103	rbxassetid://98616255072587	3519972374
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://121158065949906	rbxassetid://98616255072587	3519972453
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://123720993696670	rbxassetid://98616255072587	3519972540
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://95224550415811	rbxassetid://98616255072587	3519972656
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://127841276677202	rbxassetid://98616255072587	3519972811
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://120738172280657	rbxassetid://98616255072587	3519972915
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519973404
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://91134558890103	rbxassetid://98616255072587	3519973516
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://121158065949906	rbxassetid://98616255072587	3519973609
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://123720993696670	rbxassetid://98616255072587	3519973732
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://95224550415811	rbxassetid://98616255072587	3519973805
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://127841276677202	rbxassetid://98616255072587	3519973900
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://120738172280657	rbxassetid://98616255072587	3519973978


V4.4loading功能

概述：我们的游戏中有很多的资源需要提前加载，为了保证游戏的体验，需要提前加载好，加载的过程中需要使用loading功能来告诉玩家正在加载

每次打开游戏时需要先进行加载
详细规则：
1.加载过程中，需要把StarterGui - Loading - Bg的Visible属性改成True，这是我们的整个loading页面的父节点
2.StarterGui - Loading - Bg - LoadingImage是背景图，在把Bg的visible属性改成true之前，先从rbxassetid://97379194248218以及rbxassetid://100148763396788以及rbxassetid://130504383522242以及rbxassetid://91249044330188中随机一张图，设置为LoadingImage的图片内容，这是loading页面
3.StarterGui - Loading - Bg - ProgressBg是加载进度条背景，StarterGui - Loading - Bg - ProgressBg - Progressbar是进度条填充，加载进度为0的时候，Progressbar的size的X值是0，进度为1的时候，Progressbar的size的X值是1（这里用的值是scale）
4.StarterGui - Loading - Bg - ProgressBg - Number是加载进度数值，格式为XX%，代表加载进度
5.加载进度变化时，需要进度与加载进度数值实时变化
6.当加载完成时，进度填满并且加载进度数值变成100%，然后把StarterGui - Loading - Bg的Visible属性改成False


策划文档V4.5 盲盒信息显示

1.我们需要在盲盒从传送带上刷新出来时，给盲盒赋予基础信息显示，包括价格/名字/稀有度等，具体逻辑见下方
2.当一个盲盒刷新出来时，去ReplicatedStorage下寻找一个叫CapsuleInfo的BillboardGui，挂在盲盒模型的primaryPart上
3.CapsuleInfo - Name是盲盒的名字，读取盲盒的名字即可，
4.CapsuleInfo - Price是盲盒的价格，用大数值逻辑显示
5.每个盲盒下都有叫Light/Gold/Diamond/Rainbow的textlabel，当盲盒刷新时，如果稀有度是1，就不处理，稀有度是2，把Light显示出来，稀有度是3，把Gold显示出来，稀有度是4，把Diamond显示出来，稀有度是5，把Rainbow显示出来
6.盲盒的名字显示，不同品质，需要给不同的颜色：
品质	颜色
Leaf	0, 255, 0
Water	0, 255, 255
Lunar	170, 0, 170
Solar	255, 255, 0
Flame	255, 0, 0
Heart	255, 152, 220
Celestial	27, 42, 53


策划文档V4.6 手办稀有度展示逻辑

概述：我们的手办有不同的稀有度，因此我在手办模型上做了一些不同的表现，需要在手办的不同稀有度情况下进行显示区分

详细规则：
1.我们以LBB - Leaf - LBB09这个手办来举例，手办模型下有多个子节点，分别是Seat1到Seat5，每个seat都是由多个part组成的
2.Seat1对应稀有度1，Seat5对应稀有度5，以此类推
3.当手办模型展示时，如果是稀有度1，就把Seat1下面的所有Part子节点透明度设置为0，然后把其余的所有Seat的子节点的Part的透明度设置为1，同理如果抽到了一个稀有度3的手办，原来的稀有度是1，则需要把Seat1的下面的Part透明度设置为1，然后把Seat3下面的Part的透明度设置为0

4.同时除了稀有度1外，稀有度2到稀有度5都有不同的特效表现，具体逻辑是：
    a.ReplicatedStorage - Effect - LevelRarity下有多个子节点，分别是EffectLight/EffectGold/EffectDiamond/EffectRaibow，分别对应稀有度2到稀有度5
    b.每个节点下都有一些特效节点，以EffectLight举例，当一个手办当前解锁的稀有度是2，也就是Light的时候，需要去复制ReplicatedStorage - Effect - LevelRarity - EffectLight下的所有子节点（注意是所有），挂在这个手办上，挂给手办的PartLbb下，每个手办都有PartLbb
    

策划文档V4.7 付费购买金币

概述：玩家可花费罗布币购买开发者道具，获得基于当前产速一定数值的金币

详细规则：

1.在主界面有三个按钮，分别是：StarterGui - MainGui - CoinAdd01以及StarterGui - MainGui - CoinAdd02以及StarterGui - MainGui - CoinAdd03
2.这三个按钮分别对应对3个开发者道具的购买，CoinAdd01对应开发者道具：3521138526，CoinAdd02对应开发者道具：3521779177，CoinAdd03对应开发者道具：3521779711
3.三个开发者道具分别对应基于当前产速一定时长的金币数值：
    a.CoinAdd01,即3521138526，对应时长是1800秒
    b.CoinAdd02,即3521779177，对应时长是7200秒
    c.CoinAdd03,即3521779711，对应时长是36000秒
4.玩家点击按钮触发对开发者道具的购买，购买成功后，要基于购买时的金币产出速度，根据对应时长，为玩家发放对应数值的金币。比如买了3521138526，对应时长1800秒，购买时产速是100/秒，则购买成功后为玩家发放180000金币
5.以CoinAdd01举例（CoinAdd02和CoinAdd03一样），StarterGui - MainGui - CoinAdd01 - Number是一个textlabel，这个数值要根据玩家当前的产速来实时更新数值，注意要用大数值显示逻辑
6.这三个按钮，在玩家的总产速大于等于10/秒之前，默认是隐藏的，满足条件后才显示出来


策划文档V4.8 

概述:玩家可以通过付费，来直接购买产速倍率

详细规则是：

1.在StarterGui - MainGui下有个按钮叫DoubleForever，玩家点击按钮，可以触发对金币产速倍率的购买
2.倍率分别有2倍，4倍，6倍等等到26倍，具体看配置即可
3.倍率同时只有最高倍率会生效，比如买了2倍，买了4倍，那么生效倍率就是4倍
4.所有倍率购买共用DoubleForever这一个按钮，购买是线性的，要购买了前一个倍率，才能购买下一个倍率，比如一定要先买2倍，然后4倍购买入口才出来，才能购买4倍，买了之后这个倍率就从2倍变成4倍

5.StarterGui - MainGui - DoubleForever - Name是用于显示当前所售商品的倍率的，如果卖的是2倍倍率，Name的文本就是CashX2,如果当前所售的是10倍，文本就是CashX10
6.StarterGui - MainGui - DoubleForever - Price是罗布币价格，这个具体读我表中的配置即可
7.默认显示的是2倍倍率的购买，购买完成后改成4倍的购买
8.每个倍率对应一个开发者商品id，具体对应关系见下面的配置

ID	倍率	开发者商品id	罗布币价格
1	2	3522025794	19
2	4	3522026011	49
3	6	3522026281	89
4	8	3522026559	139
5	10	3522026859	199
6	12	3522027227	269
7	14	3522027539	349
8	16	3522027869	439
9	18	3522028113	539
10	20	3522030207	649
11	22	3522030413	769
12	24	3522030729	899
13	26	3522031063	1039


策划文档V4.9 修改盲盒刷新逻辑

我们将对现有的盲盒刷新逻辑进行修改，具体修改后的逻辑是：

1.分多套刷新池，我会在配置中添加多套刷新池子
2.为玩家设定种解锁条件，达到解锁条件后，自动切换刷新池子，目前设定以下几种解锁条件：
    a.玩家总产速达到xxx/s
3.即：专门做一套刷新池子解锁表，当达到目标产速时，自动把玩家的刷新池子换成最新的这个刷新池子

目前暂时设定的初版的刷新池是：
Id	刷新池编号	盲盒id	权重
10001	1	1001	100
10002	1	1002	80
10003	1	1003	20
10004	1	1004	20
10005	1	1005	20
10006	1	1006	20
10007	1	1007	20
10001	2	1001	20
10002	2	1002	20
10003	2	1003	100
10004	2	1004	80
10005	2	1005	20
10006	2	1006	20
10007	2	1007	20
10001	3	1001	20
10002	3	1002	20
10003	3	1003	20
10004	3	1004	20
10005	3	1005	100
10006	3	1006	80
10007	3	1007	20


目前暂时设定的刷新池解锁表是：
ID	刷新池编号	解锁产速
1001	1	0
1002	2	300
1003	3	600

这里需要补充的是：解锁产速是0就意味着默认解锁

另外一个需要修改的逻辑是：我们需要加入盲盒稀有度突变逻辑，即：在我们上述的卡池中填的盲盒，都是基础的稀有度为1的盲盒，在刷新时，需要再做一层判断，判断本次生成是否生成高稀有度的盲盒，具体逻辑是：

在我们的盲盒配置中，是把同一个盲盒的不同稀有度配置成了不同的id，比如品质1的盲盒，稀有度从1到5，id分别是1001，2001，3001，4001，5001
以及我们在盲盒表中有盲盒品质和盲盒稀有度两个字段，这样可以把相同品质的不同稀有度的盲盒全部对应起来

我们的突变规则是：
1.在盲盒从上面的刷新池中根据权重概率确定了本次的盲盒是哪个后，再执行下一步
2.从盲盒突变表中，去根据稀有度权重概率，确定本次生成的盲盒的稀有度是什么
3.从上述两步分别确定了品质和稀有度后，去盲盒表中就能找到对应的盲盒的id，从而生成这个盲盒

盲盒突变表是：
id	稀有度	权重
1001	1	80
1002	2	30
1003	3	15
1004	4	5
1005	5	1

策划文档V5.0 关于开启盲盒展示的一些小优化
1.在开启盲盒后，现在会播展示动画（先展示Result的那个过程）
2.现在需要优化为：在初始的震动结束，要立刻展示出抽卡结果时，需要把GachaResult - Result - LightBg显示出来，显示出来的同时，要不断自转，这是一个光效，不断旋转形成闪闪发光的效果

策划文档V5.1 更新一版数据表：

盲盒刷新池子：
Id	刷新池编号	盲盒id	权重
10001	1	1001	4000
10002	1	1002	1000
10003	1	1003	400
10004	1	1004	200
10005	1	1005	100
10006	1	1006	0
10007	1	1007	0
20001	2	1001	4000
20002	2	1002	1500
20003	2	1003	600
20004	2	1004	300
20005	2	1005	100
20006	2	1006	30
20007	2	1007	30
30001	3	1001	4000
30002	3	1002	1500
30003	3	1003	800
30004	3	1004	400
30005	3	1005	150
30006	3	1006	80
30007	3	1007	50

盲盒刷新池子解锁表：
ID	刷新池编号	解锁产速
1001	1	0
1002	2	200
1003	3	2000

盲盒突变表：
id	稀有度	权重
1001	1	8275
1002	2	1000
1003	3	400
1004	4	200
1005	5	100

盲盒表：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片	开发者商品id
1001	Leaf	1	1	LeafCommon	50 	8	90001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519967882
1002	Water	2	1	WaterCommon	1500 	40	90002	rbxassetid://91134558890103	rbxassetid://98616255072587	3519968035
1003	Lunar	3	1	LunarCommon	20000 	140	90003	rbxassetid://121158065949906	rbxassetid://98616255072587	3519968159
1004	Solar	4	1	SolarCommon	180000 	480	90004	rbxassetid://123720993696670	rbxassetid://98616255072587	3519968449
1005	Flame	5	1	FlameCommon	1200000 	1800	90005	rbxassetid://95224550415811	rbxassetid://98616255072587	3519968675
1006	Heart	6	1	HeartCommon	5000000 	6600	90006	rbxassetid://127841276677202	rbxassetid://98616255072587	3519968812
1007	Celestial	7	1	CelestialCommon	20000000 	19800	90007	rbxassetid://120738172280657	rbxassetid://98616255072587	3519968929
2001	Leaf	1	2	LeafLight	100 	9	90001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519969700
2002	Water	2	2	WaterLight	3000 	44	90002	rbxassetid://91134558890103	rbxassetid://98616255072587	3519969830
2003	Lunar	3	2	LunarLight	40000 	154	90003	rbxassetid://121158065949906	rbxassetid://98616255072587	3519969998
2004	Solar	4	2	SolarLight	360000 	528	90004	rbxassetid://123720993696670	rbxassetid://98616255072587	3519970139
2005	Flame	5	2	FlameLight	2400000 	1980	90005	rbxassetid://95224550415811	rbxassetid://98616255072587	3519970259
2006	Heart	6	2	HeartLight	10000000 	7260	90006	rbxassetid://127841276677202	rbxassetid://98616255072587	3519970376
2007	Celestial	7	2	CelestialLight	40000000 	21780	90007	rbxassetid://120738172280657	rbxassetid://98616255072587	3519970446
3001	Leaf	1	3	LeafGold	300 	10	90001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519971147
3002	Water	2	3	WaterGold	9000 	50	90002	rbxassetid://91134558890103	rbxassetid://98616255072587	3519971264
3003	Lunar	3	3	LunarGold	120000 	175	90003	rbxassetid://121158065949906	rbxassetid://98616255072587	3519971358
3004	Solar	4	3	SolarGold	1080000 	600	90004	rbxassetid://123720993696670	rbxassetid://98616255072587	3519971507
3005	Flame	5	3	FlameGold	7200000 	2250	90005	rbxassetid://95224550415811	rbxassetid://98616255072587	3519971613
3006	Heart	6	3	HeartGold	30000000 	8250	90006	rbxassetid://127841276677202	rbxassetid://98616255072587	3519971705
3007	Celestial	7	3	CelestialGold	120000000 	24750	90007	rbxassetid://120738172280657	rbxassetid://98616255072587	3519971799
4001	Leaf	1	4	LeafDiamond	750 	12	90001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519972281
4002	Water	2	4	WaterDiamond	22500 	58	90002	rbxassetid://91134558890103	rbxassetid://98616255072587	3519972374
4003	Lunar	3	4	LunarDiamond	300000 	203	90003	rbxassetid://121158065949906	rbxassetid://98616255072587	3519972453
4004	Solar	4	4	SolarDiamond	2700000 	696	90004	rbxassetid://123720993696670	rbxassetid://98616255072587	3519972540
4005	Flame	5	4	FlameDiamond	18000000 	2610	90005	rbxassetid://95224550415811	rbxassetid://98616255072587	3519972656
4006	Heart	6	4	HeartDiamond	75000000 	9570	90006	rbxassetid://127841276677202	rbxassetid://98616255072587	3519972811
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	90007	rbxassetid://120738172280657	rbxassetid://98616255072587	3519972915
5001	Leaf	1	5	LeafRainbow	2500 	14	90001	rbxassetid://107877804846649	rbxassetid://98616255072587	3519973404
5002	Water	2	5	WaterRainbow	75000 	68	90002	rbxassetid://91134558890103	rbxassetid://98616255072587	3519973516
5003	Lunar	3	5	LunarRainbow	1000000 	238	90003	rbxassetid://121158065949906	rbxassetid://98616255072587	3519973609
5004	Solar	4	5	SolarRainbow	9000000 	816	90004	rbxassetid://123720993696670	rbxassetid://98616255072587	3519973732
5005	Flame	5	5	FlameRainbow	60000000 	3060	90005	rbxassetid://95224550415811	rbxassetid://98616255072587	3519973805
5006	Heart	6	5	HeartRainbow	250000000 	11220	90006	rbxassetid://127841276677202	rbxassetid://98616255072587	3519973900
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	90007	rbxassetid://120738172280657	rbxassetid://98616255072587	3519973978

手办卡池表：
卡池id	手办id	刷新权重
90001	10001	402
90001	10002	213
90001	10003	136
90001	10004	92
90001	10005	64
90001	10006	44
90001	10007	28
90001	10008	16
90001	10009	6
90002	20001	402
90002	20002	213
90002	20003	136
90002	20004	92
90002	20005	64
90002	20006	44
90002	20007	28
90002	20008	16
90002	20009	6
90003	30001	402
90003	30002	213
90003	30003	136
90003	30004	92
90003	30005	64
90003	30006	44
90003	30007	28
90003	30008	16
90003	30009	6
90004	40001	402
90004	40002	213
90004	40003	136
90004	40004	92
90004	40005	64
90004	40006	44
90004	40007	28
90004	40008	16
90004	40009	6
90005	50001	433
90005	50002	225
90005	50003	142
90005	50004	95
90005	50005	64
90005	50006	42
90005	50007	26
90006	60001	433
90006	60002	225
90006	60003	142
90006	60004	95
90006	60005	64
90006	60006	42
90006	60007	26
90007	70001	468
90007	70002	236
90007	70003	144
90007	70004	93
90007	70005	60


策划文档V5.2 养成系统

概述：我们在游戏中要加入一个养成系统，玩家通过在游戏内达成各种各样的成就，来实现各个维度的养成

详细规则：
1.我们设定以下一些养成维度类型：
    a.可放置的盲盒数+1：当前的可放置的盲盒数是受限制的，当每完成一个这个维度，就把盲盒可放置数+1
    b.整体盲盒开启倒计时减少x%：当前每个盲盒都有自己的开启时间，当获得这个维度的养成后，就将开启倒计时设定为原定时间*（1-x%），注意：这里如果有多个养成，取最大的，比如A任务完成奖励减少10%，B任务完成奖励减少15%，则最终盲盒减少时间是15%（取最大值）
    c.整体金币产速速度+x%
        1）这里的产速加成是算在某个手办最终的产速计算后，再进行加成，比如最终产速=手办算出来的产速*（1+x%），如果玩家购买了之前的开发者道具直接购买倍率，则倍率乘在这个外围
        2）版本到目前位置的最终产速：最终金币产速=基础产速*稀有度系数*（1+（等级-1）*品质系数）*（1+养成加成）*购买倍率
        3）注意这里的金币产速加成，如果有多个，取最高值，比如共3个奖励，分别奖励产速+5%，+10%，+15%，则最终按15%算
    d.额外好运*x
        1）额外好运是一个百分数值，是指在打开盲盒时，有一定的几率变成更好的一个卡牌，这个根据手办的基础阶级来判断即可
        2）比如这个数值是25%，也就是开启一个盲盒时，比如开的是1001这个手办，则在开启时有25%的几率变成1002
        3）我会在手办表中给每个手办添加一个基础阶级，比如开了一个基础阶级是3的手办，有几率变成4，但是不会变成5及以上
        4）如果开启的时候直接是最高的阶级了，那就不执行这个逻辑
    e.离线时间上限增加x分钟
        1）目前我们的离线产出经验还没设定上限，在这里，我们需要先补一个离线产出上限，设定2小时，也就是玩家离线2小时以上，那么离线产出最多产出2小时
        2）通过这个维度我们可以延长这个时间，也是多个数值时取最大的数值
    f.品质1盲盒突变率提升x%
        1）我们的盲盒在生成时，会根据权重决定本次盲盒生成的稀有度是什么
        2）这个概率是：在确定了稀有度后，再执行一次突变概率，有一定的概率，变成更高一级稀有度的盲盒，比如稀有度1的盲盒生成时，有25%的几率，变成稀有度2的盲盒生成出来
        3）每个独立运行，这个只生效给品质1的盲盒生成时去突变
    g.品质2盲盒突变率提升x%
    h.品质3盲盒突变率提升x%
    i.品质4盲盒突变率提升x%


2.我们需要设定一些成就类型，达成这些成就条件，来获得对应的养成维度
    a.累计游戏时长达到X分钟,用目前游戏内已经做好的累计时长数值即可
    b.累计开启X个盲盒，这里不分类型，只要是盲盒即可，每开启一个盲盒，计数就+1
    c.累计打开个Leaf盲盒，注意这里不论稀有度，只要是品质1的盲盒就行，稀有度1品质1的盲盒打开和稀有度3品质1的盲盒打开都是计数+1
    d.累计打开X个Water盲盒
    e.累计打开x个Lunar盲盒
    f.累计打开x个Solar盲盒
    g.累计打开X个Flame盲盒
    h.累计打开x个heart盲盒
    i.累计打开x个Celestial盲盒
    j.收集Leaf盲盒中的所有手办:注意这里不管稀有度，只管有就行
    k.收集Water盲盒中的所有手办:注意这里不管稀有度，只管有就行
    l.收集Lunar盲盒中的所有手办:注意这里不管稀有度，只管有就行
    m.收集Solar盲盒中的所有手办:注意这里不管稀有度，只管有就行
    n.收集Flame盲盒中的所有手办:注意这里不管稀有度，只管有就行
    o.收集heart盲盒中的所有手办:注意这里不管稀有度，只管有就行
    p.收集Celestial盲盒中的所有手办:注意这里不管稀有度，只管有就行
    q.累计打开X个品质2的盲盒，任何品质的都可以，稀有度是2就行
    r.累计打开X个品质3的盲盒，任何品质的都可以，稀有度是3就行
    s.累计打开X个品质4的盲盒，任何品质的都可以，稀有度是4就行
    t.累计打开X个品质5的盲盒，任何品质的都可以，稀有度是5就行


3.在每个成就达成时，我们会给玩家发放一份奖励，基本就是奖励一些钻石，所以我们需要增加一套货币：钻石，这个需要你来实现

以下是一些客户端相关规则：

1.玩家点击StarterGui - MainGui - Progression按钮，可以打开养成界面（把StarterGui - Progression - ProgressionBg的Visible属性改成True），点击StarterGui - Progression - ProgressionBg - Title - CloseButton可以关闭界面，注意这里点击按钮要有通用的按钮点击效果
2.我们的每个成就，都需要在ui列表中显示出来，我做了一个模板，打开游戏时，立刻生成所有的成就的模板，并同步玩家当前的进度
3.StarterGui - Progression - ProgressionBg - ScrollingFrame - CapsuleTemplate就是我们的模板，默认是隐藏的，所以每次复制出来一个信息时都要把复制出来的元素的visible属性改成true显示出来
4.ProgressionBg - ScrollingFrame - CapsuleTemplate - Icon是成就图标，在配置表中读取对应的配置即可
5.ProgressionBg - ScrollingFrame - CapsuleTemplate - Name是textlabel，去读取配置表中的成就文本这个字段即可
6.ProgressionBg - ScrollingFrame - CapsuleTemplate - Reward是textlabel，去读取配置表中的奖励文本这个字段即可
7.ProgressionBg - ScrollingFrame - CapsuleTemplate - Progress是textlabel，用于显示当前这个成就的完成进度，格式是x/y,X是当前的值，Y是目标值，Y就去读配置表中的达成条件这个数值即可，注意：如果类型是游戏时长的，Y固定就是1，达成条件就是1/1,未达成就是0/1即可
8.达成条件后，我们会奖励钻石。如果奖励达成后，需要把ProgressionBg - ScrollingFrame - CapsuleTemplate -Bg以及ProgressionBg - ScrollingFrame - CapsuleTemplate -Diamond以及ProgressionBg - ScrollingFrame - CapsuleTemplate - RedPoint这三个的visible属性改成True
9.有未领取的钻石奖励时，需要给ProgressionBg - ScrollingFrame - CapsuleTemplate -Diamond做个小动效，隔1秒就抖动一下，注意是中心不动，左右摆动那种就行，看起来像抖了一下
10.玩家点击ProgressionBg - ScrollingFrame - CapsuleTemplate -Diamond，可以领取钻石
11.玩家领取了钻石后，需要把ProgressionBg - ScrollingFrame - CapsuleTemplate -Bg以及ProgressionBg - ScrollingFrame - CapsuleTemplate -Diamond以及ProgressionBg - ScrollingFrame - CapsuleTemplate - RedPoint这三个的visible属性改成Visible属性改成false
12.领取了钻石后，需要把ProgressionBg - ScrollingFrame - CapsuleTemplate - Progress的文本改成：Active
13.当有未领取的钻石奖励时，需要把StarterGui - MainGui - Progression - RedPoint的visible属性改成True，没有可领取的奖励时再隐藏
14.玩家领取钻石奖励时，需要播放领取动画，具体逻辑是：
    1）将StarterGui - ClaimTipsGui - ClaimSuccessful的Visible属性设置成True（这里需要做一个出现动画，从屏幕左边滑出来）
    2）将StarterGui - ClaimTipsGui - ClaimSuccessful - Bg - ItemListFrame - ItemTemplate的Visible属性改成True，要等上面一条滑动完成后再出现
    3）ItemTemplate - Icon是奖励图标，换成钻石图标资源即可，ItemTemplate - Number是奖励数量，换成钻石奖励的数量即可
    4）整个流程出现后，在屏幕上0.5秒内无法关闭，过了0.5秒后玩家点击屏幕任意区域即可关闭弹框
    5）在StarterGui - ClaimTipsGui - ClaimSuccessful出现完成后，需要把StarterGui - ClaimTipsGui - LightBg的visible属性也改成True，然后让LightBg不断自转
    6）关闭界面时把LightBg和ClaimSuccessful的visible属性全部设定成false即可

关于数据表：
我把我的这一块的数据表放在这个文件中："D:\RobloxGame\Labubu\Labubu\临时数据表.lua"，你直接读取即可

策划文档V5.3  产速加成药水

概述：我们在游戏中加入药水的道具，使用药水后，可以使基础的金币产出速度提升，这个加成和之前的养成带来的加成以及玩家购买的产速倍率共同生效，以下是计算逻辑：
1.药水会分不同品质，每个品质的基础加成效果不一样，目前我们分3档药水，药水1是加30%，药水2是加50%，药水3是加100%
2.每个品质的药水的加成比例是单独计算的，比如品质1+20%，品质2+30%，那么两个药水同时使用时，加成总值就是50%


我们之前定的产出最终公式是：最终金币产速=基础产速*稀有度系数*（1+（等级-1）*品质系数）*（1+养成加成）*购买倍率
现在我们需要把产出加成公式计算为：最终金币产速=基础产速*稀有度系数*（1+（等级-1）*品质系数）*（1+养成加成+购买倍率加成+药水1加成+药水2加成+药水3加成）
这里需要注意的是：我们之前的购买倍率，比如之前购买的倍率是3倍，那么这里的购买倍率加成数值就是2，如果购买的倍率最终是22倍，那这里的值就是21

每个药水都有使用时间，使用后开始进行倒计时，倒计时结束后，该药水的加成效果消失，同一个品质的药水可以多次叠加使用，使用时在其倒计时上叠加倒计时即可
比如我有3个品质1的药水，每个生效半小时，那么使用后，进入倒计时，我再使用一个，倒计时就变成1小时
倒计时是自然时间，比如玩家使用了倒计时3小时的药水，玩到2小时后离线，离线了5小时再上来，这个药水也是失效了的

详细客户端规则：

1.玩家点击StarterGui - MainGui - Option按钮，可以打开药水界面（把StarterGui - Potions - Bg的visible属性改成true）
2.玩家点击StarterGui - Potions - Bg - Title - CloseButton按钮关闭界面（把StarterGui - Potions - Bg的visible属性改成false）
3.如果玩家正在使用药水，在倒计时中，则需要把MainGui - Option - Time的内容改成药水倒计时，格式是xx:yy,xx是分钟，yy是秒，注意，哪怕xx特别大比如9000，也是显示分钟，不要转换成小时
4.如果有两个不同品质的药水同时正在生效中，则这个时间显示时间更迟结束的那个，比如同时使用药水1和药水2，药水1倒计时还有10分钟，药水2倒计时还有25分钟，这里显示的就是25分钟的倒计时
5.Potions - Bg - Buff1Bg对应药水1，Potions - Bg - Buff2Bg对应药水2，Potions - Bg - Buff3Bg对应药水3

下面我们以药水1的部分来做剩余的客户端逻辑说明，Buff2Bg和Buff3Bg逻辑基本一致

1.Potions - Bg - Buff1Bg - CountDownTime是药水倒计时，如果正在生效中，则需要把倒计时显示出来，这里的格式是：xx:yy:zz，就是小时：分钟：秒，如果这个药水未在生效中，就把Potions - Bg - Buff1Bg - CountDownTime的visible属性设置为false
2.Potions - Bg - Buff1Bg - RbxButton是一个按钮，点击可以触发对药水1的开发者商品购买，下面表中会配置每个药水对应的开发者商品道具id，购买成功后为玩家发放一个药水1，注意是发放，不是直接使用
3.每个药水可以通过开发者商品多次购买
4.Potions - Bg - Buff1Bg - DiamondButton按钮是钻石购买按钮，这里有两种状态，一种是使用钻石购买药水，一种是使用药水的按钮，具体逻辑是：
    1）如果玩家的这个药水的数量小于1（也就是数量为0），那么需要把DiamondButton - DiamondIcon和DiamondButton - DiamondPrice显示出来，其中DiamondButton - DiamondPrice是一个textlabel，用于显示钻石价格，会在表中配置
    2）玩家点击按钮可以使用钻石来购买一个这个药水，如果玩家的钻石数不足，则弹出系统提示：Diamond Not Enough！这个提示和盲盒数达到上限的提示方式一致用系统提示，如果钻石够就扣除对应钻石，购买一个按钮
    3）如果玩家的这个药水的数量大于等于1，则需要把DiamondButton - DiamondIcon和DiamondButton - DiamondPrice隐藏起来，同时把DiamondButton - UseText显示出来，内容是Use（xx），xx是玩家当前这个药水的拥有数量
    4）玩家点击按钮，则立刻使用该药水成功，增加对应的倒计时时间，扣除对应的药水数量，并立刻开始药水生效
5.Potions - Bg - DiamondNum是玩家的钻石数量，需要实时更新数值文本，但是这里不使用大数值，这里始终数字是多少就显示多少

我的药水的对应配置是：

Id	名字	加成数值	生效时间（分钟）	钻石价格	开发者商品
1001	药水1	0.3	30	29	3524122858
1002	药水2	0.5	30	89	3524122984
1003	药水3	1	30	199	3524123226

策划文档V5.4 新手引导

概述：我们需要做新手引导，引导玩家去做一些事情

详细规则：
1.增加三类引导类型：
    1）在玩家身上与目标点之间出现Beam连线，引导玩家前往目标点
    2）在ui上，出现手指图ui，引导玩家点击ui

2.关于第一类引导：在玩家与目标点之间生成beam，具体是是：
    1）在ReplicatedStorage - GuideEffect下，有两个Part，分别是Guide01和Guide02，在两个Part下都各自有一些子节点
    2）当需要引导时，把Guide01及其所有的子节点（注意是所有）全部复制到玩家身上，并挂在玩家身上，然后把Guide02及其所有子节点挂到目标单位上，这样会在玩家和目标点之间出现一道动态的beam连线，引导玩家前往目标点
    3）当引导完成时，就将Guide01和Guide02都移除，就算完成了这个引导
3.关于第二类引导，目前只使用在引导玩家点击背包中的按钮上，具体逻辑是：
    1）在StarterGui - BackpackGui - BackpackFrame - ItemListFrame - ArmyTemplate下有一个子节点，叫Finger
    2）当需要引导玩家点击时，就把Finger的Visible属性改成True
    3）显示出来的情况下，需要有一个不断上下浮动的效果，看起来时引导玩家点击
    4）当玩家点击后，引导完成，再把Finger隐藏起来
4.第三类引导是纯显示文本内容，也就是下面说的5的相关的部分，只不过是单纯显示文本

5.每一步引导的时候，都需要在界面上显示对应的引导文本内容，具体逻辑是：
    1）StarterGui - GuideTips - TipsBg是一个Frame，当需要把引导文本显示出来时，就把TipsBg的Visible属性改成True，需要隐藏就改成False
    2）StarterGui - GuideTips - TipsBg - Tips是textlabel，用于展示具体的引导文本内容
    3）当文本出现时，需要做一个大小不断变化的呼吸态效果

具体的引导需求是：
引导1：玩家进入游戏后，在玩家与传送带上的第一个id为1001的盲盒之间生成Beam连线（类型1），具体的引导文本是：Buy a blind box，玩家购买该盲盒后，引导完成，隐藏引导文本并移除beam连线
注意：如果链接的盲盒在玩家未购买时，就消失了，则立刻重新寻找一个1001，把Guide02挂给这个新的1002盲盒

引导2：玩家购买盲盒后，在玩家身上与玩家家园的IdleFloor中心生成Beam引导玩家前往目的地（以Player01举例，IdleFloor路径是：Workspace - Home - Player01 - Base - IdleFloor）
引导文本内容是：Head to the destination
玩家在到达目的地后引导完成
注意：如果在这个引导没完成的时候，玩家点击了任意一个背包中的盲盒并放置在地上了，则立刻视为这一步引导已经完成

引导3：玩家达到第二步的目的地后，引导玩家点击背包中的1001这个盲盒，走上面说的类型2的引导表现，引导文本是：Put this blind box on the ground
玩家点击背包中的盲盒后，立刻视为这一步引导完成
注意：如果第二步的引导完成前，玩家已经放下了任意一个盲盒，则立刻视为引导2与引导3全部完成

引导4：引导玩家开启盲盒，具体逻辑是：当盲盒放在地上时，如果倒计时结束可以开启了，则立刻显示文本提示：Unbox this blind box，玩家开启后，这一步引导完成
引导5：开启盲盒后，势必会让玩家获得一个手办在手办台上，这时候需要在这个手办对应的ClaimButton上，和玩家身上，形成一个beam，引导玩家前往领取按钮，引导文本是：Tap to collect cash
玩家触碰后，视为引导完成

需要加一个Gm工具：重置全部引导，重置后重新开始引导


策划文档V5.5 新手礼包

概述：新手礼包是一个通行证，玩家可以购买，但是也只能购买一次

详细规则：

1.玩家点击StarterGui - MainGui - StarterPack按钮，打开新手礼包界面（将StarterGui - StarterPack - Bg的Visible属性改成true）
2.点击StarterGui - StarterPack - Bg - CloseButton按钮，关闭新手礼包界面（将StarterGui - StarterPack - Bg的Visible属性改成false）
3.新手礼包通行证id是：1693176659，玩家点击StarterGui - StarterPack - Bg - Buy按钮，触发对这个通行证的购买
4.购买完成后，为玩家发放盲盒，分别是：1003盲盒2个，1004盲盒2个，1005盲盒2个
5.购买完成后，需要关闭新手礼包界面，隐藏新手礼包按钮（StarterGui - MainGui - StarterPack），然后立刻弹出购买完成弹框（用和Progression里面领钻石后一样的弹出效果），只是是三个道具领取，然后图标用盲盒的图标
6.我需要给StarterGui - MainGui - StarterPack - Price下面做渐变效果，我在Price下加了子节点也就是一个UIGradient组件，"C:\Users\ZhuanZ\Desktop\渐变录屏"，这里的彩虹两个字的渐变效果就是我要的渐变动态效果，需要你来实现，就这样不断循环渐变即可

策划文档V5.6

成就Id	成就类型	达成条件（分钟）	钻石奖励数	养成奖励类型	养成奖励数值	奖励文本	成就文本	成就图标资源
80001	1	5	10	3	0.01	Coin Rate +1%	Play for 5 minutes	rbxassetid://108052821452134
80002	1	10	10	3	0.02	Coin Rate +2%	Play for 10 minutes	rbxassetid://108052821452134
80003	1	30	10	3	0.03	Coin Rate +3%	Play for 30 minutes	rbxassetid://108052821452134
80004	1	60	15	3	0.04	Coin Rate +4%	Play for 1 hour	rbxassetid://108052821452134
80005	1	180	15	3	0.05	Coin Rate +5%	Play for 3 hours	rbxassetid://108052821452134
80006	1	300	15	3	0.06	Coin Rate +6%	Play for 5 hours	rbxassetid://108052821452134
80007	1	420	30	3	0.07	Coin Rate +7%	Play for 7 hours	rbxassetid://108052821452134
80008	1	600	30	3	0.08	Coin Rate +8%	Play for 10 hours	rbxassetid://108052821452134
80009	1	900	30	3	0.1	Coin Rate +10%	Play for 15 hours	rbxassetid://108052821452134
80010	1	1200	30	3	0.12	Coin Rate +12%	Play for 20 hours	rbxassetid://108052821452134
80011	1	1800	30	3	0.14	Coin Rate +14%	Play for 30 hours	rbxassetid://108052821452134
80012	1	2400	30	3	0.16	Coin Rate +16%	Play for 40 hours	rbxassetid://108052821452134
80013	1	3000	50	3	0.18	Coin Rate +18%	Play for 50 hours	rbxassetid://108052821452134
80014	1	4800	50	3	0.2	Coin Rate +20%	Play for 80 hours	rbxassetid://108052821452134
80015	1	6000	50	3	0.25	Coin Rate +25%	Play for 100 hours	rbxassetid://108052821452134
80016	1	9000	50	3	0.3	Coin Rate +30%	Play for 150 hours	rbxassetid://108052821452134
79001	2	5	10	4	3	Extra Luck +3%	Open 5 Blind Boxes	rbxassetid://100745360383588
79002	2	30	10	4	6	Extra Luck +6%	Open 30 Blind Boxes	rbxassetid://100745360383588
79003	2	100	10	4	9	Extra Luck +9%	Open 100 Blind Boxes	rbxassetid://100745360383588
79004	2	500	20	4	12	Extra Luck +12%	Open 500 Blind Boxes	rbxassetid://100745360383588
79005	2	1000	20	4	15	Extra Luck +15%	Open 1000 Blind Boxes	rbxassetid://100745360383588
79006	2	1500	20	4	18	Extra Luck +18%	Open 1500 Blind Boxes	rbxassetid://100745360383588
79007	2	2000	20	4	21	Extra Luck +21%	Open 2000 Blind Boxes	rbxassetid://100745360383588
79008	2	3000	30	4	24	Extra Luck +24%	Open 3000 Blind Boxes	rbxassetid://100745360383588
79009	2	4000	30	4	27	Extra Luck +27%	Open 4000 Blind Boxes	rbxassetid://100745360383588
79010	2	5000	30	4	30	Extra Luck +30%	Open 5000 Blind Boxes	rbxassetid://100745360383588
79011	2	6000	30	4	33	Extra Luck +33%	Open 6000 Blind Boxes	rbxassetid://100745360383588
79012	2	8000	40	4	36	Extra Luck +36%	Open 8000 Blind Boxes	rbxassetid://100745360383588
79013	2	10000	40	4	39	Extra Luck +39%	Open 10000 Blind Boxes	rbxassetid://100745360383588
79014	2	12000	50	4	42	Extra Luck +42%	Open 12000 Blind Boxes	rbxassetid://100745360383588
79015	2	14000	50	4	45	Extra Luck +45%	Open 14000 Blind Boxes	rbxassetid://100745360383588
79016	2	16000	50	4	48	Extra Luck +48%	Open 16000 Blind Boxes	rbxassetid://100745360383588
78001	17	10	10	6	0.06	Light Blind Box Mutation Chance +6%	Open 10 Light Blind Boxes	rbxassetid://91025569595788
78002	17	30	10	6	0.08	Light Blind Box Mutation Chance +8%	Open 30 Light Blind Boxes	rbxassetid://91025569595788
78003	17	50	10	6	0.1	Light Blind Box Mutation Chance +10%	Open 50 Light Blind Boxes	rbxassetid://91025569595788
78004	17	100	10	6	0.12	Light Blind Box Mutation Chance +12%	Open 100 Light Blind Boxes	rbxassetid://91025569595788
78005	17	150	10	6	0.14	Light Blind Box Mutation Chance +14%	Open 150 Light Blind Boxes	rbxassetid://91025569595788
78006	17	200	10	6	0.16	Light Blind Box Mutation Chance +16%	Open 200 Light Blind Boxes	rbxassetid://91025569595788
78007	17	300	10	6	0.18	Light Blind Box Mutation Chance +18%	Open 300 Light Blind Boxes	rbxassetid://91025569595788
78008	17	500	10	6	0.2	Light Blind Box Mutation Chance +20%	Open 500 Light Blind Boxes	rbxassetid://91025569595788
78009	18	10	10	7	0.06	Gold Blind Box Mutation Chance +6%	Open 10 Gold Blind Boxes	rbxassetid://99762356223447
78010	18	30	10	7	0.08	Gold Blind Box Mutation Chance +8%	Open 30 Gold Blind Boxes	rbxassetid://99762356223447
78011	18	50	10	7	0.1	Gold Blind Box Mutation Chance +10%	Open 50 Gold Blind Boxes	rbxassetid://99762356223447
78012	18	100	10	7	0.12	Gold Blind Box Mutation Chance +12%	Open 100 Gold Blind Boxes	rbxassetid://99762356223447
78013	18	150	10	7	0.14	Gold Blind Box Mutation Chance +14%	Open 150 Gold Blind Boxes	rbxassetid://99762356223447
78014	18	200	10	7	0.16	Gold Blind Box Mutation Chance +16%	Open 200 Gold Blind Boxes	rbxassetid://99762356223447
78015	18	300	10	7	0.18	Gold Blind Box Mutation Chance +18%	Open 300 Gold Blind Boxes	rbxassetid://99762356223447
78016	18	500	10	7	0.2	Gold Blind Box Mutation Chance +20%	Open 500 Gold Blind Boxes	rbxassetid://99762356223447
78017	19	10	10	8	0.06	Diamond Blind Box Mutation Chance +6%	Open 10 Diamond Blind Boxes	rbxassetid://73066433210790
78018	19	30	10	8	0.08	Diamond Blind Box Mutation Chance +8%	Open 30 Diamond Blind Boxes	rbxassetid://73066433210790
78019	19	50	10	8	0.1	Diamond Blind Box Mutation Chance +10%	Open 50 Diamond Blind Boxes	rbxassetid://73066433210790
78020	19	100	10	8	0.12	Diamond Blind Box Mutation Chance +12%	Open 100 Diamond Blind Boxes	rbxassetid://73066433210790
78021	19	150	10	8	0.14	Diamond Blind Box Mutation Chance +14%	Open 150 Diamond Blind Boxes	rbxassetid://73066433210790
78022	19	200	10	8	0.16	Diamond Blind Box Mutation Chance +16%	Open 200 Diamond Blind Boxes	rbxassetid://73066433210790
78023	19	300	10	8	0.18	Diamond Blind Box Mutation Chance +18%	Open 300 Diamond Blind Boxes	rbxassetid://73066433210790
78024	19	500	10	8	0.2	Diamond Blind Box Mutation Chance +20%	Open 500 Diamond Blind Boxes	rbxassetid://73066433210790
78025	20	10	10	9	0.06	Rainbow Blind Box Mutation Chance +6%	Open 10 Rainbow Blind Boxes	rbxassetid://123395554624809
78026	20	30	10	9	0.08	Rainbow Blind Box Mutation Chance +8%	Open 30 Rainbow Blind Boxes	rbxassetid://123395554624809
78027	20	50	10	9	0.1	Rainbow Blind Box Mutation Chance +10%	Open 50 Rainbow Blind Boxes	rbxassetid://123395554624809
78028	20	100	10	9	0.12	Rainbow Blind Box Mutation Chance +12%	Open 100 Rainbow Blind Boxes	rbxassetid://123395554624809
78029	20	150	10	9	0.14	Rainbow Blind Box Mutation Chance +14%	Open 150 Rainbow Blind Boxes	rbxassetid://123395554624809
78030	20	200	10	9	0.16	Rainbow Blind Box Mutation Chance +16%	Open 200 Rainbow Blind Boxes	rbxassetid://123395554624809
78031	20	300	10	9	0.18	Rainbow Blind Box Mutation Chance +18%	Open 300 Rainbow Blind Boxes	rbxassetid://123395554624809
78032	20	500	10	9	0.2	Rainbow Blind Box Mutation Chance +20%	Open 500 Rainbow Blind Boxes	rbxassetid://123395554624809
77001	10	9	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Leaf Blind Box	rbxassetid://131284622139605
77002	11	9	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Water Blind Box	rbxassetid://119510387965714
77003	12	9	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Lunar Blind Box	rbxassetid://137875148961886
77004	13	9	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Solar Blind Box	rbxassetid://110395015182791
77005	14	7	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Flame Blind Box	rbxassetid://115686630835615
77006	15	7	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Heart Blind Box	rbxassetid://95301400310853
77007	16	5	10	1	1	Max Placeable Blind Boxes +1	Collect all figurines in the Celestial Blind Box	rbxassetid://108680777302678


策划文档V5.7  群组奖励

概述：玩家加入我们游戏的群组，可以领一份奖励

详细规则是：

1.玩家点击StarterGui - TopRightGui - GroupReward - Button这个按钮，打开奖励领取界面（把StarterGui - GroupReward - Bg的visible属性改成true）
2.玩家点击StarterGui - GroupReward - Bg - Title - CloseButton按钮，关闭界面
3.玩家点击StarterGui - GroupReward - Bg - Claim这个按钮，触发领取验证，如果验证成功，则为玩家发放奖励，需要弹出系统飘字提示：Claim Successful!（这个参考在线奖励的领取成功飘字提示），同时领取成功后把Claim这个按钮的Visible属性改成false，然后把StarterGui - GroupReward - Bg - Claimed这个textlabel的visible属性改成True
4.玩家领取成功后，需要把StarterGui - TopRightGui - GroupReward这个按钮的Visible属性改成False，永久改成False不再出现了。
5.玩家如果点击领取时，不满足领取条件，则无法领取，飘字提示：Join the group for rewards!，然后需要播放一下我们系统的警告音，和购买时库存不足的音效一致

我们的奖励领取条件是：
1.玩家一定要加入我们游戏的群组，这个应该在roblox有提供的官方验证接口，直接用这个接口判断玩家是否加入了群组
2.玩家在点击领取奖励的那一刻在群组中，即可领取成功

奖励内容是为玩家发放5个1003这个id的盲盒

至于我们的群组id，是602157319