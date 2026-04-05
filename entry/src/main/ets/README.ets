/**
 * OpenNGA - NGA论坛鸿蒙客户端
 * 
 * 项目说明
 * =========
 * 
 * 本项目是从 Android NGA 客户端 (open-nga) 完全重写为鸿蒙 6.0 原生应用。
 * 
 * 项目结构
 * --------
 * 
 * entry/src/main/ets/
 * ├── common/                    # 公共模块
 * │   ├── constants/             # 常量配置
 * │   │   ├── AppConstants.ets   # 应用常量、API路径、结果码
 * │   │   └── ThemeColors.ets    # 主题颜色、字体大小、间距配置
 * │   ├── manager/               # 管理器
 * │   │   └── UserManager.ets    # 用户管理（登录、登出、状态管理）
 * │   └── utils/                 # 工具类
 * │       ├── CommonUtils.ets    # 通用工具（字符串、文件、验证、颜色）
 * │       └── LogUtils.ets       # 日志工具
 * │
 * ├── model/                     # 数据模型
 * │   └── entity/                # 实体类
 * │       ├── User.ets           # 用户实体
 * │       ├── Board.ets          # 版块实体
 * │       ├── Topic.ets          # 主题/帖子实体
 * │       ├── Article.ets        # 文章/评论实体
 * │       └── Message.ets        # 消息实体
 * │
 * ├── network/                   # 网络层
 * │   └── api/
 * │       ├── HttpClient.ets     # HTTP客户端（基于@ohos.net.http）
 * │       └── NgaApi.ets         # NGA API接口封装
 * │
 * ├── data/                      # 数据层
 * │   ├── preferences/           # 偏好设置
 * │   │   └── PreferencesManager.ets
 * │   └── database/              # 数据库（待实现）
 * │
 * ├── ui/                        # UI层
 * │   └── components/            # 通用组件
 * │       └── CommonComponents.ets # 加载视图、头像、标签等
 * │
 * ├── pages/                     # 页面
 * │   ├── main/
 * │   │   └── MainPage.ets       # 主页面（首页、版块、消息、我的）
 * │   ├── login/
 * │   │   └── LoginPage.ets      # 登录页面
 * │   ├── topic/
 * │   │   └── TopicListPage.ets  # 帖子列表页面
 * │   ├── article/
 * │   │   └── ArticleListPage.ets # 帖子详情页面
 * │   └── settings/
 * │       └── SettingsPage.ets   # 设置页面
 * │
 * ├── router/
 * │   └── AppRouter.ets          # 路由管理
 * │
 * └── index.ets                  # 模块导出索引
 * 
 * 
 * 技术栈
 * ------
 * - 鸿蒙 SDK: 6.0.2(22)
 * - 开发语言: ArkTS (TypeScript扩展)
 * - UI框架: ArkUI 声明式UI
 * - 网络请求: @ohos.net.http
 * - 数据存储: @ohos.data.preferences
 * 
 * 
 * 主要功能
 * --------
 * 1. 用户模块
 *    - 登录/登出
 *    - 用户资料查看
 *    - 多账号支持
 * 
 * 2. 帖子模块
 *    - 版块列表
 *    - 帖子列表（支持置顶、精华筛选）
 *    - 帖子详情
 *    - 发帖/回帖
 *    - 点赞、收藏、举报
 * 
 * 3. 消息模块
 *    - 消息列表
 *    - 消息详情
 *    - 发送消息
 * 
 * 4. 搜索模块
 *    - 搜索帖子
 *    - 搜索文章
 * 
 * 5. 设置模块
 *    - 夜间模式
 *    - 字体大小调整
 *    - 缓存管理
 *    - 关键词过滤
 *    - 黑名单
 * 
 * 6. 其他功能
 *    - 自动签到
 *    - 收藏夹
 *    - 浏览历史
 *    - 通知提醒
 * 
 * 
 * 与Android版本对比
 * -----------------
 * 
 * Android版本使用:
 * - 语言: Java + Kotlin
 * - 架构: MVP + MVVM
 * - 网络: Retrofit + RxJava2
 * - 数据库: Room
 * - 图片: Glide
 * - 路由: ARouter
 * 
 * 鸿蒙版本使用:
 * - 语言: ArkTS
 * - 架构: MVVM (响应式)
 * - 网络: @ohos.net.http
 * - 存储: @ohos.data.preferences
 * - UI: ArkUI 声明式组件
 * - 路由: @ohos.router
 * 
 * 
 * 开发说明
 * --------
 * 1. 确保已安装 HarmonyOS SDK 6.0+
 * 2. 使用 DevEco Studio 打开项目
 * 3. 同步项目依赖
 * 4. 运行到模拟器或真机
 * 
 * 
 * 待完善功能
 * ----------
 * - [ ] 数据库实现（关系型数据库）
 * - [ ] 图片加载缓存
 * - [ ] HTML内容解析渲染
 * - [ ] 表情输入
 * - [ ] 文件上传
 * - [ ] 推送通知
 * - [ ] 深色主题完善
 * - [ ] 国际化支持
 * 
 * 
 * 版本历史
 * --------
 * v1.2.1 (2024-04-05)
 * - 完成鸿蒙6.0原生重写
 * - 实现核心功能模块
 * - 优化UI界面
 * 
 * 
 * 开源协议
 * --------
 * 本项目基于原 Android open-nga 项目重写
 * 遵循相同的开源协议
 */
