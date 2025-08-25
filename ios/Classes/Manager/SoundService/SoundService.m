//
//  SoundService.m
//  QuanYuDemo
//
//  Created by 周新 on 2020/3/3.
//  Copyright © 2020 周新. All rights reserved.
//

#import "SoundService.h"
#import <AVFoundation/AVFoundation.h>
#import <TargetConditionals.h>

#define RELEASE_PLAYER(player)                                                                                         \
    if (player) {                                                                                                      \
        if (player.playing) {                                                                                          \
            [player stop];                                                                                             \
        }                                                                                                              \
    }

@interface SoundService ()

@property(nonatomic, assign) BOOL speakerOn;

@property(nonatomic, strong) AVAudioPlayer *playerRingTone;
@property(nonatomic, strong) AVAudioPlayer *playerRingBackTone;

+ (AVAudioPlayer *)initPlayerWithPath:(NSString *)path;

@end

@implementation SoundService

+ (AVAudioPlayer *)initPlayerWithPath:(NSString *)path {

    NSURL *url =
        [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], path]];

    NSError *error;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];

    return player;
}

- (BOOL)setSpeakerEnabled:(BOOL)enabled {
#if TARGET_OS_IOS
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionAllowBluetooth |
                                            AVAudioSessionCategoryOptionAllowAirPlay |
                                            AVAudioSessionCategoryOptionDefaultToSpeaker;

    if (!enabled) {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }

    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:options error:&error];

    if (error) {
        NSLog(@"设置音频会话类别失败: %@", error.localizedDescription);
        _speakerOn = enabled; // 同步内部状态
        return NO;
    }

    if (enabled) {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    } else {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    }

    if (error) {
        NSLog(@"覆盖音频输出端口失败: %@", error.localizedDescription);
    }

    [session setActive:YES error:&error];

    if (error) {
        NSLog(@"激活音频会话失败: %@", error.localizedDescription);
        _speakerOn = enabled; // 同步内部状态
        return NO;
    }

    AVAudioSessionRouteDescription *route = session.currentRoute;
    NSLog(@"当前音频输出: %@", route.outputs);

    _speakerOn = enabled; // 同步内部状态
    return YES;
#else
    // 非 iOS 平台（例如 macOS 编译器索引），不使用 AVAudioSession，直接维护内部状态
    _speakerOn = enabled;
    return YES;
#endif
}

- (BOOL)isSpeakerEnabled {
#if TARGET_OS_IOS
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *route = session.currentRoute;
    for (AVAudioSessionPortDescription *output in route.outputs) {
        if ([output.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
            return YES;
        }
    }
    return NO;
#else
    // 非 iOS 平台下回退到内部标记，避免编译期/静态分析错误
    return _speakerOn;
#endif
}

- (BOOL)playRingTone {

    if (!_playerRingTone) {
        _playerRingTone = [SoundService initPlayerWithPath:@"ringtone.mp3"];
    }

    if (_playerRingTone) {
        _playerRingTone.numberOfLoops = -1;
        [self speakerEnabled:YES];
        [_playerRingTone play];
        return YES;
    }

    return NO;
}

- (BOOL)stopRingTone {

    if (_playerRingTone && _playerRingTone.playing) {
        [_playerRingTone stop];
    }

    return YES;
}

- (BOOL)playRingBackTone {

    if (!_playerRingBackTone) {
        _playerRingBackTone = [SoundService initPlayerWithPath:@"ringtone.mp3"];
    }

    if (_playerRingBackTone) {
        _playerRingBackTone.numberOfLoops = -1;
        [self speakerEnabled:NO];
        [_playerRingBackTone play];
        return YES;
    }

    return NO;
}

- (BOOL)stopRingBackTone {
    if (_playerRingBackTone && _playerRingBackTone.playing) {
        [_playerRingBackTone stop];
    }
    return YES;
}

- (BOOL)speakerEnabled:(BOOL)enabled {
    return [self setSpeakerEnabled:enabled];
}

- (void)dealloc {

    RELEASE_PLAYER(_playerRingBackTone);
    RELEASE_PLAYER(_playerRingTone);

#undef RELEASE_PLAYER
}

@end
