//
//  MPPreferencesViewController.h
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 04/06/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPTypeViewController.h"

@interface MPPreferencesViewController : UITableViewController

@property(weak, nonatomic) IBOutlet UISwitch *savePasswordSwitch;
@property(weak, nonatomic) IBOutlet UISwitch *touchIDSwitch;
@property(weak, nonatomic) IBOutlet UITableViewCell *signOutCell;
@property(weak, nonatomic) IBOutlet UITableViewCell *feedbackCell;
@property(weak, nonatomic) IBOutlet UITableViewCell *showHelpCell;
@property(weak, nonatomic) IBOutlet UITableViewCell *exportCell;
@property(weak, nonatomic) IBOutlet UITableViewCell *checkInconsistencies;
@property(weak, nonatomic) IBOutlet UIImageView *avatarImage;
@property(weak, nonatomic) IBOutlet UISegmentedControl *generatedTypeControl;
@property(weak, nonatomic) IBOutlet UISegmentedControl *storedTypeControl;

- (IBAction)previousAvatar:(id)sender;
- (IBAction)nextAvatar:(id)sender;
- (IBAction)valueChanged:(id)sender;
- (IBAction)homePageButton:(id)sender;
- (IBAction)securityButton:(id)sender;
- (IBAction)sourceButton:(id)sender;
- (IBAction)thanksButton:(id)sender;

@end
