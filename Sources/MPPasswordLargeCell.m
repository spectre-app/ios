/**
* Copyright Maarten Billemont (http://www.lhunath.com, lhunath@lyndir.com)
*
* See the enclosed file LICENSE for license information (LGPLv3). If you did
* not receive this file, see http://www.gnu.org/licenses/lgpl-3.0.txt
*
* @author   Maarten Billemont <lhunath@lyndir.com>
* @license  http://www.gnu.org/licenses/lgpl-3.0.txt
*/

//
//  MPAvatarCell.h
//  MPAvatarCell
//
//  Created by lhunath on 2014-03-11.
//  Copyright, lhunath (Maarten Billemont) 2014. All rights reserved.
//

#import "MPPasswordLargeCell.h"
#import "MPiOSAppDelegate.h"
#import "MPAppDelegate_Store.h"
#import "MPPasswordLargeGeneratedCell.h"
#import "MPPasswordLargeStoredCell.h"
#import "MPPasswordTypesCell.h"

@implementation MPPasswordLargeCell

#pragma mark - Life

+ (instancetype)dequeueCellWithType:(MPElementType)type fromCollectionView:(UICollectionView *)collectionView
                        atIndexPath:(NSIndexPath *)indexPath {

    NSString *reuseIdentifier;
    if (type & MPElementTypeClassGenerated)
        reuseIdentifier = NSStringFromClass( [MPPasswordLargeGeneratedCell class] );
    else if (type & MPElementTypeClassStored)
        reuseIdentifier = NSStringFromClass( [MPPasswordLargeStoredCell class] );
    else
        Throw( @"Unexpected password type: %@", [MPAlgorithmDefault nameOfType:type] );

    MPPasswordLargeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    cell.type = type;

    return cell;
}

- (void)awakeFromNib {

    [super awakeFromNib];

    self.layer.cornerRadius = 5;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowRadius = 5;
    self.layer.shadowOpacity = 0;
    self.layer.shadowColor = [UIColor whiteColor].CGColor;

    [self prepareForReuse];
}

- (void)prepareForReuse {

    _contentFieldMode = 0;
    self.contentField.text = nil;

    [super prepareForReuse];
}

- (void)update {

    self.loginButton.alpha = 0;
    self.upgradeButton.alpha = 0;
    self.nameLabel.text = @"";
    self.typeLabel.text = @"";
    self.contentField.text = @"";
    self.contentField.placeholder = nil;
    self.contentField.enabled = self.contentFieldMode == MPContentFieldModeUser;
    self.loginButton.selected = self.contentFieldMode == MPContentFieldModeUser;

    switch (self.contentFieldMode) {
        case MPContentFieldModePassword: {
            if (self.type & MPElementTypeClassStored)
                self.contentField.placeholder = strl( @"Set custom password" );
            else if (self.type & MPElementTypeClassGenerated)
                self.contentField.placeholder = strl( @"Generating..." );
            break;
        }
        case MPContentFieldModeUser: {
            self.contentField.placeholder = strl( @"Enter your login name" );
            break;
        }
    }
}

- (void)updateWithTransientSite:(NSString *)siteName {

    [self update];

    self.nameLabel.text = strl( @"%@ - Tap to create", siteName );
    self.typeLabel.text = [MPAlgorithmDefault nameOfType:self.type];

    [self resolveContentOfCellTypeForTransientSite:siteName usingKey:[MPiOSAppDelegate get].key result:^(NSString *string) {
        PearlMainQueue( ^{ self.contentField.text = string; } );
    }];
}

- (void)updateWithElement:(MPElementEntity *)mainElement {

    [self update];

    if (!mainElement)
        return;

    self.loginButton.alpha = 1;
    if (mainElement.requiresExplicitMigration)
        self.upgradeButton.alpha = 1;

    self.nameLabel.text = mainElement.name;
    if (self.type == (MPElementType)NSNotFound)
        self.typeLabel.text = @"Delete";
    else
        self.typeLabel.text = [mainElement.algorithm nameOfType:self.type];

    switch (self.contentFieldMode) {
        case MPContentFieldModePassword: {
            MPKey *key = [MPiOSAppDelegate get].key;
            if (self.type == mainElement.type)
                [mainElement resolveContentUsingKey:key result:^(NSString *string) {
                    PearlMainQueue( ^{ self.contentField.text = string; } );
                }];
            else
                [self resolveContentOfCellTypeForElement:mainElement usingKey:key result:^(NSString *string) {
                    PearlMainQueue( ^{ self.contentField.text = string; } );
                }];
            break;
        }
        case MPContentFieldModeUser: {
            self.contentField.text = mainElement.loginName;
            break;
        }
    }
}

- (void)resolveContentOfCellTypeForTransientSite:(NSString *)siteName usingKey:(MPKey *)key result:(void ( ^ )(NSString *))resultBlock {

    resultBlock( nil );
}

- (void)resolveContentOfCellTypeForElement:(MPElementEntity *)element usingKey:(MPKey *)key result:(void ( ^ )(NSString *))resultBlock {

    resultBlock( nil );
}

- (MPElementEntity *)saveContentTypeWithElement:(MPElementEntity *)element saveInContext:(NSManagedObjectContext *)context {

    return [[MPiOSAppDelegate get] changeElement:element saveInContext:context toType:self.type];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {

    if (textField == self.contentField) {
        NSString *newContent = textField.text;
        textField.enabled = NO;

        if (self.contentFieldMode == MPContentFieldModeUser)
            [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                MPElementEntity *element = [[MPPasswordTypesCell findAsSuperviewOf:self] elementInContext:context];
                if (!element)
                    return;

                element.loginName = newContent;
                [context saveToStore];

                PearlMainQueue( ^{
                    [self updateAnimated:YES];
                    [PearlOverlay showTemporaryOverlayWithTitle:@"Login Updated" dismissAfter:2];
                } );
            }];
    }
}

#pragma mark - Actions

- (IBAction)doUser:(id)sender {

    switch (self.contentFieldMode) {
        case MPContentFieldModePassword: {
            self.contentFieldMode = MPContentFieldModeUser;
            break;
        }
        case MPContentFieldModeUser: {
            self.contentFieldMode = MPContentFieldModePassword;
            break;
        }
    }
}

- (IBAction)doUpgrade:(UIButton *)sender {

    [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
        if ([[[MPPasswordTypesCell findAsSuperviewOf:self] elementInContext:context] migrateExplicitly:YES]) {
            [context saveToStore];

            PearlMainQueue( ^{
                [[MPPasswordTypesCell findAsSuperviewOf:self] reloadData];
                [PearlOverlay showTemporaryOverlayWithTitle:@"Site Upgraded" dismissAfter:2];
            } );
        }
        else
            PearlMainQueue( ^{
                [PearlOverlay showTemporaryOverlayWithTitle:@"Site Not Upgraded" dismissAfter:2];
            } );
    }];
}

#pragma mark - Properties

- (void)setContentFieldMode:(MPContentFieldMode)contentFieldMode {

    if (_contentFieldMode == contentFieldMode)
        return;

    _contentFieldMode = contentFieldMode;

    [[MPPasswordTypesCell findAsSuperviewOf:self] reloadData];
}

@end
