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
//  MPPasswordsViewController.h
//  MPPasswordsViewController
//
//  Created by lhunath on 2014-03-08.
//  Copyright, lhunath (Maarten Billemont) 2014. All rights reserved.
//

#import "MPPasswordsViewController.h"
#import "MPiOSAppDelegate.h"
#import "MPAppDelegate_Store.h"
#import "MPPasswordLargeCell.h"
#import "MPPasswordTypesCell.h"
#import "MPPasswordSmallCell.h"
#import "MPPopdownSegue.h"
#import "MPAppDelegate_Key.h"
#import "MPCoachmarkViewController.h"

@interface MPPasswordsViewController()<NSFetchedResultsControllerDelegate>

@property(nonatomic, strong) IBOutlet UINavigationBar *navigationBar;
@property(nonatomic, readonly) NSString *query;

@end

@implementation MPPasswordsViewController {
    __weak id _storeObserver;
    __weak id _mocObserver;
    NSArray *_notificationObservers;
    __weak UITapGestureRecognizer *_passwordsDismissRecognizer;
    NSFetchedResultsController *_fetchedResultsController;
    BOOL _exactMatch;
    NSMutableDictionary *_fetchedUpdates;
    UIColor *_backgroundColor;
    UIColor *_darkenedBackgroundColor;
    __weak UIViewController *_popdownVC;
}

#pragma mark - Life

- (void)viewDidLoad {

    [super viewDidLoad];

    _fetchedUpdates = [NSMutableDictionary dictionaryWithCapacity:4];
    _backgroundColor = self.passwordCollectionView.backgroundColor;
    _darkenedBackgroundColor = [_backgroundColor colorWithAlphaComponent:0.6f];
    _coachmark = [MPCoachmark coachmarkForClass:[self class] version:0];

    self.view.backgroundColor = [UIColor clearColor];
    self.passwordCollectionView.contentInset = UIEdgeInsetsMake( 108, 0, 0, 0 );
    [self.passwordCollectionView automaticallyAdjustInsetsForKeyboard];
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    [self registerObservers];
    [self observeStore];
    [self updatePasswords];
}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];

    PearlMainQueueAfter( 1, ^{
        if (!self.coachmark.coached)
            [self performSegueWithIdentifier:@"coachmarks" sender:self];
    } );
}

