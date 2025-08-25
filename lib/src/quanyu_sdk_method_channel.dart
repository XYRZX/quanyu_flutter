import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quanyu_sdk_platform_interface.dart';

/// 基于方法通道的全宇通话助手SDK实现
///
/// 这是[QuanyuSdkPlatform]的具体实现，使用Flutter的MethodChannel和EventChannel
/// 与原生平台代码进行通信。该实现负责：
///
/// 1. 通过MethodChannel调用原生方法（登录、拨号、挂断等）
/// 2. 通过EventChannel接收原生事件（连接状态、通话状态等）
/// 3. 数据序列化和反序列化
/// 4. 异常处理和错误传播
///
/// 原生平台实现：
/// - Android: QuanyuSdkPlugin.kt
/// - iOS: 即将支持
class MethodChannelQuanyuSdk extends QuanyuSdkPlatform {
  /// 方法通道实例
  ///
  /// 用于调用原生平台的方法，通道名称为'quanyu_sdk'。
  /// 该通道与原生代码中的QuanyuSdkPlugin类进行通信。
  @visibleForTesting
  final methodChannel = const MethodChannel('quanyu_sdk');

  /// 事件通道实例
  ///
  /// 用于接收来自原生平台的事件流，通道名称为'quanyu_sdk_events'。
  /// 原生代码通过此通道发送连接状态、通话状态等实时事件。
  @visibleForTesting
  // 事件通道实例
  final eventChannel = const EventChannel('quanyu_sdk_events');

  // 获取SDK事件流
  @override
  Stream<dynamic> get events => eventChannel.receiveBroadcastStream();

  /// 用户登录实现【】
  ///
  /// 通过方法通道调用原生平台的登录方法。
  /// 将所有登录参数打包发送给原生代码进行处理。
  ///
  /// 原生方法名：'login'
  /// 参数格式：Map<String, String>
  /// 返回值：Map<String, dynamic> 包含登录结果
  @override
  Future<Map<String, dynamic>> login(
      {required String loginUrl,
      required String appKey,
      required String secretKey,
      required String gid,
      required String code,
      required String extPhone}) async {
    final result = await methodChannel.invokeMethod('login', {
      'loginUrl': loginUrl,
      'appKey': appKey,
      'secretKey': secretKey,
      'gid': gid,
      'code': code,
      'extPhone': extPhone,
    });
    return Map<String, dynamic>.from(result);
  }

  /// 用户登出实现 【】
  ///
  /// 通过方法通道调用原生平台的登出方法。
  /// 原生代码将断开WebSocket连接并清理资源。
  ///
  /// 原生方法名：'logout'
  /// 参数：无
  @override
  Future<void> logout() async {
    await methodChannel.invokeMethod('logout');
  }

  /// 设置扬声器开关实现【】
  ///
  /// 通过方法通道调用原生平台的扬声器控制方法。
  /// 原生代码将切换音频输出设备。
  ///
  /// 原生方法名：'setSpeakerOn'
  /// 参数格式：Map<String, bool>
  @override
  Future<void> setSpeakerOn({required bool enabled}) async {
    await methodChannel.invokeMethod('setSpeakerOn', {'enabled': enabled});
  }

  /// 获取当前是否开启扬声器（免提）【】
  ///
  /// 通过MethodChannel调用原生方法'getSpeakerEnabled'，
  /// 返回当前扬声器状态。
  /// 返回值：bool
  @override
  Future<bool> getSpeakerEnabled() async {
    final result = await methodChannel.invokeMethod('getSpeakerEnabled');
    return result as bool;
  }

  /// 发送自定义消息实现【】
  ///
  /// 通过方法通道调用原生平台的消息发送方法。
  /// 原生代码将通过WebSocket发送消息给服务器。
  ///
  /// 原生方法名：'sendRequestWithMessage'
  /// 参数格式：Map<String, String>
  @override
  Future<void> sendRequestWithMessage({required String message}) async {
    await methodChannel
        .invokeMethod('sendRequestWithMessage', {'message': message});
  }

  /// 设置音频输出音量（喇叭音量）【】
  ///
  /// 通过MethodChannel调用原生方法'setChannelOutputVolumeScaling'，
  /// 控制通话过程中的音频输出音量大小。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'volume': int // 音量值，范围0-1000
  /// }
  /// ```
  @override
  Future<void> setChannelOutputVolumeScaling({required int volume}) async {
    return await methodChannel.invokeMethod('setChannelOutputVolumeScaling', {
      'volume': volume,
    });
  }

  /// 设置音频输入音量（麦克风音量）【】
  ///
  /// 通过MethodChannel调用原生方法'setChannelInputVolumeScaling'，
  /// 控制通话过程中的音频输入音量大小。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'volume': int // 音量值，范围0-1000
  /// }
  /// ```
  @override
  Future<void> setChannelInputVolumeScaling({required int volume}) async {
    return await methodChannel.invokeMethod('setChannelInputVolumeScaling', {
      'volume': volume,
    });
  }

