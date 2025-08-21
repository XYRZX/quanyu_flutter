# QuanYu SDK (iOS Only)

QuanYu Flutter 插件（仅支持 iOS）。

重要说明：PortSIPVoIPSDK 不通过公开渠道分发，无法通过 CocoaPods/网络连接方式获取。您需要联系我们的客服获取 PortSIPVoIPSDK.framework，并将其放置到指定目录后再执行构建。

获取和放置 PortSIPVoIPSDK.framework
- 如何获取：请联系 QuanYu 客服，索取 PortSIPVoIPSDK.framework。
- 放置位置（必须）：
  - 将获得的 `PortSIPVoIPSDK.framework` 放入插件目录：
    - `ios/Frameworks/PortSIPVoIPSDK.framework`
  - 目录结构示例：
    - ios/
      - Classes/
      - Frameworks/
        - PortSIPVoIPSDK.framework/
        - QuanYu.xcframework/ (可选，本插件默认通过 CocoaPods 引入 QuanYu 1.0.4；若你手动放置本地 xcframework，也会自动使用本地)
      - quanyu_sdk.podspec

为何必须放置本地框架
- 我们不提供 PortSIPVoIPSDK 的公开 Pod 仓库，也不支持远程拉取。插件的 Podspec 会在 `pod install` 时检查 `ios/Frameworks/PortSIPVoIPSDK.framework` 是否存在，如果不存在将中断安装并提示错误。

iOS 集成要求
- iOS 版本：12.0+
- Podfile：建议启用 `use_frameworks!` 与 `use_modular_headers!`，可参考 example/ios/Podfile。
- 系统依赖：已在 podspec 中声明（Foundation、UIKit、AVFoundation、CoreAudio、AudioToolbox、VideoToolbox、GLKit、MetalKit、Network；以及系统库 c++、resolv）。

安装步骤
1. 在 Flutter 项目中添加依赖
   ```yaml
   dependencies:
     quanyu_sdk: ^0.0.1
   ```
2. 获取 PortSIPVoIPSDK.framework 并放置到插件目录 `ios/Frameworks/` 下（详见上文）。
3. 安装 iOS 依赖
   ```bash
   cd ios
   pod install
   ```
   如缺少 PortSIPVoIPSDK.framework，会在此步报错并提示放置路径。

QuanYu 依赖
- 默认通过 CocoaPods 引入 QuanYu 1.0.4。
- 如果你在 `ios/Frameworks/` 下放置了 `QuanYu.xcframework`，插件会自动优先使用本地框架。

权限与注意事项
- 麦克风权限：请在宿主 App 的 Info.plist 中配置 `NSMicrophoneUsageDescription`。
- 授权信息：如果你在工程内使用 PortSIP 授权 key，请确保不要将敏感密钥提交到公共仓库。建议使用外部配置（例如从 Flutter 传入或从 Info.plist/Secure Storage 读取）。

API 使用
- 入口：lib/quanyu_sdk.dart
- 支持能力：登录、登出、软电话注册/重注册、扬声器开关、输入/输出音量缩放、心跳和连接恢复间隔、自动接听、应答、挂断、日志开关等。

示例工程
- 参考 example/ 目录，iOS 侧 Podfile 已开启 use_frameworks! 和 use_modular_headers!。

问题排查
- pod install 报错 "Missing required framework: PortSIPVoIPSDK.framework"：
  - 请确认已经将 PortSIPVoIPSDK.framework 放置于插件目录 `ios/Frameworks/` 下。
  - 确认目录名与大小写完全一致。
  - 清理后重试：`rm -rf Pods Podfile.lock && pod repo update && pod install`。

反馈与支持
- 请联系 QuanYu 客服获取 PortSIPVoIPSDK.framework 以及进一步技术支持。