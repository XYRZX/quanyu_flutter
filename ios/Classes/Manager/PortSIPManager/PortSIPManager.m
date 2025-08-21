//
//  PortSIPManager.m
//  QuanYuDemo
//
//  Created by 周新 on 2020/2/27.
//  Copyright © 2020 周新. All rights reserved.
//

#import "PortSIPManager.h"
#import "AccountManager.h"
#import "NSString+QY.h"
#import "SoundService.h"

#import <QuanYu/QuanYu.h>
#import <QuanYu/QuanYuSocket.h>

#define MAX_LINES 8

@interface PortSIPManager () <PortSIPEventDelegate> {
    long _lineSessions[MAX_LINES];
}

@property(nonatomic, strong) PortSIPSDK *portSIPSDK;

@property(nonatomic, assign) BOOL sipInitialized; // 当前电话是否已经注册  - 默认NO

@property(nonatomic, strong) NSString *sipURL;

@property(nonatomic, strong) SoundService *mSoundService;

@property(nonatomic, strong) NSTimer *autoRegisterTimer;
@property(nonatomic, assign) int autoRegisterRetryTimes;

@end

@implementation PortSIPManager

+ (instancetype)shared {
    static PortSIPManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
        _portSIPSDK = [[PortSIPSDK alloc] init];
        _portSIPSDK.delegate = self;
        
        [_portSIPSDK setPresenceStatus:666 statusText:@"在线"];
        
        _sipRegistrationStatus = 0;
        _autoRegisterRetryTimes = 0;
        
        for (int i = 0; i < MAX_LINES; i++) {
            _lineSessions[i] = INVALID_SESSION_ID;
        }
        
        _activeSessionId = INVALID_SESSION_ID;
        
        _mSoundService = [[SoundService alloc] init];
    }
    return self;
}

#pragma mark - 方法

// 接听电话
- (int)answerCall {
    if (_activeSessionId != INVALID_SESSION_ID) {
        int i = [_portSIPSDK answerCall:_activeSessionId videoCall:NO];
        return i == 0 ? 0 : 1;
    } else {
        return 1;
    }
}

