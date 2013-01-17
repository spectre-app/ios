//
//  MPMainViewController.m
//  MasterPassword
//
//  Created by Maarten Billemont on 24/11/11.
//  Copyright (c) 2011 Lyndir. All rights reserved.
//

#import "MPMainViewController.h"
#import "MPAppDelegate.h"
#import "MPAppDelegate_Key.h"
#import "MPAppDelegate_Store.h"
#import "LocalyticsSession.h"


@implementation MPMainViewController
@synthesize siteInfoHidden = _siteInfoHidden;
@synthesize activeElement = _activeElement;
@synthesize searchDelegate = _searchDelegate;
@synthesize pullDownGesture = _pullDownGesture;
@synthesize pullUpGesture = _pullUpGesture;
@synthesize typeButton = _typeButton;
@synthesize helpView = _helpView;
@synthesize siteName = _siteName;
@synthesize passwordCounter = _passwordCounter;
@synthesize passwordIncrementer = _passwordIncrementer;
@synthesize passwordEdit = _passwordEdit;
@synthesize passwordUpgrade = _passwordUpgrade;
@synthesize contentContainer = _contentContainer;
@synthesize displayContainer = _displayContainer;
@synthesize helpContainer = _helpContainer;
@synthesize contentTipContainer = _copiedContainer;
@synthesize loginNameTipContainer = _loginNameTipContainer;
@synthesize alertContainer = _alertContainer;
@synthesize alertTitle = _alertTitle;
@synthesize alertBody = _alertBody;
@synthesize contentTipBody = _contentTipBody;
@synthesize loginNameTipBody = _loginNameTipBody;
@synthesize toolTipEditIcon = _contentTipEditIcon;
@synthesize searchTipContainer = _searchTipContainer;
@synthesize actionsTipContainer = _actionsTipContainer;
@synthesize typeTipContainer = _typeTipContainer;
@synthesize toolTipContainer = _toolTipContainer;
@synthesize toolTipBody = _toolTipBody;
@synthesize loginNameContainer = _loginNameContainer;
@synthesize loginNameField = _loginNameField;
@synthesize passwordUser = _passwordUser;
@synthesize outdatedAlertContainer = _outdatedAlertContainer;
@synthesize outdatedAlertBack = _outdatedAlertBack;
@synthesize outdatedAlertCloseButton = _outdatedAlertCloseButton;
@synthesize pullUpView = _pullUpView;
@synthesize pullDownView = _pullDownView;
@synthesize contentField = _contentField;
@synthesize contentTipCleanup = _contentTipCleanup, toolTipCleanup = _toolTipCleanup;

#pragma mark - View lifecycle

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {

    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

    [self updateHelpHiddenAnimated:NO];
    [self updateUserHiddenAnimated:NO];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([[segue identifier] isEqualToString:@"MP_ChooseType"])
        ((MPTypeViewController *)[segue destinationViewController]).delegate = self;
}

