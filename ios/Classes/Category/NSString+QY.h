//
//  NSString+QY.h
//  QuanYuDemo
//
//  Created by 周新 on 2020/3/3.
//  Copyright © 2020 周新. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (QY)

// 字典转json
+ (NSString *)convertToJsonData:(NSDictionary *)dict;

// JSON转换Dic
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;

//色值转换
+ (UIColor *)colorWithHexStringRGB:(NSString *)hexColor;

@end

NS_ASSUME_NONNULL_END
