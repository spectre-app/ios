//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "LayoutConfiguration.h"

@interface LayoutTarget()

@property(nonatomic, readwrite, nullable) UIView *view;
@property(nonatomic, readwrite, nullable) UILayoutGuide *layoutGuide;

+ (instancetype)layoutTargetWithView:(UIView *)view;
+ (instancetype)layoutTargetWithLayoutGuide:(UILayoutGuide *)layoutGuide;

@end

@interface LayoutConfiguration()

@property(nonatomic, readwrite, strong) LayoutTarget *target;
@property(nonatomic, readwrite, strong) NSMutableArray<LayoutConstrainers> *constrainers;
@property(nonatomic, readwrite, strong) NSMutableSet<NSLayoutConstraint *> *activeConstraints;
@property(nonatomic, readwrite, strong) NSMutableArray<LayoutConfiguration *> *activeConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<LayoutConfiguration *> *inactiveConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *> *layoutViews;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *> *displayViews;
@property(nonatomic, readwrite, strong) NSMutableArray<void ( ^ )(UIView *)> *actions;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id> *activeValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id> *inactiveValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id> *activeProperties;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id> *inactiveProperties;

@end

@implementation LayoutConfiguration {
}

+ (instancetype)configuration {

    LayoutConfiguration *configuration = [self new];
    configuration->_activated = YES;
    return [configuration deactivate];
}

+ (instancetype)configurationWithTarget:(LayoutTarget *)layoutTarget {

    LayoutConfiguration *configuration = [self configuration];
    configuration.target = layoutTarget;
    return configuration;
}

+ (instancetype)configurationWithView:(UIView *)view {

    return [self configurationWithTarget:[LayoutTarget layoutTargetWithView:view]];
}

+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks {

    LayoutConfiguration *configuration = [self configurationWithView:view];

    if (configurationBlocks) {
        LayoutConfiguration *active = [self configurationWithView:view];
        LayoutConfiguration *inactive = [self configurationWithView:view];
        configurationBlocks( active, inactive );
        [configuration applyLayoutConfiguration:active active:YES];
        [configuration applyLayoutConfiguration:inactive active:NO];
    }

    return configuration;
}

+ (instancetype)configurationWithLayoutGuide:(UILayoutGuide *)layoutGuide {

    return [self configurationWithTarget:[LayoutTarget layoutTargetWithLayoutGuide:layoutGuide]];
}

+ (instancetype)configurationWithLayoutGuide:(UILayoutGuide *)layoutGuide
                              configurations:(nullable void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks {

    LayoutConfiguration *configuration = [self configurationWithLayoutGuide:layoutGuide];

    if (configurationBlocks) {
        LayoutConfiguration *active = [self configurationWithTarget:configuration.target];
        LayoutConfiguration *inactive = [self configurationWithTarget:configuration.target];
        configurationBlocks( active, inactive );
        [configuration applyLayoutConfiguration:active active:YES];
        [configuration applyLayoutConfiguration:inactive active:NO];
    }

    return configuration;
}

- (instancetype)init {

    if (!(self = [super init]))
        return nil;

    self.constrainers = [NSMutableArray new];
    self.activeConstraints = [NSMutableSet new];
    self.activeConfigurations = [NSMutableArray new];
    self.inactiveConfigurations = [NSMutableArray new];
    self.layoutViews = [NSMutableArray new];
    self.displayViews = [NSMutableArray new];
    self.actions = [NSMutableArray new];
    self.activeValues = [NSMutableDictionary new];
    self.inactiveValues = [NSMutableDictionary new];
    self.activeProperties = [NSMutableDictionary new];

    return self;
}

- (instancetype)constrainTo:(NSLayoutConstraint *)constraint {

    return [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
        return constraint;
    }];
}

- (instancetype)compressionResistancePriority {

    return [self compressionResistancePriorityHorizontal:UILayoutPriorityRequired vertical:UILayoutPriorityRequired];
}