- (void)viewDidLoad {

    self.searchDelegate                                  = [MPSearchDelegate new];
    self.searchDelegate.delegate                         = self;
    self.searchDelegate.searchDisplayController          = self.searchDisplayController;
    self.searchDelegate.searchTipContainer               = self.searchTipContainer;
    self.searchDisplayController.searchBar.delegate      = self.searchDelegate;
    self.searchDisplayController.delegate                = self.searchDelegate;
    self.searchDisplayController.searchResultsDelegate   = self.searchDelegate;
    self.searchDisplayController.searchResultsDataSource = self.searchDelegate;

    [self.passwordIncrementer addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                 action:@selector(resetPasswordCounter:)]];
    [self.loginNameContainer addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                action:@selector(editLoginName:)]];
    [self.loginNameContainer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyLoginName:)]];
    [self.outdatedAlertBack addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                         action:@selector(infoOutdatedAlert)]];

    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"ui_background"]];

    self.contentField.font = [UIFont fontWithName:@"Exo-Black" size:self.contentField.font.pointSize];

    self.alertBody.text         = nil;
    self.toolTipEditIcon.hidden = YES;

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:self queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      [MPAppDelegate get].activeUser.requiresExplicitMigration = NO;
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:MPNotificationElementUpdated object:nil queue:nil
                                                  usingBlock:^void(NSNotification *note) {
                                                      if (self.activeElement.type & MPElementTypeClassStored
                                                       && ![[self.activeElement.content description] length])
                                                          [self showToolTip:@"Tap        to set a password." withIcon:self.toolTipEditIcon];
                                                      if (self.activeElement.requiresExplicitMigration)
                                                          [self showToolTip:@"Password outdated. Tap to upgrade it." withIcon:nil];
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:MPNotificationSignedOut object:nil queue:nil
                                                  usingBlock:^void(NSNotification *note) {
                                                      self.activeElement = nil;
                                                  }];

    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {

    if ([[MPiOSConfig get].showQuickStart boolValue])
        [[MPAppDelegate get] showGuide];
    if (![MPAppDelegate get].activeUser)
        [self presentViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"MPUnlockViewController"]
                           animated:animated completion:nil];


    if (self.activeElement.user != [MPAppDelegate get].activeUser)
        self.activeElement                      = nil;
    self.searchDisplayController.searchBar.text = nil;

    self.alertContainer.alpha         = 0;
    self.outdatedAlertContainer.alpha = 0;
    self.searchTipContainer.alpha     = 0;
    self.actionsTipContainer.alpha    = 0;
    self.typeTipContainer.alpha       = 0;
    self.toolTipContainer.alpha       = 0;

    [self updateAnimated:animated];

    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {

    inf(@"Main will appear");
    
    // Sometimes, the search bar gets stuck in some sort of first-responder mode that it can't get out of...
    [[self.view.window findFirstResponderInHierarchy] resignFirstResponder];

    // Needed for when we appear after a modal VC dismisses:
    // We can't present until the other modal VC has been fully dismissed and presenting in viewDidAppear will fail.
    if (![MPAppDelegate get].activeUser)
        [self presentViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"MPUnlockViewController"]
                                                animated:animated completion:nil];

    if (![[MPiOSConfig get].actionsTipShown boolValue])
        [UIView animateWithDuration:animated? 0.3f: 0 animations:^{
            self.actionsTipContainer.alpha = 1;
        }                completion:^(BOOL finished) {
            if (finished) {
                [MPiOSConfig get].actionsTipShown = PearlBool(YES);

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.2f animations:^{
                        self.actionsTipContainer.alpha = 0;
                    }                completion:^(BOOL finished_) {
                        if (![self.activeElement.name length])
                            [UIView animateWithDuration:animated? 0.3f: 0 animations:^{
                                self.searchTipContainer.alpha = 1;
                            }];
                    }];
                });
            }
        }];

    if ([MPAppDelegate get].activeUser)
        [MPAlgorithmDefault migrateUser:[MPAppDelegate get].activeUser completion:^(BOOL userRequiresNewMigration) {
            if (userRequiresNewMigration)
                [UIView animateWithDuration:0.3f animations:^{
                    self.outdatedAlertContainer.alpha = 1;
                }];
        }];

    [[LocalyticsSession sharedLocalyticsSession] tagScreen:@"Main"];

    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {

    inf(@"Main will disappear.");
    [super viewWillDisappear:animated];
}

- (void)updateAnimated:(BOOL)animated {

    if (animated) {
        [UIView animateWithDuration:0.3f animations:^{
            [self updateAnimated:NO];
        }];
        return;
    }

    [self setHelpChapter:self.activeElement? @"2": @"1"];
    [self updateHelpHiddenAnimated:NO];

    self.passwordCounter.alpha     = 0;
    self.passwordIncrementer.alpha = 0;
    self.passwordEdit.alpha        = 0;
    self.passwordUpgrade.alpha     = 0;
    self.passwordUser.alpha        = 0;

    if (self.activeElement)
        self.passwordUser.alpha = 0.5f;

    if (self.activeElement.requiresExplicitMigration)
        self.passwordUpgrade.alpha = 0.5f;

    else {
        if (self.activeElement.type & MPElementTypeClassGenerated) {
            self.passwordCounter.alpha     = 0.5f;
            self.passwordIncrementer.alpha = 0.5f;
        } else
            if (self.activeElement.type & MPElementTypeClassStored)
                self.passwordEdit.alpha = 0.5f;
    }

    self.siteName.text = self.activeElement.name;

    self.typeButton.alpha = self.activeElement? 1: 0;
    [self.typeButton setTitle:self.activeElement.typeName
                     forState:UIControlStateNormal];

    if ([self.activeElement isKindOfClass:[MPElementGeneratedEntity class]])
        self.passwordCounter.text = PearlString(@"%u", ((MPElementGeneratedEntity *)self.activeElement).counter);

    self.contentField.enabled = NO;
    self.contentField.text    = @"";
    if (self.activeElement.name && ![self.activeElement isDeleted])
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *description = [self.activeElement.content description];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.contentField.text = description;
            });
        });

    self.loginNameField.enabled = NO;
    self.loginNameField.text    = self.activeElement.loginName;
    self.siteInfoHidden = !self.activeElement || ([[MPiOSConfig get].siteInfoHidden boolValue] && (self.activeElement.loginName
     == nil));
    [self updateUserHiddenAnimated:NO];
}

