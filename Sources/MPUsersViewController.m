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
//  MPCombinedViewController.h
//  MPCombinedViewController
//
//  Created by lhunath on 2014-03-08.
//  Copyright, lhunath (Maarten Billemont) 2014. All rights reserved.
//

#import "MPUsersViewController.h"
#import "MPEntities.h"
#import "MPAvatarCell.h"
#import "MPiOSAppDelegate.h"
#import "MPAppDelegate_Store.h"
#import "MPAppDelegate_Key.h"

typedef NS_ENUM(NSUInteger, MPActiveUserState) {
    /** The users are all inactive */
            MPActiveUserStateNone,
    /** The selected user is activated and being logged in with */
            MPActiveUserStateLogin,
    /** The selected user is activated and its user name is being asked for */
            MPActiveUserStateUserName,
    /** The selected user is activated and its new master password is being asked for */
            MPActiveUserStateMasterPasswordChoice,
    /** The selected user is activated and the confirmation of the previously entered master password is being asked for */
            MPActiveUserStateMasterPasswordConfirmation,
    /** The selected user is activated displayed at the top with the rest of the UI inactive */
            MPActiveUserStateMinimized,
};

@interface MPUsersViewController()

@property(nonatomic) MPActiveUserState activeUserState;
@property(nonatomic, strong) NSArray *userIDs;
@property(nonatomic, strong) NSTimer *marqueeTipTimer;
@property(nonatomic, strong) NSArray *marqueeTipTexts;
@property(nonatomic) NSUInteger marqueeTipTextIndex;
@end

@implementation MPUsersViewController {
    __weak id _storeObserver;
    __weak id _mocObserver;
    NSArray *_notificationObservers;
    NSString *_masterPasswordChoice;
    NSOperationQueue *_afterUpdates;
}

