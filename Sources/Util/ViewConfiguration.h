//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>

CF_IMPLICIT_BRIDGING_ENABLED
#pragma clang assume_nonnull begin

/**
 * A view configuration holds a set of operations that will be performed on the view when the configuration's active state changes.
 */
@interface ViewConfiguration : NSObject

//! The view upon which this configuration's operations operate.
@property(nonatomic, readonly, strong) UIView *view;
//! Whether this configuration has last been activated or deactivated.
@property(nonatomic, readonly, assign) BOOL activated;
//! Child configurations which will be activated when this configuration is activated and deactivated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<ViewConfiguration *> *activeConfigurations;
//! Child configurations which will be deactivated when this configuration is activated and activated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<ViewConfiguration *> *inactiveConfigurations;

//! Create a new empty configuration for the view.
+ (instancetype)configurationWithView:(UIView *)view;

//! Create a new configuration for the view and automatically add an active and inactive child configuration for it; configure them in the block.
+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(ViewConfiguration *active, ViewConfiguration *inactive))configurationBlocks;

//! Activate this constraint when the configuration becomes active.
- (instancetype)addConstraint:(NSLayoutConstraint *)constraint;
//! Set a given value for the view at the given key, when the configuration becomes active.
- (instancetype)add:(nullable id)value forKey:(NSString *)key;
//! Set a given value for the view at the given key, when the configuration becomes active.  If reverses, restore the old value when deactivated.
- (instancetype)add:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses;
//! Add a child configuration that triggers when this configuration is activated.
- (instancetype)addViewConfiguration:(ViewConfiguration *)configuration;
//! Add a child configuration that triggers when this configuration is activated or deactivated.
- (instancetype)addViewConfiguration:(ViewConfiguration *)configuration active:(BOOL)active;
//! Mark this configuration's view as needing layout after activating the configuration.  Useful if you have custom layout code.
- (instancetype)addNeedsLayout:(UIView *)view;
//! Mark this configuration's view as needing a redraw after activating the configuration.  Useful if you have custom draw code.
- (instancetype)addNeedsDisplay:(UIView *)layoutView;
//! Run this action when the configuration becomes active.
- (instancetype)addAction:(void ( ^ )(UIView *view))action;
//! Request that this configuration's view become the first responder when the configuration becomes active.
- (instancetype)becomeFirstResponder;
//! Request that this configuration's view resigns first responder when the configuration becomes active.
- (instancetype)resignFirstResponder;

//! Activate this configuration and apply its operations.
- (instancetype)activate;
//! Deactivate this configuration and reverse its relevant operations.
- (instancetype)deactivate;

// Convenience alternatives.

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