- (void)toggleHelpAnimated:(BOOL)animated {

    [self setHelpHidden:![[MPiOSConfig get].helpHidden boolValue] animated:animated];
}

- (void)setHelpHidden:(BOOL)hidden animated:(BOOL)animated {

    [MPiOSConfig get].helpHidden = @(hidden);
    [self updateHelpHiddenAnimated:animated];
}

- (void)updateHelpHiddenAnimated:(BOOL)animated {

    if (animated) {
        [UIView animateWithDuration:0.3f animations:^{
            [self updateHelpHiddenAnimated:NO];
        }];
        return;
    }

    self.pullUpView.hidden = ![[MPiOSConfig get].helpHidden boolValue];
    self.pullDownView.hidden = [[MPiOSConfig get].helpHidden boolValue];

    if ([[MPiOSConfig get].helpHidden boolValue]) {
        self.contentContainer.frame = CGRectSetHeight(self.contentContainer.frame, self.view.bounds.size.height - 44 /* search bar */);
        self.helpContainer.frame    = CGRectSetY(self.helpContainer.frame, self.view.bounds.size.height - 20);
    } else {
        self.contentContainer.frame = CGRectSetHeight(self.contentContainer.frame, 225);
        self.helpContainer.frame    = CGRectSetY(self.helpContainer.frame, 246);
    }
}

- (IBAction)toggleUser {

    [self toggleUserAnimated:YES];
}

- (void)toggleUserAnimated:(BOOL)animated {

    [MPiOSConfig get].siteInfoHidden = PearlBool(!self.siteInfoHidden);
    self.siteInfoHidden              = [[MPiOSConfig get].siteInfoHidden boolValue];
    [self updateUserHiddenAnimated:animated];
}

- (void)updateUserHiddenAnimated:(BOOL)animated {

    if (animated) {
        [UIView animateWithDuration:0.3f animations:^{
            [self updateUserHiddenAnimated:NO];
        }];
        return;
    }

    if (self.siteInfoHidden) {
        self.displayContainer.frame = CGRectSetHeight(self.displayContainer.frame, 87);
    } else {
        self.displayContainer.frame = CGRectSetHeight(self.displayContainer.frame, 137);
    }

}

- (void)setHelpChapter:(NSString *)chapter {

#ifdef TESTFLIGHT_SDK_VERSION
    [TestFlight passCheckpoint:PearlString(MPCheckpointHelpChapter @"_%@", chapter)];
#endif
    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointHelpChapter attributes:@{@"chapter": chapter}];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *url = [NSURL URLWithString:[@"#" stringByAppendingString:chapter]
                            relativeToURL:[[NSBundle mainBundle] URLForResource:@"help" withExtension:@"html"]];
        [self.helpView loadRequest:[NSURLRequest requestWithURL:url]];
    });
}

- (IBAction)panHelpDown:(UIPanGestureRecognizer *)sender {

    CGFloat targetY = MIN(self.view.bounds.size.height - 20, 246 + [sender translationInView:self.helpContainer].y);
    BOOL hideHelp = YES;
    if (targetY <= 246) {
        hideHelp = NO;
        targetY = 246;
    }

    self.helpContainer.frame = CGRectSetY(self.helpContainer.frame, targetY);

    if (sender.state == UIGestureRecognizerStateEnded)
        [self setHelpHidden:hideHelp animated:YES];
}

