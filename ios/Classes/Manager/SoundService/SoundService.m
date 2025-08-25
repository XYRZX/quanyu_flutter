//
//  SoundService.m
//  QuanYuDemo
//
//  Created by 周新 on 2020/3/3.
//  Copyright © 2020 周新. All rights reserved.
//

#import "SoundService.h"
#import <AVFoundation/AVFoundation.h>

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
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // 获取当前类别选项，但明确设置我们需要的所有选项
    AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionAllowBluetooth |
                                            AVAudioSessionCategoryOptionAllowAirPlay |
                                            AVAudioSessionCategoryOptionDefaultToSpeaker;

    // 根据需求调整选项
    if (!enabled) {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }

    // 首先设置类别和选项
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:options error:&error];

    if (error) {
        NSLog(@"设置音频会话类别失败: %@", error.localizedDescription);
        return NO;
    }

    // 然后尝试覆盖音频输出端口（更强制性的方法）
    if (enabled) {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    } else {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    }

    if (error) {
        NSLog(@"覆盖音频输出端口失败: %@", error.localizedDescription);
        // 即使覆盖失败，仍然返回YES，因为类别设置可能已成功
        // 实际项目中可根据需求调整此逻辑
    }

    // 激活音频会话
    [session setActive:YES error:&error];

    if (error) {
        NSLog(@"激活音频会话失败: %@", error.localizedDescription);
        return NO;
    }

    // 添加日志输出当前音频路由
    AVAudioSessionRouteDescription *route = session.currentRoute;
    NSLog(@"当前音频输出: %@", route.outputs);

    return YES;
}

- (BOOL)isSpeakerEnabled {

    return _speakerOn;
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

- (void)dealloc {

    RELEASE_PLAYER(_playerRingBackTone);
    RELEASE_PLAYER(_playerRingTone);

#undef RELEASE_PLAYER
}

@end
