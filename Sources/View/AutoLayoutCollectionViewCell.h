//
// Created by Maarten Billemont on 2018-05-18.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Automatically size the layout attributes for this cell to its auto-layout size.
 *
 * Note: to enable auto-layout, set your layout's \c estimatedItemSize to non-zero (eg. \c UICollectionViewFlowLayoutAutomaticSize).
 */
@interface AutoLayoutCollectionViewCell : UICollectionViewCell

/**
 * Set to \c YES to automatically fill the layout's available width.
 */
@property(nonatomic) BOOL fullWidth;

/**
 * Indicate that the cell's auto-layout size may have changed and the collection view's layout should be updated accordingly.
 *
 * Override \c -updateConstraints if you need to apply constraint adjustments to reflect some internal state changes.
 */
- (void)invalidateLayoutAnimated:(BOOL)animated;

@end
