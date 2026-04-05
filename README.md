# HarmonyOS NGA 论坛客户端

基于 Android open-nga 项目重写的鸿蒙原生 NGA 论坛客户端。

## 项目简介

本项目是将 Android 平台的 NGA 论坛客户端（open-nga）完全重写为鸿蒙 HarmonyOS 6.0 原生应用。采用 ArkTS 语言和 ArkUI 框架开发，实现了 NGA 论坛的核心功能。

## 功能特性

### 核心功能
- 🔐 **用户登录** - WebView 登录，支持 Cookie 持久化
- 📋 **版块列表** - 完整版块分类，支持版块收藏
- 📝 **帖子浏览** - 帖子列表、帖子详情、回复查看
- ⭐ **收藏功能** - 帖子收藏、版块收藏
- 🔍 **搜索功能** - 帖子搜索、搜索历史
- 🔔 **消息通知** - 回复通知、@通知
- 📜 **浏览历史** - 自动记录浏览历史

### 页面列表
| 页面 | 路径 | 功能描述 |
|------|------|----------|
| 主页 | `pages/main/MainPage` | 首页、版块、消息、我的 |
| 登录 | `pages/login/LoginPage` | WebView 登录 |
| 版块列表 | `pages/board/BoardListPage` | 所有版块、收藏版块 |
| 帖子列表 | `pages/topic/TopicListPage` | 版块帖子列表 |
| 帖子详情 | `pages/article/ArticleListPage` | 帖子内容和回复 |
| 收藏 | `pages/favorite/FavoritePage` | 收藏的帖子 |
| 历史 | `pages/history/HistoryPage` | 浏览历史 |
| 通知 | `pages/notification/NotificationPage` | 消息通知 |
| 搜索 | `pages/search/SearchPage` | 搜索帖子 |
| 发帖 | `pages/post/PostPage` | 发帖、回复 |
| 个人资料 | `pages/profile/ProfilePage` | 用户信息 |
| 设置 | `pages/settings/SettingsPage` | 应用设置 |

## 技术栈

- **开发语言**: ArkTS (TypeScript 超集)
- **UI 框架**: ArkUI (声明式 UI)
- **目标平台**: HarmonyOS 6.0 (API 22)
- **网络请求**: @ohos.net.http
- **本地存储**: @ohos.data.preferences
- **构建工具**: Hvigor

## 项目结构

```
harmony-open-nga/
├── AppScope/                    # 应用全局配置
│   ├── app.json5               # 应用配置
│   └── resources/              # 全局资源
├── entry/                       # 主模块
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── common/         # 公共模块
│   │   │   │   ├── constants/  # 常量定义
│   │   │   │   ├── manager/    # 管理器
│   │   │   │   └── utils/      # 工具类
│   │   │   ├── data/           # 数据层
│   │   │   │   └── preferences/# 本地存储
│   │   │   ├── model/          # 数据模型
│   │   │   │   └── entity/     # 实体类
│   │   │   ├── network/        # 网络层
│   │   │   │   └── api/        # API 接口
│   │   │   ├── pages/          # 页面
│   │   │   ├── router/         # 路由
│   │   │   └── ui/             # UI 组件
│   │   ├── module.json5        # 模块配置
│   │   └── resources/          # 资源文件
│   └── build-profile.json5     # 构建配置
├── hvigor/                      # 构建工具配置
├── build-profile.json5          # 项目构建配置
├── oh-package.json5             # 依赖配置
└── README.md                    # 项目说明
```

## 开发环境要求

### 必需软件
- **DevEco Studio**: 5.0.0 或更高版本
- **HarmonyOS SDK**: API 22 (HarmonyOS 6.0)
- **Node.js**: 18.x 或更高版本

### 可选软件
- **Git**: 版本控制

## 编译和运行

### 1. 克隆项目

```bash
git clone git@github.com:tyro668/harmony-open-nga.git
cd harmony-open-nga
```

### 2. 使用 DevEco Studio 打开项目

