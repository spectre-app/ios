//
// Created by Maarten Billemont on 2018-03-07.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pop/POP.h>

@interface POPPropertyAnimation(MP)

+ (__nonnull instancetype)animationWithProperty:(POPAnimatableProperty *__nonnull)prop;

+ (__nonnull instancetype)animationWithFloatAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass;
+ (__nonnull instancetype)animationWithFloatAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass
                                            threshold:(CGFloat)threshold;

+ (__nonnull instancetype)animationWithPointAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass;
+ (__nonnull instancetype)animationWithPointAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass
                                            threshold:(CGFloat)threshold;

+ (__nonnull instancetype)animationWithSizeAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass;
+ (__nonnull instancetype)animationWithSizeAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass
                                           threshold:(CGFloat)threshold;

+ (__nonnull instancetype)animationWithRectAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass;
+ (__nonnull instancetype)animationWithRectAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass
                                           threshold:(CGFloat)threshold;

+ (__nonnull instancetype)animationWithSizeOfFontAtKeyPath:(NSString *__nonnull)aKeyPath onClass:(__nonnull Class)aClass;

@end
