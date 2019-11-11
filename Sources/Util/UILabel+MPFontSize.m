//
// Created by Maarten Billemont on 2018-05-18.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "UILabel+MPFontSize.h"


//@interface UILabel (MPFontSize_Private)
//
//@property(nonatomic) UIFont *targetFont_mpFontSize;
//@property(nonatomic) UIFont *originalFont_mpFontSize;
//
//@end
//
//@implementation UILabel (MPFontSize)
//
//PearlAssociatedObjectProperty( UIFont*, TargetFont_mpFontSize, targetFont_mpFontSize );
//PearlAssociatedObjectProperty( UIFont*, OriginalFont_mpFontSize, originalFont_mpFontSize );
//
//- (void)setFontSize:(CGFloat)fontSize {
//
//    PearlSwizzleTR( [UILabel class], @selector( intrinsicContentSize ), ^CGSize, (UILabel * self), {
//        @try {
//            if (self.targetFont_mpFontSize)
//                self.font = self.targetFont_mpFontSize;
//            return self.intrinsicContentSize;
//        }
//        @finally {
//            if (self.originalFont_mpFontSize)
//                self.font = self.originalFont_mpFontSize;
//        }
//    }, CGSizeValue );
//
//    CGAffineTransform originalTransform = self.transform;
//    self.originalFont_mpFontSize = self.font;
//    self.targetFont_mpFontSize   = [self.font fontWithSize:fontSize];
//    [self invalidateIntrinsicContentSize];
//
//    [UIView animateWithDuration:0 delay:0 options:0 animations:^{
//        CGFloat scale = fontSize / self.fontSize;
//        self.transform = CGAffineTransformScale( originalTransform, scale, scale );
//    }                completion:^(BOOL finished) {
//        self.transform = originalTransform;
//
//        if (self.targetFont_mpFontSize) {
//            if (finished)
//                self.font = self.targetFont_mpFontSize;
//
//            self.targetFont_mpFontSize = self.originalFont_mpFontSize = nil;
//            [self invalidateIntrinsicContentSize];
//        }
//    }];
//}
//
//- (CGFloat)fontSize {
//
//    return self.font.pointSize;
//};
//
//@end