- (instancetype)compressionResistancePriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical {

    self.activeProperties[@"compressionResistance.horizontal"] = @(horizontal);
    self.activeProperties[@"compressionResistance.vertical"] = @(vertical);
    return self;
}

- (instancetype)huggingPriority {

    return [self huggingPriorityHorizontal:UILayoutPriorityRequired vertical:UILayoutPriorityRequired];
}

- (instancetype)huggingPriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical {

    self.activeProperties[@"hugging.horizontal"] = @(horizontal);
    self.activeProperties[@"hugging.vertical"] = @(vertical);
    return self;
}

- (instancetype)set:(nullable id)value forKey:(NSString *)key {

    return [self set:value forKey:key reverses:NO];
}

- (instancetype)set:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses {

    self.activeValues[key] = value?: [NSNull null];

    if (reverses)
        self.inactiveValues[key] = [self.target valueForKeyPath:key]?: [NSNull null];

    return self;
}

- (instancetype)applyLayoutConfigurations:(void ( ^ )(LayoutConfiguration *active, LayoutConfiguration *inactive))configurationBlocks {

    LayoutConfiguration *active = [LayoutConfiguration configurationWithTarget:self.target];
    LayoutConfiguration *inactive = [LayoutConfiguration configurationWithTarget:self.target];
    configurationBlocks( active, inactive );
    [self.activeConfigurations addObject:active];
    [self.inactiveConfigurations addObject:inactive];

    if (self.activated)
        [active activate];
    else
        [inactive activate];

    return self;
}

- (instancetype)applyLayoutConfiguration:(LayoutConfiguration *)configuration {

    return [self applyLayoutConfiguration:configuration active:YES];
}

- (instancetype)applyLayoutConfiguration:(LayoutConfiguration *)configuration active:(BOOL)active {

    [(active? self.activeConfigurations: self.inactiveConfigurations) addObject:configuration];

    if (self.activated && active)
        [configuration activate];
    else if (!self.activated && !active)
        [configuration activate];

    return self;
}

- (instancetype)needsLayout:(UIView *)view {

    [self.layoutViews addObject:view];
    return self;
}

- (instancetype)needsDisplay:(UIView *)view {

    [self.displayViews addObject:view];
    return self;
}

- (instancetype)doAction:(ViewAction)action {

    [self.actions addObject:[action copy]];
    return self;
}

- (instancetype)becomeFirstResponder {

    return [self doAction:^(UIView *view) {
        [view becomeFirstResponder];
    }];
}

- (instancetype)resignFirstResponder {

    return [self doAction:^(UIView *view) {
        [view resignFirstResponder];
    }];
}

- (void)setActivated:(BOOL)activated {

    [self updateActivated:activated];
}

- (BOOL)updateActivated:(BOOL)activated {

    if (activated == _activated)
        return NO;

    if (activated)
        [self activate];
    else
        [self deactivate];

    return YES;
}

- (instancetype)activate {

    return [self activateFromParent:nil];
}

- (instancetype)activateAnimated:(BOOL)animated {

    if (animated)
        [UIView animateWithDuration:1 animations:^{
            [self activate];
        }];
    else
        [UIView performWithoutAnimation:^{
            [self activate];
        }];

    return self;
}