- (IBAction)panHelpUp:(UIPanGestureRecognizer *)sender {

    CGFloat targetY = MAX(246, self.view.bounds.size.height - 20 + [sender translationInView:self.helpContainer].y);
    BOOL hideHelp = NO;
    if (targetY >= self.view.bounds.size.height - 20) {
        hideHelp = YES;
        targetY = self.view.bounds.size.height - 20 ;
    }

    self.helpContainer.frame = CGRectSetY(self.helpContainer.frame, targetY);

    if (sender.state == UIGestureRecognizerStateEnded)
        [self setHelpHidden:hideHelp animated:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {

    NSString *error = [self.helpView stringByEvaluatingJavaScriptFromString:
                                      PearlString(@"setClass('%@');", self.activeElement.typeClassName)];
    if (error.length)
    err(@"helpView.setClass: %@", error);
}

- (void)showContentTip:(NSString *)message withIcon:(UIImageView *)icon {

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.contentTipCleanup)
            self.contentTipCleanup(NO);

        self.contentTipBody.text = message;
        self.contentTipCleanup   = ^(BOOL finished) {
            icon.hidden            = YES;
            self.contentTipCleanup = nil;
        };

        icon.hidden = NO;
        [UIView animateWithDuration:0.3f animations:^{
            self.contentTipContainer.alpha = 1;
        }                completion:^(BOOL finished) {
            if (finished) {
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                    [UIView animateWithDuration:0.2f animations:^{
                        self.contentTipContainer.alpha = 0;
                    }                completion:self.contentTipCleanup];
                });
            }
        }];
    });
}

- (void)showLoginNameTip:(NSString *)message {

    dispatch_async(dispatch_get_main_queue(), ^{
        self.loginNameTipBody.text = message;

        [UIView animateWithDuration:0.3f animations:^{
            self.loginNameTipContainer.alpha = 1;
        }                completion:^(BOOL finished) {
            if (finished) {
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                    [UIView animateWithDuration:0.2f animations:^{
                        self.loginNameTipContainer.alpha = 0;
                    }];
                });
            }
        }];
    });
}

- (void)showToolTip:(NSString *)message withIcon:(UIImageView *)icon {

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.toolTipCleanup)
            self.toolTipCleanup(NO);

        self.toolTipBody.text = message;
        self.toolTipCleanup   = ^(BOOL finished) {
            icon.hidden         = YES;
            self.toolTipCleanup = nil;
        };

        icon.hidden = NO;
        [UIView animateWithDuration:0.3f animations:^{
            self.toolTipContainer.alpha = 1;
        }                completion:^(BOOL finished) {
            if (finished) {
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                    [UIView animateWithDuration:0.2f animations:^{
                        self.toolTipContainer.alpha = 0;
                    }                completion:self.toolTipCleanup];
                });
            }
        }];
    });
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {

    dispatch_async(dispatch_get_main_queue(), ^{
        self.alertTitle.text = title;
        NSRange scrollRange = NSMakeRange(self.alertBody.text.length, message.length);
        if ([self.alertBody.text length])
            self.alertBody.text = [NSString stringWithFormat:@"%@\n\n---\n\n%@", self.alertBody.text, message];
        else
            self.alertBody.text = message;
        [self.alertBody scrollRangeToVisible:scrollRange];

        [UIView animateWithDuration:0.3f animations:^{
            self.alertContainer.alpha = 1;
        }];
    });
}

#pragma mark - Protocols

- (IBAction)copyContent {

    id content = self.activeElement.content;
    if (!content)
        // Nothing to copy.
        return;

    inf(@"Copying password for: %@", self.activeElement.name);
    [UIPasteboard generalPasteboard].string = [content description];

    [self showContentTip:@"Copied!" withIcon:nil];

#ifdef TESTFLIGHT_SDK_VERSION
    [TestFlight passCheckpoint:MPCheckpointCopyToPasteboard];
#endif
    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointCopyToPasteboard
                                               attributes:@{@"type": self.activeElement.typeName,
                                                                         @"version": @(self.activeElement.version)}];
}

- (IBAction)copyLoginName:(UITapGestureRecognizer *)sender {

    if (!self.activeElement.loginName)
        return;

    inf(@"Copying user name for: %@", self.activeElement.name);
    [UIPasteboard generalPasteboard].string = self.activeElement.loginName;

    [self showLoginNameTip:@"Copied!"];

#ifdef TESTFLIGHT_SDK_VERSION
    [TestFlight passCheckpoint:MPCheckpointCopyLoginNameToPasteboard];
#endif
    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointCopyLoginNameToPasteboard
                                               attributes:@{@"type": self.activeElement.typeName,
                                                                         @"version": @(self.activeElement.version)}];
}

