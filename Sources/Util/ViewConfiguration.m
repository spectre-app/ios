//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "ViewConfiguration.h"


@interface ViewConfiguration ()

@property(nonatomic, readwrite, strong) UIView                               *view;
@property(nonatomic, readwrite, strong) NSMutableArray<NSLayoutConstraint *> *constraints;
@property(nonatomic, readwrite, strong) NSMutableArray<ViewConfiguration *>  *activeConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<ViewConfiguration *>  *inactiveConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *>             *layoutViews;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *>             *displayViews;
@property(nonatomic, readwrite, strong) NSMutableArray<void ( ^ )(UIView *)> *actions;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id>  *activeValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id>  *inactiveValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id>  *activeProperties;
@property(nonatomic, readwrite, strong) NSMutableDictionary<NSString *, id>  *inactiveProperties;

@end

@implementation ViewConfiguration {
}

+ (instancetype)configuration {

    return [[self new] deactivate];
}

+ (instancetype)configurationWithView:(UIView *)view {

    ViewConfiguration *configuration = [self configuration];
    configuration.view = view;
    return configuration;
}

+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(ViewConfiguration *active, ViewConfiguration *inactive))configurationBlocks {

    ViewConfiguration *configuration = [self configurationWithView:view];

    if (configurationBlocks) {
        ViewConfiguration *active   = [self configurationWithView:view];
        ViewConfiguration *inactive = [self configurationWithView:view];
        configurationBlocks( active, inactive );
        [configuration applyViewConfiguration:active active:YES];
        [configuration applyViewConfiguration:inactive active:NO];
    }

    return configuration;
}

- (instancetype)init {

    if (!(self = [super init]))
        return nil;

    self.constraints            = [NSMutableArray new];
    self.activeConfigurations   = [NSMutableArray new];
    self.inactiveConfigurations = [NSMutableArray new];
    self.layoutViews            = [NSMutableArray new];
    self.displayViews           = [NSMutableArray new];
    self.actions                = [NSMutableArray new];
    self.activeValues           = [NSMutableDictionary new];
    self.inactiveValues         = [NSMutableDictionary new];
    self.activeProperties       = [NSMutableDictionary new];

    return self;
}

- (instancetype)constrainTo:(NSLayoutConstraint *)constraint {

    [self.constraints addObject:constraint];
    return self;
}

- (instancetype)compressionResistancePriority {

    return [self compressionResistancePriorityHorizontal:UILayoutPriorityRequired vertical:UILayoutPriorityRequired];
}

- (instancetype)compressionResistancePriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical {

    self.activeProperties[@"compressionResistance.horizontal"] = @(horizontal);
    self.activeProperties[@"compressionResistance.vertical"]   = @(vertical);
    return self;
}

- (instancetype)huggingPriority {

    return [self huggingPriorityHorizontal:UILayoutPriorityRequired vertical:UILayoutPriorityRequired];
}

- (instancetype)huggingPriorityHorizontal:(UILayoutPriority)horizontal vertical:(UILayoutPriority)vertical {

    self.activeProperties[@"hugging.horizontal"] = @(horizontal);
    self.activeProperties[@"hugging.vertical"]   = @(vertical);
    return self;
}

- (instancetype)set:(nullable id)value forKey:(NSString *)key {

    return [self set:value forKey:key reverses:NO];
}

- (instancetype)set:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses {

    self.activeValues[key] = value?: [NSNull null];

    if (reverses)
        self.inactiveValues[key] = [self.view valueForKeyPath:key]?: [NSNull null];

    return self;
}

- (instancetype)applyViewConfiguration:(ViewConfiguration *)configuration {

    return [self applyViewConfiguration:configuration active:YES];
}

