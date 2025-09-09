//
//  QuanyuSdkPlugin.m
//  全宇通话助手Flutter插件 - iOS实现
//
//  该文件实现了Flutter插件的核心功能，包括：
//  - 方法通道处理：处理来自Flutter的方法调用
//  - 事件通道处理：向Flutter发送实时事件
//  - QuanYu SDK集成：调用原生SDK功能
//  - 错误处理和参数验证
//

#import "QuanyuSdkPlugin.h"

#import "AccountManager.h"
#import "NSString+QY.h"

@interface QuanyuSdkPlugin () <FlutterStreamHandler, QuanYuSocketDelegate, PortSIPManagerDelegate>

@property(nonatomic, copy) FlutterEventSink eventSink; // 事件流处理器，用于向Flutter发送实时事件

@property(nonatomic, assign) BOOL isRegisterSoftPhone; // 是否正在注册

@property(nonatomic, strong) NSMutableDictionary *infoDic;

@property(nonatomic, strong) NSMutableArray<NSDictionary *> *eventBuffer; // 事件缓冲队列

@end

@implementation QuanyuSdkPlugin

/**
 * Flutter插件注册方法
 * 在Flutter引擎启动时被调用，用于初始化插件的通信通道
 *
 * @param registrar Flutter插件注册器，提供与Flutter引擎通信的能力
 */
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    // 创建方法通道，用于处理Flutter调用的方法
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"quanyu_sdk"
                                                                binaryMessenger:[registrar messenger]];

    // 创建插件实例
    QuanyuSdkPlugin *instance = [[QuanyuSdkPlugin alloc] init];

    // 注册方法调用处理器
    [registrar addMethodCallDelegate:instance channel:channel];

    // 创建事件通道，用于向Flutter发送实时事件
    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:@"quanyu_sdk_events"
                                                                  binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];

    // 设置QuanYu SDK的代理，接收SDK回调事件
    [QuanYuSocket shared].delegate = instance;

    // 设置PortSIPManager的代理，接收软电话相关回调
    [PortSIPManager shared].delegate = instance;

    // 请求麦克风权限
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio
                             completionHandler:^(BOOL granted) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                 if (granted) {
                                     NSLog(@"麦克风权限已获取");
                                     // 可选：显示成功提示
                                 } else {
                                     NSLog(@"用户拒绝了权限");
                                     // 可选：引导用户去设置页开启
                                 }
                               });
                             }];
}

/**
 * 处理来自Flutter的方法调用
 * 根据方法名分发到对应的处理逻辑
 *
 * @param call Flutter方法调用对象，包含方法名和参数
 * @param result 结果回调，用于向Flutter返回处理结果
 */