- (IBAction)incrementPasswordCounter {

    if (![self.activeElement isKindOfClass:[MPElementGeneratedEntity class]])
     // Not of a type that supports a password counter.
        return;

    [self changeElementWithWarning:
           @"You are incrementing the site's password counter.\n\n"
            @"If you continue, a new password will be generated for this site.  "
            @"You will then need to update your account's old password to this newly generated password.\n\n"
            @"You can reset the counter by holding down on this button."
                                do:^{
                                    inf(@"Incrementing password counter for: %@", self.activeElement.name);
                                    ++((MPElementGeneratedEntity *)self.activeElement).counter;

#ifdef TESTFLIGHT_SDK_VERSION
                                    [TestFlight passCheckpoint:MPCheckpointIncrementPasswordCounter];
#endif
                                    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointIncrementPasswordCounter
                                                                               attributes:@{@"type": self.activeElement.typeName,
                                                                                                         @"version": @(self.activeElement.version)}];
                                }];
}

- (IBAction)resetPasswordCounter:(UILongPressGestureRecognizer *)sender {

    if (sender.state != UIGestureRecognizerStateBegan)
     // Only fire when the gesture was first detected.
        return;
    if (![self.activeElement isKindOfClass:[MPElementGeneratedEntity class]])
     // Not of a type that supports a password counter.
        return;
    if (((MPElementGeneratedEntity *)self.activeElement).counter == 1)
     // Counter has initial value, no point resetting.
        return;

    [self changeElementWithWarning:
           @"You are resetting the site's password counter.\n\n"
            @"If you continue, the site's password will change back to its original value.  "
            @"You will then need to update your account's password back to this original value."
                                do:^{
                                    inf(@"Resetting password counter for: %@", self.activeElement.name);
                                    ((MPElementGeneratedEntity *)self.activeElement).counter = 1;

#ifdef TESTFLIGHT_SDK_VERSION
                                    [TestFlight passCheckpoint:MPCheckpointResetPasswordCounter];
#endif
                                    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointResetPasswordCounter
                                                                               attributes:@{@"type": self.activeElement.typeName,
                                                                                                         @"version": @(self.activeElement.version)}];
                                }];
}

- (IBAction)editLoginName:(UILongPressGestureRecognizer *)sender {

    if (sender.state != UIGestureRecognizerStateBegan)
     // Only fire when the gesture was first detected.
        return;

    if (!self.activeElement)
        return;

    self.loginNameField.enabled = YES;
    [self.loginNameField becomeFirstResponder];

#ifdef TESTFLIGHT_SDK_VERSION
    [TestFlight passCheckpoint:MPCheckpointEditLoginName];
#endif
    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointEditLoginName attributes:@{@"type": self.activeElement.typeName,
                                                                                                             @"version": @(self.activeElement.version)}];
}

- (void)changeElementWithWarning:(NSString *)warning do:(void (^)(void))task; {

    [PearlAlert showAlertWithTitle:@"Password Change" message:warning viewStyle:UIAlertViewStyleDefault
                         initAlert:nil tappedButtonBlock:^(UIAlertView *alert, NSInteger buttonIndex) {
        if (buttonIndex == [alert cancelButtonIndex])
            return;

        [self changeElementWithoutWarningDo:task];
    }                  cancelTitle:[PearlStrings get].commonButtonCancel otherTitles:[PearlStrings get].commonButtonContinue, nil];
}

- (void)changeElementWithoutWarningDo:(void (^)(void))task; {

    // Update element, keeping track of the old password.
    NSString *oldPassword = [self.activeElement.content description];
    task();
    NSString *newPassword = [self.activeElement.content description];
    [[MPAppDelegate get] saveContext];
    [self updateAnimated:YES];

    // Show new and old password.
    if ([oldPassword length] && ![oldPassword isEqualToString:newPassword])
        [self showAlertWithTitle:@"Password Changed!"
                         message:PearlString(@"The password for %@ has changed.\n\n"
                                              @"IMPORTANT:\n"
                                              @"Don't forget to update the site with your new password! "
                                              @"Your old password was:\n"
                                              @"%@", self.activeElement.name, oldPassword)];
}


- (IBAction)editPassword {

    if (self.activeElement.type & MPElementTypeClassStored) {
        self.contentField.enabled = YES;
        [self.contentField becomeFirstResponder];

#ifdef TESTFLIGHT_SDK_VERSION
        [TestFlight passCheckpoint:MPCheckpointEditPassword];
#endif
        [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointEditPassword
                                                   attributes:@{@"type": self.activeElement.typeName,
                                                                             @"version": @(self.activeElement.version)}];
    }
}

