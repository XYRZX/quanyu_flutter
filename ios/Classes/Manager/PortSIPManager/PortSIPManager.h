//
//  PortSIPManager.h
//  QuanYuDemo
//
//  Created by 周新 on 2020/2/27.
//  Copyright © 2020 周新. All rights reserved.
//

#import <Foundation/Foundation.h>

// 条件导入 PortSIP SDK，如不可用则提供最小兜底声明与常量，保证编译通过
#if __has_include(<PortSIPVoIPSDK/PortSIPVoIPSDK.h>)
#import <PortSIPVoIPSDK/PortSIPVoIPSDK.h>
#else
@class PortSIPSDK;
@protocol PortSIPEventDelegate;

// 兜底日志级别常量
#ifndef PORTSIP_LOG_DEBUG
#define PORTSIP_LOG_DEBUG 2
#endif

// 兜底音视频编解码常量
#ifndef AUDIOCODEC_OPUS
#define AUDIOCODEC_OPUS 0
#endif
#ifndef AUDIOCODEC_G729
#define AUDIOCODEC_G729 1
#endif
#ifndef AUDIOCODEC_PCMA
#define AUDIOCODEC_PCMA 2
#endif
#ifndef AUDIOCODEC_PCMU
#define AUDIOCODEC_PCMU 3
#endif
#ifndef VIDEO_CODEC_H264
#define VIDEO_CODEC_H264 0
#endif

// 会话无效值兜底
#ifndef INVALID_SESSION_ID
#define INVALID_SESSION_ID (-1L)
#endif
#endif

// 条件导入 QuanYuSocket，如不可用则做前向声明，避免类型未识别
#if __has_include(<QuanYu/QuanYuSocket.h>)
#import <QuanYu/QuanYuSocket.h>
#else
@class QuanYuSocket;
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol PortSIPManagerDelegate <NSObject>

// 注册回调
- (void)registerSoftPhoneCallback:(int)code errorMsg:(NSString *)error;

// 打印网页日志
- (void)pushAppLogToWeb:(NSString *)message info:(NSString *)info;

// 调用JS
- (void)CallJSWithJSonStr:(NSString *)JSStr;

@end

@interface PortSIPManager : NSObject

+ (instancetype)shared;

@property(nonatomic, assign) long activeSessionId;

// 标记：坐席连接断开且当前通话未结束时，通话结束后执行软电话注销
@property(nonatomic, assign) BOOL unregisterWhenCallEnds;

@property(nonatomic, assign)
    int sipRegistrationStatus; // 0 - 未注册 1 - 注册中 2 - 已注册 3 -
                               // 注册失败/已注销

@property(nonatomic, strong) NSDictionary *userInfo; // 登录用户的信息

@property(nonatomic, weak) id<PortSIPManagerDelegate> delegate;

// 接听电话
- (int)answerCall;

// 上线
- (void)onLine;

// 下线
- (void)offLine;

// 挂起
- (void)hungUpCall;

// 挂机
- (void)hangUp;

// 喇叭扩音
- (void)setVoiceNum:(int)sender;

// 麦克风扩音
- (void)setMicrophone:(int)sender;

// 刷新注册
- (void)refreshRegister;

// 从SIP代理服务器注销。
- (void)unRegister;

- (void)startKeepAwake;

- (void)stopKeepAwake;

// 免提功能
- (BOOL)setSpeakerEnabled:(BOOL)enabled;
- (BOOL)isSpeakerEnabled;

@end

NS_ASSUME_NONNULL_END
