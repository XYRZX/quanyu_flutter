//
//  SoundService.h
//  QuanYuDemo
//
//  Created by 周新 on 2020/3/3.
//  Copyright © 2020 周新. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SoundService : NSObject

- (BOOL)speakerEnabled:(BOOL)enabled;
- (BOOL)isSpeakerEnabled;

- (BOOL)playRingTone;
- (BOOL)stopRingTone;

- (BOOL)playRingBackTone;
- (BOOL)stopRingBackTone;

@end

NS_ASSUME_NONNULL_END
