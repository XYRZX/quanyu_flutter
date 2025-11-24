/// 全宇通话助手Flutter SDK
///
/// 该库提供了与全宇通话助手系统的完整集成功能，包括：
/// - 用户认证和登录管理
/// - 实时通话功能（拨打、接听、挂断）
/// - 通话控制（静音、保持、恢复）
/// - 音频设备控制（扬声器开关）
/// - WebSocket实时事件监听
/// - 自定义消息发送
///
/// 支持平台：iOS
library quanyu_sdk;

export 'src/quanyu_sdk_platform_interface.dart';
export 'src/quanyu_sdk_method_channel.dart';

import 'src/quanyu_sdk_platform_interface.dart';

/// 全宇通话助手SDK主类
///
/// 这是SDK的主要入口点，提供了所有通话相关功能的统一接口。
/// 该类采用单例模式，通过平台接口与原生代码进行通信。
class QuanyuSdk {
  /// 获取SDK事件流
  ///
  /// 返回一个Stream，用于监听来自原生层的实时事件，包括：
  /// - 连接状态变化（连接成功、失败、断开）
  /// - 登录状态（成功、失败）
  /// - 通话状态变化（呼入、接通、挂断等）
  /// - 错误信息和异常
  /// - 服务器消息
  ///
  /// 事件数据格式：
  /// ```dart
  /// {
  ///   'type': 'event_type',        // 事件类型
  ///   'message': 'event_message',   // 事件消息
  ///   'data': {...}                 // 附加数据（可选）
  /// }
  /// ```
  Stream<dynamic> get events {
    return QuanyuSdkPlatform.instance.events;
  }

  /// 用户登录
  ///
  /// 使用提供的认证信息连接到全宇通话助手服务器。
  /// 登录成功后，SDK将建立WebSocket连接并自动注册软电话。
  Future<Map<String, dynamic>> login(
      {required String loginUrl,
      required String appKey,
      required String secretKey,
      required String gid,
      required String code,
      required String extPhone,
      bool busy = false,
      bool force = false}) async {
    final result = await QuanyuSdkPlatform.instance.login(
        loginUrl: loginUrl,
        appKey: appKey,
        secretKey: secretKey,
        gid: gid,
        code: code,
        extPhone: extPhone,
        busy: busy,
        force: force);

    // 登录成功后自动注册软电话
    if (result['success'] == true) {
      try {
        // // 延时1秒后注册软电话
        // await Future.delayed(Duration(seconds: 1));
        // await registerSoftPhone();
      } catch (e) {
        // 软电话注册失败不影响登录结果，但可以记录错误
        print('软电话注册失败: $e');
      }
    }

    return result;
  }

  /// 用户登出
  ///
  /// 断开与服务器的连接，清理所有资源。
  /// 登出后需要重新调用login()才能使用其他功能。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.logout();
  /// print('已登出');
  /// ```
  Future<void> logout() {
    return QuanyuSdkPlatform.instance.logout();
  }

  /// 设置扬声器开关
  ///
  /// 控制音频输出设备，在听筒和扬声器之间切换。
  ///
  /// 参数：
  /// - [enabled]: true为开启扬声器，false为关闭（使用听筒）
  ///
  /// 示例：
  /// ```dart
  /// // 开启扬声器
  /// await sdk.setSpeakerOn(enabled: true);
  ///
  /// // 关闭扬声器（使用听筒）
  /// await sdk.setSpeakerOn(enabled: false);
  /// ```
  Future<void> setSpeakerOn({required bool enabled}) {
    return QuanyuSdkPlatform.instance.setSpeakerOn(enabled: enabled);
  }

  /// 获取当前是否开启扬声器（免提）
  ///
  /// 返回值：
  /// - [bool]: true 表示扬声器已开启（免提），false 表示关闭（听筒）
  Future<bool> getSpeakerEnabled() {
    return QuanyuSdkPlatform.instance.getSpeakerEnabled();
  }

  /// 发送自定义消息
  ///
  /// 通过WebSocket向服务器发送自定义消息。
  /// 可用于发送业务相关的数据或控制指令。
  ///
  /// 参数：
  /// - [message]: 要发送的消息内容（通常为JSON字符串）
  ///
  /// 示例：
  /// ```dart
  /// // 发送JSON格式的业务数据
  /// await sdk.sendRequestWithMessage('{
  ///   "type": "customer_info",
  ///   "data": {
  ///     "customer_id": "12345",
  ///     "name": "张三"
  ///   }
  /// }');
  /// ```
  Future<void> sendRequestWithMessage({required String message}) {
    return QuanyuSdkPlatform.instance.sendRequestWithMessage(message: message);
  }

  /// 设置音频输出音量（喇叭音量）
  ///
  /// 控制通话过程中的音频输出音量大小。
  ///
  /// 参数：
  /// - [volume]: 音量值，范围0-1000
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setChannelOutputVolumeScaling(volume: 500);
  /// ```
  Future<void> setChannelOutputVolumeScaling({required int volume}) {
    return QuanyuSdkPlatform.instance
        .setChannelOutputVolumeScaling(volume: volume);
  }