- (void)viewDidLoad {

    [super viewDidLoad];

    _afterUpdates = [NSOperationQueue new];

    self.marqueeTipTexts = @[
            strl( @"Press and hold to change password or delete." ),
            strl( @"Shake for emergency generator." ),
    ];

    self.view.backgroundColor = [UIColor clearColor];
    self.avatarCollectionView.allowsMultipleSelection = YES;
    [self.entryField addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];

    [self setActive:YES animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    self.userSelectionContainer.alpha = 0;

    [self observeStore];
    [self registerObservers];
    [self reloadUsers];

    [self.marqueeTipTimer invalidate];
    self.marqueeTipTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(firedMarqueeTimer:) userInfo:nil
                                                           repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {

    [super viewWillDisappear:animated];

    [self removeObservers];
    [self stopObservingStore];

    [self.marqueeTipTimer invalidate];
}

- (void)viewDidLayoutSubviews {

    [super viewDidLayoutSubviews];

    [self.avatarCollectionView.collectionViewLayout invalidateLayout];
}


#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    if (textField == self.entryField) {
        switch (self.activeUserState) {
            case MPActiveUserStateNone: {
                [textField resignFirstResponder];
                break;
            }
            case MPActiveUserStateLogin: {
                [self.entryField endEditing:YES];
                [self selectedAvatar].spinnerActive = YES;
                [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                    BOOL signedIn = NO, isNew = NO;
                    MPUserEntity *user = [self selectedUserInContext:context isNew:&isNew];
                    if (!isNew && user)
                        signedIn = [[MPiOSAppDelegate get] signInAsUser:user saveInContext:context
                                                    usingMasterPassword:self.entryField.text];

                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        self.entryField.text = @"";
                        [self selectedAvatar].spinnerActive = NO;

                        if (!signedIn) {
                            // Sign in failed.
                            [self showEntryTip:strl( @"Looks like a typo!\nTry again; that password was incorrect." )];
                            return;
                        }
                    }];
                }];
                break;
            }
            case MPActiveUserStateUserName: {
                NSString *userName = self.entryField.text;
                if (![userName length]) {
                    // No name entered.
                    [self showEntryTip:strl( @"First, enter your name." )];
                    return NO;
                }

                [self selectedAvatar].name = userName;
                self.activeUserState = MPActiveUserStateMasterPasswordChoice;
                break;
            }
            case MPActiveUserStateMasterPasswordChoice: {
                NSString *masterPassword = self.entryField.text;
                if (![masterPassword length]) {
                    // No password entered.
                    [self showEntryTip:strl( @"Pick a master password." )];
                    return NO;
                }

                self.activeUserState = MPActiveUserStateMasterPasswordConfirmation;
                break;
            }
            case MPActiveUserStateMasterPasswordConfirmation: {
                NSString *masterPassword = self.entryField.text;
                if (![masterPassword length]) {
                    // No password entered.
                    [self showEntryTip:strl( @"Confirm your master password." )];
                    return NO;
                }

                if (![masterPassword isEqualToString:_masterPasswordChoice]) {
                    // Master password confirmation failed.
                    [self showEntryTip:strl( @"Looks like a typo!\nTry again; enter your master password twice." )];
                    self.activeUserState = MPActiveUserStateMasterPasswordChoice;
                    return NO;
                }

                [self.entryField endEditing:YES];
                MPAvatarCell *avatarCell = [self selectedAvatar];
                avatarCell.spinnerActive = YES;
                if (![MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                    BOOL isNew = NO;
                    MPUserEntity *user = [self userForAvatar:avatarCell inContext:context isNew:&isNew];
                    if (isNew) {
                        user = [MPUserEntity insertNewObjectInContext:context];
                        user.avatar = avatarCell.avatar;
                        user.name = avatarCell.name;
                    }

                    BOOL signedIn = [[MPiOSAppDelegate get] signInAsUser:user saveInContext:context usingMasterPassword:masterPassword];
                    PearlMainQueue( ^{
                        self.entryField.text = @"";
                        [self selectedAvatar].spinnerActive = NO;

                        if (!signedIn) {
                            // Sign in failed, shouldn't happen for a new user.
                            [self showEntryTip:strl( @"Couldn't create new user." )];
                            self.activeUserState = MPActiveUserStateNone;
                            return;
                        }
                    } );
                }])
                    avatarCell.spinnerActive = NO;

                break;
            }
            case MPActiveUserStateMinimized: {
                [textField resignFirstResponder];
                break;
            }
        }
    }

    return NO;
}

// This isn't really in UITextFieldDelegate.  We fake it from UITextFieldTextDidChangeNotification.
- (void)textFieldEditingChanged:(UITextField *)textField {

    if (textField == self.entryField) {
        switch (self.activeUserState) {
            case MPActiveUserStateNone:
                break;
            case MPActiveUserStateLogin:
                break;
            case MPActiveUserStateUserName: {
                NSString *userName = self.entryField.text;
                [self selectedAvatar].name = [userName length]? userName: strl( @"New User" );
                break;
            }
            case MPActiveUserStateMasterPasswordChoice:
                break;
            case MPActiveUserStateMasterPasswordConfirmation:
                break;
            case MPActiveUserStateMinimized:
                break;
        }
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.avatarCollectionView) {
        CGSize parentSize = self.avatarCollectionView.bounds.size;
        return CGSizeMake( parentSize.width / 2, parentSize.height );
    }

    Throw(@"unexpected collection view: %@", collectionView);
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {

    if (collectionView == self.avatarCollectionView)
        return [self.userIDs count] + 1;

    Throw(@"unexpected collection view: %@", collectionView);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.avatarCollectionView) {
        MPAvatarCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[MPAvatarCell reuseIdentifier] forIndexPath:indexPath];
        [cell addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)]];
        [self updateModeForAvatar:cell atIndexPath:indexPath animated:NO];
        [self updateVisibilityForAvatar:cell atIndexPath:indexPath animated:NO];

        BOOL isNew = NO;
        MPUserEntity *user = [self userForIndexPath:indexPath inContext:[MPiOSAppDelegate managedObjectContextForMainThreadIfReady]
                                              isNew:&isNew];
        if (isNew)
                // New User
            cell.avatar = MPAvatarAdd;
        else {
            // Existing User
            cell.avatar = user.avatar;
            cell.name = user.name;
        }

        return cell;
    }

    Throw(@"unexpected collection view: %@", collectionView);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.avatarCollectionView) {
        [self.avatarCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                  animated:YES];

        // Deselect all other cells.
        for (NSUInteger otherItem = 0; otherItem < [collectionView numberOfItemsInSection:indexPath.section]; ++otherItem)
            if (otherItem != indexPath.item) {
                NSIndexPath *otherIndexPath = [NSIndexPath indexPathForItem:otherItem inSection:indexPath.section];
                [collectionView deselectItemAtIndexPath:otherIndexPath animated:YES];
            }

        BOOL isNew = NO;
        MPUserEntity *user = [self userForIndexPath:indexPath inContext:[MPiOSAppDelegate managedObjectContextForMainThreadIfReady]
                                              isNew:&isNew];

        if (isNew)
            self.activeUserState = MPActiveUserStateUserName;
        else if (!user.keyID)
            self.activeUserState = MPActiveUserStateMasterPasswordChoice;
        else
            self.activeUserState = MPActiveUserStateLogin;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.avatarCollectionView)
        self.activeUserState = MPActiveUserStateNone;
}

