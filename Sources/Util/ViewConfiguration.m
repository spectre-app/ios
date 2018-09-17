//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "ViewConfiguration.h"

@interface ViewConfiguration()

@property(nonatomic, readwrite, strong) UIView *view;
@property(nonatomic, readwrite, strong) ViewConfiguration *parent;
@property(nonatomic, readwrite, strong) NSMutableArray<NSLayoutConstraint *> *constraints;
@property(nonatomic, readwrite, strong) NSMutableArray<ViewConfiguration *> *activeConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<ViewConfiguration *> *inactiveConfigurations;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *> *layoutViews;
@property(nonatomic, readwrite, strong) NSMutableArray<UIView *> *displayViews;
@property(nonatomic, readwrite, strong) NSMutableArray<void ( ^ )(UIView *)> *actions;
@property(nonatomic, readwrite, strong) NSMutableDictionary <NSString *, id> *activeValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary <NSString *, id> *inactiveValues;

@end

@implementation ViewConfiguration {
}

+ (instancetype)configuration {

    return [self configurationWithParent:nil];
}

+ (instancetype)configurationWithView:(UIView *)view {

    return [self configurationWithView:view configurations:nil];
}

+ (instancetype)configurationWithParent:(ViewConfiguration *)parent {

    ViewConfiguration *configuration = [self configurationWithView:parent.view configurations:nil];
    configuration.parent = parent;
    return configuration;
}

+ (instancetype)configurationWithView:(UIView *)view
                       configurations:(nullable void ( ^ )(ViewConfiguration *active, ViewConfiguration *inactive))configurationBlocks {

    ViewConfiguration *configuration = [self new];
    configuration.view = view;

    if (configurationBlocks) {
        ViewConfiguration *active = [[self class] configurationWithParent:configuration];
        ViewConfiguration *inactive = [[self class] configurationWithParent:configuration];
        [configuration.activeConfigurations addObject:active];
        [configuration.inactiveConfigurations addObject:inactive];
        configurationBlocks( active, inactive );
    }

    return [configuration deactivate];
}

- (instancetype)init {

    if (!(self = [super init]))
        return nil;

    self.constraints = [NSMutableArray new];
    self.activeConfigurations = [NSMutableArray new];
    self.inactiveConfigurations = [NSMutableArray new];
    self.layoutViews = [NSMutableArray new];
    self.displayViews = [NSMutableArray new];
    self.actions = [NSMutableArray new];
    self.activeValues = [NSMutableDictionary new];
    self.inactiveValues = [NSMutableDictionary new];

    return self;
}

- (instancetype)constrainTo:(NSLayoutConstraint *)constraint {

    [self.constraints addObject:constraint];
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

- (instancetype)doAction:(void ( ^ )(UIView *view))action {

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

    PearlMainQueue( ^{
        for (ViewConfiguration *inactiveConfiguration in self.inactiveConfigurations)
            [inactiveConfiguration deactivate];

        if (self.constraints)
            self.view.translatesAutoresizingMaskIntoConstraints = NO;

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

        for (
                void(^action)(UIView *)
                in self.actions)
            action( self.view );

        for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration activate];

        self->_activated = YES;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

        if (!self.parent)
            [self.view.window layoutIfNeeded];
    } );

    return self;
}

- (instancetype)deactivate {

    PearlMainQueue( ^{
        for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
            [activeConfiguration deactivate];

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
            [inactiveConfiguration activate];

        self->_activated = NO;

        for (UIView *view in self.layoutViews)
            [view setNeedsLayout];
        for (UIView *view in self.displayViews)
            [view setNeedsDisplay];

//        if (!self.parent)
//            [self.view.window layoutIfNeeded];
    } );

    return self;
}

- (instancetype)constrainToUsing:(NSLayoutConstraint *( ^ )(UIView *superview, UIView *view))constraintBlock {

    return [self constrainTo:constraintBlock( self.view.superview, self.view )];
}

- (instancetype)constrainToSuperview {

    return [self constrainToSuperviewForAttributes:
            NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing | NSLayoutFormatAlignAllBottom];
}

- (instancetype)constrainToSuperviewForAttributes:(NSLayoutFormatOptions)attributes {

    if (attributes & NSLayoutFormatAlignAllTop)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.topAnchor constraintEqualToAnchor:view.topAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllLeading)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.leadingAnchor constraintEqualToAnchor:view.leadingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllTrailing)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.trailingAnchor constraintEqualToAnchor:view.trailingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllBottom)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.bottomAnchor constraintEqualToAnchor:view.bottomAnchor];
        }];

    return self;
}

- (instancetype)constrainToSuperviewMargins {

    return [self constrainToSuperviewMarginsForAttributes:
            NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing | NSLayoutFormatAlignAllBottom];
}

- (instancetype)constrainToSuperviewMarginsForAttributes:(NSLayoutFormatOptions)attributes {

    if (attributes & NSLayoutFormatAlignAllTop)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.layoutMarginsGuide.topAnchor constraintEqualToAnchor:view.topAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllLeading)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.layoutMarginsGuide.leadingAnchor constraintEqualToAnchor:view.leadingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllTrailing)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.layoutMarginsGuide.trailingAnchor constraintEqualToAnchor:view.trailingAnchor];
        }];
    if (attributes & NSLayoutFormatAlignAllBottom)
        [self constrainToUsing:^NSLayoutConstraint *(UIView *superview, UIView *view) {
            return [superview.layoutMarginsGuide.bottomAnchor constraintEqualToAnchor:view.bottomAnchor];
        }];

    return self;
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