- (void)viewWillDisappear:(BOOL)animated {

    [super viewWillDisappear:animated];

    [self removeObservers];
    [self stopObservingStore];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.identifier isEqualToString:@"popdown"])
        _popdownVC = segue.destinationViewController;
    if ([segue.identifier isEqualToString:@"coachmarks"])
        ((MPCoachmarkViewController *)segue.destinationViewController).coachmark = self.coachmark;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.passwordCollectionView) {
        if (indexPath.item < 3 ||
            indexPath.item >= ((id<NSFetchedResultsSectionInfo>)self.fetchedResultsController.sections[indexPath.section]).numberOfObjects)
            return CGSizeMake( 300, 100 );

        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)collectionViewLayout;
        return CGSizeMake( (300 - layout.minimumInteritemSpacing) / 2, 44 );
    }

    Throw(@"Unexpected collection view: %@", collectionView);
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {

    if (collectionView == self.passwordCollectionView)
        return [self.fetchedResultsController.sections count];

    Throw(@"Unexpected collection view: %@", collectionView);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {

    if (collectionView == self.passwordCollectionView)
        return ![MPiOSAppDelegate get].activeUserOID? 0:
               ((id<NSFetchedResultsSectionInfo>)self.fetchedResultsController.sections[section]).numberOfObjects +
               (!_exactMatch && [[self query] length]? 1: 0);

    Throw(@"Unexpected collection view: %@", collectionView);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    if (collectionView == self.passwordCollectionView) {
        [UIView setAnimationsEnabled:NO];
        MPPasswordElementCell *cell;
        if (indexPath.item < ((id<NSFetchedResultsSectionInfo>)self.fetchedResultsController.sections[indexPath.section]).numberOfObjects) {
            MPElementEntity *element = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if (indexPath.item < 3)
                cell = [MPPasswordTypesCell dequeueCellForElement:element fromCollectionView:collectionView atIndexPath:indexPath];
            else
                cell = [MPPasswordSmallCell dequeueCellForElement:element fromCollectionView:collectionView atIndexPath:indexPath];
        }
        else
                // New Site.
            cell = [MPPasswordTypesCell dequeueCellForTransientSite:self.query fromCollectionView:collectionView atIndexPath:indexPath];

        [UIView setAnimationsEnabled:YES];
        return cell;
    }

    Throw(@"Unexpected collection view: %@", collectionView);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    MPPasswordElementCell *cell = (MPPasswordElementCell *)[collectionView cellForItemAtIndexPath:indexPath];
    NSString *newSiteName = cell.transientSite;
    if (newSiteName) {
        [PearlAlert showAlertWithTitle:@"Create Site"
                               message:strf( @"Do you want to create a new site named:\n%@", newSiteName )
                             viewStyle:UIAlertViewStyleDefault
                             initAlert:nil tappedButtonBlock:^(UIAlertView *alert, NSInteger buttonIndex) {
            if (buttonIndex == [alert cancelButtonIndex]) {
                // Cancel
                NSIndexPath *indexPath_ = [collectionView indexPathForCell:cell];
                [collectionView selectItemAtIndexPath:indexPath_ animated:NO
                                       scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                [collectionView deselectItemAtIndexPath:indexPath_ animated:YES];
                return;
            }

            // Create
            [[MPiOSAppDelegate get] addElementNamed:newSiteName completion:^(MPElementEntity *element) {
                PearlMainQueue( ^{
                    [PearlOverlay showTemporaryOverlayWithTitle:strf( @"Added %@", newSiteName ) dismissAfter:2];
                    PearlMainQueueAfter( 0.2f, ^{
                        NSIndexPath *indexPath_ = [collectionView indexPathForCell:cell];
                        [collectionView selectItemAtIndexPath:indexPath_ animated:NO
                                               scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                        [collectionView deselectItemAtIndexPath:indexPath_ animated:YES];
                    } );
                } );
            }];
        }                  cancelTitle:[PearlStrings get].commonButtonCancel otherTitles:[PearlStrings get].commonButtonYes, nil];
        return;
    }

    MPElementEntity *element = [cell mainElement];
    if (!element) {
        [collectionView selectItemAtIndexPath:indexPath animated:NO
                               scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
        [collectionView deselectItemAtIndexPath:indexPath animated:YES];
        return;
    }

    inf(@"Copying password for: %@", element.name);
    MPCheckpoint( MPCheckpointCopyToPasteboard, @{
            @"type"      : NilToNSNull(element.typeName),
            @"version"   : @(element.version),
            @"emergency" : @NO
    } );

    [element resolveContentUsingKey:[MPAppDelegate_Shared get].key result:^(NSString *result) {
        if (![result length]) {
            PearlMainQueue( ^{
                NSIndexPath *indexPath_ = [collectionView indexPathForCell:cell];
                [collectionView selectItemAtIndexPath:indexPath_ animated:NO
                                       scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                [collectionView deselectItemAtIndexPath:indexPath_ animated:YES];
            } );
            return;
        }

        [UIPasteboard generalPasteboard].string = result;
        PearlMainQueue( ^{
            [PearlOverlay showTemporaryOverlayWithTitle:@"Password Copied" dismissAfter:2];
            PearlMainQueueAfter( 0.2f, ^{
                NSIndexPath *indexPath_ = [collectionView indexPathForCell:cell];
                [collectionView selectItemAtIndexPath:indexPath_ animated:NO
                                       scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
                [collectionView deselectItemAtIndexPath:indexPath_ animated:YES];

                [MPiOSAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *context) {
                    [[cell elementInContext:context] use];
                    [context saveToStore];
                }];
            } );
        } );
    }];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {

    if (controller == _fetchedResultsController) {
        dbg(@"controllerWillChangeContent");
        NSAssert(![_fetchedUpdates count], @"Didn't finish a previous change update?");
        if ([_fetchedUpdates count]) {
            [_fetchedUpdates removeAllObjects];
            [self.passwordCollectionView reloadData];
        }
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {

    if (controller == _fetchedResultsController) {
        NSMutableArray *updatesForType = _fetchedUpdates[@(type)];
        if (!updatesForType)
            _fetchedUpdates[@(type)] = updatesForType = [NSMutableArray new];

        [updatesForType addObject:@{
                @"object"       : NilToNSNull(anObject),
                @"indexPath"    : NilToNSNull(indexPath),
                @"newIndexPath" : NilToNSNull(newIndexPath)
        }];
        switch (type) {
            case NSFetchedResultsChangeInsert:
                dbg(@"didChangeObject: insert: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeDelete:
                dbg(@"didChangeObject: delete: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeMove:
                dbg(@"didChangeObject: move: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeUpdate:
                dbg(@"didChangeObject: update: %@", [updatesForType lastObject]);
                break;
        }
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

    if (controller == _fetchedResultsController) {
        NSMutableArray *updatesForType = _fetchedUpdates[@(type << 3)];
        if (!updatesForType)
            _fetchedUpdates[@(type << 3)] = updatesForType = [NSMutableArray new];

        [updatesForType addObject:@{
                @"sectionInfo" : NilToNSNull(sectionInfo),
                @"index"       : @(sectionIndex)
        }];
        switch (type) {
            case NSFetchedResultsChangeInsert:
                dbg(@"didChangeSection: insert: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeDelete:
                dbg(@"didChangeSection: delete: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeMove:
                dbg(@"didChangeSection: move: %@", [updatesForType lastObject]);
                break;
            case NSFetchedResultsChangeUpdate:
                dbg(@"didChangeSection: update: %@", [updatesForType lastObject]);
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {

    if (controller == _fetchedResultsController && [_fetchedUpdates count]) {
        [self.passwordCollectionView performBatchUpdates:^{
            [_fetchedUpdates enumerateKeysAndObjectsUsingBlock:^(NSNumber *typeNumber, NSArray *updates, BOOL *stop) {
                BOOL updateIsSection = NO;
                NSFetchedResultsChangeType type = [typeNumber unsignedIntegerValue];
                if (type >= 1 << 3) {
                    updateIsSection = YES;
                    type = type >> 3;
                }

                switch (type) {
                    case NSFetchedResultsChangeInsert:
                        if (updateIsSection) {
                            for (NSDictionary *update in updates) {
                                dbg(@"insertSections:%@", update[@"index"]);
                                [self.passwordCollectionView insertSections:
                                        [NSIndexSet indexSetWithIndex:[update[@"index"] unsignedIntegerValue]]];
                            }
                        }
                        else {
                            dbg(@"insertItemsAtIndexPaths:%@", [updates valueForKeyPath:@"@unionOfObjects.newIndexPath"]);
                            [self.passwordCollectionView insertItemsAtIndexPaths:[updates valueForKeyPath:@"@unionOfObjects.newIndexPath"]];
                        }
                        break;
                    case NSFetchedResultsChangeDelete:
                        if (updateIsSection) {
                            for (NSDictionary *update in updates) {
                                dbg(@"deleteSections:%@", update[@"index"]);
                                [self.passwordCollectionView deleteSections:
                                        [NSIndexSet indexSetWithIndex:[update[@"index"] unsignedIntegerValue]]];
                            }
                        }
                        else {
                            dbg(@"deleteItemsAtIndexPaths:%@", [updates valueForKeyPath:@"@unionOfObjects.indexPath"]);
                            [self.passwordCollectionView deleteItemsAtIndexPaths:[updates valueForKeyPath:@"@unionOfObjects.indexPath"]];
                        }
                        break;
                    case NSFetchedResultsChangeMove:
                        NSAssert(!updateIsSection, @"Move not supported for sections");
                        for (NSDictionary *update in updates) {
                            dbg(@"moveItemAtIndexPath:%@ toIndexPath:%@", update[@"indexPath"], update[@"newIndexPath"]);
                            [self.passwordCollectionView moveItemAtIndexPath:update[@"indexPath"] toIndexPath:update[@"newIndexPath"]];
                        }
                        break;
                    case NSFetchedResultsChangeUpdate:
                        NSAssert(!updateIsSection, @"Update not supported for sections");
                        dbg(@"reloadItemsAtIndexPaths:%@", [updates valueForKeyPath:@"@unionOfObjects.indexPath"]);
                        [self.passwordCollectionView reloadItemsAtIndexPaths:[updates valueForKeyPath:@"@unionOfObjects.indexPath"]];
                        break;
                }
            }];
        }                                     completion:nil];
        [_fetchedUpdates removeAllObjects];
    }
}


#pragma mark - UIScrollViewDelegate

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {

    if (searchBar == self.passwordsSearchBar) {
        searchBar.text = nil;
        return YES;
    }

    return NO;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {

    if (searchBar == self.passwordsSearchBar) {
        self.originalQuery = self.query;
        self.passwordsSearchBar.showsCancelButton = YES;
        _passwordsDismissRecognizer = [self.view dismissKeyboardForField:self.passwordsSearchBar onTouchForced:NO];

        [UIView animateWithDuration:0.3f animations:^{
            self.passwordCollectionView.backgroundColor = _darkenedBackgroundColor;
        }];
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {

    if (searchBar == self.passwordsSearchBar) {
        self.passwordsSearchBar.showsCancelButton = NO;
        if (_passwordsDismissRecognizer)
            [self.view removeGestureRecognizer:_passwordsDismissRecognizer];

        [UIView animateWithDuration:0.3f animations:^{
            self.passwordCollectionView.backgroundColor = _backgroundColor;
        }];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {

    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {

    [searchBar resignFirstResponder];

    if (searchBar == self.passwordsSearchBar) {
        self.passwordsSearchBar.text = self.originalQuery;
        [self updatePasswords];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {

    if (searchBar == self.passwordsSearchBar)
        [self updatePasswords];
}


#pragma mark - Private

- (void)registerObservers {

    if ([_notificationObservers count])
        return;

    Weakify(self);
    _notificationObservers = @[
            [[NSNotificationCenter defaultCenter]
                    addObserverForName:UIApplicationWillResignActiveNotification object:nil
                                 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                Strongify(self);

                self.passwordSelectionContainer.alpha = 0;
            }],
            [[NSNotificationCenter defaultCenter]
                    addObserverForName:MPSignedOutNotification object:nil
                                 queue:nil usingBlock:^(NSNotification *note) {
                Strongify(self);

                _fetchedResultsController = nil;
                self.passwordsSearchBar.text = nil;
                [self updatePasswords];
            }],
            [[NSNotificationCenter defaultCenter]
                    addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                                 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                Strongify(self);

                [self updatePasswords];
                [UIView animateWithDuration:1 animations:^{
                    self.passwordSelectionContainer.alpha = 1;
                }];
            }],
    ];
}

- (void)removeObservers {

    for (id observer in _notificationObservers)
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    _notificationObservers = nil;
}

- (void)observeStore {

    Weakify(self);

    NSManagedObjectContext *mainContext = [MPiOSAppDelegate managedObjectContextForMainThreadIfReady];
    if (!_mocObserver && mainContext)
        _mocObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:mainContext
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
//                    Strongify(self);
//                    [self updatePasswords];
                }];
    if (!_storeObserver)
        _storeObserver = [[NSNotificationCenter defaultCenter]
                addObserverForName:USMStoreDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                    Strongify(self);
                    _fetchedResultsController = nil;
                    [self updatePasswords];
                }];
}

- (void)stopObservingStore {

    if (_mocObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_mocObserver];
    if (_storeObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_storeObserver];
}

- (void)updatePasswords {

    NSString *query = self.query;
    NSManagedObjectID *activeUserOID = [MPiOSAppDelegate get].activeUserOID;
    if (!activeUserOID) {
        self.passwordsSearchBar.text = nil;
        PearlMainQueue( ^{
            [self.passwordCollectionView reloadData];
            [self.passwordCollectionView setContentOffset:CGPointMake( 0, -self.passwordCollectionView.contentInset.top ) animated:YES];
        } );
        return;
    }

    [self.fetchedResultsController.managedObjectContext performBlock:^{
        NSError *error = nil;
        self.fetchedResultsController.fetchRequest.predicate =
                [query length]?
                [NSPredicate predicateWithFormat:@"user == %@ AND name BEGINSWITH[cd] %@", activeUserOID, query]:
                [NSPredicate predicateWithFormat:@"user == %@", activeUserOID];
        if (![self.fetchedResultsController performFetch:&error])
        err(@"Couldn't fetch elements: %@", error);

        _exactMatch = NO;
        for (MPElementEntity *entity in self.fetchedResultsController.fetchedObjects)
            if ([entity.name isEqualToString:query]) {
                _exactMatch = YES;
                break;
            }

        PearlMainQueue( ^{
            [self.passwordCollectionView performBatchUpdates:^{
                NSInteger fromSections = self.passwordCollectionView.numberOfSections;
                NSInteger toSections = [self numberOfSectionsInCollectionView:self.passwordCollectionView];
                for (int section = 0; section < MAX(toSections, fromSections); section++) {
                    if (section >= fromSections) {
                        dbg(@"insertSections:%d", section);
                        [self.passwordCollectionView insertSections:[NSIndexSet indexSetWithIndex:section]];
                    }
                    else if (section >= toSections) {
                        dbg(@"deleteSections:%d", section);
                        [self.passwordCollectionView deleteSections:[NSIndexSet indexSetWithIndex:section]];
                    }
                    else {
                        dbg(@"reloadSections:%d", section);
                        [self.passwordCollectionView reloadSections:[NSIndexSet indexSetWithIndex:section]];
                    }
                }
            }                                     completion:^(BOOL finished) {
                if (finished)
                    [self.passwordCollectionView setContentOffset:CGPointMake( 0, -self.passwordCollectionView.contentInset.top )
                                                         animated:YES];
            }];
        } );
    }];
}

#pragma mark - Properties

- (NSString *)query {

    return [self.passwordsSearchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSFetchedResultsController *)fetchedResultsController {

    if (!_fetchedResultsController) {
        [MPiOSAppDelegate managedObjectContextForMainThreadPerformBlockAndWait:^(NSManagedObjectContext *mainContext) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass( [MPElementEntity class] )];
            fetchRequest.sortDescriptors = @[
                    [[NSSortDescriptor alloc] initWithKey:NSStringFromSelector( @selector(lastUsed) ) ascending:NO]
            ];
            fetchRequest.fetchBatchSize = 10;
            _fetchedResultsController = [[NSFetchedResultsController alloc]
                    initWithFetchRequest:fetchRequest managedObjectContext:mainContext sectionNameKeyPath:nil cacheName:nil];
            _fetchedResultsController.delegate = self;
        }];
        [self observeStore];
    }

    return _fetchedResultsController;
}

- (void)setActive:(BOOL)active {

    [self setActive:active animated:NO completion:nil];
}

- (void)setActive:(BOOL)active animated:(BOOL)animated completion:(void (^)(BOOL finished))completion {

    _active = active;

    [UIView animateWithDuration:animated? 0.4f: 0 animations:^{
        self.navigationBarToTopConstraint.priority = active? 1: UILayoutPriorityDefaultHigh;
        self.passwordsToBottomConstraint.priority = active? 1: UILayoutPriorityDefaultHigh;

        [self.navigationBarToTopConstraint apply];
        [self.passwordsToBottomConstraint apply];
    }                completion:completion];
}

#pragma mark - Actions

- (IBAction)dismissPopdown:(id)sender {

    if (_popdownVC)
        [[[MPPopdownSegue alloc] initWithIdentifier:@"unwind-popdown" source:_popdownVC destination:self] perform];
    else
        self.popdownToTopConstraint.priority = UILayoutPriorityDefaultHigh;
}

- (IBAction)signOut:(id)sender {

    [[MPiOSAppDelegate get] signOutAnimated:YES];
}

@end
