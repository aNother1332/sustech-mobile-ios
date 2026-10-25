# 系统分享打印验证包

普通包 SUSTechMobile-unsigned.ipa 排除分享扩展；优先用它验证主要功能。

SUSTechMobile-with-share-unsigned.ipa 包含 PlugIns/CampusPrintShare.appex。重新签名时需同时正确处理主 App 和扩展，以及下列共享容器授权：

- 主 App：cn.sustech.community.daily
- 分享扩展：cn.sustech.community.daily.printshare
- 双方相同的 App Group：group.cn.sustech.community.daily
- 预期 entitlement：com.apple.security.application-groups，值为包含上述 group 的数组，附 SHARE-AppGroups.entitlements。

无签名构建不提供 Apple 授权或 provisioning profile；现有 iLoader 是否能为本人账号注册/重写并签发这一共享容器未验证。不得以手工加入字符串代替有效的 Apple 授权。签名工具若重写 Bundle ID/Group ID，须与两个组件实际运行时使用的容器标识一致。

没有容器时扩展会给出说明，主 App 保留直接导入 PDF。不要为了测试共享容器反复申请或撤销证书。

设备验收：从“文件”选择一个 50 MB 以内 PDF → 分享 → 校园打印 → 收件成功 → 打开主 App 的“校园打印/系统分享待打印” → 选择文件 → 本人核对参数后提交。扩展只接收文件，不自动打印、不自动上传，不使用未公开方式唤起主 App。iPhone/iPad、未授权容器、无效/过大/多个文件均需核对。本轮仅编译，未在用户设备签名验收。
