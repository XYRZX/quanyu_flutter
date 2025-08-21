//
//  SoundService.m
//  QuanYuDemo
//
//  Created by 周新 on 2020/3/3.
//  Copyright © 2020 周新. All rights reserved.
//

#import "SoundService.h"
#import <AVFoundation/AVFoundation.h>

#define RELEASE_PLAYER(player)                                               \
if (player) {                                                                \
if (player.playing) {                                                      \
[player stop];                                                           \
}                                                                          \
}

@interface SoundService ()

@property (nonatomic, assign) BOOL speakerOn;

@property (nonatomic, strong) AVAudioPlayer *playerRingTone;
@property (nonatomic, strong) AVAudioPlayer *playerRingBackTone;

+ (AVAudioPlayer *)initPlayerWithPath:(NSString *)path;

@end

@implementation SoundService

+ (AVAudioPlayer *)initPlayerWithPath:(NSString *)path {
    
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], path]];
    
    NSError *error;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    
    return player;
}


- (BOOL)speakerEnabled:(BOOL)enabled {
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionCategoryOptions options = session.categoryOptions;
    
    if (enabled) {
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    } else {
        options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:options
                   error:&error];
    
    return error != nil ? NO : YES;
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