- (void)handleMethodCall:(FlutterMethodCall *)call result:(nonnull FlutterResult)result {
    if ([@"login" isEqualToString:call.method]) { // 登录
        [self handleLogin:call result:result];
    } else if ([@"logout" isEqualToString:call.method]) { // 退出登录
        [self handleLogout:call result:result];
    } else if ([@"registerSoftPhone" isEqualToString:call.method]) { // 注册软电话
        [self handleRegisterSoftPhone:call result:result];
    } else if ([@"reregisterSoftPhone" isEqualToString:call.method]) { // 重新注册分机
        [self handleReregisterSoftPhone:call result:result];
    } else if ([@"setChannelOutputVolumeScaling" isEqualToString:call.method]) { // 设置外放声音
        [self handleSetChannelOutputVolumeScaling:call result:result];
    } else if ([@"setChannelInputVolumeScaling" isEqualToString:call.method]) { // 设置麦克风声音
        [self handleSetChannelInputVolumeScaling:call result:result];
    } else if ([@"setKeepAlive" isEqualToString:call.method]) { // 设置常驻
        [self handleSetKeepAlive:call result:result];
    } else if ([@"setSpeakerOn" isEqualToString:call.method]) { // 是否免提
        [self handleSetSpeakerOn:call result:result];
    } else if ([@"getSpeakerEnabled" isEqualToString:call.method]) { // 获取是否免提
        [self handleGetSpeakerEnabled:call result:result];
    } else if ([@"sendRequestWithMessage" isEqualToString:call.method]) { // 发送命令
        [self handleSendRequestWithMessage:call result:result];
    } else if ([@"setHeartbeatInterval" isEqualToString:call.method]) { // 设置心跳间隔
        [self handleSetHeartbeatInterval:call result:result];
    } else if ([@"setConnectionRecoveryMaxInterval" isEqualToString:call.method]) { // 设置连接恢复最大间隔
        [self handleSetConnectionRecoveryMaxInterval:call result:result];
    } else if ([@"setConnectionRecoveryMinInterval" isEqualToString:call.method]) { // 设置连接恢复最小间隔
        [self handleSetConnectionRecoveryMinInterval:call result:result];
    } else if ([@"setAutoAnswerCall" isEqualToString:call.method]) { // 设置自动接听
        [self handleSetAutoAnswerCall:call result:result];
    } else if ([@"clientAnswer" isEqualToString:call.method]) { // 客户端接听
        [self handleClientAnswer:call result:result];
    } else if ([@"hangup" isEqualToString:call.method]) { // 挂断电话
        [self handleHangup:call result:result];
    } else if ([@"setLogEnabled" isEqualToString:call.method]) { // 设置日志开关
        [self handleSetLogEnabled:call result:result];
    } else if ([@"getLogEnabled" isEqualToString:call.method]) { // 获取日志开关状态
        [self handleGetLogEnabled:call result:result];
    } else {
        // 未实现的方法
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - 监听网络
- (void)refreshNotification:(NSNotification *)aNotification {
    NSDictionary *info = [aNotification userInfo];
    if ([[info objectForKey:@"netSatus"] isEqualToString:@"有网"]) {

        // 上线
        NSDictionary *userDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"QuanYu_websocket_user"];

        // 注销之前旧的
        [[PortSIPManager shared] unRegister];

        // 设置PortSIPManager的代理和用户信息
        [PortSIPManager shared].userInfo = userDict;

        // 执行软电话注册
        [[PortSIPManager shared] onLine];

        // 重连
        [[QuanYuSocket shared] reStarConnectServer];
    } else if ([[info objectForKey:@"netSatus"] isEqualToString:@"无网"]){

        [self sendEventToFlutter:@{
            @"event" : @"soft_phone_registration_status",
            @"data" : @{
                @"status" : @"offline",
                @"code" : @(0),
                @"message" : @"软电话离线",
                @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
            }
        }];

        // 下线
        [[PortSIPManager shared] offLine];

        [[PortSIPManager shared] unRegister];
    }
}

#pragma mark - 方法处理器

/**
 * 处理用户登录
 * 从Flutter接收登录参数，初始化WebSocket连接
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleLogin:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 获取登录参数
        NSString *loginUrl = call.arguments[@"loginUrl"];
        NSString *appKey = call.arguments[@"appKey"];
        NSString *secretKey = call.arguments[@"secretKey"];
        NSString *gid = call.arguments[@"gid"];
        NSString *code = call.arguments[@"code"];
        NSString *extPhone = call.arguments[@"extPhone"];

        // 参数验证
        if (!loginUrl || loginUrl.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"登录URL不能为空" details:nil]);
            return;
        }

        if (!appKey || appKey.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"AppKey不能为空" details:nil]);
            return;
        }

        if (!secretKey || secretKey.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"SecretKey不能为空" details:nil]);
            return;
        }

        QuanYuLoginModel *model = [[QuanYuLoginModel alloc] init];
        model.domain = loginUrl;
        model.gid = gid;
        model.code = code;
        model.extPhone = extPhone;
        model.appKey = appKey;
        model.secretKey = secretKey;

        // 先连接WebSocket
        [[QuanYuSocket shared] login:model
                          completion:^(BOOL success, NSString *_Nonnull errorMessage) {
                            if (success) {
                                [[NSNotificationCenter defaultCenter] addObserver:self
                                                                         selector:@selector(refreshNotification:)
                                                                             name:@"internetChange"
                                                                           object:nil];
                                // 登录成功,返回成功信息
                                result(@{@"success" : @YES, @"message" : @"登录成功"});
                            } else {
                                [[NSNotificationCenter defaultCenter] removeObserver:self];
                                // 登录失败,返回失败信息
                                result(@{@"success" : @NO, @"message" : errorMessage});
                                
                                [[QuanYuSocket shared]
                                    saveLog:@"Service-portSip-ECoreErrorNone"
                                    message:[NSString stringWithFormat:@"Service-portSip-ECoreErrorNone"]];
                            }
                          }];

    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"LOGIN_EXCEPTION"
                                   message:[NSString stringWithFormat:@"登录过程中发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理用户登出
 * 断开WebSocket连接并清理资源
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleLogout:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 取消网络监听
        [[NSNotificationCenter defaultCenter] removeObserver:self];

        // 取消自动接听
        [[AccountManager sharedAccountManager] setAutoAnswerCall:NO];

        // 执行登出操作
        [[QuanYuSocket shared] logout];

        // 下线
        [[PortSIPManager shared] offLine];

        // 关闭保活
        [[QuanYuSocket shared] setupKeepAlive:NO];

        // 向Flutter发送登出成功事件
        [self sendEventToFlutter:@{@"event" : @"logout_success", @"data" : @{@"message" : @"登出成功"}}];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"LOGOUT_EXCEPTION"
                                   message:[NSString stringWithFormat:@"登出过程中发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理软电话注册
 * 从本地存储获取用户信息并注册软电话
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleRegisterSoftPhone:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 从本地存储获取用户信息字典
        NSDictionary *userDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"QuanYu_websocket_user"];

        if (!userDict) {
            result([FlutterError errorWithCode:@"NO_USER_INFO" message:@"未找到本地用户信息，请先登录" details:nil]);
            return;
        }

        // 验证必要的软电话信息是否存在
        NSString *extphone = userDict[@"extphone"];
        NSString *extphonePassword = userDict[@"extphonePassword"];
        NSString *sipServerIPPort = userDict[@"sipServerIPPort"];

        if (!extphone || extphone.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_USER_INFO" message:@"分机号码不能为空" details:nil]);
            return;
        }

        if (!extphonePassword || extphonePassword.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_USER_INFO" message:@"分机密码不能为空" details:nil]);
            return;
        }

        if (!sipServerIPPort || sipServerIPPort.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_USER_INFO" message:@"电话服务器IP不能为空" details:nil]);
            return;
        }

        // 注销之前旧的
        [[PortSIPManager shared] unRegister];

        // 设置PortSIPManager的代理和用户信息
        [PortSIPManager shared].userInfo = userDict;

        // 执行软电话注册
        [[PortSIPManager shared] onLine];

        // 向Flutter发送注册开始事件
        [self sendEventToFlutter:@{
            @"event" : @"soft_phone_register_started",
            @"data" : @{@"message" : @"软电话注册已开始", @"extphone" : extphone}
        }];

        result(@{@"success" : @YES, @"message" : @"软电话注册已开始"});

    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"REGISTER_SOFT_PHONE_EXCEPTION"
                                   message:[NSString stringWithFormat:@"注册软电话过程中发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理重新注册分机
 * 先下线再上线，重新建立分机连接
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleReregisterSoftPhone:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {

        // 注销之前旧的
        [[PortSIPManager shared] unRegister];

        // 执行软电话注册
        [[PortSIPManager shared] onLine];

        [[QuanYuSocket shared] reconnectAttempts];

    } @catch (NSException *exception) {
        result([FlutterError
            errorWithCode:@"REREGISTER_SOFT_PHONE_EXCEPTION"
                  message:[NSString stringWithFormat:@"重新注册分机过程中发生异常: %@", exception.reason]
                  details:nil]);
    }
}

/**
 * 处理发送自定义消息
 * 向服务器发送自定义格式的消息
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleSendRequestWithMessage:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        NSString *message = call.arguments[@"message"];

        if (!message || message.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"消息内容不能为空" details:nil]);
            return;
        }

        [[QuanYuSocket shared] sendRequestWithMessage:message];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SEND_MESSAGE_EXCEPTION"
                                   message:[NSString stringWithFormat:@"发送消息过程中发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理扬声器开关设置
 * 设置音频输出设备
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleSetSpeakerOn:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 设置扬声器开关
        BOOL enabled = [call.arguments[@"enabled"] boolValue];

        // 执行
        [[PortSIPManager shared] setSpeakerEnabled:enabled];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_SPEAKER_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置扬声器时发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理音量设置
 * 设置音频输出音量
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleSetChannelOutputVolumeScaling:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 设置音频输出音量（喇叭音量）
        NSNumber *volume = call.arguments[@"volume"];
        if (!volume) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"音量参数不能为空" details:nil]);
            return;
        }

        if ([PortSIPManager shared].activeSessionId != INVALID_SESSION_ID) {

            // 执行
            [[PortSIPManager shared] setVoiceNum:volume.intValue];
        } else {

            result([FlutterError errorWithCode:@"INVALID_PARAMS"
                                       message:@"activeSessionId为空，暂时不能设置喇叭音量"
                                       details:nil]);
        }

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_SPEAKER_VOLUME_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置喇叭音量时发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

- (void)handleSetChannelInputVolumeScaling:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 设置音频输入音量（麦克风音量）
        NSNumber *volume = call.arguments[@"volume"];
        if (!volume) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"音量参数不能为空" details:nil]);
            return;
        }

        if ([PortSIPManager shared].activeSessionId != INVALID_SESSION_ID) {

            // 执行
            [[PortSIPManager shared] setMicrophone:volume.intValue];
        } else {

            result([FlutterError errorWithCode:@"INVALID_PARAMS"
                                       message:@"activeSessionId为空，暂时不能设置麦克风音量"
                                       details:nil]);
        }

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_MICROPHONE_VOLUME_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置麦克风音量时发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理设置保活状态
 * 控制连接保活功能的开启或关闭
 *
 * @param call Flutter方法调用对象
 * @param result 结果回调
 */
- (void)handleSetKeepAlive:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        // 获取保活开关参数
        BOOL enabled = [call.arguments[@"enabled"] boolValue];

        // 调用QuanYu SDK的保活设置方法
        [[QuanYuSocket shared] setupKeepAlive:enabled];

        // 向Flutter发送保活状态变更事件
        [self sendEventToFlutter:@{
            @"event" : @"keep_alive_changed",
            @"data" : @{@"enabled" : @(enabled), @"message" : enabled ? @"保活已开启" : @"保活已关闭"}
        }];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_KEEP_ALIVE_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置保活状态时发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

#pragma mark - 辅助方法

/**
 * 处理设置心跳间隔
 */
- (void)handleSetHeartbeatInterval:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        NSNumber *heartbeatInterval = call.arguments[@"heartbeatInterval"];

        if (!heartbeatInterval) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"心跳间隔参数不能为空" details:nil]);
            return;
        }

        [QuanYuSocket shared].heartbeatInterval = [heartbeatInterval intValue];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_HEARTBEAT_INTERVAL_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置心跳间隔异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理设置连接恢复最大间隔
 */
