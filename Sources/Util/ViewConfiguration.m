//
// Created by Maarten Billemont on 2018-03-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "ViewConfiguration.h"

@interface ViewConfiguration()

@property(nonatomic, readwrite, strong) UIView *view;
@property(nonatomic, readwrite, strong) ViewConfiguration *parent;
@property(nonatomic, readwrite, strong) ViewConfiguration *active;
@property(nonatomic, readwrite, strong) ViewConfiguration *inactive;
@property(nonatomic, readwrite, strong) NSMutableArray <NSLayoutConstraint *> *constraints;
@property(nonatomic, readwrite, strong) NSMutableDictionary <NSString *, NSValue *> *activeValues;
@property(nonatomic, readwrite, strong) NSMutableDictionary <NSString *, NSValue *> *inactiveValues;

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

    if (configurationBlocks)
        configurationBlocks( configuration.active, configuration.inactive );

    return [configuration deactivate];
}

- (instancetype)init {

    if (!(self = [super init]))
        return nil;

    self.constraints = [NSMutableArray new];
    self.activeValues = [NSMutableDictionary new];
    self.inactiveValues = [NSMutableDictionary new];

    return self;
}

- (instancetype)addConstraint:(NSLayoutConstraint *)constraint {

    [self.constraints addObject:constraint];
    return self;
}

- (instancetype)addValue:(NSValue *)value forKey:(NSString *)key {

    self.activeValues[key] = value;
    return self;
}

- (instancetype)activate {

    [_inactive deactivate];

    if (self.constraints)
        self.view.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSLayoutConstraint *constraint in self.constraints)
        constraint.active = YES;

    [self.activeValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSValue *value, BOOL *stop) {
        self.inactiveValues[key] = [self.view valueForKeyPath:key];
        [self.view setValue:value forKeyPath:key];
    }];

    [_active activate];

    if (!self.parent)
        [self.view.window layoutIfNeeded];

    return self;
}

- (instancetype)deactivate {

    [_active deactivate];

    for (NSLayoutConstraint *constraint in self.constraints)
        constraint.active = NO;

    [self.inactiveValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSValue *value, BOOL *stop) {
        [self.view setValue:value forKeyPath:key];
    }];

    [_inactive activate];

    if (!self.parent)
        [self.view.window layoutIfNeeded];

    return self;
}

- (ViewConfiguration *)active {

    return _active?: (_active = [[self class] configurationWithParent:self]);
}

- (ViewConfiguration *)inactive {

    return _inactive?: (_inactive = [[self class] configurationWithParent:self]);
}

- (instancetype)addUsing:(NSLayoutConstraint *( ^ )(UIView *view))constraintBlock {

    return [self addConstraint:constraintBlock( self.view )];
}

- (instancetype)addFloat:(CGFloat)value forKey:(NSString *)key {

    return [self addValue:@(value) forKey:key];
}

- (instancetype)addPoint:(CGPoint)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithCGPoint:value] forKey:key];
}

- (instancetype)addSize:(CGSize)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithCGSize:value] forKey:key];
}

- (instancetype)addRect:(CGRect)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithCGRect:value] forKey:key];
}

- (instancetype)addTransform:(CGAffineTransform)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithCGAffineTransform:value] forKey:key];
}

- (instancetype)addEdgeInsets:(UIEdgeInsets)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithUIEdgeInsets:value] forKey:key];
}

- (instancetype)addOffset:(UIOffset)value forKey:(NSString *)key {

    return [self addValue:[NSValue valueWithUIOffset:value] forKey:key];
}

@end