1. 启动 DevEco Studio
2. 选择 `File > Open`
3. 选择项目根目录 `harmony-open-nga`
4. 等待项目初始化完成（首次打开会自动下载依赖）

### 3. 配置签名（可选）

如需在真机上运行，需要配置签名：

1. 选择 `File > Project Structure > Project > Signing Configs`
2. 配置签名信息
3. 或在 `build-profile.json5` 中配置 `signingConfigs`

### 4. 运行项目

#### 方式一：使用 DevEco Studio

1. 连接鸿蒙设备或启动模拟器
2. 点击工具栏的运行按钮（绿色三角形）
3. 或使用快捷键 `Ctrl+R` (Windows) / `Cmd+R` (Mac)

#### 方式二：使用命令行编译

```bash
# 编译 HAP 包
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p module=entry@default -p product=default \
  -p requiredDeviceType=phone assembleHap \
  --analyze=normal --parallel --incremental --daemon

# 编译产物位置
# entry/build/default/outputs/default/entry-default-*.hap
```

### 5. 安装到设备

编译完成后，HAP 包位于：
```
entry/build/default/outputs/default/entry-default-signed.hap
```

使用 hdc 工具安装：
```bash
hdc install entry/build/default/outputs/default/entry-default-signed.hap
```

## API 接口说明

### 基础 URL
- 主站: `https://bbs.nga.cn`
- 备用: `https://bbs.ngacn.cc`

### 主要接口

| 功能 | 接口 | 参数 |
|------|------|------|
| 帖子列表 | `/thread.php` | `fid`, `stid`, `page`, `lite=js`, `noprefix` |
| 帖子详情 | `/read.php` | `tid`, `page`, `__output=8`, `noprefix`, `v2` |
| 收藏帖子 | `/thread.php` | `favor=1`, `page`, `lite=js`, `noprefix` |
| 通知列表 | `/nuke.php` | `__lib=noti`, `__output=8`, `__act=get_all` |
| 用户资料 | `/nuke.php` | `func=ucp`, `uid` |

### 请求头
```
User-Agent: Mozilla/5.0 ...
X-User-Agent: Nga_Official
Cookie: ngaPassportUid=xxx; ngaPassportCid=xxx
```

## 常见问题

### Q: 编译报错 "Cannot find module"
A: 检查 SDK 版本是否为 API 22，在 DevEco Studio 中更新 SDK。

### Q: 运行时白屏
A: 检查日志输出，确认网络权限已配置。在 `module.json5` 中添加：
```json
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET"
  }
]
```

### Q: 登录后无法获取数据
A: 确认 Cookie 是否正确保存，检查 `UserManager` 的初始化。

### Q: 版块列表为空
A: `BoardManager` 包含硬编码的版块数据，检查初始化是否正确。

## 开发指南

### 添加新页面

1. 在 `entry/src/main/ets/pages/` 下创建页面文件
2. 在 `entry/src/main/resources/base/profile/main_pages.json` 中注册路由：
```json
{
  "src": [
    "pages/main/MainPage",
    "pages/your/NewPage"
  ]
}
```

### 添加新 API

1. 在 `entry/src/main/ets/network/api/NgaApi.ets` 中添加方法
2. 使用 `HttpClient.getInstance().get()` 或 `post()` 发起请求
3. 解析返回数据

### 数据持久化

使用 `PreferencesManager`：
```typescript
// 保存数据
await PreferencesManager.getInstance().putString('key', 'value');

// 读取数据
const value = await PreferencesManager.getInstance().getString('key');
```

## 参考项目

本项目基于 Android 版 open-nga 重写：
- 原项目路径: `android/open-nga-main`
- 原项目架构: MVP + MVVM
- 原项目技术: Java + Kotlin, Retrofit, RxJava2, Room

## 许可证

本项目仅供学习交流使用。

## 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 更新日志

### v1.2.1 (2024-04-05)
- 初始版本
- 实现核心功能：登录、版块、帖子、收藏、搜索等
- 完成鸿蒙原生适配
