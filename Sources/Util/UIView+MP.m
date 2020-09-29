//
// Created by Maarten Billemont on 2020-06-04.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

#import "UIView+MP.h"
#import <objc/runtime.h>

@interface UIView(MP_Swift)

- (NSString *)describeWithShort:(BOOL)s;

@end

@implementation UIView(MP)

- (UIEdgeInsets)alignmentRectInsets {

    return UIEdgeInsetsMake(
            -self.alignmentRectOutsets.top, -self.alignmentRectOutsets.left,
            -self.alignmentRectOutsets.bottom, -self.alignmentRectOutsets.right );
}

- (void)setAlignmentRectInsets:(UIEdgeInsets)alignmentRectInsets {

    self.alignmentRectOutsets = UIEdgeInsetsMake(
            -alignmentRectInsets.top, -alignmentRectInsets.left,
            -alignmentRectInsets.bottom, -alignmentRectInsets.right );
}

- (UIEdgeInsets)alignmentRectOutsets {

    return [objc_getAssociatedObject( self, @selector( alignmentRectOutsets ) ) UIEdgeInsetsValue];
}

- (void)setAlignmentRectOutsets:(UIEdgeInsets)alignmentRectOutsets {

    objc_setAssociatedObject( self, @selector( alignmentRectOutsets ),
            [NSValue valueWithUIEdgeInsets:alignmentRectOutsets], OBJC_ASSOCIATION_RETAIN );
}

- (CGRect)alignmentRect {

    return [self alignmentRectForFrame:self.frame];
}

- (NSString *)accessibilityIdentifier {

    if ([NSThread currentThread].threadDictionary[@"accessibilityIdentifier"])
        return nil;

    @try {
        [NSThread currentThread].threadDictionary[@"accessibilityIdentifier"] = @YES;
        return [self describeWithShort:NO];
    }
    @finally {
        [NSThread currentThread].threadDictionary[@"accessibilityIdentifier"] = nil;
    }
}

@end