- (instancetype)applyViewConfiguration:(ViewConfiguration *)configuration active:(BOOL)active {

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

- (instancetype)needsDisplay:(UIView *)layoutView {

    [self.displayViews addObject:layoutView];
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
        [self.view unanimated:^{
            [self activate];
        }];

    return self;
}

- (instancetype)activateFromParent:(ViewConfiguration *)parent {

    PearlMainQueue( ^{
        for (ViewConfiguration *inactiveConfiguration in self.inactiveConfigurations)
            [inactiveConfiguration deactivateFromParent:self];

        if (self.constraints)
            self.view.translatesAutoresizingMaskIntoConstraints = NO;

        UILayoutPriority oldPriority, newPriority;
        if ((newPriority = [self.activeProperties[@"compressionResistance.horizontal"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [self.view contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal]) != newPriority) {
                self.inactiveProperties[@"compressionResistance.horizontal"] = @(oldPriority);
                [self.view setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
            }
        if ((newPriority = [self.activeProperties[@"compressionResistance.vertical"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [self.view contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical]) != newPriority) {
                self.inactiveProperties[@"compressionResistance.vertical"] = @(oldPriority);
                [self.view setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisVertical];
            }
        if ((newPriority = [self.activeProperties[@"hugging.horizontal"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [self.view contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal]) != newPriority) {
                self.inactiveProperties[@"hugging.horizontal"] = @(oldPriority);
                [self.view setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
            }
        if ((newPriority = [self.activeProperties[@"hugging.vertical"]?: @(-1) floatValue]) >= 0)
            if ((oldPriority = [self.view contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical]) != newPriority) {
                self.inactiveProperties[@"hugging.vertical"] = @(oldPriority);
                [self.view setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisVertical];
            }

        for (NSLayoutConstraint *constraint in self.constraints)
            if (!constraint.active) {
                //trc( @"%@: activating %@", [self.view infoPathName], constraint );
                constraint.active = YES;
            }

        [self.activeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
            id oldValue = [self.view valueForKeyPath:key]?: [NSNull null];
            if ([newValue isEqual:oldValue])
                return;

            if ([[self.inactiveValues allKeys] containsObject:key])
                self.inactiveValues[key] = oldValue;

            //trc( @"%@: %@, %@ -> %@", [self.view infoPathName], key, oldValue, newValue );
            [self.view setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
        }];

        for (ViewAction action in self.actions)
            action( self.view );

        for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration activateFromParent:self];

        self->_activated = YES;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

        if (!parent.view.window)
            [self.view.window layoutIfNeeded];
    } );

    return self;
}

- (instancetype)deactivate {

    return [self deactivateFromParent:nil];
}

- (instancetype)deactivateAnimated:(BOOL)animated {

    if (animated)
        [UIView animateWithDuration:1 animations:^{
            [self activate];
        }];
    else
        [self.view unanimated:^{
            [self activate];
        }];

    return self;
}

- (instancetype)deactivateFromParent:(ViewConfiguration *)parent {

    PearlMainQueue( ^{
        for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration deactivateFromParent:self];

        UILayoutPriority newPriority;
        if ((newPriority = [self.inactiveProperties[@"compressionResistance.horizontal"]?: @(-1) floatValue]) >= 0)
            if ([self.view contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisHorizontal] != newPriority)
                [self.view setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
        if ((newPriority = [self.inactiveProperties[@"compressionResistance.vertical"]?: @(-1) floatValue]) >= 0)
            if ([self.view contentCompressionResistancePriorityForAxis:UILayoutConstraintAxisVertical] != newPriority)
                [self.view setContentCompressionResistancePriority:newPriority forAxis:UILayoutConstraintAxisVertical];
        if ((newPriority = [self.inactiveProperties[@"hugging.horizontal"]?: @(-1) floatValue]) >= 0)
            if ([self.view contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal] != newPriority)
                [self.view setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisHorizontal];
        if ((newPriority = [self.inactiveProperties[@"hugging.vertical"]?: @(-1) floatValue]) >= 0)
            if ([self.view contentHuggingPriorityForAxis:UILayoutConstraintAxisVertical] != newPriority)
                [self.view setContentHuggingPriority:newPriority forAxis:UILayoutConstraintAxisVertical];

        for (NSLayoutConstraint *constraint in self.constraints)
            if (constraint.active) {
                //trc( @"%@: deactivating %@", [self.view infoPathName], constraint );
                constraint.active = NO;
            }

        [self.inactiveValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
            id oldValue = [self.view valueForKeyPath:key]?: [NSNull null];
            if ([newValue isEqual:oldValue])
                return;

            //trc( @"%@: %@, %@ -> %@", [self.view infoPathName], key, oldValue, newValue );
            [self.view setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
        }];

        for (ViewConfiguration *inactiveConfiguration in self.inactiveConfigurations)
            [inactiveConfiguration activateFromParent:self];

        self->_activated = NO;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

        if (!parent.view.window)
            [self.view.window layoutIfNeeded];
    } );

    return self;
}

- (instancetype)constrainToUsing:(NSLayoutConstraint *( ^ )(UIView *superview, UIView *view))constraintBlock {

    return [self constrainTo:constraintBlock( self.view.superview, self.view )];
}

- (instancetype)constrainToAllUsing:(NSArray<NSLayoutConstraint *> *( ^ )(UIView *superview, UIView *view))constraintBlock {

    for (NSLayoutConstraint *constraint in constraintBlock( self.view.superview, self.view ))
        [self constrainTo:constraint];

    return self;
}

- (instancetype)constrainToView:(nullable UIView *)view {

    return [self constrainToView:view withMargins:NO forAttributes:
            NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing | NSLayoutFormatAlignAllBottom];
}

- (instancetype)constrainToMarginsOfView:(nullable UIView *)view {

    return [self constrainToView:view withMargins:YES forAttributes:
            NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing | NSLayoutFormatAlignAllBottom];
}

- (instancetype)constrainToView:(nullable UIView *)host withMargins:(BOOL)margins forAttributes:(NSLayoutFormatOptions)attributes {

    if (attributes & NSLayoutFormatAlignAllTop)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            if (margins)
                return [(host?: superview).layoutMarginsGuide.topAnchor constraintEqualToAnchor:view.topAnchor];
            else
                return [(host?: superview).topAnchor constraintEqualToAnchor:view.topAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllLeading)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            if (margins)
                return [(host?: superview).layoutMarginsGuide.leadingAnchor constraintEqualToAnchor:view.leadingAnchor];
            else
                return [(host?: superview).leadingAnchor constraintEqualToAnchor:view.leadingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllTrailing)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            if (margins)
                return [(host?: superview).layoutMarginsGuide.trailingAnchor constraintEqualToAnchor:view.trailingAnchor];
            else
                return [(host?: superview).trailingAnchor constraintEqualToAnchor:view.trailingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllBottom)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            if (margins)
                return [(host?: superview).layoutMarginsGuide.bottomAnchor constraintEqualToAnchor:view.bottomAnchor];
            else
                return [(host?: superview).bottomAnchor constraintEqualToAnchor:view.bottomAnchor];
        }];

    return self;
}

- (instancetype)constrainToSuperview {

    return [self constrainToView:nil];
}

- (instancetype)constrainToMarginsOfSuperview {

    return [self constrainToSuperviewWithMargins:YES];
}

- (instancetype)constrainToSuperviewWithMargins:(BOOL)margins {

    return [self constrainToSuperviewWithMargins:margins forAttributes:
            NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing | NSLayoutFormatAlignAllBottom];
}

- (instancetype)constrainToSuperviewWithMargins:(BOOL)margins forAttributes:(NSLayoutFormatOptions)attributes {

    return [self constrainToView:nil withMargins:margins forAttributes:attributes];
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