- (void)handleSetConnectionRecoveryMaxInterval:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        NSNumber *maxInterval = call.arguments[@"connectionRecoveryMaxInterval"];

        if (!maxInterval) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"连接恢复最大间隔参数不能为空" details:nil]);
            return;
        }

        [QuanYuSocket shared].connectionRecoveryMaxInterval = [maxInterval intValue];
        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_CONNECTION_RECOVERY_MAX_INTERVAL_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置连接恢复最大间隔异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理设置连接恢复最小间隔
 */
- (void)handleSetConnectionRecoveryMinInterval:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        NSNumber *minInterval = call.arguments[@"connectionRecoveryMinInterval"];

        if (!minInterval) {
            result([FlutterError errorWithCode:@"INVALID_PARAMS" message:@"连接恢复最小间隔参数不能为空" details:nil]);
            return;
        }

        [QuanYuSocket shared].connectionRecoveryMinInterval = [minInterval intValue];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_CONNECTION_RECOVERY_MIN_INTERVAL_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置连接恢复最小间隔异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理设置自动接听
 */
- (void)handleSetAutoAnswerCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {

        [[AccountManager sharedAccountManager] setAutoAnswerCall:YES];
        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_AUTO_ANSWER_CALL_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置自动接听异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理客户端接听
 */
- (void)handleClientAnswer:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {

        [[QuanYuSocket shared] saveLog:@"clientAnswer" message:@"软电话接听"];

        [[PortSIPManager shared] answerCall];

    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"CLIENT_ANSWER_EXCEPTION"
                                   message:[NSString stringWithFormat:@"客户端接听异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理挂断电话
 */
- (void)handleHangup:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        [[PortSIPManager shared] hungUpCall];

    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"HANGUP_EXCEPTION"
                                   message:[NSString stringWithFormat:@"挂断电话异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理设置日志开关
 */
- (void)handleSetLogEnabled:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        BOOL enabled = [call.arguments[@"enabled"] boolValue];

        [[QuanYuSocket shared] setLogEnabled:enabled];

        result(nil);
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"SET_LOG_ENABLED_EXCEPTION"
                                   message:[NSString stringWithFormat:@"设置日志开关异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 处理获取日志开关状态
 */
- (void)handleGetLogEnabled:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {

        BOOL enabled = [[QuanYuSocket shared] isLogEnabled];

        result(@(enabled));
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"GET_LOG_ENABLED_EXCEPTION"
                                   message:[NSString stringWithFormat:@"获取日志开关状态异常: %@", exception.reason]
                                   details:nil]);
    }
}

/**
 * 向Flutter发送事件
 * 通过事件通道向Flutter发送实时事件
 *
 * @param eventData 事件数据字典
 */
- (void)sendEventToFlutter:(NSDictionary *)eventData {
    // 统一事件键名为"event"（兼容旧的"type"）
    NSMutableDictionary *normalized = [eventData mutableCopy];
    if (!normalized[@"event"] && normalized[@"type"]) {
        id typeVal = normalized[@"type"];
        if ([typeVal isKindOfClass:[NSString class]]) {
            normalized[@"event"] = typeVal;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventSink) {
            NSLog(@"sendEventToFlutter:%@", normalized);
            self.eventSink([normalized copy]);
        } else {
            if (!self.eventBuffer) {
                self.eventBuffer = [NSMutableArray array];
            }
            // 控制缓冲区最大50条
            if (self.eventBuffer.count >= 50) {
                [self.eventBuffer removeObjectAtIndex:0];
            }
            [self.eventBuffer addObject:[normalized copy]];
        }
    });
}

#pragma mark - QuanYuSocketDelegate 协议实现

/**
 * 接收到WebSocket消息时的回调
 * 将服务器发送的消息转发给Flutter端
 *
 * @param message 接收到的消息内容
 */
- (void)onMessage:(NSString *)message {
    NSLog(@"收到消息[onMessage]: %@", message);
    [[QuanYuSocket shared] saveLog:@"websocket" message:message];

    NSDictionary *dic = [NSString dictionaryWithJsonString:message];

    if ([[dic allKeys] containsObject:@"registerState"]) {
        int code = [[dic objectForKey:@"registerState"] intValue];
        if ([PortSIPManager shared].sipRegistrationStatus == 0 || [PortSIPManager shared].sipRegistrationStatus == 3 ||
            code == 0) {
            // 离线
            [self sendEventToFlutter:@{
                @"event" : @"soft_phone_registration_status",
                @"data" : @{
                    @"status" : @"offline",
                    @"code" : @(code),
                    @"message" : @"软电话离线",
                    @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
                }
            }];

            //        [[QuanYuSocket shared] logout];
            [[QuanYuSocket shared] reStarConnectServer];
        } else {
            // 在线
            [self sendEventToFlutter:@{
                @"event" : @"soft_phone_registration_status",
                @"data" : @{
                    @"status" : @"online",
                    @"code" : @(code),
                    @"message" : @"在线",
                    @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
                }
            }];
        }
    }

    if ([[dic allKeys] containsObject:@"state"]) {

        int code = [[dic objectForKey:@"state"] intValue];

        if (code == 0) {
            [self sendEventToFlutter:@{
                @"event" : @"soft_phone_registration_status",
                @"data" : @{
                    @"status" : @"offline",
                    @"code" : @(code),
                    @"message" : @"未连接",
                    @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
                }
            }];
        } else if (code == 999) {
            [self sendEventToFlutter:@{
                @"event" : @"soft_phone_registration_status",
                @"data" : @{
                    @"status" : @"online",
                    @"code" : @(code),
                    @"message" : @"在线",
                    @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
                }
            }];
        } else if ([[dic allKeys] containsObject:@"opcode"] &&
                   [[dic objectForKey:@"opcode"] isEqualToString:@"S_AgentState"]) {

            NSLog(@"soft_phone_status: %@", dic);
            [self sendEventToFlutter:@{
                @"event" : @"soft_phone_status",
                @"data" : @{
                    @"messageDic" : dic,
                    @"code" : @(code),
                    @"message" : [NSString stringWithFormat:@"%d", code],
                    @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
                }
            }];

            if (code == 11 && [QuanYuSocket shared].hangupToFree == 1) {
                // 执行置闲
                [[QuanYuSocket shared] sendRequestWithMessage:@"{\"opcode\": \"C_SetFree\"}"];
            }
        }
    }
}

/**
 * WebSocket连接中状态回调
 * 通知Flutter端正在建立连接
 *
 * @param attempts 连接尝试次数
 */
- (void)onConnecting:(int)attempts {
    NSLog(@"连接中[onConnecting]: 尝试次数 %d", attempts);

    [[QuanYuSocket shared] saveLog:@"start_re_connect" message:[NSString stringWithFormat:@"开始重连：%d", attempts]];
    [self sendEventToFlutter:@{ @"event" : @"onConnecting", @"data" : @(attempts) }];
}

/**
 * WebSocket连接成功回调
 * 通知Flutter端连接已建立
 */
- (void)onConnected {
    NSLog(@"连接成功[onConnected]");
    [self sendEventToFlutter:@{ @"event" : @"onConnected" }];
}

/**
 * WebSocket连接断开回调
 * 通知Flutter端连接已断开，并提供断开原因
 *
 * @param code 断开状态码
 * @param reason 断开原因描述
 */
- (void)onDisconnectedWithCode:(int)code WithReason:(NSString *)reason {
    NSLog(@"连接断开[onDisconnected]: 状态码 %d, 原因: %@", code, reason);

    [[QuanYuSocket shared]
        saveLog:@"OnDisconnect"
        message:[NSString stringWithFormat:@"连接断开[onDisconnected]: 状态码 %d, 原因: %@", code, reason]];

    [self sendEventToFlutter:@{ @"event" : @"onDisconnected", @"data" : @{ @"code" : @(code), @"reason" : reason ?: @"" } }];
}

/**
 * WebSocket连接失败回调
 * 通知Flutter端连接建立失败，并提供失败原因
 *
 * @param code 失败状态码
 * @param reason 失败原因描述
 */
- (void)onConnectFailedWithCode:(int)code WithReason:(NSString *)reason {
    // 对reason参数进行null检查，提供默认值
    NSString *safeReason = reason ?: @"未知错误";

    NSLog(@"WebSocket连接失败回调[onConnectFailed]: 状态码 %d, 原因: %@", code, safeReason);
    
    [[QuanYuSocket shared]
        saveLog:@"disconnect"
        message:[NSString stringWithFormat:@"断开[onConnectFailedWithCode]: 状态码 %d, 原因: %@", code, reason]];
    
    [self sendEventToFlutter:@{ @"event" : @"onConnectFailed", @"data" : @{ @"code" : @(code), @"reason" : safeReason } }];
}

#pragma mark - PortSIPManagerDelegate
// 注册回调
- (void)registerSoftPhoneCallback:(int)code errorMsg:(NSString *)error {
    NSLog(@"registerSoftPhoneCallback:%d errorMsg:%@", code, error);
    NSLog(@"当前sipRegistrationStatus: %d", [PortSIPManager shared].sipRegistrationStatus);

    if ([PortSIPManager shared].sipRegistrationStatus == 2) {
        // 注册成功
        NSLog(@"软电话注册成功，发送事件给Flutter");
        NSDictionary *eventData = @{
            @"event" : @"soft_phone_registration_status",
            @"data" : @{
                @"status" : @"online",
                @"code" : @(code),
                @"message" : @"软电话注册成功",
                @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
            }
        };
        NSLog(@"发送事件数据: %@", eventData);
        [self sendEventToFlutter:eventData];

        self.isRegisterSoftPhone = YES;

        [[QuanYuSocket shared] saveLog:@"RegisterServer" message:@"软电话成功"];

    } else if ([PortSIPManager shared].sipRegistrationStatus == 3) {
        // 注册失败
        NSLog(@"软电话注册失败: %@", error);
        [self sendEventToFlutter:@{
            @"event" : @"soft_phone_registration_status",
            @"data" : @{
                @"status" : @"offline",
                @"code" : @(code),
                @"message" : error ?: @"软电话注册失败",
                @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
            }
        }];

        self.isRegisterSoftPhone = NO;

    } else {
        // 其他状态
        typeof(self) weakSelf = self;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
          [weakSelf sendEventToFlutter:@{
              @"event" : @"soft_phone_registration_status",
              @"data" : @{
                  @"status" : @"offline",
                  @"code" : @(1),
                  @"message" : error ?: @"软电话注册失败",
                  @"sipRegistrationStatus" : @([PortSIPManager shared].sipRegistrationStatus)
              }
          }];

          weakSelf.isRegisterSoftPhone = NO;

          [[QuanYuSocket shared] saveLog:@"Service-portSip-unRegisterServer"
                                 message:[NSString stringWithFormat:@"软电话注册失败 sipRegistrationStatus = %@",
                                                                    @([PortSIPManager shared].sipRegistrationStatus)]];
        });
    }
}

