//
// Created by Maarten Billemont on 2018-03-17.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "UIUtils+MP.h"


CGPathRef CGPathCreateBetween(CGRect fromRect, CGRect toRect) {

    CGPoint          p1, p2;
    CGMutablePathRef path = CGPathCreateMutable();

    if (ABS( CGRectGetMinX( fromRect ) - CGRectGetMinX( toRect ) ) <
        ABS( CGRectGetMaxX( fromRect ) - CGRectGetMaxX( toRect ) )) {
        p1 = CGRectGetLeft( fromRect );
        p2 = CGRectGetTopLeft( toRect );
        CGPathMoveToPoint( path, NULL, p1.x, p1.y );
        CGPathAddLineToPoint( path, NULL, p2.x, p1.y );
        CGPathAddLineToPoint( path, NULL, p2.x, p2.y );
        p2 = CGRectGetBottomLeft( toRect );
        CGPathAddLineToPoint( path, NULL, p2.x, p2.y );
    }
    else {
        p1 = CGRectGetRight( fromRect );
        p2 = CGRectGetTopRight( toRect );
        CGPathMoveToPoint( path, NULL, p1.x, p1.y );
        CGPathAddLineToPoint( path, NULL, p2.x, p1.y );
        CGPathAddLineToPoint( path, NULL, p2.x, p2.y );
        p2 = CGRectGetBottomRight( toRect );
        CGPathAddLineToPoint( path, NULL, p2.x, p2.y );
    }

    return path;
}
