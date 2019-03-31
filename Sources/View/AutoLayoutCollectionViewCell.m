//
// Created by Maarten Billemont on 2018-05-18.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "AutoLayoutCollectionViewCell.h"


@implementation AutoLayoutCollectionViewCell {
    BOOL               needsLayoutInvalidation;
    NSLayoutConstraint *widthConstraint;
}

- (void)setFullWidth:(BOOL)fullWidth {

    if ((_fullWidth = fullWidth)) {
        if (!widthConstraint)
            widthConstraint = [[self.contentView.widthAnchor constraintEqualToConstant:
                                                                     UIScreen.mainScreen.bounds.size.width] activate];
    }
    else if (widthConstraint) {
        [widthConstraint deactivate];
        widthConstraint = nil;
    }
}

- (void)invalidateLayoutAnimated:(BOOL)animated {

    if (needsLayoutInvalidation)
        return;

    needsLayoutInvalidation = YES;
    PearlMainQueueOperation( ^{
        UICollectionView *collectionView = [UICollectionView findAsSuperviewOf:self];
        [UIView animateWithDuration:animated? 0.3: 0 animations:^{
            [self setNeedsUpdateConstraints];
            [collectionView performBatchUpdates:nil completion:nil];
            [collectionView layoutIfNeeded];
        }];

        self->needsLayoutInvalidation = NO;
    } );
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {

    // Fit the cell width to collection view's space.
    if (widthConstraint) {
        UICollectionView           *collectionView = [UICollectionView findAsSuperviewOf:self];
        UICollectionViewFlowLayout *flowLayout     =
                                           [collectionView.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]?
                                                   (UICollectionViewFlowLayout *) collectionView.collectionViewLayout: nil;
        if (collectionView)
            // collectionView.collectionViewLayout.collectionViewContentSize.width triggers some kind of strange side-effect.
            widthConstraint.constant = collectionView.bounds.size.width
                                       - flowLayout.sectionInset.left - flowLayout.sectionInset.right;
    }

    // The layout's size is used as a minimum for auto-layout, preventing it from shrinking.
    layoutAttributes.size = UILayoutFittingCompressedSize;

    return [super preferredLayoutAttributesFittingAttributes:layoutAttributes];
}

@end