// 上线
- (void)onLine {
    
    [[QuanYuSocket shared] saveLog:@"selfPhone" message:@"注册软电话"];
    
    if (!_userInfo) {
        NSLog(@"没有用户数据");
        return;
    }
    
    if (_sipInitialized) {
        [self offLine];
    }
    
    NSString *authName = [_userInfo objectForKey:@"name"];
    NSString *userName = [_userInfo objectForKey:@"extphone"];
    NSString *password = [_userInfo objectForKey:@"extphonePassword"];
    NSString *SIPServer = [_userInfo objectForKey:@"sipServerIPPort"];
    
    // 解析 IP 和端口
    NSArray *components = [SIPServer componentsSeparatedByString:@":"];
    NSString *userDomain;
    int mSIPServerPort;
    
    if (components.count >= 2) {
        userDomain = components[0];                // IP 地址部分
        mSIPServerPort = [components[1] intValue]; // 端口部分
    } else {
        // 如果格式不正确，使用原来的逻辑作为备用
        userDomain = [_userInfo objectForKey:@"ip"];
        mSIPServerPort = [[_userInfo objectForKey:@"port"] intValue];
    }
    
    if ([userName length] < 1) {
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate registerSoftPhoneCallback:1 errorMsg:@"Please enter user name!"];
        }
        return;
    }
    
    if ([password length] < 1) {
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate registerSoftPhoneCallback:1 errorMsg:@"Please enter password!"];
        }
        return;
    }
    
    if ([SIPServer length] < 1) {
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate registerSoftPhoneCallback:1 errorMsg:@"Please enter SIP Server!"];
        }
        return;
    }
    
    TRANSPORT_TYPE transport = TRANSPORT_UDP;
    SRTP_POLICY srtp = SRTP_POLICY_NONE;
    
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings setObject:authName forKey:@"kAuthName"];
    [settings setObject:userName forKey:@"kUserName"];
    [settings setObject:password forKey:@"kPassword"];
    [settings setObject:SIPServer forKey:@"kSIPServer"];
    [settings setInteger:transport forKey:@"kTRANSPORT"];
    [settings setObject:userDomain forKey:@"kUserDomain"];
    [settings setObject:[NSString stringWithFormat:@"%d",mSIPServerPort] forKey:@"kSIPServerPort"];
    
    int localSIPPort = 5060 + arc4random() % 60000; // 本地端口范围5k-7k
    NSString *loaclIPaddress = @"0.0.0.0";         // 自动选择IP地址
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    int ret = [_portSIPSDK initialize:transport localIP:loaclIPaddress localSIPPort:localSIPPort loglevel:PORTSIP_LOG_DEBUG logPath:documentsDirectory maxLine:8 agent:@"PortSIP SDK for IOS" audioDeviceLayer:0 videoDeviceLayer:0 TLSCertificatesRootPath:@"" TLSCipherList:@"" verifyTLSCertificate:NO];
    
    if (ret != 0) {
        NSLog(@"initialize failure ErrorCode = %d", ret);
        
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate registerSoftPhoneCallback:1
                                            errorMsg:[NSString stringWithFormat:@"initialize failure "
                                                      @"ErrorCode = %d",
                                                      ret]];
        }
        
        return;
    }
    
    // 固定端口
    int randomOutboundPort = 5060;
    
    ret = [_portSIPSDK setUser:userName
                   displayName:@""
                      authName:@""
                      password:password
                    userDomain:@""
                     SIPServer:userDomain
                 SIPServerPort:mSIPServerPort
                    STUNServer:@""
                STUNServerPort:0
                outboundServer:@""
            outboundServerPort:randomOutboundPort];
    
    if (ret != 0) {
        NSLog(@"setUser failure ErrorCode = %d", ret);
        
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate
             registerSoftPhoneCallback:1
             errorMsg:[NSString stringWithFormat:@"setUser failure ErrorCode = %d", ret]];
        }
        
        return;
    }
    
    // PORTSIP_TEST_LICENSE
    int rt = [_portSIPSDK
              setLicenseKey:@"1iOS3h05MjdEOUU4NkRBMTdCOTk5QTE1QTg0NzkwRUNGNDJCREA0NzdCMzlDQzVDNDJFNzFFMDUyRUYwNkEwNkZEMUE1MUB"
              @"EM0RENEZGNkM1RDVFOTBFMDM3RjBFQTc1MTI3NTJGMEA0NkFGMjdCQjdDREEzNTREMTM3MEQ0RjczNUM3OTkxOQ"];
    
    if (rt != 0) {
        if ([self.delegate respondsToSelector:@selector(pushAppLogToWeb:info:)]) {
            [self.delegate pushAppLogToWeb:@"错误" info:[NSString stringWithFormat:@"本机授权失败 ErrorCode = %d", rt]];
        }
        
        NSLog(@"本机授权失败");
        return;
    }
    
    [_portSIPSDK addAudioCodec:AUDIOCODEC_OPUS];
    [_portSIPSDK addAudioCodec:AUDIOCODEC_G729];
    [_portSIPSDK addAudioCodec:AUDIOCODEC_PCMA];
    [_portSIPSDK addAudioCodec:AUDIOCODEC_PCMU];
    
    [_portSIPSDK addVideoCodec:VIDEO_CODEC_H264];
    
    [_portSIPSDK setVideoBitrate:-1 bitrateKbps:500]; // Default video send bitrate,500kbps
    [_portSIPSDK setVideoFrameRate:-1 frameRate:10];  // Default video frame rate,10
    [_portSIPSDK setVideoResolution:352 height:288];
    [_portSIPSDK setAudioSamples:20 maxPtime:60]; // ptime 20
    
    [_portSIPSDK setInstanceId:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    
    // 0、后置相机  1、前置相机
    [_portSIPSDK setVideoDeviceId:1];
    
    // 启用/禁用NACK功能(RFC4585)以帮助提高视频质量。
    [_portSIPSDK setVideoNackStatus:YES];
    
    // 设置SRTP策略
    [_portSIPSDK setSrtpPolicy:srtp];
    
    // 尝试注册默认身份
    // 注册刷新间隔为90秒
    ret = [_portSIPSDK registerServer:90 retryTimes:0];
    if (ret != 0) {
        [[QuanYuSocket shared] saveLog:@"unRegisterServer" message:[NSString stringWithFormat:@"注销软电话 ErrorCode = %d", ret]];
        [_portSIPSDK unInitialize];
        NSLog(@"registerServer failure ErrorCode = %d", ret);
        
        if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
            [self.delegate
             registerSoftPhoneCallback:1
             errorMsg:[NSString stringWithFormat:@"registerServer failure ErrorCode = %d", ret]];
        }
        
        return;
    }
    
    if (transport == TRANSPORT_TCP || transport == TRANSPORT_TLS) {
        [_portSIPSDK setKeepAliveTime:0];
    }
    
    if (mSIPServerPort == 5060) {
        _sipURL = [[NSString alloc] initWithFormat:@"sip:%@:%@", userName, userDomain];
    } else {
        _sipURL = [[NSString alloc] initWithFormat:@"sip:%@:%@:%d", userName, userDomain, mSIPServerPort];
    }
    
    _sipInitialized = YES;
    _sipRegistrationStatus = 1;
    
    if ([self.delegate respondsToSelector:@selector(pushAppLogToWeb:info:)]) {
        [self.delegate pushAppLogToWeb:@"register" info:@"正在连接软电话"];
    }
}

// 下线
- (void)offLine {
    
    if (_sipInitialized) {
        [[QuanYuSocket shared] saveLog:@"unRegisterServer" message:@"注销软电话"];
        
        [NSThread sleepForTimeInterval:1.0];
        
        [_portSIPSDK unInitialize];
        _sipInitialized = NO;
    }
    
    _sipRegistrationStatus = 0;
}

// 挂起
- (void)hungUpCall {
    if (_activeSessionId != INVALID_SESSION_ID) {
        [_mSoundService stopRingTone];
        [_mSoundService stopRingBackTone];
    }
}