- (instancetype)activateFromParent:(LayoutConfiguration *)parent {
    
    if (self.activated)
        return self;

    PearlMainQueue( ^{
        UIView *owningView = self.target.owningView;
        UIView *targetView = self.target.view?: owningView;

        for (LayoutConfiguration *inactiveConfiguration in self.inactiveConfigurations)
            [inactiveConfiguration deactivateFromParent:self];

        if (self.constrainers.count)
            self.target.view.translatesAutoresizingMaskIntoConstraints = NO;

        UILayoutPriority oldPriority, newPriority;
        if ((newPriority = [self.activeProperties[@"compressionResistance.horizontal"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [targetView contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal]) != newPriority) {
                self.inactiveProperties[@"compressionResistance.horizontal"] = @(oldPriority);
                [targetView setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
            }
        if ((newPriority = [self.activeProperties[@"compressionResistance.vertical"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [targetView contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical]) != newPriority) {
                self.inactiveProperties[@"compressionResistance.vertical"] = @(oldPriority);
                [targetView setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisVertical];
            }
        if ((newPriority = [self.activeProperties[@"hugging.horizontal"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [targetView contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal]) != newPriority) {
                self.inactiveProperties[@"hugging.horizontal"] = @(oldPriority);
                [targetView setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
            }
        if ((newPriority = [self.activeProperties[@"hugging.vertical"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [targetView contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical]) != newPriority) {
                self.inactiveProperties[@"hugging.vertical"] = @(oldPriority);
                [targetView setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisVertical];
            }

        if (self.constrainers.count) {
            NSAssert( owningView, @"Skipping layout constraints since view has no owner: %@",
                    (id)self.target.view?: self.target.layoutGuide );
            for (LayoutConstrainers constrainer in self.constrainers)
                for (NSLayoutConstraint *constraint in constrainer( owningView, self.target )) {
                    //trc( @"%@: activating %@", [targetView infoPathName], constraint );
                    constraint.active = YES;
                    [self.activeConstraints addObject:constraint];
                }
        }

        [self.activeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
            id oldValue = [targetView valueForKeyPath:key]?: [NSNull null];
            if ([newValue isEqual:oldValue])
                return;

            if ([[self.inactiveValues allKeys] containsObject:key])
                self.inactiveValues[key] = oldValue;

            //trc( @"%@: %@, %@ -> %@", [targetView infoPathName], key, oldValue, newValue );
            [targetView setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
        }];

        for (ViewAction action in self.actions)
            action( targetView );

        for (LayoutConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration activateFromParent:self];

        self->_activated = YES;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

        if (!parent.target)
            [self layoutIfNeeded];
    } );

    return self;
}

- (instancetype)deactivate {

    return [self deactivateFromParent:nil];
}

- (instancetype)deactivateAnimated:(BOOL)animated {

    if (animated)
        [UIView animateWithDuration:1 animations:^{
            [self deactivate];
        }];
    else
        [UIView performWithoutAnimation:^{
            [self deactivate];
        }];

    return self;
}

- (instancetype)deactivateFromParent:(LayoutConfiguration *)parent {

    if (!self.activated)
        return self;

    PearlMainQueue( ^{
        UIView *owningView = self.target.owningView;
        UIView *targetView = self.target.view?: owningView;

        for (LayoutConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration deactivateFromParent:self];

        UILayoutPriority newPriority;
        if ((newPriority = [self.inactiveProperties[@"compressionResistance.horizontal"]?: @(-1) floatValue]) >= 0)
            if ([targetView contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal] != newPriority)
                [targetView setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
        if ((newPriority = [self.inactiveProperties[@"compressionResistance.vertical"]?: @(-1) floatValue]) >= 0)
            if ([targetView contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical] != newPriority)
                [targetView setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisVertical];
        if ((newPriority = [self.inactiveProperties[@"hugging.horizontal"]?: @(-1) floatValue]) >= 0)
            if ([targetView contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal] != newPriority)
                [targetView setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
        if ((newPriority = [self.inactiveProperties[@"hugging.vertical"]?: @(-1) floatValue]) >= 0)
            if ([targetView contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical] != newPriority)
                [targetView setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisVertical];

        for (NSLayoutConstraint *constraint in self.activeConstraints) {
            //trc( @"%@: deactivating %@", [targetView infoPathName], constraint );
            constraint.active = NO;
        }
        [self.activeConstraints removeAllObjects];

        [self.inactiveValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
            id oldValue = [targetView valueForKeyPath:key]?: [NSNull null];
            if ([newValue isEqual:oldValue])
                return;

            //trc( @"%@: %@, %@ -> %@", [targetView infoPathName], key, oldValue, newValue );
            [targetView setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
        }];

        for (LayoutConfiguration *inactiveConfiguration in self.inactiveConfigurations)
            [inactiveConfiguration activateFromParent:self];

        self->_activated = NO;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

        if (!parent.target)
            [self layoutIfNeeded];
    } );

    return self;
}

- (void)layoutIfNeeded {

    UIView *owningView = self.target.owningView;
    if ([owningView isKindOfClass:[UIWindow class]] || owningView.window)
        [owningView layoutIfNeeded];
}

- (instancetype)constrainToUsing:(LayoutConstrainer)constrainer {

    return [self constrainToAllUsing:^NSArray<NSLayoutConstraint *> *(UIView *owningView, LayoutTarget *target) {
        return @[ constrainer( owningView, target ) ];
    }];
}

- (instancetype)constrainToAllUsing:(LayoutConstrainers)constrainer {

    // TODO: activate if configuration is active?
    [self.constrainers addObject:constrainer];
    return self;
}

- (instancetype)constrainToView:(nullable UIView *)view {

    return [self constrainToView:view withMargins:NO anchors:
            AnchorTop | AnchorLeading | AnchorTrailing | AnchorBottom];
}

- (instancetype)constrainToMarginsOfView:(nullable UIView *)view {

    return [self constrainToView:view withMargins:YES anchors:
            AnchorTop | AnchorLeading | AnchorTrailing | AnchorBottom];
}

- (instancetype)constrainToView:(nullable UIView *)host withMargins:(BOOL)margins anchors:(Anchor)anchor {

    if (anchor & AnchorTop)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.topAnchor constraintEqualToAnchor:target.topAnchor];
            else
                return [(host?: owningView).topAnchor constraintEqualToAnchor:target.topAnchor];
        }];
    if (anchor & AnchorLeading)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.leadingAnchor constraintEqualToAnchor:target.leadingAnchor];
            else
                return [(host?: owningView).leadingAnchor constraintEqualToAnchor:target.leadingAnchor];
        }];
    if (anchor & AnchorTrailing)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.trailingAnchor constraintEqualToAnchor:target.trailingAnchor];
            else
                return [(host?: owningView).trailingAnchor constraintEqualToAnchor:target.trailingAnchor];
        }];
    if (anchor & AnchorBottom)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.bottomAnchor constraintEqualToAnchor:target.bottomAnchor];
            else
                return [(host?: owningView).bottomAnchor constraintEqualToAnchor:target.bottomAnchor];
        }];
    if (anchor & AnchorLeft)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.leftAnchor constraintEqualToAnchor:target.leftAnchor];
            else
                return [(host?: owningView).leftAnchor constraintEqualToAnchor:target.leftAnchor];
        }];
    if (anchor & AnchorRight)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.rightAnchor constraintEqualToAnchor:target.rightAnchor];
            else
                return [(host?: owningView).rightAnchor constraintEqualToAnchor:target.rightAnchor];
        }];
    if (anchor & AnchorWidth)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.widthAnchor constraintEqualToAnchor:target.widthAnchor];
            else
                return [(host?: owningView).widthAnchor constraintEqualToAnchor:target.widthAnchor];
        }];
    if (anchor & AnchorHeight)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.heightAnchor constraintEqualToAnchor:target.heightAnchor];
            else
                return [(host?: owningView).heightAnchor constraintEqualToAnchor:target.heightAnchor];
        }];
    if (anchor & AnchorCenterX)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.centerXAnchor constraintEqualToAnchor:target.centerXAnchor];
            else
                return [(host?: owningView).centerXAnchor constraintEqualToAnchor:target.centerXAnchor];
        }];
    if (anchor & AnchorCenterY)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *owningView, LayoutTarget *target) {
            if (margins)
                return [(host?: owningView).layoutMarginsGuide.centerYAnchor constraintEqualToAnchor:target.centerYAnchor];
            else
                return [(host?: owningView).centerYAnchor constraintEqualToAnchor:target.centerYAnchor];
        }];

    return self;
}