#pragma mark - UILongPressGestureRecognizer

- (void)didLongPress:(UILongPressGestureRecognizer *)recognizer {

    if ([recognizer.view isKindOfClass:[MPAvatarCell class]]) {
        if (recognizer.state != UIGestureRecognizerStateBegan)
                // Don't show the action menu unless the state is Began.
            return;

        MPAvatarCell *avatarCell = (MPAvatarCell *)recognizer.view;
        NSManagedObjectContext *mainContext = [MPiOSAppDelegate managedObjectContextForMainThreadIfReady];

        BOOL isNew = NO;
        MPUserEntity *user = [self userForAvatar:avatarCell inContext:mainContext isNew:&isNew];
        NSManagedObjectID *userID = user.objectID;
        if (isNew || !user)
            return;

        [PearlSheet showSheetWithTitle:user.name
                             viewStyle:UIActionSheetStyleBlackTranslucent
                             initSheet:nil tappedButtonBlock:^(UIActionSheet *sheet, NSInteger buttonIndex) {
            if (buttonIndex == [sheet cancelButtonIndex])
                return;

            if (buttonIndex == [sheet destructiveButtonIndex]) {
                // Delete User
                [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                    NSManagedObject *user_ = [context existingObjectWithID:userID error:NULL];
                    if (user_) {
                        [context deleteObject:user_];
                        [context saveToStore];
                    }
                }];
                return;
            }

            if (buttonIndex == [sheet firstOtherButtonIndex])
                    // Reset Password
                [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                    MPUserEntity *user_ = (MPUserEntity *)[context existingObjectWithID:userID error:NULL];
                    if (user_)
                        [[MPiOSAppDelegate get] changeMasterPasswordFor:user_ saveInContext:context didResetBlock:^{
                            PearlMainQueue( ^{
                                NSIndexPath *avatarIndexPath = [self.avatarCollectionView indexPathForCell:avatarCell];
                                [self.avatarCollectionView selectItemAtIndexPath:avatarIndexPath animated:NO
                                                                  scrollPosition:UICollectionViewScrollPositionNone];
                                [self collectionView:self.avatarCollectionView didSelectItemAtIndexPath:avatarIndexPath];
                            } );
                        }];
                }];
        }                  cancelTitle:[PearlStrings get].commonButtonCancel
                      destructiveTitle:@"Delete User" otherTitles:@"Reset Password", nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {

    if (scrollView == self.avatarCollectionView) {
        CGPoint offsetToCenter = self.avatarCollectionView.center;
        NSIndexPath *avatarIndexPath = [self.avatarCollectionView indexPathForItemAtPoint:
                CGPointPlusCGPoint( *targetContentOffset, offsetToCenter )];
        CGPoint targetCenter = [self.avatarCollectionView layoutAttributesForItemAtIndexPath:avatarIndexPath].center;
        *targetContentOffset = CGPointMinusCGPoint( targetCenter, offsetToCenter );
        NSAssert([self.avatarCollectionView indexPathForItemAtPoint:targetCenter].item == avatarIndexPath.item, @"should be same item");
    }
}

#pragma mark - Private

- (void)showEntryTip:(NSString *)message {

    NSUInteger newlineIndex = [message rangeOfString:@"\n"].location;
    NSString *messageTitle = newlineIndex == NSNotFound? message: [message substringToIndex:newlineIndex];
    NSString *messageSubtitle = newlineIndex == NSNotFound? nil: [message substringFromIndex:newlineIndex];
    self.entryTipTitleLabel.text = messageTitle;
    self.entryTipSubtitleLabel.text = messageSubtitle;

    [UIView animateWithDuration:0.3f animations:^{
        self.entryTipContainer.alpha = 1;
    }                completion:^(BOOL finished) {
        if (finished)
            PearlMainQueueAfter( 4, ^{
                [UIView animateWithDuration:0.3f animations:^{
                    self.entryTipContainer.alpha = 0;
                }];
            } );
    }];
}

- (void)firedMarqueeTimer:(NSTimer *)timer {

    [UIView animateWithDuration:0.5 animations:^{
        self.hintLabel.alpha = 0;
    }                completion:^(BOOL finished) {
        if (!finished)
            return;

        self.hintLabel.text = self.marqueeTipTexts[++self.marqueeTipTextIndex % [self.marqueeTipTexts count]];
        [UIView animateWithDuration:0.5 animations:^{
            self.hintLabel.alpha = 1;
        }];
    }];
}

- (MPAvatarCell *)selectedAvatar {

    NSArray *selectedIndexPaths = self.avatarCollectionView.indexPathsForSelectedItems;
    if (![selectedIndexPaths count]) {
        // No selected user.
        return nil;
    }

    return (MPAvatarCell *)[self.avatarCollectionView cellForItemAtIndexPath:selectedIndexPaths.firstObject];
}

- (MPUserEntity *)selectedUserInContext:(NSManagedObjectContext *)context isNew:(BOOL *)isNew {

    MPAvatarCell *selectedAvatar = [self selectedAvatar];
    if (!selectedAvatar) {
        // No selected user.
        *isNew = NO;
        return nil;
    }

    return [self userForAvatar:selectedAvatar inContext:context isNew:isNew];
}

- (MPUserEntity *)userForAvatar:(MPAvatarCell *)cell inContext:(NSManagedObjectContext *)context isNew:(BOOL *)isNew {

    return [self userForIndexPath:[self.avatarCollectionView indexPathForCell:cell] inContext:context isNew:isNew];
}

- (MPUserEntity *)userForIndexPath:(NSIndexPath *)indexPath inContext:(NSManagedObjectContext *)context isNew:(BOOL *)isNew {

    if ((*isNew = indexPath.item >= [self.userIDs count]))
        return nil;

    NSError *error = nil;
    MPUserEntity *user = (MPUserEntity *)[context existingObjectWithID:self.userIDs[indexPath.item] error:&error];
    if (error)
    wrn(@"Failed to load user into context: %@", error);

    return user;
}

- (void)updateAvatars {

    for (NSIndexPath *indexPath in self.avatarCollectionView.indexPathsForVisibleItems)
        [self updateAvatarAtIndexPath:indexPath];
}

- (void)updateAvatarAtIndexPath:(NSIndexPath *)indexPath {

    MPAvatarCell *cell = (MPAvatarCell *)[self.avatarCollectionView cellForItemAtIndexPath:indexPath];
    [self updateModeForAvatar:cell atIndexPath:indexPath animated:NO];
    [self updateVisibilityForAvatar:cell atIndexPath:indexPath animated:NO];
}

- (void)updateModeForAvatar:(MPAvatarCell *)avatarCell atIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {

    switch (self.activeUserState) {
        case MPActiveUserStateNone: {
            [self.avatarCollectionView deselectItemAtIndexPath:indexPath animated:YES];
            [avatarCell setMode:MPAvatarModeLowered animated:animated];
            break;
        }
        case MPActiveUserStateLogin:
        case MPActiveUserStateUserName:
        case MPActiveUserStateMasterPasswordChoice:
        case MPActiveUserStateMasterPasswordConfirmation: {
            if ([self.avatarCollectionView.indexPathsForSelectedItems containsObject:indexPath])
                [avatarCell setMode:MPAvatarModeRaisedAndActive animated:animated];
            else
                [avatarCell setMode:MPAvatarModeRaisedButInactive animated:animated];
            break;
        }
        case MPActiveUserStateMinimized: {
            if ([self.avatarCollectionView.indexPathsForSelectedItems containsObject:indexPath])
                [avatarCell setMode:MPAvatarModeRaisedAndMinimized animated:animated];
            else
                [avatarCell setMode:MPAvatarModeRaisedAndHidden animated:animated];
            break;
        }
    }
}

- (void)updateVisibilityForAvatar:(MPAvatarCell *)cell atIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {

    CGFloat current = [self.avatarCollectionView layoutAttributesForItemAtIndexPath:indexPath].center.x -
                      self.avatarCollectionView.contentOffset.x;
    CGFloat max = self.avatarCollectionView.bounds.size.width;

    CGFloat visibility = MAX(0, MIN( 1, 1 - ABS( current / (max / 2) - 1 ) ));
    [cell setVisibility:visibility animated:animated];

    if (cell.newUser) {
        self.previousAvatarButton.alpha = cell.mode == MPAvatarModeRaisedAndActive? visibility * 0.7f: 0;
        self.nextAvatarButton.alpha = cell.mode == MPAvatarModeRaisedAndActive? visibility * 0.7f: 0;
    }
}

- (void)afterUpdatesMainQueue:(void (^)(void))block {

    [_afterUpdates addOperationWithBlock:^{
        PearlMainQueue( block );
    }];
}

- (void)registerObservers {

    if ([_notificationObservers count])
        return;

    Weakify(self);
    _notificationObservers = @[
            [[NSNotificationCenter defaultCenter]
                    addObserverForName:UIApplicationWillResignActiveNotification object:nil
                                 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                Strongify(self);

//                [self emergencyCloseAnimated:NO];
                self.userSelectionContainer.alpha = 0;
            }],
            [[NSNotificationCenter defaultCenter]
                    addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                                 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                Strongify(self);

                [self reloadUsers];

                [UIView animateWithDuration:1 animations:^{
                    self.userSelectionContainer.alpha = 1;
                }];
            }],
    ];

    [self observeKeyPath:@"avatarCollectionView.contentOffset" withBlock:
            ^(id from, id to, NSKeyValueChange cause, MPUsersViewController *_self) {
                [_self updateAvatars];
            }];
}