// 喇叭扩音
- (void)setVoiceNum:(int)sender {
    [[AccountManager sharedAccountManager] setVoiceNum:sender];
    [_portSIPSDK setChannelOutputVolumeScaling:_activeSessionId scaling:sender];
}

// 麦克风扩音
- (void)setMicrophone:(int)sender {
    [[AccountManager sharedAccountManager] setMicrophone:sender];
    [_portSIPSDK setChannelInputVolumeScaling:_activeSessionId scaling:sender];
}

// 刷新注册
- (void)refreshRegister {
    
    if (_sipRegistrationStatus == 0) { // 0 - 未注册
        
    } else if (_sipRegistrationStatus == 1) { // 1 - 注册中
        
    } else if (_sipRegistrationStatus == 2) { // 2 - 已注册
        
        [_portSIPSDK refreshRegistration:0];
        
        if ([self.delegate respondsToSelector:@selector(pushAppLogToWeb:info:)]) {
            [self.delegate pushAppLogToWeb:@"Refresh" info:@"Refresh Registration..."];
        }
    } else if (_sipRegistrationStatus == 3) { // 3 - 注册失败/已注销
        
        if ([self.delegate respondsToSelector:@selector(pushAppLogToWeb:info:)]) {
            [self.delegate pushAppLogToWeb:@"Refresh" info:@"retry a new register"];
        }
        
        [[QuanYuSocket shared] saveLog:@"unRegisterServer" message:@"注销软电话"];
        [_portSIPSDK unInitialize];
        
        _sipInitialized = NO;
    }
}

// 从SIP代理服务器注销。
- (void)unRegister {
    if (_sipRegistrationStatus == 1 || _sipRegistrationStatus == 2) {
        
        if ([self.delegate respondsToSelector:@selector(pushAppLogToWeb:info:)]) {
            [self.delegate pushAppLogToWeb:@"unRegister" info:@"unRegister when background"];
        }
        
        [[QuanYuSocket shared] saveLog:@"unRegisterServer" message:@"注销软电话"];
        [_portSIPSDK unInitialize];
        
        _sipRegistrationStatus = 3;
    }
}

#pragma mark - 私有方法
- (int)findIdleLine {
    for (int i = 0; i < MAX_LINES; i++) {
        if (_lineSessions[i] == INVALID_SESSION_ID) {
            return i;
        }
    }
    NSLog(@"No idle line available. All lines are in use.");
    return -1;
};

- (int)findSession:(long)sessionId {
    for (int i = 0; i < MAX_LINES; i++) {
        if (_lineSessions[i] == sessionId) {
            return i;
        }
    }
    NSLog(@"Can't find session, Not exist this SessionId = %ld", sessionId);
    return -1;
};

- (void)freeLine:(long)sessionId {
    for (int i = 0; i < MAX_LINES; i++) {
        if (_lineSessions[i] == sessionId) {
            _lineSessions[i] = INVALID_SESSION_ID;
            return;
        }
    }
    NSLog(@"Can't Free Line, Not exist this SessionId = %ld", sessionId);
};

- (void)startKeepAwake {
    [_portSIPSDK startKeepAwake];
}

- (void)stopKeepAwake {
    [_portSIPSDK stopKeepAwake];
}

#pragma mark - 免提功能

// 设置免提开启/关闭
- (BOOL)setSpeakerEnabled:(BOOL)enabled {
    
    [[QuanYuSocket shared] saveLog:@"setAudioDevice" message:enabled ? @"YES" : @"NO"];
    return [_mSoundService speakerEnabled:enabled];
}

// 获取当前免提状态
- (BOOL)isSpeakerEnabled {
    return [_mSoundService isSpeakerEnabled];
}



#pragma mark - PortSIPEventDelegate

// 注册成功
- (void)onRegisterSuccess:(char*)statusText statusCode:(int)statusCode sipMessage:(char*)sipMessage{
    
    _sipRegistrationStatus = 2;
    _autoRegisterRetryTimes = 0;
    
    if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
        [self.delegate registerSoftPhoneCallback:0 errorMsg:@"注册软电话成功"];
    }
}

