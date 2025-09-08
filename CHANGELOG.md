# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [0.0.1] - 2025-01-XX

### Added
- 初始版本发布
- SDK初始化功能
- 获取SDK版本功能
- 设置用户信息功能
- 发送事件功能
- 获取设备ID功能
- iOS平台支持
- 完整的示例应用
- 单元测试覆盖
- 详细的文档说明

### Features
- ✅ iOS 平台支持
- ✅ 方法通道（Method Channel）通信
- ✅ 错误处理和异常捕获
- ✅ 类型安全的API设计
- ✅ 插件平台接口抽象
- ✅ 完整的测试套件

### Technical Details
- Flutter SDK: >=2.17.0 <4.0.0
- iOS最低版本: 9.0
- iOS开发语言: Objective-C

### Documentation
- README.md with comprehensive usage guide
- API documentation
- Integration instructions for iOS native SDK
- Example app with all features demonstrated

### Testing
- Unit tests for all public APIs
- Mock platform implementation for testing
- Example app for manual testing


## [0.0.2] - 2025-08-22

### Changed
- 发布版本 0.0.2：更新包元数据（homepage/repository），完善 README 说明。 
- iOS podspec 强化 PortSIPVoIPSDK.framework 的本地放置策略（移除远程回退）。 
- 改进文档与发布流程说明，确保可以直接从 pub.dev 集成。

## [0.0.4] - 2025-09-02

### Changed
- 同步 iOS Podspec 和 Dart 包版本为 0.0.4，保持一致性。
- 发布前检查通过（flutter pub publish --dry-run 0 warnings）。
- 进一步明确 iOS 端依赖获取方式与本地放置校验（PortSIP 框架）。

## [0.0.5] - 2025-09-08

### Fixed
- 修复 pub.dev 发布失败：同步 Dart 与 iOS Podspec 版本为 0.0.5；确保 .pubignore 排除本地二进制框架与 example 构建产物。

### Chore
- 发布流程：执行 `dart pub publish --dry-run` 验证通过后再发布。