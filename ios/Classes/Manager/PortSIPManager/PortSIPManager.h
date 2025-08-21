//
//  PortSIPManager.h
//  QuanYuDemo
//
//  Created by 周新 on 2020/2/27.
//  Copyright © 2020 周新. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PortSIPVoIPSDK/PortSIPVoIPSDK.h>

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

@property (nonatomic, assign) long activeSessionId;

@property (nonatomic, assign) int sipRegistrationStatus; // 0 - 未注册 1 - 注册中 2 - 已注册 3 - 注册失败/已注销

@property (nonatomic, strong) NSDictionary *userInfo;//登录用户的信息

@property (nonatomic, weak) id<PortSIPManagerDelegate> delegate;


// 接听电话
- (int)answerCall;

// 上线
- (void)onLine;

// 下线
- (void)offLine;

// 挂起
- (void)hungUpCall;

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
