//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>

CF_IMPLICIT_BRIDGING_ENABLED
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS( NSUInteger, Anchor ) {
    AnchorNone = 0,
    AnchorLeading = 1 << 0,
    AnchorTrailing = 1 << 1,
    AnchorLeft = 1 << 2,
    AnchorRight = 1 << 3,
    AnchorTop = 1 << 4,
    AnchorBottom = 1 << 5,
    AnchorWidth = 1 << 6,
    AnchorHeight = 1 << 7,
    AnchorCenterX = 1 << 8,
    AnchorCenterY = 1 << 9,
    AnchorCenter = AnchorCenterX | AnchorCenterY,
    AnchorHorizontally = AnchorLeading | AnchorTrailing,
    AnchorVertically = AnchorTop | AnchorBottom,
    AnchorBox = AnchorHorizontally | AnchorVertically,
    AnchorLeadingBox = AnchorLeading | AnchorVertically,
    AnchorLeadingCenter = AnchorLeading | AnchorCenterY,
    AnchorTrailingBox = AnchorTrailing | AnchorVertically,
    AnchorTrailingCenter = AnchorTrailing | AnchorCenterY,
    AnchorTopBox = AnchorTop | AnchorHorizontally,
    AnchorTopCenter = AnchorTop | AnchorCenterX,
    AnchorBottomBox = AnchorBottom | AnchorHorizontally,
    AnchorBottomCenter = AnchorBottom | AnchorCenterX,
};

@interface LayoutTarget : NSObject

@property(nonatomic, readonly, nullable) UIView *view;
@property(nonatomic, readonly, nullable) UIView *owningView;

@property(nonatomic, readonly, nonnull) NSLayoutXAxisAnchor *leadingAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutXAxisAnchor *trailingAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutXAxisAnchor *leftAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutXAxisAnchor *rightAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutYAxisAnchor *topAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutYAxisAnchor *bottomAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutDimension *widthAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutDimension *heightAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutXAxisAnchor *centerXAnchor;
@property(nonatomic, readonly, nonnull) NSLayoutYAxisAnchor *centerYAnchor;
@property(nonatomic, readonly, nullable) NSLayoutYAxisAnchor *firstBaselineAnchor;
@property(nonatomic, readonly, nullable) NSLayoutYAxisAnchor *lastBaselineAnchor;

@end

typedef void ( ^ViewAction )(UIView *view);
typedef NSLayoutConstraint *__nonnull ( ^LayoutConstrainer )(UIView *__nonnull owningView, LayoutTarget *__nonnull target);
typedef NSArray<NSLayoutConstraint *> *__nonnull( ^LayoutConstrainers )(UIView *__nonnull owningView, LayoutTarget *__nonnull target);

/**
 * A layout configuration holds a set of operations that will be performed on the target when the configuration's active state changes.
 */
@interface LayoutConfiguration : NSObject

//! The target upon which this configuration's operations operate.
@property(nonatomic, readonly, strong) LayoutTarget *target;
//! The layout guide upon which this configuration's operations operate.
@property(nonatomic, readonly, strong) UILayoutGuide *layoutGuide;
//! Whether this configuration has last been activated or deactivated.
@property(nonatomic, readwrite, assign) BOOL activated;
//! Child configurations which will be activated when this configuration is activated and deactivated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<LayoutConfiguration *> *activeConfigurations;
//! Child configurations which will be deactivated when this configuration is activated and activated when this configuration is deactivated.
@property(nonatomic, readonly, strong) NSMutableArray<LayoutConfiguration *> *inactiveConfigurations;

//! Create a new configuration without a target.  New configurations start deactivated.
+ (instancetype)configuration;

//! Create a new configuration for the view.  New configurations start deactivated.
+ (instancetype)configurationWithView:(UIView *)view;

