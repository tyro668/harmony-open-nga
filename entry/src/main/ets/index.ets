/**
 * OpenNGA - NGA论坛鸿蒙客户端
 * 
 * 模块导出索引文件
 */

// 常量
export { AppConstants, ApiPath, ResultCode } from './common/constants/AppConstants';
export { ThemeColors, FontSize, Spacing, BorderRadius } from './common/constants/ThemeColors';

// 实体类
export { User, UserEntity } from './model/entity/User';
export { Board, BoardEntity, BoardCategory, BoardCategoryEntity } from './model/entity/Board';
export { Topic, TopicEntity, TopicList, TopicListInfo } from './model/entity/Topic';
export { Article, ArticleEntity, ArticleList, ArticleListInfo, Attachment, AttachmentEntity, AttachmentType } from './model/entity/Article';
export { Message, MessageEntity, MessageList, MessageListInfo, MessageType } from './model/entity/Message';

// 网络层
export { HttpClient, RequestConfig, HttpResponse } from './network/api/HttpClient';
export { NgaApi, ngaApi } from './network/api/NgaApi';

// 数据层
export { PreferencesManager, preferencesManager } from './data/preferences/PreferencesManager';

// 管理器
export { UserManager, userManager, UserState } from './common/manager/UserManager';

// 工具类
export { StringUtils, FileUtils, ValidateUtils, ColorUtils } from './common/utils/CommonUtils';
export { LogUtils } from './common/utils/LogUtils';

// UI组件
export { LoadingView, EmptyView, ErrorView, AvatarView, TagView, DividerView, ListItemView, SearchBar, LoadingState } from './ui/components/CommonComponents';

// 路由
export { AppRouter, RouterConfig } from './router/AppRouter';