  /// 设置音频输入音量（麦克风音量）
  ///
  /// 控制通话过程中的音频输入音量大小。
  ///
  /// 参数：
  /// - [volume]: 音量值，范围0-1000
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setChannelInputVolumeScaling(volume: 500);
  /// ```
  Future<void> setChannelInputVolumeScaling({required int volume}) {
    return QuanyuSdkPlatform.instance
        .setChannelInputVolumeScaling(volume: volume);
  }

  /// 设置保活状态
  ///
  /// 控制连接保活功能的开启或关闭。
  ///
  /// 参数：
  /// - [enabled]: true为开启保活，false为关闭保活
  ///
  /// 示例：
  /// ```dart
  /// // 开启保活
  /// await sdk.setKeepAlive(enabled: true);
  ///
  /// // 关闭保活
  /// await sdk.setKeepAlive(enabled: false);
  /// ```
  Future<void> setKeepAlive({required bool enabled}) {
    return QuanyuSdkPlatform.instance.setKeepAlive(enabled: enabled);
  }

  /// 注册软电话
  ///
  /// 向服务器注册软电话功能，建立VoIP通话能力。
  /// 通常在登录成功后自动调用，也可以手动调用。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.registerSoftPhone();
  /// print('软电话注册成功');
  /// ```
  Future<void> registerSoftPhone() {
    return QuanyuSdkPlatform.instance.registerSoftPhone();
  }

  /// 重新注册分机
  ///
  /// 重新注册分机功能，先下线再上线，用于解决分机连接问题。
  /// 与registerSoftPhone不同，这是一个重连操作。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.reregisterSoftPhone();
  /// print('分机重新注册成功');
  /// ```
  Future<void> reregisterSoftPhone() {
    return QuanyuSdkPlatform.instance.reregisterSoftPhone();
  }

  /// 设置心跳时间间隔
  ///
  /// 控制心跳包发送的时间间隔。
  ///
  /// 参数：
  /// - [heartbeatInterval]: 心跳间隔时间，单位为秒
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setHeartbeatInterval(heartbeatInterval: 30);
  /// ```
  Future<void> setHeartbeatInterval({required int heartbeatInterval}) {
    return QuanyuSdkPlatform.instance
        .setHeartbeatInterval(heartbeatInterval: heartbeatInterval);
  }

  /// 设置最大重连时间间隔
  ///
  /// 控制连接断开后重连的最大时间间隔。
  ///
  /// 参数：
  /// - [connectionRecoveryMaxInterval]: 最大重连间隔时间，单位为秒
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setConnectionRecoveryMaxInterval(connectionRecoveryMaxInterval: 300);
  /// ```
  Future<void> setConnectionRecoveryMaxInterval(
      {required int connectionRecoveryMaxInterval}) {
    return QuanyuSdkPlatform.instance.setConnectionRecoveryMaxInterval(
        connectionRecoveryMaxInterval: connectionRecoveryMaxInterval);
  }

  /// 设置最小重连时间间隔
  ///
  /// 控制连接断开后重连的最小时间间隔。
  ///
  /// 参数：
  /// - [connectionRecoveryMinInterval]: 最小重连间隔时间，单位为秒
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setConnectionRecoveryMinInterval(connectionRecoveryMinInterval: 5);
  /// ```
  Future<void> setConnectionRecoveryMinInterval(
      {required int connectionRecoveryMinInterval}) {
    return QuanyuSdkPlatform.instance.setConnectionRecoveryMinInterval(
        connectionRecoveryMinInterval: connectionRecoveryMinInterval);
  }

  /// 设置自动接听
  ///
  /// 开启自动接听功能，来电时将自动接听。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.setAutoAnswerCall();
  /// print('自动接听已开启');
  /// ```
  Future<void> setAutoAnswerCall() {
    return QuanyuSdkPlatform.instance.setAutoAnswerCall();
  }

  /// 接听电话
  ///
  /// 手动接听当前来电。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.clientAnswer();
  /// print('电话已接听');
  /// ```
  Future<void> clientAnswer() {
    return QuanyuSdkPlatform.instance.clientAnswer();
  }

  /// 挂断电话
  ///
  /// 挂断当前通话。
  ///
  /// 示例：
  /// ```dart
  /// await sdk.hangup();
  /// print('电话已挂断');
  /// ```
  Future<void> hangup() {
    return QuanyuSdkPlatform.instance.hangup();
  }

  /// 设置日志开关
  ///
  /// 控制SDK的日志输出功能。
  ///
  /// 参数：
  /// - [enabled]: true为开启日志，false为关闭日志
  ///
  /// 示例：
  /// ```dart
  /// // 开启日志
  /// await sdk.setLogEnabled(enabled: true);
  ///
  /// // 关闭日志
  /// await sdk.setLogEnabled(enabled: false);
  /// ```
  Future<void> setLogEnabled({required bool enabled}) {
    return QuanyuSdkPlatform.instance.setLogEnabled(enabled: enabled);
  }

  /// 获取日志开关状态
  ///
  /// 返回当前日志功能是否开启。
  ///
  /// 返回值：
  /// - [bool]: true表示日志已开启，false表示日志已关闭
  ///
  /// 示例：
  /// ```dart
  /// bool isLogEnabled = await sdk.getLogEnabled();
  /// print('日志状态: ${isLogEnabled ? "开启" : "关闭"}');
  /// ```
  Future<bool> getLogEnabled() {
    return QuanyuSdkPlatform.instance.getLogEnabled();
  }
}
