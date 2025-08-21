//
//  AccountManager.h
//  jikeForEngineer
//
//  Created by 周新 on 2019/3/26.
//  Copyright © 2019 XYR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AccountManager : NSObject

+ (AccountManager *)sharedAccountManager;

//喇叭扩音

- (void)setVoiceNum:(int)sender;

- (int)VoiceNum;

//麦克风扩音

- (void)setMicrophone:(int)sender;

- (int)Microphone;

//免提

- (void)setOutVoice:(BOOL)sender;

- (BOOL)OutVoice;

//自动接听
- (void)setAutoAnswerCall:(BOOL)sender;

- (BOOL)AutoAnswerCall;

@end