- (void)removeObservers {

    for (id observer in _notificationObservers)
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    _notificationObservers = nil;

    [self removeKeyPathObservers];
}

- (void)observeStore {

    Weakify(self);

    NSManagedObjectContext *mainContext = [MPiOSAppDelegate managedObjectContextForMainThreadIfReady];
    [UIView animateWithDuration:0.3f animations:^{
        self.avatarCollectionView.alpha = mainContext? 1: 0;
    }];
    if (mainContext && self.storeLoadingActivity.isAnimating)
        [self.storeLoadingActivity stopAnimating];
    if (!mainContext && !self.storeLoadingActivity.isAnimating)
        [self.storeLoadingActivity startAnimating];

    if (!_mocObserver && mainContext)
        _mocObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:mainContext
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                    Strongify(self);
                    NSSet *insertedObjects = note.userInfo[NSInsertedObjectsKey];
                    NSSet *deletedObjects = note.userInfo[NSDeletedObjectsKey];
                    if ([[NSSetUnion(insertedObjects, deletedObjects)
                            filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
                                return [evaluatedObject isKindOfClass:[MPUserEntity class]];
                            }]] count])
                        [self reloadUsers];
                }];
    if (!_storeObserver)
        _storeObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:USMStoreDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                    Strongify(self);
                    [self reloadUsers];
                }];
}

