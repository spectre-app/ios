//
// Created by Maarten Billemont on 2018-03-07.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "POPAnimation+MP.h"

@implementation POPPropertyAnimation(MP)

+ (instancetype)animationWithProperty:(POPAnimatableProperty *)prop {

    POPPropertyAnimation *animation = [self new];
    animation.property = prop;
    return animation;
}

+ (instancetype)animationWithFloatAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass {

    return [self animationWithFloatAtKeyPath:aKeyPath onClass:aClass threshold:0.01f];
}

+ (instancetype)animationWithFloatAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass threshold:(CGFloat)threshold {

    return [self animationWithProperty:
            [POPAnimatableProperty propertyWithName:strf( @"%@.%@", NSStringFromClass( aClass ), aKeyPath ) initializer:
                    ^(POPMutableAnimatableProperty *prop) {
                        prop.readBlock = ^(id obj, CGFloat values[]) {
                            values[0] = (CGFloat)[[obj valueForKeyPath:aKeyPath] doubleValue];
                        };
                        prop.writeBlock = ^(id obj, const CGFloat values[]) {
                            [obj setValue:@(values[0]) forKey:aKeyPath];
                        };
                        prop.threshold = threshold;
                    }]];
}

+ (instancetype)animationWithPointAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass {

    return [self animationWithPointAtKeyPath:aKeyPath onClass:aClass threshold:0.01f];
}

+ (instancetype)animationWithPointAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass threshold:(CGFloat)threshold {

    return [self animationWithProperty:
            [POPAnimatableProperty propertyWithName:strf( @"%@.%@", NSStringFromClass( aClass ), aKeyPath ) initializer:
                    ^(POPMutableAnimatableProperty *prop) {
                        prop.readBlock = ^(id obj, CGFloat values[]) {
                            CGPoint point = [[obj valueForKeyPath:aKeyPath] CGPointValue];
                            values[0] = point.x;
                            values[1] = point.y;
                        };
                        prop.writeBlock = ^(id obj, const CGFloat values[]) {
                            [obj setValue:[NSValue valueWithCGPoint:CGPointMake( values[0], values[1] )] forKey:aKeyPath];
                        };
                        prop.threshold = threshold;
                    }]];
}

+ (instancetype)animationWithSizeAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass {

    return [self animationWithSizeAtKeyPath:aKeyPath onClass:aClass threshold:0.01f];
}

+ (instancetype)animationWithSizeAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass threshold:(CGFloat)threshold {

    return [self animationWithProperty:
            [POPAnimatableProperty propertyWithName:strf( @"pop.%@.%@", NSStringFromClass( aClass ), aKeyPath ) initializer:
                    ^(POPMutableAnimatableProperty *prop) {
                        prop.readBlock = ^(id obj, CGFloat values[]) {
                            CGSize size = [[obj valueForKeyPath:aKeyPath] CGSizeValue];
                            values[0] = size.width;
                            values[1] = size.height;
                        };
                        prop.writeBlock = ^(id obj, const CGFloat values[]) {
                            [obj setValue:[NSValue valueWithCGSize:CGSizeMake( values[0], values[1] )]
                                   forKey:aKeyPath];
                        };
                        prop.threshold = threshold;
                    }]];
}

+ (instancetype)animationWithRectAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass {

    return [self animationWithRectAtKeyPath:aKeyPath onClass:aClass threshold:0.01f];
}

+ (instancetype)animationWithRectAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass threshold:(CGFloat)threshold {

    return [self animationWithProperty:
            [POPAnimatableProperty propertyWithName:strf( @"pop.%@.%@", NSStringFromClass( aClass ), aKeyPath ) initializer:
                    ^(POPMutableAnimatableProperty *prop) {
                        prop.readBlock = ^(id obj, CGFloat values[]) {
                            CGRect rect = [[obj valueForKeyPath:aKeyPath] CGRectValue];
                            values[0] = rect.origin.x;
                            values[1] = rect.origin.y;
                            values[2] = rect.size.width;
                            values[3] = rect.size.height;
                        };
                        prop.writeBlock = ^(id obj, const CGFloat values[]) {
                            [obj setValue:[NSValue valueWithCGRect:CGRectMake( values[0], values[1], values[2], values[3] )]
                                   forKey:aKeyPath];
                        };
                        prop.threshold = threshold;
                    }]];
}

+ (instancetype)animationWithSizeOfFontAtKeyPath:(NSString *)aKeyPath onClass:(Class)aClass {

    return [self animationWithProperty:
            [POPAnimatableProperty propertyWithName:strf( @"pop.%@.%@", NSStringFromClass( aClass ), aKeyPath ) initializer:
                    ^(POPMutableAnimatableProperty *prop) {
                        prop.readBlock = ^(id obj, CGFloat values[]) {
                            UIFont *font = [obj valueForKeyPath:aKeyPath];
                            values[0] = font.pointSize;
                        };
                        prop.writeBlock = ^(id obj, const CGFloat values[]) {
                            UIFont *font = [obj valueForKeyPath:aKeyPath];
                            [obj setValue:[font fontWithSize:values[0]] forKey:aKeyPath];
                        };
                        prop.threshold = 0.01f;
                    }]];
}

@end