- (IBAction)upgradePassword {

    [self changeElementWithWarning:
           self.activeElement.type & MPElementTypeClassGenerated?
            @"You are upgrading the site.\n\n"
             @"This upgrade improves the site's compatibility with the latest version of Master Password.\n\n"
             @"Your password will change and you will need to update your site's account."
            :
            @"You are upgrading the site.\n\n"
             @"This upgrade improves the site's compatibility with the latest version of Master Password."
                                do:^{
                                    inf(@"Explicitly migrating element: %@", self.activeElement);
                                    [self.activeElement migrateExplicitly:YES];

#ifdef TESTFLIGHT_SDK_VERSION
                                    [TestFlight passCheckpoint:MPCheckpointExplicitMigration];
#endif
                                    [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointExplicitMigration
                                                                               attributes:@{@"type": self.activeElement.typeName,
                                                                                                         @"version": @(self.activeElement.version)}];
                                }];
}

- (IBAction)searchOutdatedElements {

    self.searchDisplayController.searchBar.selectedScopeButtonIndex    = MPSearchScopeOutdated;
    self.searchDisplayController.searchBar.searchResultsButtonSelected = YES;
    [self.searchDisplayController.searchBar becomeFirstResponder];
}

- (IBAction)closeAlert {

    [UIView animateWithDuration:0.3f animations:^{
        self.alertContainer.alpha = 0;
    }                completion:^(BOOL finished) {
        if (finished)
            self.alertBody.text = nil;
    }];
}

- (IBAction)closeOutdatedAlert {

    [UIView animateWithDuration:0.3f animations:^{
        self.outdatedAlertContainer.alpha = 0;
    }];
}

- (IBAction)infoOutdatedAlert {

    [self setHelpChapter:@"outdated"];
    [self setHelpHidden:NO animated:YES];
    [self closeOutdatedAlert];
    [MPAppDelegate get].activeUser.requiresExplicitMigration = NO;
}

- (IBAction)action:(id)sender {

    [PearlSheet showSheetWithTitle:nil viewStyle:UIActionSheetStyleAutomatic
                         initSheet:nil
                 tappedButtonBlock:^(UIActionSheet *sheet, NSInteger buttonIndex) {
                     if (buttonIndex == [sheet cancelButtonIndex])
                         return;

                     switch (buttonIndex - [sheet firstOtherButtonIndex]) {
                         case 0: {
                             inf(@"Action: FAQ");
                             [self setHelpChapter:@"faq"];
                             [self setHelpHidden:NO animated:YES];
                             break;
                         }
                         case 1: {
                             inf(@"Action: Guide");
                             [[MPAppDelegate get] showGuide];
                             break;
                         }
                         case 2: {
                             inf(@"Action: Preferences");
                             [self performSegueWithIdentifier:@"UserProfile" sender:self];
                             break;
                         }
                         case 3: {
                             inf(@"Action: Other Apps");
                             [self performSegueWithIdentifier:@"OtherApps" sender:self];
                             break;
                         }
//#if defined(ADHOC) && defined(TESTFLIGHT_SDK_VERSION)
//                         case 4: {
//                             inf(@"Action: Feedback via TestFlight");
//                             [TestFlight openFeedbackView];
//                             break;
//                         }
//                         case 5:
//#else
                         case 4: {
                             inf(@"Action: Feedback via Mail");
                             [[MPAppDelegate get] showFeedbackWithLogs:YES forVC:self];
                             break;
                         }
                         case 5:
//#endif
                         {
                             inf(@"Action: Sign out");
                             [[MPAppDelegate get] signOutAnimated:YES];
                             break;
                         }

                         default: {
                             wrn(@"Unsupported action: %u", buttonIndex - [sheet firstOtherButtonIndex]);
                             break;
                         }
                     }
                 }
                       cancelTitle:[PearlStrings get].commonButtonCancel destructiveTitle:nil otherTitles:
     @"FAQ", @"Tutorial", @"Preferences", @"Other Apps", @"Feedback", @"Sign Out",
     nil];
}

- (MPElementType)selectedType {

    return self.activeElement.type;
}