// 注册失败
- (void)onRegisterFailure:(char*)statusText statusCode:(int)statusCode sipMessage:(char*)sipMessage{
    
    _sipRegistrationStatus = 3;
    
    if ([self.delegate respondsToSelector:@selector(registerSoftPhoneCallback:errorMsg:)]) {
        [self.delegate registerSoftPhoneCallback:statusCode errorMsg:[NSString stringWithFormat:@"onRegisterFailure:%d %s", statusCode, statusText]];
    }
    
    if (statusCode != 401 && statusCode != 403 && statusCode != 404) {
        
        int interval = _autoRegisterRetryTimes * 2 + 1;
        
        interval = interval > 60 ? 60 : interval;
        ++_autoRegisterRetryTimes;
        _autoRegisterTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                              target:self
                                                            selector:@selector(refreshRegister)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)onInviteAnswered:(long)sessionId callerDisplayName:(char *)callerDisplayName caller:(char *)caller calleeDisplayName:(char *)calleeDisplayName callee:(char *)callee audioCodecs:(char *)audioCodecs videoCodecs:(char *)videoCodecs existsAudio:(BOOL)existsAudio existsVideo:(BOOL)existsVideo sipMessage:(char *)sipMessage {
    
    [_mSoundService stopRingTone];
    [_mSoundService stopRingBackTone];
}

- (void)onInviteClosed:(long)sessionId {
    [[AccountManager sharedAccountManager] setAutoAnswerCall:NO];
    
    NSString *jsString = [NSString stringWithFormat:@"onInviteClosed('{\"sessionId\":\"%ld\"}')", sessionId];
    if ([self.delegate respondsToSelector:@selector(CallJSWithJSonStr:)]) {
        [self.delegate CallJSWithJSonStr:jsString];
    }
}

- (void)onInviteConnected:(long)sessionId {
    if ([[AccountManager sharedAccountManager] OutVoice]) {
        [_portSIPSDK setLoudspeakerStatus:YES];
    } else {
        [_portSIPSDK setLoudspeakerStatus:NO];
    }
}

- (void)onInviteIncoming:(long)sessionId callerDisplayName:(char *)callerDisplayName caller:(char *)caller calleeDisplayName:(char *)calleeDisplayName callee:(char *)callee audioCodecs:(char *)audioCodecs videoCodecs:(char *)videoCodecs existsAudio:(BOOL)existsAudio existsVideo:(BOOL)existsVideo sipMessage:(char *)sipMessage {
    
    int index = [self findIdleLine];
    if (index < 0) {
        [_portSIPSDK rejectCall:sessionId code:486];
        return;
    }
    
    _activeSessionId = sessionId;
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:0];
    [dic setObject:[NSNumber numberWithLong:sessionId] forKey:@"sessionId"];
    [dic setObject:[NSString stringWithFormat:@"%s",callerDisplayName] forKey:@"callerDisplayName"];
    [dic setObject:[NSString stringWithFormat:@"%s",caller] forKey:@"caller"];
    [dic setObject:[NSString stringWithFormat:@"%s",calleeDisplayName] forKey:@"calleeDisplayName"];
    [dic setObject:[NSString stringWithFormat:@"%s",callee] forKey:@"callee"];
    [dic setObject:[NSString stringWithFormat:@"%s",audioCodecs] forKey:@"audioCodecs"];
    [dic setObject:[NSString stringWithFormat:@"%s",videoCodecs] forKey:@"videoCodecs"];
    [dic setObject:[NSString stringWithFormat:@"%s",sipMessage] forKey:@"sipMessage"];
    [dic setObject:[NSNumber numberWithBool:existsAudio] forKey:@"existsAudio"];
    [dic setObject:[NSNumber numberWithBool:existsVideo] forKey:@"existsVideo"];
    
    NSString *jsonStr = [NSString convertToJsonData:dic];
    NSString *jsString = [NSString stringWithFormat:@"onInviteIncoming('%@')", jsonStr];
    
    [[QuanYuSocket shared] saveLog:@"onReceivedSignaling" message:jsString];
    
    if ([self.delegate respondsToSelector:@selector(CallJSWithJSonStr:)]) {
        [self.delegate CallJSWithJSonStr:jsString];
    }
    
    [self setVoiceNum:[[AccountManager sharedAccountManager] VoiceNum]];
    [self setMicrophone:[[AccountManager sharedAccountManager] Microphone]];
    
    // 判断自动接听
    if ([[AccountManager sharedAccountManager] AutoAnswerCall]) {
        [_portSIPSDK answerCall:sessionId videoCall:existsVideo];
        return;
    }
    
    _lineSessions[index] = sessionId;
}

- (void)onRecvOutOfDialogMessage:(char *)fromDisplayName from:(char *)from toDisplayName:(char *)toDisplayName to:(char *)to mimeType:(char *)mimeType subMimeType:(char *)subMimeType messageData:(unsigned char *)messageData messageDataLength:(int)messageDataLength sipMessage:(char *)sipMessage {

    if (strcasecmp(mimeType, "text") == 0 && strcasecmp(subMimeType, "plain") == 0) {
        NSString *recvMessage = nil;
        if (messageData && messageDataLength > 0) {
            recvMessage = [[NSString alloc] initWithBytes:messageData
                                                   length:messageDataLength
                                                 encoding:NSUTF8StringEncoding];
        }
        NSLog(@"收到消息: %@", recvMessage ? recvMessage : @"(空消息)");
    } else if (strcasecmp(mimeType, "application") == 0 && strcasecmp(subMimeType, "vnd.3gpp.sms") == 0) {
        // messageData 是二进制数据
    } else if (strcasecmp(mimeType, "application") == 0 && strcasecmp(subMimeType, "vnd.3gpp2.sms") == 0) {
        // messageData 是二进制数据
    }
}