- (void)stopObservingStore {

    if (_mocObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_mocObserver];
    if (_storeObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_storeObserver];
}

- (void)reloadUsers {

    [self afterUpdatesMainQueue:^{
        [self observeStore];
        [MPiOSAppDelegate managedObjectContextForMainThreadPerformBlockAndWait:^(NSManagedObjectContext *mainContext) {
            NSError *error = nil;
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass( [MPUserEntity class] )];
            fetchRequest.sortDescriptors = @[
                    [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector( @selector(lastUsed) ) ascending:NO]
            ];
            NSArray *users = [mainContext executeFetchRequest:fetchRequest error:&error];
            if (!users) {
                err(@"Failed to load users: %@", error);
                self.userIDs = nil;
            }

            NSMutableArray *userIDs = [NSMutableArray arrayWithCapacity:[users count]];
            for (MPUserEntity *user in users)
                [userIDs addObject:user.objectID];
            self.userIDs = userIDs;
        }];
    }];
}

#pragma mark - Properties

- (void)setActive:(BOOL)active {

    [self setActive:active animated:NO];
}

- (void)setActive:(BOOL)active animated:(BOOL)animated {

    _active = active;
    dbg(@"active -> %d", active);

    if (active)
        [self setActiveUserState:MPActiveUserStateNone animated:animated];
    else
        [self setActiveUserState:MPActiveUserStateMinimized animated:animated];
}

