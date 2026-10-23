# MPx 中文版

基于 [MPx Player](https://github.com/mohammedbakri123/MPx-player) 完整版开发的中文改进分支，保留本地播放、字幕、下载、媒体库和短视频浏览等功能，重点改进中文体验、短视频交互及存储使用方式。

本项目是社区维护的 Fork，非上游官方中文版。原作者及贡献者的开发工作是本项目的基础，许可证和原有署名继续保留。

> **请使用 [`cn-full-player` 分支](https://github.com/niubaosama/MPx-player-cn/tree/cn-full-player)。** 中文版基于上游完整版提交 [`9e644a1`](https://github.com/mohammedbakri123/MPx-player/commit/9e644a1daa986f85dc30c2ebedc4110a7bb89d6f) 继续维护，与上游后续的 v3 重写版分开演进。查看其他分支时，功能和构建方式可能不同。

## 下载安装

**[直接下载 MPx 中文版 2.3.0 APK](https://github.com/niubaosama/MPx-player-cn/releases/download/v2.3.0-cn/MPx-player-cn-2.3.0-arm64.apk)** · [发布说明与附件](https://github.com/niubaosama/MPx-player-cn/releases/tag/v2.3.0-cn)

- 已签名安装包，约 68 MB，下载后即可安装，无需自行构建。
- 适用于 Android 7.0 及以上的 ARM64 设备，可与原版共存。
- 当前为预览版，自动化测试及构建、签名验证已完成，本轮实机回归仍待完成。
- 在发布页下载时，选择 Assets 下的 `MPx-player-cn-2.3.0-arm64.apk`；`Source code` 附件是源码，不能直接安装。

APK SHA-256：

```text
7b5f8d8cfe941af571853e7a31be4038195b7d2c18a87ae03dbbdc75d6dea532
```

## 当前版本

| 项目 | 说明 |
| --- | --- |
| 应用名称 | MPx 中文版；英文系统下显示 MPx CN |
| 版本 | 2.3.0（versionCode 2） |
| Android 包名 | `com.niubaosama.mpx.cn` |
| 当前 APK 目标 | Android 7.0 及以上，ARM64（`arm64-v8a`） |
| 安装方式 | 独立安装，可与原版及此前测试版共存 |
| 语言 | 跟随系统、简体中文、English |

## 中文版改了什么

### 中文界面

- 增加应用语言设置，切换后立即生效并保存选择。
- 汉化播放器、媒体库、历史、收藏、设置、短视频和下载相关界面，以及 Android 原生分享下载界面的提示。
- 视频文件名、媒体内容和外部服务返回的原始诊断信息保持原样。

### 短视频来源：文件夹与随机本机

- 支持添加多个文件夹，并为每个来源选择是否包含子文件夹；也可添加单个视频。
- 添加来源只记录原文件路径，不再为导入操作复制一份视频。
- 移除来源不会删除原视频；按路径去重，不同目录中的同名视频可以同时保留。
- 新增“随机本机”模式，从应用有权限访问的本机视频中建立队列，无需先添加来源。
- 文件夹来源与随机本机模式分别保留本次使用期间的队列和当前位置。

### 短视频播放与操作

- 上下滑动切换视频，点击暂停或继续，长按临时以 2 倍速播放，松开后恢复原速度。
- 增加明确的静音操作，移除常驻的退出手势提示。
- 进入短视频标签页时停用首页标签之间的左右滑动切换，减少拖进度条时误切页面。
- 与普通播放器共用进度条组件，扩大触摸区域；拖动时先预览时间，松开后再跳转。
- 切到其他页面后暂停播放；返回时恢复当前视频、进度、队列顺序、倍速、静音及暂停状态。
- 当前播放页使用播放器实例，切换和离开页面时清理相关播放资源。

### 普通播放与短视频互相切换

- 支持从普通播放进入短视频，也支持从短视频返回普通播放。
- 切换时传递视频队列、当前视频、播放进度、倍速和播放或暂停状态。
- 首页和历史记录等入口继续复用同一个普通播放器组件。
- 调整亮度、音量滑动的触发距离和灵敏度，减少误操作；补全手势取消时的状态恢复。
- 调整底部控制按钮在窄屏下的布局。

### 媒体库、性能与存储

- 保存媒体库索引，优先展示缓存结果，再在后台更新；复用父目录扫描结果，减少重复扫描。
- 缩略图生成限制并发，增加内存与磁盘缓存约束，检查缓存文件是否仍然存在。
- 清理播放器监听、计时器和离开页面后的资源，减少无效界面刷新及重复队列复制。
- 调整播放缓冲参数，修复刷新短视频列表时可能跳回旧视频、被其他页面覆盖后仍播放等问题。
- 修复新建数据库的字段遗漏，并验证旧数据库的升级过程。

这些改动针对卡顿和资源占用的相关原因；大文件、高码率视频和不同设备上的实际效果仍需实机验证。

### 启动界面

- 可关闭应用内启动页，或设置显示时长（200～3000 毫秒）。
- 可选择简洁或装饰样式，自定义标题和副标题。
- 移除原有额外固定等待。Android 系统自身的启动画面仍可能短暂显示。

## 保留的主要功能

| 功能 | 内容 |
| --- | --- |
| 本地播放 | mpv 播放核心、倍速、画面比例、双击快进与快退、滑动定位、亮度与音量手势、画中画 |
| 字幕与音轨 | 外挂字幕、字幕样式调整、音轨选择及恢复 |
| 媒体库 | 文件夹浏览、搜索、收藏、缩略图、历史记录与续播 |
| 下载 | 基于 Chaquopy 与 yt-dlp 的下载流程，以及 Android 分享入口 |
| 短视频 | 文件夹来源、随机本机、上下滑动浏览和普通播放模式切换 |

外部网站的下载可用性取决于站点规则、网络及 yt-dlp 支持情况，不保证所有链接均可下载。

## 安装与开始使用

1. 从 [Releases](https://github.com/niubaosama/MPx-player-cn/releases/tag/v2.3.0-cn) 下载并安装已签名的中文版 APK。当前提供的构建目标为 ARM64，32 位设备不适用。
2. 首次打开时，按系统提示授予读取视频所需的权限。中文版是独立应用，需要重新授权。
3. 在设置中选择应用语言；进入短视频后，可通过来源菜单选择“文件夹来源”或“随机本机”。
4. 使用文件夹来源时，添加需要浏览的文件夹，并按需要开启“包含子文件夹”。视频保持在原位置。

### 升级与数据说明

- 中文版采用独立包名，不会覆盖原版，也不会自动迁移原版的历史、设置或私有目录中的视频。
- 后续覆盖升级需要保持相同包名和签名证书。请妥善备份签名密钥，不要将私钥或密码上传到仓库。
- 新的来源机制不会因添加视频而再复制原文件，但缩略图、索引和实际下载的文件仍会占用空间。
- 此前旧版导入产生的大体积副本不会自动清理，需先确认原文件及备份，再决定如何处理。
- 视频路径改变、文件删除、存储设备断开或权限失效后，来源可能需要刷新或重新选择。
- 当前短视频记忆覆盖应用内切页、切换模式及进入后台再返回；**不保证结束应用进程后恢复完整队列和全部播放状态**。
- 首次没有索引时仍需扫描；“随机本机”仅覆盖系统允许应用访问的存储位置。

## 截图

以下为上游原版截图，用于展示整体布局，尚未替换为当前中文版界面。

<p align="center">
  <img src="screenshots/library.jpg" width="170" alt="原版媒体库界面">
  <img src="screenshots/player2.jpg" width="170" alt="原版播放器界面">
  <img src="screenshots/reels.jpg" width="170" alt="原版短视频界面">
  <img src="screenshots/settings.jpg" width="170" alt="原版设置界面">
</p>

## 验证状态

2.3.0 首轮交付时的检查记录：

对应的 [自动检查记录](https://github.com/niubaosama/MPx-player-cn/actions/runs/39814281021) 和 [APK 构建记录](https://github.com/niubaosama/MPx-player-cn/actions/runs/39813774108) 可在 GitHub Actions 查看；构建附件有保留期限。

| 检查 | 结果 |
| --- | --- |
| Flutter 自动化测试 | 83 项通过，覆盖播放控制、短视频状态与导航、来源管理、索引、进度条、启动设置及布局等 |
| Python 自动化测试 | 7 项通过，覆盖下载汉化与数据库建表、升级 |
| 静态分析 | 无错误；仍有原项目已有的 5 项警告和 4 项 API 弃用提示 |
| Android 构建 | 云端 ARM64 release 构建完成，交付 APK 已使用固定证书签名并验证签名 |
| 实机验证 | 此前汉化测试包已在用户设备运行；本轮 2.3.0 的性能、手势和长时间使用表现仍待实机回归 |

测试通过不代表所有机型与视频格式均已验证。反馈问题时请附设备型号、Android 版本、应用版本、操作步骤，以及相关视频的格式、分辨率和大小；不要上传不便公开的个人媒体。

## 开发与构建

### 技术栈

- Flutter / Dart，Provider 状态管理。
- `flutter_mpv`、`flutter_mpv_video`、`flutter_mpv_libs_video` 播放核心。
- SQLite（`sqflite`）及 SharedPreferences 保存索引、记录与设置。
- Android Kotlin，Chaquopy + Python + yt-dlp 支持下载。

### 云端构建：电脑无需安装 Android 开发环境

仓库提供 [GitHub Actions 工作流](.github/workflows/android-apk.yml)。在自己的 Fork 中启用 Actions 后，手动运行“检查与编译安卓汉化版”，选择 `cn-full-player` 分支即可执行检查和构建。

- 云端环境：Ubuntu 24.04、Flutter 3.41.0、JDK 17、Python 3.14，以及 Android 构建工具。
- 普通源码推送执行检查；手动触发工作流，或推送提交信息包含 `[build-apk]` 的源码改动时，才生成 APK。
- 构建产物 `MPx-player-cn-arm64-unsigned` 包含待签名 APK 和官方 `apksigner.jar`，保留 7 天。
- **待签名 APK 不能直接安装，必须使用自己的固定密钥完成签名。** 当前工作流不保存发布私钥，也未配置自动签名发布。

云端承担 Flutter 和 Android 编译，本机不必安装 Android Studio 或完整 SDK；如需在本机签名，仍需 Java 环境及相应签名工具。签名材料属于维护者私有文件，不随源码分发。

### 本地开发

建议与 CI 保持一致：Flutter 3.41.0、JDK 17、Python 3.14，以及匹配项目配置的 Android SDK / 构建工具。Android Studio 可按开发需要安装，命令行构建不强制要求 IDE。

```powershell
git clone --branch cn-full-player https://github.com/niubaosama/MPx-player-cn.git
cd MPx-player-cn
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
python -B -m unittest discover -s test -p '*_test.py' -v
flutter run
```

构建 ARM64 release 待签名包：

```powershell
flutter build apk --release --target-platform android-arm64
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。当前 release 配置不自动签名；安装或分发前需完成签名并验证证书。

### 项目结构与贡献

```text
lib/
  core/          # 共享服务、数据库、语言资源与组件
  features/
    downloader/  # 下载
    library/     # 媒体库、历史与收藏
    player/      # 播放核心、控制器与普通播放界面
    reels/       # 短视频来源、队列与播放界面
    settings/    # 应用设置
android/         # Android 原生入口与构建配置
test/            # 自动化测试
```

架构和贡献说明见 [ARCHITECTURE.md](ARCHITECTURE.md)、[CONTRIBUTING.md](CONTRIBUTING.md)。安全问题参见 [SECURITY.md](SECURITY.md)。这些文档部分沿用上游内容，具体功能与构建配置以本分支源码为准。

欢迎提交可复现的问题和范围明确的改进，尤其是播放稳定性、手势体验、媒体索引和不同设备上的回归结果。

## AI 辅助开发说明

本分支的中文汉化及后续体验改进使用 **OpenAI Codex 辅助编程**。维护者提出需求、确定交互方向并提供实机使用反馈，AI 参与源码分析、方案讨论、代码修改、自动化测试、构建排查及文档整理。

- 本说明适用于中文版分支的改动，不代表上游原项目采用相同开发方式。
- AI 辅助编写的代码同样需要检查、测试和实际使用验证。上方“验证状态”列出了本轮已经完成的检查及尚待实机验证的部分。
- 功能取舍、版本发布和问题跟进由本分支维护者负责；欢迎通过 Issue 提供可复现的问题，帮助持续改进。
- AI 参与不改变原项目及其依赖的版权归属和许可证要求。

## 致谢与许可证

感谢 [mohammedbakri123/MPx-player](https://github.com/mohammedbakri123/MPx-player) 原作者与所有贡献者，以及 Flutter、mpv、yt-dlp 等开源项目。

本项目沿用上游 [MIT License](LICENSE)。原有版权声明和许可文本保持不变。