  /// 设置保活状态【】
  ///
  /// 通过MethodChannel调用原生方法'setKeepAlive'，
  /// 控制连接保活功能的开启或关闭。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'enabled': bool // 是否开启保活
  /// }
  /// ```
  @override
  Future<void> setKeepAlive({required bool enabled}) async {
    return await methodChannel.invokeMethod('setKeepAlive', {
      'enabled': enabled,
    });
  }

  /// 注册软电话【】
  ///
  /// 通过MethodChannel调用原生方法'registerSoftPhone'，
  /// 向服务器注册软电话功能，建立VoIP通话能力。
  ///
  /// 原生方法名：'registerSoftPhone'
  /// 参数：无
  @override
  Future<void> registerSoftPhone() async {
    return await methodChannel.invokeMethod('registerSoftPhone');
  }

  /// 重新注册分机【】
  ///
  /// 通过MethodChannel调用原生方法'reregisterSoftPhone'，
  /// 重新注册分机功能，先下线再上线，用于解决分机连接问题。
  ///
  /// 原生方法名：'reregisterSoftPhone'
  /// 参数：无
  @override
  Future<void> reregisterSoftPhone() async {
    return await methodChannel.invokeMethod('reregisterSoftPhone');
  }

  /// 设置心跳时间间隔【】
  ///
  /// 通过MethodChannel调用原生方法'setHeartbeatInterval'，
  /// 控制心跳包发送的时间间隔。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'heartbeatInterval': int // 心跳间隔时间，单位为秒
  /// }
  /// ```
  @override
  Future<void> setHeartbeatInterval({required int heartbeatInterval}) async {
    return await methodChannel.invokeMethod('setHeartbeatInterval', {
      'heartbeatInterval': heartbeatInterval,
    });
  }

  /// 设置最大重连时间间隔【】
  ///
  /// 通过MethodChannel调用原生方法'setConnectionRecoveryMaxInterval'，
  /// 控制连接断开后重连的最大时间间隔。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'connectionRecoveryMaxInterval': int // 最大重连间隔时间，单位为秒
  /// }
  /// ```
  @override
  Future<void> setConnectionRecoveryMaxInterval(
      {required int connectionRecoveryMaxInterval}) async {
    return await methodChannel
        .invokeMethod('setConnectionRecoveryMaxInterval', {
      'connectionRecoveryMaxInterval': connectionRecoveryMaxInterval,
    });
  }

  /// 设置最小重连时间间隔【】
  ///
  /// 通过MethodChannel调用原生方法'setConnectionRecoveryMinInterval'，
  /// 控制连接断开后重连的最小时间间隔。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'connectionRecoveryMinInterval': int // 最小重连间隔时间，单位为秒
  /// }
  /// ```
  @override
  Future<void> setConnectionRecoveryMinInterval(
      {required int connectionRecoveryMinInterval}) async {
    return await methodChannel
        .invokeMethod('setConnectionRecoveryMinInterval', {
      'connectionRecoveryMinInterval': connectionRecoveryMinInterval,
    });
  }

  /// 设置自动接听【】
  ///
  /// 通过MethodChannel调用原生方法'setAutoAnswerCall'，
  /// 开启或关闭自动接听功能。
  ///
  /// 原生方法名：'setAutoAnswerCall'
  /// 参数：无
  @override
  Future<void> setAutoAnswerCall() async {
    return await methodChannel.invokeMethod('setAutoAnswerCall');
  }

  /// 接听电话【】
  ///
  /// 通过MethodChannel调用原生方法'clientAnswer'，
  /// 接听当前来电。
  ///
  /// 原生方法名：'clientAnswer'
  /// 参数：无
  @override
  Future<void> clientAnswer() async {
    return await methodChannel.invokeMethod('clientAnswer');
  }

  /// 挂断电话【】
  ///
  /// 通过MethodChannel调用原生方法'hangup'，
  /// 挂断当前通话。
  ///
  /// 原生方法名：'hangup'
  /// 参数：无
  @override
  Future<void> hangup() async {
    return await methodChannel.invokeMethod('hangup');
  }

  /// 设置日志开关【】
  ///
  /// 通过MethodChannel调用原生方法'setLogEnabled'，
  /// 控制SDK的日志输出功能。
  ///
  /// 参数格式：
  /// ```dart
  /// {
  ///   'enabled': bool // 是否开启日志
  /// }
  /// ```
  @override
  Future<void> setLogEnabled({required bool enabled}) async {
    return await methodChannel.invokeMethod('setLogEnabled', {
      'enabled': enabled,
    });
  }

  /// 获取日志开关状态【】
  ///
  /// 通过MethodChannel调用原生方法'getLogEnabled'，
  /// 返回当前日志功能是否开启。
  ///
  /// 原生方法名：'getLogEnabled'
  /// 参数：无
  /// 返回值：bool
  @override
  Future<bool> getLogEnabled() async {
    final result = await methodChannel.invokeMethod('getLogEnabled');
    return result as bool;
  }
}