- (instancetype)constrainToOwner {

    return [self constrainToView:nil];
}

- (instancetype)constrainToMarginsOfOwner {

    return [self constrainToMarginsOfOwnerWithAnchors:
            AnchorTop | AnchorLeading | AnchorTrailing | AnchorBottom];
}

- (instancetype)constrainToOwnerWithAnchors:(Anchor)anchor {

    return [self constrainToView:nil withMargins:NO anchors:anchor];
}

- (instancetype)constrainToMarginsOfOwnerWithAnchors:(Anchor)anchor {

    return [self constrainToView:nil withMargins:YES anchors:anchor];
}

- (instancetype)setFloat:(CGFloat)value forKey:(NSString *)key {

    return [self set:@(value) forKey:key];
}

- (instancetype)setPoint:(CGPoint)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithCGPoint:value] forKey:key];
}

- (instancetype)setSize:(CGSize)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithCGSize:value] forKey:key];
}

- (instancetype)setRect:(CGRect)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithCGRect:value] forKey:key];
}

- (instancetype)setTransform:(CGAffineTransform)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithCGAffineTransform:value] forKey:key];
}

- (instancetype)setEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithUIEdgeInsets:value] forKey:key];
}

- (instancetype)setOffset:(UIOffset)value forKey:(NSString *)key {

    return [self set:[NSValue valueWithUIOffset:value] forKey:key];
}