- (void)setUserIDs:(NSArray *)userIDs {

    _userIDs = userIDs;
    dbg(@"userIDs -> %lu", (unsigned long)[userIDs count]);

    PearlMainQueue( ^{
        BOOL isNew = NO;
        NSManagedObjectID *selectUserID = [MPiOSAppDelegate get].activeUserOID;
        if (!selectUserID)
            selectUserID = [self selectedUserInContext:[MPiOSAppDelegate managedObjectContextForMainThreadIfReady]
                                                 isNew:&isNew].objectID;
        [self.avatarCollectionView reloadData];

        NSUInteger selectedAvatarItem = isNew? [_userIDs count]: selectUserID? [_userIDs indexOfObject:selectUserID]: NSNotFound;
        if (selectedAvatarItem != NSNotFound)
            [self.avatarCollectionView selectItemAtIndexPath:[NSIndexPath indexPathForItem:selectedAvatarItem inSection:0] animated:NO
                                              scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];

        [UIView animateWithDuration:0.3f animations:^{
            self.userSelectionContainer.alpha = 1;
        }];
    } );
}

- (void)setActiveUserState:(MPActiveUserState)activeUserState {

    [self setActiveUserState:activeUserState animated:YES];
}

- (void)setActiveUserState:(MPActiveUserState)activeUserState animated:(BOOL)animated {

    _activeUserState = activeUserState;
    _masterPasswordChoice = nil;

    if (activeUserState != MPActiveUserStateMinimized && (!self.active || [MPiOSAppDelegate get].activeUserOID)) {
        [[MPiOSAppDelegate get] signOutAnimated:YES];
        return;
    }

    [_afterUpdates setSuspended:YES];
    dbg(@"suspend updates");
    __block BOOL requestFirstResponder = NO;
    [UIView animateWithDuration:animated? 0.4f: 0 animations:^{
        MPAvatarCell *selectedAvatar = [self selectedAvatar];

        // Set avatar modes.
        for (NSUInteger item = 0; item < [self.avatarCollectionView numberOfItemsInSection:0]; ++item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:0];
            MPAvatarCell *avatarCell = (MPAvatarCell *)[self.avatarCollectionView cellForItemAtIndexPath:indexPath];
            [self updateModeForAvatar:avatarCell atIndexPath:indexPath animated:animated];
            [self updateVisibilityForAvatar:avatarCell atIndexPath:indexPath animated:animated];

            if (selectedAvatar && avatarCell == selectedAvatar)
                [self.avatarCollectionView scrollToItemAtIndexPath:indexPath
                                                  atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
        }

        // Set the entry container's contents.
        switch (activeUserState) {
            case MPActiveUserStateNone:
                dbg(@"activeUserState -> none");
                break;
            case MPActiveUserStateLogin: {
                dbg(@"activeUserState -> login");
                self.entryLabel.text = strl( @"Enter your master password:" );
                self.entryField.text = nil;
                self.entryField.secureTextEntry = YES;
                self.entryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                break;
            }
            case MPActiveUserStateUserName: {
                dbg(@"activeUserState -> userName");
                self.entryLabel.text = strl( @"Enter your full name:" );
                self.entryField.text = nil;
                self.entryField.secureTextEntry = NO;
                self.entryField.autocapitalizationType = UITextAutocapitalizationTypeWords;
                break;
            }
            case MPActiveUserStateMasterPasswordChoice: {
                dbg(@"activeUserState -> masterPasswordChoice");
                self.entryLabel.text = strl( @"Choose your master password:" );
                self.entryField.text = nil;
                self.entryField.secureTextEntry = YES;
                self.entryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                break;
            }
            case MPActiveUserStateMasterPasswordConfirmation: {
                dbg(@"activeUserState -> masterPasswordConfirmation");
                _masterPasswordChoice = self.entryField.text;
                self.entryLabel.text = strl( @"Confirm your master password:" );
                self.entryField.text = nil;
                self.entryField.secureTextEntry = YES;
                self.entryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                break;
            }
            case MPActiveUserStateMinimized:
                dbg(@"activeUserState -> minimized");
                break;
        }

        // Manage the entry container depending on whether a user is activate or not.
        switch (activeUserState) {
            case MPActiveUserStateNone: {
                self.navigationBarToTopConstraint.priority = UILayoutPriorityDefaultHigh;
                self.avatarCollectionView.scrollEnabled = YES;
                self.entryContainer.alpha = 0;
                self.footerContainer.alpha = 1;
                break;
            }
            case MPActiveUserStateLogin:
            case MPActiveUserStateUserName:
            case MPActiveUserStateMasterPasswordChoice:
            case MPActiveUserStateMasterPasswordConfirmation: {
                self.navigationBarToTopConstraint.priority = UILayoutPriorityDefaultHigh;
                self.avatarCollectionView.scrollEnabled = NO;
                self.entryContainer.alpha = 1;
                self.footerContainer.alpha = 1;
                requestFirstResponder = YES;
                break;
            }
            case MPActiveUserStateMinimized: {
                self.navigationBarToTopConstraint.priority = 1;
                self.avatarCollectionView.scrollEnabled = NO;
                self.entryContainer.alpha = 0;
                self.footerContainer.alpha = 0;
                break;
            }
        }
        [self.navigationBarToTopConstraint apply];
    }                completion:^(BOOL finished) {
        dbg(@"resume updates");
        [_afterUpdates setSuspended:NO];
    }];

    UIResponder *oldFirstResponder = [UIResponder findFirstResponder];
    if (requestFirstResponder)
        [self.entryField becomeFirstResponder];
    else
        [self.entryField resignFirstResponder];
    UIResponder *newFirstResponder = [UIResponder findFirstResponder];
    if (newFirstResponder != oldFirstResponder)
    dbg(@"first responder: %@ -> %@", oldFirstResponder, newFirstResponder);
}

#pragma mark - Actions

- (IBAction)changeAvatar:(UIButton *)sender {

    if (sender == self.previousAvatarButton)
        --[self selectedAvatar].avatar;
    if (sender == self.nextAvatarButton)
        ++[self selectedAvatar].avatar;
}

@end
