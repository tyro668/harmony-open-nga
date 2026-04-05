import { Board, BoardCategory } from '../../model/entity/Board';
import { PreferencesManager } from '../../data/preferences/PreferencesManager';

/**
 * 版块管理器
 */
export class BoardManager {
  private static instance: BoardManager;
  private categories: BoardCategory[] = [];
  private bookmarkBoards: Board[] = [];
  private readonly KEY_BOOKMARK: string = 'bookmark_boards';

  private constructor() {}

  static getInstance(): BoardManager {
    if (!BoardManager.instance) {
      BoardManager.instance = new BoardManager();
    }
    return BoardManager.instance;
  }

  /**
   * 初始化版块数据
   */
  async init(): Promise<void> {
    // 加载版块数据
    this.categories = this.getDefaultCategories();
    // 加载收藏
    await this.loadBookmarks();
  }

  /**
   * 获取所有版块分类
   */
  getCategories(): BoardCategory[] {
    return this.categories;
  }

  /**
   * 获取收藏版块
   */
  getBookmarks(): Board[] {
    return this.bookmarkBoards;
  }

  /**
   * 判断是否已收藏
   */
  isBookmark(fid: string, stid: string): boolean {
    for (let i = 0; i < this.bookmarkBoards.length; i++) {
      const board = this.bookmarkBoards[i];
      if (board.id === fid && board.stid === stid) {
        return true;
      }
    }
    return false;
  }

  /**
   * 添加收藏
   */
  async addBookmark(board: Board): Promise<void> {
    if (!this.isBookmark(board.id, board.stid)) {
      this.bookmarkBoards.push(board);
      await this.saveBookmarks();
    }
  }

  /**
   * 移除收藏
   */
  async removeBookmark(fid: string, stid: string): Promise<void> {
    for (let i = 0; i < this.bookmarkBoards.length; i++) {
      const board = this.bookmarkBoards[i];
      if (board.id === fid && board.stid === stid) {
        this.bookmarkBoards.splice(i, 1);
        break;
      }
    }
    await this.saveBookmarks();
  }

  /**
   * 加载收藏
   */
  private async loadBookmarks(): Promise<void> {
    try {
      const jsonStr = await PreferencesManager.getInstance().getString(this.KEY_BOOKMARK);
      if (jsonStr != '') {
        const list: Board[] = JSON.parse(jsonStr);
        this.bookmarkBoards = list;
      }
    } catch (err) {
      console.error('Load bookmarks failed:', err);
    }
  }

  /**
   * 保存收藏
   */
  private async saveBookmarks(): Promise<void> {
    try {
      const jsonStr = JSON.stringify(this.bookmarkBoards);
      await PreferencesManager.getInstance().putString(this.KEY_BOOKMARK, jsonStr);
    } catch (err) {
      console.error('Save bookmarks failed:', err);
    }
  }

