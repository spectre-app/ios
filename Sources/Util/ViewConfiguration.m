//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "ViewConfiguration.h"

@interface ViewConfiguration()

@property(nonatomic, readwrite, strong) UIView *view;
@property(nonatomic, readwrite, assign) BOOL activated;
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

- (instancetype)addConstraint:(NSLayoutConstraint *)constraint {

    [self.constraints addObject:constraint];
    return self;
}

- (instancetype)add:(nullable id)value forKey:(NSString *)key {

    return [self add:value forKey:key reverses:NO];
}

- (instancetype)add:(nullable id)value forKey:(NSString *)key reverses:(BOOL)reverses {

    self.activeValues[key] = value?: [NSNull null];

    if (reverses)
        self.inactiveValues[key] = [self.view valueForKeyPath:key]?: [NSNull null];

    return self;
}

- (instancetype)addViewConfiguration:(ViewConfiguration *)configuration {

    return [self addViewConfiguration:configuration active:YES];
}

- (instancetype)addViewConfiguration:(ViewConfiguration *)configuration active:(BOOL)active {

    [(active? self.activeConfigurations: self.inactiveConfigurations) addObject:configuration];
    return self;
}

- (instancetype)addNeedsLayout:(UIView *)view {

    [self.layoutViews addObject:view];
    return self;
}

- (instancetype)addNeedsDisplay:(UIView *)view {

    [self.displayViews addObject:view];
    return self;
}

- (instancetype)addAction:(void ( ^ )(UIView *view))action {

    [self.actions addObject:[action copy]];
    return self;
}

- (instancetype)becomeFirstResponder {

    return [self addAction:^(UIView *view) {
        [view becomeFirstResponder];
    }];
}

- (instancetype)resignFirstResponder {

    return [self addAction:^(UIView *view) {
        [view resignFirstResponder];
    }];
}

- (instancetype)activate {

    for (ViewConfiguration *inactiveConfiguration in self.inactiveConfigurations)
        [inactiveConfiguration deactivate];

    if (self.constraints)
        self.view.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSLayoutConstraint *constraint in self.constraints)
        if (!constraint.active) {
            trc( @"%@: activating %@", [self.view infoPathName], constraint );
            constraint.active = YES;
        }

    [self.activeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
        id oldValue = [self.view valueForKeyPath:key]?: [NSNull null];
        if ([newValue isEqual:oldValue])
            return;

        if ([[self.inactiveValues allKeys] containsObject:key])
            self.inactiveValues[key] = oldValue;

        trc( @"%@: %@, %@ -> %@", [self.view infoPathName], key, oldValue, newValue );
        [self.view setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
    }];

    for (void(^action)(UIView *) in self.actions)
        action( self.view );

    for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
        [activeConfiguration activate];

    self.activated = YES;

    for (UIView *view in self.layoutViews)
        [view setNeedsLayout];
    for (UIView *view in self.displayViews)
        [view setNeedsDisplay];

    if (!self.parent)
        [self.view.window layoutIfNeeded];

    return self;
}

- (instancetype)deactivate {

    for (ViewConfiguration *activeConfiguration in self.activeConfigurations)
        [activeConfiguration deactivate];

    for (NSLayoutConstraint *constraint in self.constraints)
        if (constraint.active) {
            trc( @"%@: deactivating %@", [self.view infoPathName], constraint );
            constraint.active = NO;
        }

    [self.inactiveValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newValue, BOOL *stop) {
        id oldValue = [self.view valueForKeyPath:key]?: [NSNull null];
        if ([newValue isEqual:oldValue])
            return;

        trc( @"%@: %@, %@ -> %@", [self.view infoPathName], key, oldValue, newValue );
        [self.view setValue:newValue == [NSNull null]? nil: newValue forKeyPath:key];
    }];

    for (ViewConfiguration *inactiveConfiguration in self.inactiveConfigurations)
        [inactiveConfiguration activate];

    self.activated = NO;

    for (UIView *view in self.layoutViews)
        [view setNeedsLayout];
    for (UIView *view in self.displayViews)
        [view setNeedsDisplay];

    if (!self.parent)
        [self.view.window layoutIfNeeded];

    return self;
}

//- (instancetype)addUsing:(NSLayoutConstraint *( ^ )(UIView *view, UIView *superview))constraintBlock {
//
//    return [self addConstraint:constraintBlock( self.view, self.view.superview )];
//}
//
- (instancetype)addUsing:(NSLayoutConstraint *( ^ )(UIView *view))constraintBlock {

    return [self addConstraint:constraintBlock( self.view )];
}

- (instancetype)addFloat:(CGFloat)value forKey:(NSString *)key {

    return [self add:@(value) forKey:key];
}

- (instancetype)addPoint:(CGPoint)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithCGPoint:value] forKey:key];
}

- (instancetype)addSize:(CGSize)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithCGSize:value] forKey:key];
}

- (instancetype)addRect:(CGRect)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithCGRect:value] forKey:key];
}

- (instancetype)addTransform:(CGAffineTransform)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithCGAffineTransform:value] forKey:key];
}

- (instancetype)addEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithUIEdgeInsets:value] forKey:key];
}

- (instancetype)addOffset:(UIOffset)value forKey:(NSString *)key {

    return [self add:[NSValue valueWithUIOffset:value] forKey:key];
}

@end
