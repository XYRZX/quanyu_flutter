//
//  AccountManager.m
//  jikeForEngineer
//
//  Created by 周新 on 2019/3/26.
//  Copyright © 2019 XYR. All rights reserved.
//

#import "AccountManager.h"

static AccountManager *instance = nil;

@implementation AccountManager

+ (AccountManager *)sharedAccountManager{
    
    @synchronized(self){
        if (!instance) {
            instance = [[AccountManager alloc] init];
        }
    }
    return instance;
}

//喇叭扩音

- (void)setVoiceNum:(int)sender{
    
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    
    [saveUserInfo setObject:[NSNumber numberWithInt:sender] forKey:@"VoiceValue"];
    [saveUserInfo synchronize];
}

- (int)VoiceNum{
    
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    NSNumber *num =[saveUserInfo objectForKey:@"VoiceValue"];
    if (num) {
        return [num intValue];
    }else{
        return 100;
    }
}

//麦克风扩音

- (void)setMicrophone:(int)sender{
    
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    
    [saveUserInfo setObject:[NSNumber numberWithInt:sender] forKey:@"MicroValue"];
    [saveUserInfo synchronize];
}

- (int)Microphone{
    
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    NSNumber *num =[saveUserInfo objectForKey:@"MicroValue"];
    
    if (num) {
        return [num intValue];
    }else{
        return 100;
    }
}

//免提
- (void)setOutVoice:(BOOL)sender{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    
    [saveUserInfo setObject:[NSNumber numberWithBool:sender] forKey:@"OutVoice"];
    [saveUserInfo synchronize];
}

- (BOOL)OutVoice{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    BOOL num = [saveUserInfo boolForKey:@"OutVoice"];
    
    return num;
}

//自动接听
- (void)setAutoAnswerCall:(BOOL)sender{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    
    [saveUserInfo setObject:[NSNumber numberWithBool:sender] forKey:@"AutoAnswerCall"];
    [saveUserInfo synchronize];
    NSLog(@"setAutoAnswerCall: %@", sender ? @"YES" : @"NO");
}

- (BOOL)AutoAnswerCall{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    BOOL num = [saveUserInfo boolForKey:@"AutoAnswerCall"];
    NSLog(@"get AutoAnswerCall: %@", num ? @"YES" : @"NO");
    return num;
}

//耳机和麦克风切换
- (void)setLoudspeakerMode:(BOOL)sender{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    
    [saveUserInfo setObject:[NSNumber numberWithBool:!sender] forKey:@"LoudspeakerMode"];
    [saveUserInfo synchronize];
}

- (BOOL)LoudspeakerMode{
    NSUserDefaults *saveUserInfo = [NSUserDefaults standardUserDefaults];
    BOOL num = [saveUserInfo boolForKey:@"LoudspeakerMode"];
    
    return !num;
}

@end
