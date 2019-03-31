//
// Created by Maarten Billemont on 2018-03-07.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pop/POP.h>


@interface POPPropertyAnimation (MP)

+ (nonnull instancetype)animationWithProperty:(nonnull POPAnimatableProperty *)prop;

+ (nonnull instancetype)animationWithFloatAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass;
+ (nonnull instancetype)animationWithFloatAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass
                                          threshold:(CGFloat)threshold;

+ (nonnull instancetype)animationWithPointAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass;
+ (nonnull instancetype)animationWithPointAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass
                                          threshold:(CGFloat)threshold;

+ (nonnull instancetype)animationWithSizeAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass;
+ (nonnull instancetype)animationWithSizeAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass
                                         threshold:(CGFloat)threshold;

+ (nonnull instancetype)animationWithRectAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass;
+ (nonnull instancetype)animationWithRectAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass
                                         threshold:(CGFloat)threshold;

+ (nonnull instancetype)animationWithSizeOfFontAtKeyPath:(nonnull NSString *)aKeyPath onClass:(nonnull Class)aClass;

@end