@end

@implementation LayoutTarget

+ (instancetype)layoutTargetWithView:(UIView *)view {

    LayoutTarget *target = [self new];
    target.view = view;
    return target;
}

+ (instancetype)layoutTargetWithLayoutGuide:(UILayoutGuide *)layoutGuide {

    LayoutTarget *target = [self new];
    target.layoutGuide = layoutGuide;
    return target;
}

- (UIView *)owningView {

    return self.view.superview?: self.layoutGuide.owningView;
}

- (NSLayoutXAxisAnchor *)leadingAnchor {

    return self.view.leadingAnchor?: self.layoutGuide.leadingAnchor;
}

- (NSLayoutXAxisAnchor *)trailingAnchor {

    return self.view.trailingAnchor?: self.layoutGuide.trailingAnchor;
}

- (NSLayoutXAxisAnchor *)leftAnchor {

    return self.view.leftAnchor?: self.layoutGuide.leftAnchor;
}

- (NSLayoutXAxisAnchor *)rightAnchor {

    return self.view.rightAnchor?: self.layoutGuide.rightAnchor;
}

- (NSLayoutYAxisAnchor *)topAnchor {

    return self.view.topAnchor?: self.layoutGuide.topAnchor;
}

- (NSLayoutYAxisAnchor *)bottomAnchor {

    return self.view.bottomAnchor?: self.layoutGuide.bottomAnchor;
}

- (NSLayoutDimension *)widthAnchor {

    return self.view.widthAnchor?: self.layoutGuide.widthAnchor;
}

- (NSLayoutDimension *)heightAnchor {

    return self.view.heightAnchor?: self.layoutGuide.heightAnchor;
}

- (NSLayoutXAxisAnchor *)centerXAnchor {

    return self.view.centerXAnchor?: self.layoutGuide.centerXAnchor;
}

- (NSLayoutYAxisAnchor *)centerYAnchor {

    return self.view.centerYAnchor?: self.layoutGuide.centerYAnchor;
}

- (NSLayoutYAxisAnchor *)firstBaselineAnchor {

    return self.view.firstBaselineAnchor;
}

- (NSLayoutYAxisAnchor *)lastBaselineAnchor {

    return self.view.lastBaselineAnchor;
}

@end