- (void)onRecvMessage:(long)sessionId mimeType:(char *)mimeType subMimeType:(char *)subMimeType messageData:(unsigned char *)messageData messageDataLength:(int)messageDataLength {

    int index = [self findSession:sessionId];
    if (index == -1) {
        return;
    }

    if (strcmp(mimeType, "text") == 0 && strcmp(subMimeType, "plain") == 0) {
        NSString *recvMessage = nil;
        if (messageData && messageDataLength > 0) {
            recvMessage = [[NSString alloc] initWithBytes:messageData
                                                   length:messageDataLength
                                                 encoding:NSUTF8StringEncoding];
        }
        NSLog(@"收到文本消息: %@", recvMessage ? recvMessage : @"(空消息)");
    }  else if (strcmp(mimeType, "application") == 0 && strcmp(subMimeType, "vnd.3gpp.sms") == 0) {
        // The messageData is binary data
    } else if (strcmp(mimeType, "application") == 0 && strcmp(subMimeType, "vnd.3gpp2.sms") == 0) {
        // The messageData is binary data
    }
}

- (void)onACTVTransferFailure:(long)sessionId reason:(char *)reason code:(int)code { 
    NSLog(@"onACTVTransferFailure: sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code);
    [[QuanYuSocket shared] saveLog:@"onACTVTransferFailure" message:[NSString stringWithFormat:@"sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code]];
}


- (void)onACTVTransferSuccess:(long)sessionId { 
    NSLog(@"onACTVTransferSuccess: sessionId=%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onACTVTransferSuccess" message:[NSString stringWithFormat:@"sessionId=%ld", sessionId]];
}


- (void)onAudioRawCallback:(long)sessionId audioCallbackMode:(int)audioCallbackMode data:(unsigned char *)data dataLength:(int)dataLength samplingFreqHz:(int)samplingFreqHz { 
    NSLog(@"onAudioRawCallback: sessionId=%ld, mode=%d, dataLength=%d, samplingFreq=%d", sessionId, audioCallbackMode, dataLength, samplingFreqHz);
    [[QuanYuSocket shared] saveLog:@"onAudioRawCallback" message:[NSString stringWithFormat:@"sessionId=%ld, mode=%d, dataLength=%d, samplingFreq=%d", sessionId, audioCallbackMode, dataLength, samplingFreqHz]];
}


- (void)onDialogStateUpdated:(char *)BLFMonitoredUri BLFDialogState:(char *)BLFDialogState BLFDialogId:(char *)BLFDialogId BLFDialogDirection:(char *)BLFDialogDirection { 
    NSLog(@"onDialogStateUpdated: Uri=%s, State=%s, Id=%s, Direction=%s", 
          BLFMonitoredUri ? BLFMonitoredUri : "null", 
          BLFDialogState ? BLFDialogState : "null", 
          BLFDialogId ? BLFDialogId : "null", 
          BLFDialogDirection ? BLFDialogDirection : "null");
    [[QuanYuSocket shared] saveLog:@"onDialogStateUpdated" message:[NSString stringWithFormat:@"Uri=%s, State=%s, Id=%s, Direction=%s", 
                                                                     BLFMonitoredUri ? BLFMonitoredUri : "null", 
                                                                     BLFDialogState ? BLFDialogState : "null", 
                                                                     BLFDialogId ? BLFDialogId : "null", 
                                                                     BLFDialogDirection ? BLFDialogDirection : "null"]];
}


- (void)onInviteBeginingForward:(char *)forwardTo { 
    NSLog(@"onInviteBeginingForward: forwardTo=%s", forwardTo ? forwardTo : "null");
    [[QuanYuSocket shared] saveLog:@"onInviteBeginingForward" message:[NSString stringWithFormat:@"forwardTo=%s", forwardTo ? forwardTo : "null"]];
}


- (void)onInviteFailure:(long)sessionId reason:(char *)reason code:(int)code sipMessage:(char *)sipMessage { 
    NSLog(@"onInviteFailure: sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code);
    [[QuanYuSocket shared] saveLog:@"onInviteFailure" message:[NSString stringWithFormat:@"sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code]];
}


- (void)onInviteRinging:(long)sessionId statusText:(char *)statusText statusCode:(int)statusCode sipMessage:(char *)sipMessage { 
    NSLog(@"onInviteRinging: sessionId=%ld, statusText=%s, statusCode=%d", sessionId, statusText ? statusText : "null", statusCode);
    [[QuanYuSocket shared] saveLog:@"onInviteRinging" message:[NSString stringWithFormat:@"sessionId=%ld, statusText=%s, statusCode=%d", sessionId, statusText ? statusText : "null", statusCode]];
}


- (void)onInviteSessionProgress:(long)sessionId audioCodecs:(char *)audioCodecs videoCodecs:(char *)videoCodecs existsEarlyMedia:(BOOL)existsEarlyMedia existsAudio:(BOOL)existsAudio existsVideo:(BOOL)existsVideo sipMessage:(char *)sipMessage { 
    NSLog(@"onInviteSessionProgress: sessionId=%ld, audioCodecs=%s, videoCodecs=%s, earlyMedia=%d, audio=%d, video=%d", 
          sessionId, 
          audioCodecs ? audioCodecs : "null", 
          videoCodecs ? videoCodecs : "null", 
          existsEarlyMedia, existsAudio, existsVideo);
    [[QuanYuSocket shared] saveLog:@"onInviteSessionProgress" message:[NSString stringWithFormat:@"sessionId=%ld, audioCodecs=%s, videoCodecs=%s, earlyMedia=%d, audio=%d, video=%d", 
                                                                       sessionId, 
                                                                       audioCodecs ? audioCodecs : "null", 
                                                                       videoCodecs ? videoCodecs : "null", 
                                                                       existsEarlyMedia, existsAudio, existsVideo]];
}


- (void)onInviteTrying:(long)sessionId { 
    NSLog(@"onInviteTrying: sessionId=%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onInviteTrying" message:[NSString stringWithFormat:@"sessionId=%ld", sessionId]];
}


- (void)onInviteUpdated:(long)sessionId audioCodecs:(char *)audioCodecs videoCodecs:(char *)videoCodecs existsAudio:(BOOL)existsAudio existsVideo:(BOOL)existsVideo sipMessage:(char *)sipMessage { 
    NSLog(@"onInviteUpdated: sessionId=%ld, audioCodecs=%s, videoCodecs=%s, audio=%d, video=%d", 
          sessionId, 
          audioCodecs ? audioCodecs : "null", 
          videoCodecs ? videoCodecs : "null", 
          existsAudio, existsVideo);
    [[QuanYuSocket shared] saveLog:@"onInviteUpdated" message:[NSString stringWithFormat:@"sessionId=%ld, audioCodecs=%s, videoCodecs=%s, audio=%d, video=%d", 
                                                               sessionId, 
                                                               audioCodecs ? audioCodecs : "null", 
                                                               videoCodecs ? videoCodecs : "null", 
                                                               existsAudio, existsVideo]];
}


- (void)onPlayAudioFileFinished:(long)sessionId fileName:(char *)fileName { 
    NSLog(@"onPlayAudioFileFinished: sessionId=%ld, fileName=%s", sessionId, fileName ? fileName : "null");
    [[QuanYuSocket shared] saveLog:@"onPlayAudioFileFinished" message:[NSString stringWithFormat:@"sessionId=%ld, fileName=%s", sessionId, fileName ? fileName : "null"]];
}


- (void)onPlayVideoFileFinished:(long)sessionId { 
    NSLog(@"onPlayVideoFileFinished: sessionId=%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onPlayVideoFileFinished" message:[NSString stringWithFormat:@"sessionId=%ld", sessionId]];
}


- (void)onPresenceOffline:(char *)fromDisplayName from:(char *)from { 
    NSLog(@"onPresenceOffline: fromDisplayName=%s, from=%s", fromDisplayName ? fromDisplayName : "null", from ? from : "null");
    [[QuanYuSocket shared] saveLog:@"onPresenceOffline" message:[NSString stringWithFormat:@"fromDisplayName=%s, from=%s", fromDisplayName ? fromDisplayName : "null", from ? from : "null"]];
}


- (void)onPresenceOnline:(char *)fromDisplayName from:(char *)from stateText:(char *)stateText { 
    NSLog(@"onPresenceOnline: fromDisplayName=%s, from=%s, stateText=%s", 
          fromDisplayName ? fromDisplayName : "null", 
          from ? from : "null", 
          stateText ? stateText : "null");
    [[QuanYuSocket shared] saveLog:@"onPresenceOnline" message:[NSString stringWithFormat:@"fromDisplayName=%s, from=%s, stateText=%s", 
                                                                fromDisplayName ? fromDisplayName : "null", 
                                                                from ? from : "null", 
                                                                stateText ? stateText : "null"]];
}


- (void)onPresenceRecvSubscribe:(long)subscribeId fromDisplayName:(char *)fromDisplayName from:(char *)from subject:(char *)subject { 
    NSLog(@"onPresenceRecvSubscribe: subscribeId=%ld, fromDisplayName=%s, from=%s, subject=%s", 
          subscribeId, 
          fromDisplayName ? fromDisplayName : "null", 
          from ? from : "null", 
          subject ? subject : "null");
    [[QuanYuSocket shared] saveLog:@"onPresenceRecvSubscribe" message:[NSString stringWithFormat:@"subscribeId=%ld, fromDisplayName=%s, from=%s, subject=%s", 
                                                                       subscribeId, 
                                                                       fromDisplayName ? fromDisplayName : "null", 
                                                                       from ? from : "null", 
                                                                       subject ? subject : "null"]];
}


- (void)onReceivedRTPPacket:(long)sessionId isAudio:(BOOL)isAudio RTPPacket:(unsigned char *)RTPPacket packetSize:(int)packetSize { 
    NSLog(@"onReceivedRTPPacket: sessionId=%ld, isAudio=%d, packetSize=%d", sessionId, isAudio, packetSize);
    [[QuanYuSocket shared] saveLog:@"onReceivedRTPPacket" message:[NSString stringWithFormat:@"sessionId=%ld, isAudio=%d, packetSize=%d", sessionId, isAudio, packetSize]];
}


- (void)onReceivedRefer:(long)sessionId referId:(long)referId to:(char *)to from:(char *)from referSipMessage:(char *)referSipMessage { 
    NSLog(@"onReceivedRefer: sessionId=%ld, referId=%ld, to=%s, from=%s", 
          sessionId, referId, 
          to ? to : "null", 
          from ? from : "null");
    [[QuanYuSocket shared] saveLog:@"onReceivedRefer" message:[NSString stringWithFormat:@"sessionId=%ld, referId=%ld, to=%s, from=%s", 
                                                               sessionId, referId, 
                                                               to ? to : "null", 
                                                               from ? from : "null"]];
}


- (void)onReceivedSignaling:(long)sessionId message:(char *)message { 
    NSLog(@"onReceivedSignaling: sessionId=%ld, message=%s", sessionId, message ? message : "null");
    [[QuanYuSocket shared] saveLog:@"onReceivedSignaling" message:[NSString stringWithFormat:@"sessionId=%ld, message=%s", sessionId, message ? message : "null"]];
}


- (void)onRecvDtmfTone:(long)sessionId tone:(int)tone { 
    NSLog(@"onRecvDtmfTone: sessionId=%ld, tone=%d", sessionId, tone);
    [[QuanYuSocket shared] saveLog:@"onRecvDtmfTone" message:[NSString stringWithFormat:@"sessionId=%ld, tone=%d", sessionId, tone]];
}


- (void)onRecvInfo:(char *)infoMessage { 
    NSLog(@"onRecvInfo: infoMessage=%s", infoMessage ? infoMessage : "null");
    [[QuanYuSocket shared] saveLog:@"onRecvInfo" message:[NSString stringWithFormat:@"infoMessage=%s", infoMessage ? infoMessage : "null"]];
}


- (void)onRecvNotifyOfSubscription:(long)subscribeId notifyMessage:(char *)notifyMessage messageData:(unsigned char *)messageData messageDataLength:(int)messageDataLength { 
    NSLog(@"onRecvNotifyOfSubscription: subscribeId=%ld, notifyMessage=%s, dataLength=%d", 
          subscribeId, 
          notifyMessage ? notifyMessage : "null", 
          messageDataLength);
    [[QuanYuSocket shared] saveLog:@"onRecvNotifyOfSubscription" message:[NSString stringWithFormat:@"subscribeId=%ld, notifyMessage=%s, dataLength=%d", 
                                                                          subscribeId, 
                                                                          notifyMessage ? notifyMessage : "null", 
                                                                          messageDataLength]];
}


- (void)onRecvOptions:(char *)optionsMessage { 
    NSLog(@"onRecvOptions: optionsMessage=%s", optionsMessage ? optionsMessage : "null");
    [[QuanYuSocket shared] saveLog:@"onRecvOptions" message:[NSString stringWithFormat:@"optionsMessage=%s", optionsMessage ? optionsMessage : "null"]];
}


- (void)onReferAccepted:(long)sessionId { 
    NSLog(@"onReferAccepted: sessionId=%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onReferAccepted" message:[NSString stringWithFormat:@"sessionId=%ld", sessionId]];
}


- (void)onReferRejected:(long)sessionId reason:(char *)reason code:(int)code { 
    NSLog(@"onReferRejected: sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code);
    [[QuanYuSocket shared] saveLog:@"onReferRejected" message:[NSString stringWithFormat:@"sessionId=%ld, reason=%s, code=%d", sessionId, reason ? reason : "null", code]];
}


- (void)onRemoteHold:(long)sessionId { 
    NSLog(@"onRemoteHold: sessionId=%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onRemoteHold" message:[NSString stringWithFormat:@"sessionId=%ld", sessionId]];
}


- (void)onRemoteUnHold:(long)sessionId audioCodecs:(char *)audioCodecs videoCodecs:(char *)videoCodecs existsAudio:(BOOL)existsAudio existsVideo:(BOOL)existsVideo { 
    NSLog(@"onRemoteUnHold: sessionId=%ld, audioCodecs=%s, videoCodecs=%s, audio=%d, video=%d", sessionId, audioCodecs ? audioCodecs : "null", videoCodecs ? videoCodecs : "null", existsAudio, existsVideo);
    [[QuanYuSocket shared] saveLog:@"onRemoteUnHold" message:[NSString stringWithFormat:@"sessionId=%ld, audioCodecs=%s, videoCodecs=%s, audio=%d, video=%d", sessionId, audioCodecs ? audioCodecs : "null", videoCodecs ? videoCodecs : "null", existsAudio, existsVideo]];
}


- (void)onSendMessageFailure:(long)sessionId messageId:(long)messageId reason:(char *)reason code:(int)code { 
    NSLog(@"onSendMessageFailure: sessionId=%ld, messageId=%ld, reason=%s, code=%d", sessionId, messageId, reason ? reason : "null", code);
    [[QuanYuSocket shared] saveLog:@"onSendMessageFailure" message:[NSString stringWithFormat:@"sessionId=%ld, messageId=%ld, reason=%s, code=%d", sessionId, messageId, reason ? reason : "null", code]];
}


- (void)onSendMessageSuccess:(long)sessionId messageId:(long)messageId { 
    NSLog(@"onSendMessageSuccess: sessionId=%ld, messageId=%ld", sessionId, messageId);
    [[QuanYuSocket shared] saveLog:@"onSendMessageSuccess" message:[NSString stringWithFormat:@"sessionId=%ld, messageId=%ld", sessionId, messageId]];
}


- (void)onSendOutOfDialogMessageFailure:(long)messageId fromDisplayName:(char *)fromDisplayName from:(char *)from toDisplayName:(char *)toDisplayName to:(char *)to reason:(char *)reason code:(int)code { 
    NSLog(@"onSendOutOfDialogMessageFailure: messageId=%ld, fromDisplayName=%s, from=%s, toDisplayName=%s, to=%s, reason=%s, code=%d", messageId, fromDisplayName ? fromDisplayName : "null", from ? from : "null", toDisplayName ? toDisplayName : "null", to ? to : "null", reason ? reason : "null", code);
    [[QuanYuSocket shared] saveLog:@"onSendOutOfDialogMessageFailure" message:[NSString stringWithFormat:@"messageId=%ld, fromDisplayName=%s, from=%s, toDisplayName=%s, to=%s, reason=%s, code=%d", messageId, fromDisplayName ? fromDisplayName : "null", from ? from : "null", toDisplayName ? toDisplayName : "null", to ? to : "null", reason ? reason : "null", code]];
}


- (void)onSendOutOfDialogMessageSuccess:(long)messageId fromDisplayName:(char *)fromDisplayName from:(char *)from toDisplayName:(char *)toDisplayName to:(char *)to { 
    NSLog(@"onSendOutOfDialogMessageSuccess: messageId=%ld, fromDisplayName=%s, from=%s, toDisplayName=%s, to=%s", messageId, fromDisplayName ? fromDisplayName : "null", from ? from : "null", toDisplayName ? toDisplayName : "null", to ? to : "null");
    [[QuanYuSocket shared] saveLog:@"onSendOutOfDialogMessageSuccess" message:[NSString stringWithFormat:@"messageId=%ld, fromDisplayName=%s, from=%s, toDisplayName=%s, to=%s", messageId, fromDisplayName ? fromDisplayName : "null", from ? from : "null", toDisplayName ? toDisplayName : "null", to ? to : "null"]];
}


- (void)onSendingRTPPacket:(long)sessionId isAudio:(BOOL)isAudio RTPPacket:(unsigned char *)RTPPacket packetSize:(int)packetSize { 
    NSLog(@"onSendingRTPPacket: sessionId=%ld, isAudio=%d, packetSize=%d", sessionId, isAudio, packetSize);
    [[QuanYuSocket shared] saveLog:@"onSendingRTPPacket" message:[NSString stringWithFormat:@"sessionId=%ld, isAudio=%d, packetSize=%d", sessionId, isAudio, packetSize]];
}


- (void)onSendingSignaling:(long)sessionId message:(char *)message {
    
    NSLog(@"onSendingSignaling:%ld message:%s", sessionId, message);
    
    [[QuanYuSocket shared] saveLog:@"onSendingSignaling" message:[NSString stringWithFormat:@"sessionId=%ld, message=%s", sessionId, message]];
}


- (void)onSubscriptionFailure:(long)subscribeId statusCode:(int)statusCode { 
    NSLog(@"onSubscriptionFailure:%ld statusCode:%d", subscribeId, statusCode);
    [[QuanYuSocket shared] saveLog:@"onSubscriptionFailure" message:[NSString stringWithFormat:@"onSubscriptionFailure:%ld statusCode:%d", subscribeId, statusCode]];
}


- (void)onSubscriptionTerminated:(long)subscribeId { 
    NSLog(@"onSubscriptionTerminated:%ld", subscribeId);
    [[QuanYuSocket shared] saveLog:@"onSubscriptionTerminated" message:[NSString stringWithFormat:@"onSubscriptionTerminated:%ld", subscribeId]];
}


- (void)onTransferRinging:(long)sessionId { 
    NSLog(@"onTransferRinging:%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onTransferRinging" message:[NSString stringWithFormat:@"onTransferRinging:%ld", sessionId]];
}


- (void)onTransferTrying:(long)sessionId { 
    NSLog(@"onTransferTrying:%ld", sessionId);
    [[QuanYuSocket shared] saveLog:@"onTransferTrying" message:[NSString stringWithFormat:@"onTransferTrying:%ld", sessionId]];
}


- (int)onVideoRawCallback:(long)sessionId videoCallbackMode:(int)videoCallbackMode width:(int)width height:(int)height data:(unsigned char *)data dataLength:(int)dataLength { 
    return 0;
}


- (void)onWaitingFaxMessage:(char *)messageAccount urgentNewMessageCount:(int)urgentNewMessageCount urgentOldMessageCount:(int)urgentOldMessageCount newMessageCount:(int)newMessageCount oldMessageCount:(int)oldMessageCount { 
    
}


- (void)onWaitingVoiceMessage:(char *)messageAccount urgentNewMessageCount:(int)urgentNewMessageCount urgentOldMessageCount:(int)urgentOldMessageCount newMessageCount:(int)newMessageCount oldMessageCount:(int)oldMessageCount { 
    
}


@end
