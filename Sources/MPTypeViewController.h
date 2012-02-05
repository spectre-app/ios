//
//  MPTypeViewController.h
//  MasterPassword
//
//  Created by Maarten Billemont on 27/11/11.
//  Copyright (c) 2011 Lyndir. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MPTypeDelegate <NSObject>

- (void)didSelectType:(MPElementType)type;

@end

@interface MPTypeViewController : UITableViewController

@property (nonatomic, weak) id<MPTypeDelegate> delegate;

@end
