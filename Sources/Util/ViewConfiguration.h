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
@property(nonatomic, readwrite, assign) BOOL activated;
//! Child configurations which will be activated when this configuration is activated and deactivated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<ViewConfiguration *> *activeConfigurations;
//! Child configurations which will be deactivated when this configuration is activated and activated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<ViewConfiguration *> *inactiveConfigurations;

//! Create a new configuration without a view context.
+ (instancetype)configuration;

//! Create a new configuration for the view.
+ (instancetype)configurationWithView:(UIView *)view;

//! Create a new configuration for the view and automatically add an active and inactive child configuration for it; configure them in the block.
+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(ViewConfiguration *active, ViewConfiguration *inactive))configurationBlocks;

//! Activate this constraint when the configuration becomes active.
- (instancetype)constrainTo:(NSLayoutConstraint *)constraint;
//! Set a given value for the view at the given key, when the configuration becomes active.
- (instancetype)set:(nullable id)value forKey:(NSString *)key;
//! Set a given value for the view at the given key, when the configuration becomes active.  If reverses, restore the old value when deactivated.
- (instancetype)set:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses;
//! Add a child configuration that triggers when this configuration is activated.
- (instancetype)applyViewConfiguration:(ViewConfiguration *)configuration;
//! Add a child configuration that triggers when this configuration is activated or deactivated.
- (instancetype)applyViewConfiguration:(ViewConfiguration *)configuration active:(BOOL)active;
//! Mark this configuration's view as needing layout after activating the configuration.  Useful if you have custom layout code.
- (instancetype)needsLayout:(UIView *)view;
//! Mark this configuration's view as needing a redraw after activating the configuration.  Useful if you have custom draw code.
- (instancetype)needsDisplay:(UIView *)layoutView;
//! Run this action when the configuration becomes active.
- (instancetype)doAction:(void ( ^ )(UIView *view))action;
//! Request that this configuration's view become the first responder when the configuration becomes active.
- (instancetype)becomeFirstResponder;
//! Request that this configuration's view resigns first responder when the configuration becomes active.
- (instancetype)resignFirstResponder;

//! Activate this configuration and apply its operations.
- (instancetype)activate;
//! Deactivate this configuration and reverse its relevant operations.
- (instancetype)deactivate;
//! If the given activation state is different from the current, update it and return YES, otherwise return NO.
- (BOOL)updateActivated:(BOOL)activated;

// Convenience alternatives.

/** Activate this constraint when the configuration becomes active
 * @param constraintBlock \c $0 superview; \c $1 configuration view
 */
- (instancetype)constrainToUsing:(NSLayoutConstraint *( ^ )(UIView *superview, UIView *view))constraintBlock;
- (instancetype)constrainToView:(UIView *__nullable)view;
- (instancetype)constrainToView:(UIView *__nullable)view  margins:(BOOL)margins forAttributes:(NSLayoutFormatOptions)attributes;
- (instancetype)constrainToSuperview;
- (instancetype)constrainToSuperviewMargins;
- (instancetype)constrainToSuperviewMargins:(BOOL)margins forAttributes:(NSLayoutFormatOptions)attributes;

- (instancetype)setFloat:(CGFloat)value forKey:(NSString *)key;
- (instancetype)setPoint:(CGPoint)value forKey:(NSString *)key;
- (instancetype)setSize:(CGSize)value forKey:(NSString *)key;
- (instancetype)setRect:(CGRect)value forKey:(NSString *)key;
- (instancetype)setTransform:(CGAffineTransform)value forKey:(NSString *)key;
- (instancetype)setEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key;
- (instancetype)setOffset:(UIOffset)value forKey:(NSString *)key;

@end

#pragma clang assume_nonnull end
CF_IMPLICIT_BRIDGING_DISABLED
