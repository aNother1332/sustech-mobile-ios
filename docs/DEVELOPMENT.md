# 构建与开发

[返回项目主页](../README.md)

## 构建与安装

### 下载已构建安装包

前往 [GitHub Releases 最新版本](https://github.com/aNother1332/sustech-mobile-ios/releases/latest)，展开 **Assets**，下载 `SUSTechMobile-unsigned.ipa` 和对应 `.sha256` 校验文件，使用 Windows iLoader 等侧载工具以本人 Apple 账号签名安装。无需自己编译或拥有 Mac。

[全部历史版本](https://github.com/aNother1332/sustech-mobile-ios/releases)保留各版本的交付包、构建元数据和版本说明。早期同为 0.2.0 的 build 2 独立标记为 `v0.2.0-build.2`，`v0.2.0` 为后续 build 4。`with-share` / `with-extensions` 为可选实验扩展包，签名与 App Groups 需单独验证。

### 自行编译

需要 Xcode 26.0+ 编译，应用运行最低要求 iOS / iPadOS 17。没有第三方 iOS 包依赖，不需要 XcodeGen。

### 使用 Mac 构建

```sh
swift test
xcodebuild -project SUSTech.xcodeproj -scheme SUSTech \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

真机运行需要使用自己的 Apple 开发签名配置。仓库不包含个人证书、私钥、Team ID 或描述文件。

### 使用 Windows 与云端构建

无需拥有本地 Mac：可使用 GitHub Actions 的 macOS runner 编译，再由 Windows 侧载工具在本地签名安装。

1. Fork 本仓库，在自己的仓库中启用 Actions。
2. 手动运行 **Build iPhone and iPad IPA** 工作流。
3. 等待成功，下载 `SUSTech-iPhone-iPad-数字` 构建产物。
4. 解压后找到 `SUSTechMobile-unsigned.ipa`，核对同目录的 SHA-256 校验文件。
5. 使用适用的侧载工具，以自己的 Apple 账号在本地重新签名并安装。

IPA 是 **arm64 真机未签名包**，不能直接从文件管理器点击安装。GitHub Actions 产物默认保留 7 天，下载通常需要登录 GitHub。工作流手动触发，不使用 Apple 或校园账号凭据。免费 Apple 账号的签名有效期、设备限制与证书限制仍适用；TestFlight 需要另行配置付费开发者计划。

当前不提供 App Store 或 TestFlight 下载。Windows 安装背景及历史排障记录见 [侧载说明](WINDOWS_SIDELOAD.md)；其中本地修补版 iLoader 的路径属于维护者环境，不是公开下载地址或通用安装依赖。

### Windows 上的源码检查

```powershell
python scripts/verify_repository.py
python -m unittest discover -s scripts/tests -v
```

可选 Swift 语法和工程结构检查：

```powershell
uv run --with tree-sitter --with tree-sitter-swift --with openstep-parser python scripts/verify_repository.py --syntax
```

这些检查不能替代 Swift 编译或真机测试。新增源文件或资源后运行 `python scripts/generate_project.py`。


## 源码目录

```text
App/                       SwiftUI 界面、WebKit 会话与应用状态
Sources/CampusCore/        独立 Swift 包：CAS、TIS、BB、模型与解析
Tests/CampusCoreTests/     Swift Testing 与虚构接口样例
Config/Info.plist          应用配置
scripts/                   工程生成、检查、截图与 IPA 打包
Design/Branding/            图标来源及生成资源
docs/                      截图、功能规划、协议证据与验收记录
.github/workflows/ios.yml   手动云端构建工作流
```


维护流程见 [版本交付与本地清理](RELEASE_WORKFLOW.md)。
