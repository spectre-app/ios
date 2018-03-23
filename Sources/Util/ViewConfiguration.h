//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>

CF_IMPLICIT_BRIDGING_ENABLED
#pragma clang assume_nonnull begin

@interface ViewConfiguration : NSObject

@property(nonatomic, readonly, strong) UIView *view;
@property(nonatomic, readonly, strong) ViewConfiguration *active;
@property(nonatomic, readonly, strong) ViewConfiguration *inactive;

+ (instancetype)configurationWithView:(UIView *)view;
+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(ViewConfiguration *active, ViewConfiguration *inactive))configurationBlocks;

- (instancetype)addConstraint:(NSLayoutConstraint *)constraint;
- (instancetype)addValue:(NSValue *)value forKey:(NSString *)key;
- (instancetype)activate;
- (instancetype)deactivate;

- (instancetype)addUsing:(NSLayoutConstraint *( ^ )(UIView *view))constraintBlock;

- (instancetype)addFloat:(CGFloat)value forKey:(NSString *)key;
- (instancetype)addPoint:(CGPoint)value forKey:(NSString *)key;
- (instancetype)addSize:(CGSize)value forKey:(NSString *)key;
- (instancetype)addRect:(CGRect)value forKey:(NSString *)key;
- (instancetype)addTransform:(CGAffineTransform)value forKey:(NSString *)key;
- (instancetype)addEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key;
- (instancetype)addOffset:(UIOffset)value forKey:(NSString *)key;

@end

#pragma clang assume_nonnull end
CF_IMPLICIT_BRIDGING_DISABLED
