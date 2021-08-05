// =============================================================================
// Created by Maarten Billemont on 2020-06-04.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

#import "UIView+Spectre.h"
#import <objc/runtime.h>

@interface UIView(Spectre_Swift)

- (NSString *)describeWithShort:(BOOL)s;

@end

@implementation UIView(Spectre)

+ (void)load {

    [super load];

    // FIXME: https://feedbackassistant.apple.com/feedback/9022967
    // Setting isHidden from an animation block for children of a UIStackView
    // causes the UIStackView to break layout and the view's hidden property to not update reliably.
    Method originalMethod = class_getInstanceMethod( [UIView class], @selector(setHidden:) );
    Method swizzledMethod = class_getInstanceMethod( [UIView class], @selector(_setHidden:) );
    method_exchangeImplementations( originalMethod, swizzledMethod );
}

- (void)_setHidden:(BOOL)hidden {
    if (self.isHidden != hidden) {
        [UIView performWithoutAnimation:^{
            [self _setHidden:hidden];
        }];
    }
}

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
