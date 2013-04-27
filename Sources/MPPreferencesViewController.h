//
//  MPPreferencesViewController.h
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 04/06/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPTypeViewController.h"

@interface MPPreferencesViewController : UITableViewController<MPTypeDelegate>

@property(weak, nonatomic) IBOutlet UIScrollView *avatarsView;
@property(weak, nonatomic) IBOutlet UIButton *avatarTemplate;
@property(weak, nonatomic) IBOutlet UISwitch *savePasswordSwitch;
@property(weak, nonatomic) IBOutlet UITableViewCell *exportCell;
@property(weak, nonatomic) IBOutlet UITableViewCell *changeMPCell;
@property(weak, nonatomic) IBOutlet UILabel *defaultTypeLabel;

- (IBAction)didToggleSwitch:(UISwitch *)sender;

@end
