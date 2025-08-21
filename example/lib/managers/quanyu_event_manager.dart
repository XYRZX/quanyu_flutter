import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quanyu_sdk/quanyu_sdk.dart';

/// QuanyuSDK事件管理器
/// 封装事件监听逻辑，提供统一的事件处理接口
class QuanyuEventManager {
  static QuanyuEventManager? _instance;
  StreamSubscription<dynamic>? _eventSubscription;

  // 事件回调函数映射
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  QuanyuEventManager._internal();

  /// 获取单例实例
  static QuanyuEventManager get instance {
    _instance ??= QuanyuEventManager._internal();
    return _instance!;
  }

  /// 开始监听SDK事件
  void startListening() {
    if (_eventSubscription != null) {
      if (kDebugMode) {
        debugPrint('事件监听已经启动');
      }
      return;
    }

    _eventSubscription = QuanyuSdk().events.listen(_handleSdkEvent);
    if (kDebugMode) {
      debugPrint('QuanyuSDK事件监听已启动');
    }
  }

  /// 停止监听SDK事件
  void stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    if (kDebugMode) {
      debugPrint('QuanyuSDK事件监听已停止');
    }
  }

  /// 注册事件处理器
  /// [eventType] 事件类型
  /// [handler] 事件处理函数
  void registerEventHandler(String eventType, Function(dynamic) handler) {
    if (!_eventHandlers.containsKey(eventType)) {
      _eventHandlers[eventType] = [];
    }
    _eventHandlers[eventType]!.add(handler);

    if (kDebugMode) {
      debugPrint('注册事件处理器: $eventType');
    }
  }

  /// 注销事件处理器
  /// [eventType] 事件类型
  /// [handler] 事件处理函数
  void unregisterEventHandler(String eventType, Function(dynamic) handler) {
    if (_eventHandlers.containsKey(eventType)) {
      _eventHandlers[eventType]!.remove(handler);
      if (_eventHandlers[eventType]!.isEmpty) {
        _eventHandlers.remove(eventType);
      }
    }

    if (kDebugMode) {
      debugPrint('注销事件处理器: $eventType');
    }
  }

  /// 注销所有事件处理器
  void unregisterAllEventHandlers() {
    _eventHandlers.clear();
    if (kDebugMode) {
      debugPrint('已注销所有事件处理器');
    }
  }

  /// 处理SDK事件
  void _handleSdkEvent(dynamic event) {
    try {
      if (kDebugMode) {
        debugPrint('QuanyuEventManager收到事件: $event');
      }

      // 类型检查：确保event是Map类型
      if (event == null || event is! Map) {
        if (kDebugMode) {
          debugPrint('收到非Map类型事件，忽略: $event (类型: ${event.runtimeType})');
        }
        return;
      }

      // 确保event可以安全转换为Map<String, dynamic>
      Map<String, dynamic> eventMap;
      try {
        eventMap = Map<String, dynamic>.from(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('事件类型转换失败: $e');
        }
        return;
      }

      // 兼容旧版：如果缺少event字段，则从type字段回落
      if (!eventMap.containsKey('event') && eventMap.containsKey('type')) {
        final dynamic t = eventMap['type'];
        if (t is String && t.isNotEmpty) {
          eventMap['event'] = t;
        }
      }

      // 检查是否包含必要的event字段
      if (!eventMap.containsKey('event')) {
        if (kDebugMode) {
          debugPrint('事件缺少event字段，忽略: $eventMap');
        }
        return;
      }

      final eventType = eventMap['event'];
      if (eventType == null || eventType is! String) {
        if (kDebugMode) {
          debugPrint('事件类型无效，忽略: $eventType');
        }
        return;
      }

      // 分发事件给注册的处理器
      if (_eventHandlers.containsKey(eventType)) {
        for (final handler in _eventHandlers[eventType]!) {
          try {
            handler(eventMap);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('事件处理器执行失败: $e');
            }
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('未找到事件类型 $eventType 的处理器');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('处理事件时发生错误: $e');
        debugPrint('错误堆栈: $stackTrace');
      }
    }
  }

  /// 销毁管理器
  void dispose() {
    stopListening();
    unregisterAllEventHandlers();
    _instance = null;
  }
}
