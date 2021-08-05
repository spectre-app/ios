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

#import <UIKit/UIKit.h>

@interface UIView(Spectre)

@property(nonatomic) UIEdgeInsets alignmentRectInsets;
@property(nonatomic) UIEdgeInsets alignmentRectOutsets;
@property(nonatomic, readonly) CGRect alignmentRect;

@end
