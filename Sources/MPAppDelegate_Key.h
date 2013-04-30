//
//  MPAppDelegate_Key.h
//  MasterPassword
//
//  Created by Maarten Billemont on 24/11/11.
//  Copyright (c) 2011 Lyndir. All rights reserved.
//

#import "MPAppDelegate_Shared.h"

@interface MPAppDelegate_Shared(Key)

- (BOOL)signInAsUser:(MPUserEntity *)user saveInContext:(NSManagedObjectContext *)moc usingMasterPassword:(NSString *)password;
- (void)signOutAnimated:(BOOL)animated;

- (void)storeSavedKeyFor:(MPUserEntity *)user;
- (void)forgetSavedKeyFor:(MPUserEntity *)user;

@end
