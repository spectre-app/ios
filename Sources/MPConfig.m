//
//  MPConfig.m
//  MasterPassword
//
//  Created by Maarten Billemont on 02/01/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

#import "MPAppDelegate_Shared.h"

@implementation MPConfig

@dynamic sendInfo, rememberLogin, checkInconsistency, hidePasswords, siteAttacker;

- (id)init {

    if (!(self = [super init]))
        return nil;

    [self.defaults registerDefaults:@{
            NSStringFromSelector( @selector( askForReviews ) )     : @YES,

            NSStringFromSelector( @selector( sendInfo ) )          : @YES,
            NSStringFromSelector( @selector( rememberLogin ) )     : @NO,
            NSStringFromSelector( @selector( hidePasswords ) )     : @NO,
            NSStringFromSelector( @selector( checkInconsistency ) ): @NO,
            NSStringFromSelector( @selector( siteAttacker ) )      : @(MPAttacker1),
    }];

    self.delegate = [MPAppDelegate_Shared get];

    return self;
}

@end