- (void)CallJSWithJSonStr:(nonnull NSString *)JSStr {
    NSLog(@"CallJSWithJSonStr:%@", JSStr);
}

- (void)pushAppLogToWeb:(nonnull NSString *)message info:(nonnull NSString *)info {
    NSLog(@"pushAppLogToWeb:%@ info:%@", message, info);
}

#pragma mark - FlutterStreamHandler 协议实现

/**
 * 开始监听事件流
 * Flutter端开始监听事件时调用，保存事件发送器
 *
 * @param arguments 监听参数（通常为nil）
 * @param events 事件发送器，用于向Flutter发送事件
 * @return 错误信息，成功时返回nil
 */
- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events {
    NSLog(@"Flutter开始监听事件通道");
    self.eventSink = events;

    // 将缓冲的事件依次下发
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventBuffer.count > 0 && self.eventSink) {
            for (NSDictionary *ev in self.eventBuffer) {
                [self sendEventToFlutter:ev];
            }
            [self.eventBuffer removeAllObjects];
        }
    });

    return nil;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
    return [self onCancel:arguments];
}

/**
 * 取消事件流监听
 * Flutter端取消监听事件时调用，清空事件发送器
 *
 * @param arguments 取消参数（通常为nil）
 * @return 错误信息，成功时返回nil
 */
