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
//  MPLogsViewController.h
//  MPLogsViewController
//
//  Created by lhunath on 2013-04-29.
//  Copyright, lhunath (Maarten Billemont) 2013. All rights reserved.
//

#import "MPLogsViewController.h"
#import "MPiOSAppDelegate.h"
#import "MPAppDelegate_Store.h"

@implementation MPLogsViewController

- (void)viewDidLoad {

    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    PearlAddNotificationObserver( NSUserDefaultsDidChangeNotification, nil, [NSOperationQueue mainQueue],
            ^(MPLogsViewController *self, NSNotification *note) {
                self.levelControl.selectedSegmentIndex = [[MPiOSConfig get].traceMode boolValue]? 1: 0;
            } );

    self.logView.contentInset = UIEdgeInsetsMake( 64, 0, 93, 0 );

    [self refresh:nil];

    self.levelControl.selectedSegmentIndex = [[MPiOSConfig get].traceMode boolValue]? 1: 0;
}

- (void)viewWillDisappear:(BOOL)animated {

    [super viewWillDisappear:animated];

    PearlRemoveNotificationObservers();
}

- (IBAction)toggleLevelControl:(UISegmentedControl *)sender {

    BOOL traceEnabled = (BOOL)self.levelControl.selectedSegmentIndex;
    if (traceEnabled) {
        [PearlAlert showAlertWithTitle:@"Enable Trace Mode?" message:
                        @"Trace mode will log the internal operation of the application.\n"
                                @"Unless you're looking for the cause of a problem, you should leave this off to save memory."
                             viewStyle:UIAlertViewStyleDefault initAlert:nil
                     tappedButtonBlock:^(UIAlertView *alert, NSInteger buttonIndex) {
                         if (buttonIndex == [alert cancelButtonIndex])
                             return;

                         [MPiOSConfig get].traceMode = @YES;
                     } cancelTitle:[PearlStrings get].commonButtonCancel otherTitles:@"Enable Trace", nil];
    }
    else
        [MPiOSConfig get].traceMode = @NO;
}

- (IBAction)refresh:(UIBarButtonItem *)sender {

    self.logView.text = [[PearlLogger get] formatMessagesWithLevel:PearlLogLevelTrace];
}

- (IBAction)mail:(UIBarButtonItem *)sender {

    if ([[MPiOSConfig get].traceMode boolValue]) {
        [PearlAlert showAlertWithTitle:@"Hiding Trace Messages" message:
                        @"Trace-level log messages will not be mailed. "
                                @"These messages contain sensitive and personal information."
                             viewStyle:UIAlertViewStyleDefault initAlert:nil
                     tappedButtonBlock:^(UIAlertView *alert, NSInteger buttonIndex) {
                         [[MPiOSAppDelegate get] openFeedbackWithLogs:YES forVC:self];
                     } cancelTitle:[PearlStrings get].commonButtonOkay otherTitles:nil];
    }
    else
        [[MPiOSAppDelegate get] openFeedbackWithLogs:YES forVC:self];
}

@end