  /**
   * 获取默认版块分类（从 category.json 解析）
   */
  private getDefaultCategories(): BoardCategory[] {
    const categories: BoardCategory[] = [];

    // 网事杂谈
    const cat1 = new BoardCategory();
    cat1.id = 'other';
    cat1.name = '网事杂谈';
    cat1.boards = [];
    cat1.subCategories = [];

    const sub1_1 = new BoardCategory();
    sub1_1.name = '网事杂谈';
    sub1_1.boards = [
      this.createBoard('-7', '0', '网事杂谈'),
      this.createBoard('-447601', '0', '二次元国家地理', '动漫'),
      this.createBoard('-7955747', '0', '晴风村', '情感生活'),
      this.createBoard('-343809', '0', '寂寞的车', '车迷俱乐部'),
      this.createBoard('843', '0', '国际新闻'),
      this.createBoard('524', '0', '漩涡书院'),
      this.createBoard('485', '0', '篮球'),
      this.createBoard('-576177', '0', '音乐影视'),
      this.createBoard('-81981', '0', '生命之杯', '足球'),
      this.createBoard('706', '0', '大时代'),
      this.createBoard('-353371', '0', '宠物养成'),
      this.createBoard('-1459709', '0', '职场人生'),
      this.createBoard('-84', '0', '模玩之魂', '模型手办'),
      this.createBoard('-608808', '0', '弑熊主厨的血腥厨房', '厨艺美食'),
      this.createBoard('-7678526', '0', '麻将'),
      this.createBoard('-8725919', '0', '小窗视界', '摄影旅游'),
      this.createBoard('-54214', '0', '时尚消费'),
      this.createBoard('-202020', '0', '程序员职业交流'),
      this.createBoard('-2671', '0', '发烧友', '音频设备'),
      this.createBoard('-444012', '0', '我们的骑迹', '自行车'),
      this.createBoard('124', '0', '壁画洞窟', '原创艺术'),
      this.createBoard('-131429', '0', '红茶馆', '网络文学'),
      this.createBoard('102', '0', '作家协会', '原创文学'),
      this.createBoard('-187628', '0', '家居装修'),
      this.createBoard('-4567100', '0', '狼人杀'),
      this.createBoard('-349066', '0', '吟瑟梨茗', '曲艺'),
    ];
    cat1.subCategories.push(sub1_1);

    const sub1_2 = new BoardCategory();
    sub1_2.name = 'IT软硬件';
    sub1_2.boards = [
      this.createBoard('436', '0', '消费电子 IT新闻'),
      this.createBoard('334', '0', '硬件配置', '装机讨论'),
      this.createBoard('498', '0', '二手交易'),
      this.createBoard('722', '0', '手机研究所', '软硬件讨论'),
    ];
    cat1.subCategories.push(sub1_2);

    categories.push(cat1);

    // 拳头游戏
    const cat2 = new BoardCategory();
    cat2.id = 'riotgame';
    cat2.name = '拳头游戏';
    cat2.boards = [];
    cat2.subCategories = [];

    const sub2_1 = new BoardCategory();
    sub2_1.name = '拳头游戏';
    sub2_1.boards = [
      this.createBoard('-152678', '0', '英雄联盟', 'League Of Legends'),
      this.createBoard('708', '0', '无畏契约'),
      this.createBoard('660', '0', '云顶之弈'),
      this.createBoard('681', '0', '英雄联盟手游'),
      this.createBoard('680', '0', 'LOR'),
    ];
    cat2.subCategories.push(sub2_1);

    categories.push(cat2);

    // 暴雪游戏
    const cat3 = new BoardCategory();
    cat3.id = 'bliz';
    cat3.name = '暴雪游戏';
    cat3.boards = [];
    cat3.subCategories = [];

    const sub3_1 = new BoardCategory();
    sub3_1.name = '暴雪游戏';
    sub3_1.boards = [
      this.createBoard('459', '0', '守望先锋', 'OVERWATCH'),
      this.createBoard('422', '0', '炉石传说', 'HearthStone'),
      this.createBoard('318', '0', '暗黑破坏神3', 'D3综合讨论区'),
      this.createBoard('431', '0', '风暴英雄', 'Heroes of the Storm'),
      this.createBoard('406', '0', '星际争霸2', 'Starcraft Ⅱ'),
      this.createBoard('490', '0', '魔兽争霸', 'WarCraft'),
      this.createBoard('685', '0', '暗黑破坏神4'),
      this.createBoard('631', '0', '暗黑破坏神:不朽', 'Diablo Immortal'),
      this.createBoard('769', '0', '暗黑破坏神2 重置版'),
    ];
    cat3.subCategories.push(sub3_1);

    categories.push(cat3);

    // 魔兽世界
    const cat4 = new BoardCategory();
    cat4.id = 'wow';
    cat4.name = '魔兽世界';
    cat4.boards = [];
    cat4.subCategories = [];

    const sub4_1 = new BoardCategory();
    sub4_1.name = '魔兽世界';
    sub4_1.boards = [
      this.createBoard('7', '0', '艾泽拉斯议事厅', '魔兽主讨论区'),
      this.createBoard('230', '0', '艾泽拉斯风纪委员会', '曝光违背公认准则的行为'),
      this.createBoard('849', '0', '巨龙时代', '魔兽世界10.0'),
      this.createBoard('310', '0', '前瞻资讯', '新版本与高阶讨论'),
      this.createBoard('624', '0', '经典旧世', '怀旧服讨论'),
      this.createBoard('323', '0', '国服以外'),
      this.createBoard('850', '0', '巫妖王之怒', '新版本信息汇集'),
    ];
    cat4.subCategories.push(sub4_1);

    const sub4_2 = new BoardCategory();
    sub4_2.name = '职业讨论区';
    sub4_2.boards = [
      this.createBoard('390', '0', '五晨寺', '武僧'),
      this.createBoard('320', '0', '黑锋要塞', '死亡骑士'),
      this.createBoard('181', '0', '铁血沙场', '战士'),
      this.createBoard('182', '0', '魔法圣堂', '法师'),
      this.createBoard('183', '0', '信仰神殿', '牧师'),
      this.createBoard('185', '0', '风暴祭坛', '萨满'),
      this.createBoard('186', '0', '翡翠梦境', '德鲁伊'),
      this.createBoard('187', '0', '猎手大厅', '猎人'),
      this.createBoard('184', '0', '圣光之力', '圣骑士'),
      this.createBoard('188', '0', '恶魔深渊', '术士'),
      this.createBoard('189', '0', '暗影裂口', '盗贼'),
      this.createBoard('477', '0', '伊利达雷', '恶魔猎手'),
      this.createBoard('851', '0', '巨龙群岛', '唤魔师'),
    ];
    cat4.subCategories.push(sub4_2);

    categories.push(cat4);

    // 游戏专版
    const cat5 = new BoardCategory();
    cat5.id = 'games';
    cat5.name = '游戏专版';
    cat5.boards = [];
    cat5.subCategories = [];

    const sub5_1 = new BoardCategory();
    sub5_1.name = '游戏综合讨论区';
    sub5_1.boards = [
      this.createBoard('414', '0', '游戏综合讨论区'),
      this.createBoard('614', '0', 'PS游戏讨论'),
      this.createBoard('615', '0', 'XBOX游戏综合讨论'),
      this.createBoard('616', '0', 'Nintendo游戏讨论'),
      this.createBoard('321', '0', 'Dota2'),
      this.createBoard('630', '0', '全面战争系列'),
      this.createBoard('643', '0', '鬼泣5'),
      this.createBoard('523', '0', '全境封锁'),
      this.createBoard('640', '0', 'Apex 英雄'),
      this.createBoard('629', '0', '武侠/仙侠游戏综合'),
      this.createBoard('489', '0', '怪物猎人'),
      this.createBoard('-5080470', '0', '流放之路'),
      this.createBoard('-452227', '0', '精灵宝可梦', 'Pokemon'),
      this.createBoard('600', '0', '彩虹六号:围攻', 'Rainbow Six:Siege'),
      this.createBoard('644', '0', '只狼 影逝二度'),
      this.createBoard('513', '0', '黑暗之魂'),
      this.createBoard('627', '0', '刺客信条', 'Assassin'),
      this.createBoard('626', '0', '太吾绘卷'),
      this.createBoard('595', '0', '异度神剑'),
      this.createBoard('514', '0', '巫师3'),
      this.createBoard('-5951001', '0', '文明'),
      this.createBoard('552', '0', 'Battlefield系列'),
      this.createBoard('561', '0', '尼尔:机械纪元'),
      this.createBoard('634', '0', '古剑奇谭'),
      this.createBoard('332', '0', '战锤40K'),
      this.createBoard('638', '0', '生化危机2重置版'),
      this.createBoard('628', '0', '荒野大镖客2'),
      this.createBoard('486', '0', '辐射'),
      this.createBoard('636', '0', '使命召唤系列', 'Call of Duty'),
      this.createBoard('558', '0', '仁王'),
      this.createBoard('591', '0', '格斗游戏综合'),
      this.createBoard('604', '0', '星露谷', 'Stardew Valley'),
      this.createBoard('519', '0', '神秘海域'),
      this.createBoard('416', '0', '火炬之光2'),
      this.createBoard('-534617', '0', '轨迹系列'),
      this.createBoard('495', '0', '光荣策略游戏'),
      this.createBoard('605', '0', '边缘世界', 'RimWorld'),
      this.createBoard('455', '0', '鬼武者 魂'),
      this.createBoard('-4760591', '0', '侠客风云传'),
      this.createBoard('-362960', '0', '最终幻想14'),
      this.createBoard('-46468', '0', '坦克世界'),
      this.createBoard('441', '0', '战舰世界'),
      this.createBoard('-47218', '0', '地下城与勇士'),
      this.createBoard('603', '0', '星际战甲', 'Warframe'),
      this.createBoard('568', '0', '绝地求生'),
      this.createBoard('618', '0', '古剑奇谭网络版'),
      this.createBoard('563', '0', '命运'),
      this.createBoard('-7861121', '0', '剑网3'),
      this.createBoard('-235147', '0', '激战2', 'Guild Wars 2'),
      this.createBoard('-38213667', '0', '万智牌'),
      this.createBoard('-6194253', '0', '战争雷霆', 'War Thunder'),
      this.createBoard('611', '0', '逆水寒'),
      this.createBoard('452', '0', '天涯明月刀'),
      this.createBoard('-15219445', '0', '巫师:昆特牌'),
      this.createBoard('609', '0', '堡垒之夜'),
      this.createBoard('481', '0', 'Minecraft'),
      this.createBoard('-2081117', '0', '游戏王'),
      this.createBoard('-2371813', '0', '星战前夜', 'EVE'),
    ];
    cat5.subCategories.push(sub5_1);

    const sub5_2 = new BoardCategory();
    sub5_2.name = '手机/页游讨论';
    sub5_2.boards = [
      this.createBoard('428', '0', '手机/页游讨论'),
      this.createBoard('571', '0', '手游评分版'),
      this.createBoard('650', '0', '原神'),
      this.createBoard('599', '0', '和平精英'),
      this.createBoard('-34587507', '0', '明日方舟'),
      this.createBoard('538', '0', '阴阳师'),
      this.createBoard('516', '0', '王者荣耀'),
      this.createBoard('540', '0', 'Fate', 'Grand Order'),
      this.createBoard('-547859', '0', '少女前线-16LAB研究院'),
      this.createBoard('564', '0', '碧蓝航线'),
      this.createBoard('-373173', '0', '梦幻模拟战'),
      this.createBoard('-7202235', '0', '舰队collection'),
      this.createBoard('549', '0', '崩坏3'),
      this.createBoard('-8180483', '0', '影之诗'),
      this.createBoard('560', '0', '碧蓝幻想'),
      this.createBoard('647', '0', '一起来捉妖'),
      this.createBoard('642', '0', '第七史诗'),
      this.createBoard('641', '0', '多多自走棋'),
      this.createBoard('623', '0', '失落的龙约'),
      this.createBoard('-149110', '0', '战舰少女'),
      this.createBoard('-10308342', '0', '公主连接Re：Dive'),
      this.createBoard('555', '0', '仙境传说'),
      this.createBoard('593', '0', '决战！平安京'),
      this.createBoard('-7678526', '0', '雀魂麻将'),
      this.createBoard('556', '0', '火焰之纹章Heroes'),
      this.createBoard('607', '0', '第五人格'),
      this.createBoard('625', '0', '圣斗士星矢'),
      this.createBoard('492', '0', '部落冲突:皇室战争', 'Clash Royale'),
      this.createBoard('557', '0', "King's Raid"),
      this.createBoard('551', '0', '克鲁赛德战记'),
      this.createBoard('-103330', '0', '万象物语'),
      this.createBoard('550', '0', '不思议迷宫'),
      this.createBoard('692', '0', '天命之子'),
      this.createBoard('426', '0', '智龙迷城', 'Puzzle & Dragons'),
      this.createBoard('575', '0', '怪物弹珠'),
      this.createBoard('569', '0', '死亡爱丽丝'),
      this.createBoard('444', '0', '刀塔传奇'),
      this.createBoard('453', '0', '魔力宝贝'),
      this.createBoard('447', '0', '锁链战记'),
      this.createBoard('559', '0', '光明大陆'),
      this.createBoard('494', '0', '魔龙之魂'),
      this.createBoard('480', '0', '百万亚瑟王'),
      this.createBoard('536', '0', '七雄战记'),
      this.createBoard('537', '0', '大航海时代5'),
      this.createBoard('420', '0', '我叫MT4'),
      this.createBoard('469', '0', '像素骑士团'),
      this.createBoard('601', '0', '晓之轨迹'),
    ];
    cat5.subCategories.push(sub5_2);

    categories.push(cat5);

    // 国家地理俱乐部
    const cat6 = new BoardCategory();
    cat6.id = 'club';
    cat6.name = '国家地理俱乐部';
    cat6.boards = [];
    cat6.subCategories = [];

    const sub6_1 = new BoardCategory();
    sub6_1.name = '国家地理俱乐部';
    sub6_1.boards = [
      this.createBoard('10', '0', '银色黎明裁判所', '投诉/网站BUG/建议'),
      this.createBoard('335', '0', '论坛开发'),
    ];
    cat6.subCategories.push(sub6_1);

    const sub6_2 = new BoardCategory();
    sub6_2.name = '个人版';
    sub6_2.boards = [
      this.createBoard('-447601', '0', '二次元国家地理'),
      this.createBoard('-84', '0', '模玩之魂'),
      this.createBoard('-8725919', '0', '小窗视界'),
      this.createBoard('-965240', '0', '树洞'),
      this.createBoard('-131429', '0', '红茶馆——小说馆'),
      this.createBoard('-608808', '0', '血腥厨房'),
      this.createBoard('-469608', '0', '影~视~秀'),
      this.createBoard('-55912', '0', '音乐讨论'),
      this.createBoard('-522474', '0', '综合体育讨论区'),
      this.createBoard('-1068355', '0', '晴风村'),
      this.createBoard('-168888', '0', '育儿版'),
      this.createBoard('-54214', '0', '时尚板'),
      this.createBoard('-353371', '0', '宠物养成'),
      this.createBoard('-538800', '0', '乙女向二次元'),
      this.createBoard('-7678526', '0', '麻将科学院'),
      this.createBoard('-202020', '0', '程序员职业交流'),
      this.createBoard('-444012', '0', '我们的骑迹'),
      this.createBoard('-349066', '0', '开心茶园'),
      this.createBoard('-2671', '0', '耳机区'),
      this.createBoard('-3355501', '0', '基腐版'),
      this.createBoard('-403298', '0', '怨灵图纸收藏室'),
      this.createBoard('-187628', '0', '家居 装修'),
      this.createBoard('-8627585', '0', '牛头人酋长乐队'),
      this.createBoard('-17100', '0', '全民健身中心'),
    ];
    cat6.subCategories.push(sub6_2);

    categories.push(cat6);

    return categories;
  }

  private createBoard(fid: string, stid: string, name: string, info: string = ''): Board {
    const board = new Board();
    board.id = fid;
    board.stid = stid;
    board.name = name;
    board.description = info;
    return board;
  }
}

export const boardManager = BoardManager.getInstance();