- (FlutterError *_Nullable)onCancel:(id _Nullable)arguments {
    self.eventSink = nil;
    return nil;
}

- (NSMutableDictionary *)infoDic {
    if (!_infoDic) {
        _infoDic = [NSMutableDictionary dictionaryWithCapacity:0];

        [_infoDic setObject:@"离线" forKey:@"0"];
        [_infoDic setObject:@"空闲" forKey:@"1"];
        [_infoDic setObject:@"置忙中" forKey:@"2"];
        [_infoDic setObject:@"抢接" forKey:@"3"];
        [_infoDic setObject:@"选出队列" forKey:@"4"];
        [_infoDic setObject:@"来电振铃" forKey:@"5"];
        [_infoDic setObject:@"通话中" forKey:@"6"];
        [_infoDic setObject:@"转接中" forKey:@"7"];
        [_infoDic setObject:@"等待转移确认" forKey:@"8"];
        [_infoDic setObject:@"保持中" forKey:@"9"];
        [_infoDic setObject:@"会议中" forKey:@"10"];
        [_infoDic setObject:@"话后处理" forKey:@"11"];
        [_infoDic setObject:@"输入被叫号码" forKey:@"12"];
        [_infoDic setObject:@"发起呼叫" forKey:@"13"];
        [_infoDic setObject:@"管理状态" forKey:@"14"];
        [_infoDic setObject:@"监听" forKey:@"15"];
        [_infoDic setObject:@"强插" forKey:@"16"];
        [_infoDic setObject:@"等待电话登录" forKey:@"17"];
        [_infoDic setObject:@"等待脚本Free" forKey:@"18"];
        [_infoDic setObject:@"通话中" forKey:@"19"];
        [_infoDic setObject:@"通话中" forKey:@"20"];
        [_infoDic setObject:@"发起会议邀请" forKey:@"21"];
        [_infoDic setObject:@"会议通话确认" forKey:@"22"];
        [_infoDic setObject:@"会议主持人" forKey:@"23"];
        [_infoDic setObject:@"会议确认通话中" forKey:@"24"];
        [_infoDic setObject:@"会议成员" forKey:@"25"];
        [_infoDic setObject:@"等待pc登录" forKey:@"26"];
        [_infoDic setObject:@"正在呼叫坐席" forKey:@"27"];
        [_infoDic setObject:@"会议中" forKey:@"28"];
        [_infoDic setObject:@"小休" forKey:@"29"];
        [_infoDic setObject:@"静音" forKey:@"30"];
    }
    return _infoDic;
}

/**
 * 获取当前扬声器（免提）状态
 * 返回：true 表示开启，false 表示关闭
 */
- (void)handleGetSpeakerEnabled:(FlutterMethodCall *)call result:(FlutterResult)result {
    @try {
        BOOL enabled = [[PortSIPManager shared] isSpeakerEnabled];
        result(@(enabled));
    } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"GET_SPEAKER_STATE_EXCEPTION"
                                   message:[NSString stringWithFormat:@"获取扬声器状态时发生异常: %@", exception.reason]
                                   details:nil]);
    }
}

@end
