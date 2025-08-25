import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'quanyu_sdk_method_channel.dart';

/// 全宇通话助手SDK平台接口
///
/// 这是所有平台实现必须遵循的抽象接口。不同平台（iOS）的具体实现
/// 都需要继承此类并实现所有抽象方法。
///
/// 平台实现应该继承（extends）此类而不是实现（implements）它，因为
/// QuanyuSdk不认为新增方法是破坏性变更。继承此类可以确保子类获得默认实现，
/// 而实现此接口的平台代码在新增[QuanyuSdkPlatform]方法时会被破坏。
///
/// 支持的平台：
/// - iOS
abstract class QuanyuSdkPlatform extends PlatformInterface {
  /// 构造QuanyuSdkPlatform实例
  QuanyuSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static QuanyuSdkPlatform _instance = MethodChannelQuanyuSdk();

  /// 获取[QuanyuSdkPlatform]的默认实例
  ///
  /// 默认使用[MethodChannelQuanyuSdk]实现
  static QuanyuSdkPlatform get instance => _instance;

  /// 设置平台特定的实例
  ///
  /// 平台特定的实现应该在注册时使用继承[QuanyuSdkPlatform]的
  /// 自己的平台特定类来设置此实例。
  static set instance(QuanyuSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取SDK事件流
  ///
  /// 返回来自原生层的实时事件流，包括连接状态、通话状态、错误信息等。
  /// 子类必须实现此getter以提供平台特定的事件流。
  Stream<dynamic> get events =>
      throw UnimplementedError('events has not been implemented.');

  /// 用户登录【】
  ///
  /// 使用提供的认证信息连接到全宇
  /// 通话助手服务器。
  /// 子类必须实现此方法以提供平台特定的登录逻辑。
  ///
  /// 参数说明请参考[QuanyuSdk.login]方法的文档。
  ///
  /// 返回值：
  /// - [Map<String, dynamic>]: 包含登录结果的映射
  ///   - success: bool 登录是否成功
  ///   - message: String 登录结果消息
  Future<Map<String, dynamic>> login(
      {required String loginUrl,
      required String appKey,
      required String secretKey,
      required String gid,
      required String code,
      required String extPhone}) {
    throw UnimplementedError('login() has not been implemented.');
  }

  /// 用户登出【】
  ///
  /// 断开与服务器的连接，清理所有资源。
  /// 子类必须实现此方法以提供平台特定的登出逻辑。
  Future<void> logout() {
    throw UnimplementedError('logout() has not been implemented.');
  }

  /// 设置扬声器开关【】
  ///
  /// 控制音频输出设备。
  /// 子类必须实现此方法以提供平台特定的扬声器控制逻辑。
  ///
  /// 参数说明请参考[QuanyuSdk.setSpeakerOn]方法的文档。
  Future<void> setSpeakerOn({required bool enabled}) {
    throw UnimplementedError('setSpeakerOn() has not been implemented.');
  }

  /// 获取当前是否开启扬声器（免提）【】
  ///
  /// 返回值：
  /// - [bool]: true 表示扬声器已开启（免提），false 表示关闭（听筒）
  Future<bool> getSpeakerEnabled() {
    throw UnimplementedError('getSpeakerEnabled() has not been implemented.');
  }

  /// 发送自定义消息【】
  ///
  /// 通过WebSocket向服务器发送自定义消息。
  /// 子类必须实现此方法以提供平台特定的消息发送逻辑。
  ///
  /// 参数说明请参考[QuanyuSdk.sendRequestWithMessage]方法的文档。
  Future<void> sendRequestWithMessage({required String message}) {
    throw UnimplementedError(
        'sendRequestWithMessage() has not been implemented.');
  }

  /// 设置音频输出音量（喇叭音量）【】
  ///
  /// 控制通话过程中的音频输出音量大小，即喇叭音量调节。
  /// 子类必须实现此方法以调用原生平台的音量控制功能。
  ///
  /// 参数：
  /// - [volume]: 音量值，范围通常为0-1000
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setChannelOutputVolumeScaling({required int volume}) {
    throw UnimplementedError(
        'setChannelOutputVolumeScaling() has not been implemented.');
  }

  /// 设置音频输入音量（麦克风音量）【】
  ///
  /// 控制通话过程中的音频输入音量大小，即麦克风音量调节。
  /// 子类必须实现此方法以调用原生平台的音量控制功能。
  ///
  /// 参数：
  /// - [volume]: 音量值，范围通常为0-1000
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setChannelInputVolumeScaling({required int volume}) {
    throw UnimplementedError(
        'setChannelInputVolumeScaling() has not been implemented.');
  }

  /// 设置保活状态【】
  ///
  /// 控制连接保活功能的开启或关闭。
  /// 子类必须实现此方法以调用原生平台的保活控制功能。
  ///
  /// 参数：
  /// - [enabled]: true为开启保活，false为关闭保活
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setKeepAlive({required bool enabled}) {
    throw UnimplementedError('setKeepAlive() has not been implemented.');
  }

  /// 注册软电话【】
  ///
  /// 向服务器注册软电话功能，建立VoIP通话能力。
  /// 子类必须实现此方法以调用原生平台的软电话注册功能。
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> registerSoftPhone() {
    throw UnimplementedError('registerSoftPhone() has not been implemented.');
  }

  /// 重新注册分机【】
  ///
  /// 重新注册分机功能，先下线再上线，用于解决分机连接问题。
  /// 子类必须实现此方法以调用原生平台的分机重新注册功能。
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> reregisterSoftPhone() {
    throw UnimplementedError('reregisterSoftPhone() has not been implemented.');
  }

  /// 设置心跳时间间隔【】
  ///
  /// 控制心跳包发送的时间间隔。
  /// 子类必须实现此方法以提供平台特定的心跳间隔设置功能。
  ///
  /// 参数：
  /// - [heartbeatInterval]: 心跳间隔时间，单位为秒
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setHeartbeatInterval({required int heartbeatInterval}) {
    throw UnimplementedError(
        'setHeartbeatInterval() has not been implemented.');
  }

  /// 设置最大重连时间间隔【】
  ///
  /// 控制连接断开后重连的最大时间间隔。
  /// 子类必须实现此方法以提供平台特定的重连间隔设置功能。
  ///
  /// 参数：
  /// - [connectionRecoveryMaxInterval]: 最大重连间隔时间，单位为秒
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setConnectionRecoveryMaxInterval(
      {required int connectionRecoveryMaxInterval}) {
    throw UnimplementedError(
        'setConnectionRecoveryMaxInterval() has not been implemented.');
  }

  /// 设置最小重连时间间隔【】
  ///
  /// 控制连接断开后重连的最小时间间隔。
  /// 子类必须实现此方法以提供平台特定的重连间隔设置功能。
  ///
  /// 参数：
  /// - [connectionRecoveryMinInterval]: 最小重连间隔时间，单位为秒
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setConnectionRecoveryMinInterval(
      {required int connectionRecoveryMinInterval}) {
    throw UnimplementedError(
        'setConnectionRecoveryMinInterval() has not been implemented.');
  }

  /// 设置自动接听【】
  ///
  /// 开启或关闭自动接听功能。
  /// 子类必须实现此方法以提供平台特定的自动接听控制功能。
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setAutoAnswerCall() {
    throw UnimplementedError('setAutoAnswerCall() has not been implemented.');
  }

  /// 接听电话【】
  ///
  /// 接听当前来电。
  /// 子类必须实现此方法以提供平台特定的接听电话功能。
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> clientAnswer() {
    throw UnimplementedError('clientAnswer() has not been implemented.');
  }

  /// 挂断电话【】
  ///
  /// 挂断当前通话。
  /// 子类必须实现此方法以提供平台特定的挂断电话功能。
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> hangup() {
    throw UnimplementedError('hangup() has not been implemented.');
  }

  /// 设置日志开关【】
  ///
  /// 控制SDK的日志输出功能。
  /// 子类必须实现此方法以提供平台特定的日志控制功能。
  ///
  /// 参数：
  /// - [enabled]: true为开启日志，false为关闭日志
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<void> setLogEnabled({required bool enabled}) {
    throw UnimplementedError('setLogEnabled() has not been implemented.');
  }

  /// 获取日志开关状态【】
  ///
  /// 返回当前日志功能是否开启。
  /// 子类必须实现此方法以提供平台特定的日志状态查询功能。
  ///
  /// 返回值：
  /// - [bool]: true表示日志已开启，false表示日志已关闭
  ///
  /// 抛出异常：
  /// - [UnimplementedError]: 当子类未实现此方法时
  Future<bool> getLogEnabled() {
    throw UnimplementedError('getLogEnabled() has not been implemented.');
  }
}
