/**
 * 全宇通话助手 Flutter 插件 iOS 头文件
 * 
 * 本文件定义了全宇通话助手Flutter插件在iOS平台的接口
 * 主要功能包括：
 * - 与Flutter框架的集成
 * - QuanYu SDK的封装
 * - WebSocket通信代理
 * - 事件流处理
 * 
 * @author 全宇团队
 * @version 1.0.0
 */

#import <Foundation/Foundation.h>
#import <QuanYu/QuanYu.h>
#import <QuanYu/QuanYuSocket.h>

#import "PortSIPManager.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

// Flutter框架导入 - 兼容不同的Flutter版本和FVM配置
#if __has_include(<Flutter/Flutter.h>)
    #import <Flutter/Flutter.h>
#elif __has_include("Flutter/Flutter.h")
    #import "Flutter/Flutter.h"
#elif __has_include("FlutterPluginRegistrar.h")
    #import "FlutterPluginRegistrar.h"
    #import "FlutterMethodChannel.h"
    #import "FlutterEventChannel.h"
    #import "FlutterError.h"
#else
    // 如果找不到Flutter头文件，使用前向声明
    @protocol FlutterPlugin;
    @protocol FlutterPluginRegistrar;
    @protocol FlutterStreamHandler;
    @class FlutterMethodCall;
    @class FlutterResult;
    @class FlutterEventSink;
    @class FlutterError;
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * 全宇SDK Flutter插件主类
 * 负责处理Flutter与原生iOS代码之间的通信
 */
@interface QuanyuSdkPlugin : NSObject <QuanYuSocketDelegate>

// 如果Flutter协议可用，则遵循这些协议
#if __has_include(<Flutter/Flutter.h>) || __has_include("Flutter/Flutter.h")
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;
#endif

@end

NS_ASSUME_NONNULL_END