//! Create a new configuration for the view and automatically add an active and inactive child configuration for it; configure them in the block.  New configurations start deactivated and the inactive configuration starts activated.
+ (instancetype)configurationWithView:(UIView *)view configurations:
        (nullable void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks;

//! Create a new configuration for a layout guide created in the view.  New configurations start deactivated.
+ (instancetype)configurationWithLayoutGuide:(UILayoutGuide *_Nullable __autoreleasing *_Nullable)layoutGuide inView:(UIView *)ownerView;

//! Create a new configuration for a layout guide created in the view and automatically add an active and inactive child configuration for it; configure them in the block.  New configurations start deactivated and the inactive configuration starts activated.
+ (instancetype)configurationWithLayoutGuide:(UILayoutGuide *_Nullable __autoreleasing *_Nullable)layoutGuide inView:(UIView *)ownerView
                              configurations:
                                      (nullable void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks;

//! Activate this constraint when the configuration becomes active.
- (instancetype)constrainTo:(NSLayoutConstraint *)constraint;
- (instancetype)compressionResistancePriority;
- (instancetype)compressionResistancePriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical;
- (instancetype)huggingPriority;
- (instancetype)huggingPriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical;
//! Set a given value for the target at the given key, when the configuration becomes active.
- (instancetype)set:(nullable id)value forKey:(NSString *)key;
//! Set a given value for the target at the given key, when the configuration becomes active.  If reverses, restore the old value when deactivated.
- (instancetype)set:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses;
//! Add child configurations that triggers when this configuration's activation changes.
- (instancetype)applyLayoutConfigurations:(void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks;
//! Add a child configuration that triggers when this configuration is activated.
- (instancetype)applyLayoutConfiguration:(LayoutConfiguration *)configuration;
//! Add a child configuration that triggers when this configuration is activated or deactivated.
- (instancetype)applyLayoutConfiguration:(LayoutConfiguration *)configuration active:(BOOL)active;
//! Mark the view as needing layout after activating the configuration.  Useful if it has custom layout code.
- (instancetype)needsLayout:(UIView *)view;
//! Mark the view as needing a redraw after activating the configuration.  Useful if it has custom draw code.
- (instancetype)needsDisplay:(UIView *)view;
//! Run this action when the configuration becomes active.
- (instancetype)doAction:(ViewAction)action;
//! Request that this configuration's target become the first responder when the configuration becomes active.
- (instancetype)becomeFirstResponder;
//! Request that this configuration's target resigns first responder when the configuration becomes active.
- (instancetype)resignFirstResponder;

//! Activate this configuration and apply its operations.
- (instancetype)activate;
- (instancetype)activateAnimated:(BOOL)animated;
//! Deactivate this configuration and reverse its relevant operations.
- (instancetype)deactivate;
- (instancetype)deactivateAnimated:(BOOL)animated;
//! If the given activation state is different from the current, update it and return YES, otherwise return NO.
- (BOOL)updateActivated:(BOOL)activated;

// Convenience alternatives.

/** Activate this constraint when the configuration becomes active
 * @param constrainer \c $0 owningView; \c $1 target
 */
- (instancetype)constrainToUsing:(LayoutConstrainer)constrainer;
- (instancetype)constrainToAllUsing:(LayoutConstrainers)constrainer;
- (instancetype)constrainToView:(nullable UIView *)view;
- (instancetype)constrainToMarginsOfView:(nullable UIView *)view;
- (instancetype)constrainToView:(nullable UIView *)host withMargins:(BOOL)margins anchor:(Anchor)anchor;
- (instancetype)constrainToOwner;
- (instancetype)constrainToMarginsOfOwner;
- (instancetype)constrainToOwnerWithMargins:(BOOL)margins;
- (instancetype)constrainToOwnerWithMargins:(BOOL)margins anchor:(Anchor)anchor;

- (instancetype)setFloat:(CGFloat)value forKey:(NSString *)key;
- (instancetype)setPoint:(CGPoint)value forKey:(NSString *)key;
- (instancetype)setSize:(CGSize)value forKey:(NSString *)key;
- (instancetype)setRect:(CGRect)value forKey:(NSString *)key;
- (instancetype)setTransform:(CGAffineTransform)value forKey:(NSString *)key;
- (instancetype)setEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key;
- (instancetype)setOffset:(UIOffset)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
CF_IMPLICIT_BRIDGING_DISABLED