- (void)didSelectType:(MPElementType)type {

    [self changeElementWithWarning:
           @"You are about to change the type of this password.\n\n"
            @"If you continue, the password for this site will change.  "
            @"You will need to update your account's old password to the new one."
                                do:^{
                                    // Update password type.
                                    if ([self.activeElement.algorithm classOfType:type] != self.activeElement.typeClass)
                                     // Type requires a different class of element.  Recreate the element.
                                        [[MPAppDelegate managedObjectContextIfReady] performBlockAndWait:^{
                                            MPElementEntity *newElement = [NSEntityDescription insertNewObjectForEntityForName:[self.activeElement.algorithm classNameOfType:type]
                                                                                                        inManagedObjectContext:[MPAppDelegate managedObjectContextIfReady]];
                                            newElement.name     = self.activeElement.name;
                                            newElement.user     = self.activeElement.user;
                                            newElement.uses     = self.activeElement.uses;
                                            newElement.lastUsed = self.activeElement.lastUsed;
                                            newElement.version  = self.activeElement.version;

                                            [[MPAppDelegate managedObjectContextIfReady] deleteObject:self.activeElement];
                                            self.activeElement = newElement;
                                        }];

                                    self.activeElement.type = type;

                                    [[NSNotificationCenter defaultCenter] postNotificationName:MPNotificationElementUpdated
                                                                                        object:self.activeElement];
                                }];
}

- (void)didSelectElement:(MPElementEntity *)element {

    inf(@"Selected: %@", element.name);
    dbg(@"Element:\n%@", [element debugDescription]);

    [self closeAlert];

    if (element) {
        self.activeElement = element;
        if ([self.activeElement use] == 1)
            [self showAlertWithTitle:@"New Site" message:
                                                  PearlString(@"You've just created a password for %@.\n\n"
                                                               @"IMPORTANT:\n"
                                                               @"Go to %@ and set or change the password for your account to the password above.\n"
                                                               @"Do this right away: if you forget, you may have trouble remembering which password to use to log into the site later on.",
                                                              self.activeElement.name, self.activeElement.name)];
        [[MPAppDelegate get] saveContext];

        if (![[MPiOSConfig get].typeTipShown boolValue])
            [UIView animateWithDuration:0.5f animations:^{
                self.typeTipContainer.alpha = 1;
            }                completion:^(BOOL finished) {
                if (finished) {
                    [MPiOSConfig get].typeTipShown = PearlBool(YES);

                    dispatch_after(
                     dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                         [UIView animateWithDuration:0.2f animations:^{
                             self.typeTipContainer.alpha = 0;
                         }];
                     });
                }
            }];

        [[NSNotificationCenter defaultCenter] postNotificationName:MPNotificationElementUpdated object:self.activeElement];
#ifdef TESTFLIGHT_SDK_VERSION
        [TestFlight passCheckpoint:PearlString(MPCheckpointUseType @"_%@", self.activeElement.typeShortName)];
#endif
        [[LocalyticsSession sharedLocalyticsSession] tagEvent:MPCheckpointUseType attributes:@{@"type": self.activeElement.typeName,
                                                                                                            @"version": @(self.activeElement.version)}];
    }

    [self.searchDisplayController setActive:NO animated:YES];
    self.searchDisplayController.searchBar.text = self.activeElement.name;

    [self updateAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    if (textField == self.contentField)
        [self.contentField resignFirstResponder];
    if (textField == self.loginNameField)
        [self.loginNameField resignFirstResponder];

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {

    if (textField == self.contentField) {
        self.contentField.enabled = NO;
        if (![self.activeElement isKindOfClass:[MPElementStoredEntity class]])
         // Not of a type whose content can be edited.
            return;

        if ([((MPElementStoredEntity *)self.activeElement).content isEqual:self.contentField.text])
         // Content hasn't changed.
            return;

        [self changeElementWithoutWarningDo:^{
            ((MPElementStoredEntity *)self.activeElement).content = self.contentField.text;
        }];
    }

    if (textField == self.loginNameField) {
        self.loginNameField.enabled = NO;
        if (![[MPiOSConfig get].loginNameTipShown boolValue]) {
            [self showLoginNameTip:@"Tap to copy or hold to edit."];
            [MPiOSConfig get].loginNameTipShown = PearlBool(YES);
        }

        if ([self.loginNameField.text length])
            self.activeElement.loginName = self.loginNameField.text;
        else
            self.activeElement.loginName = nil;

        [[MPAppDelegate get] saveContext];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {

    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([[[request URL] query] isEqualToString:@"outdated"]) {
            [self searchOutdatedElements];
            return NO;
        }

        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }

    return YES;
}

@end
