//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>


CF_IMPLICIT_BRIDGING_ENABLED
NS_ASSUME_NONNULL_BEGIN

@interface Observers<__covariant ObjectType>: NSObject

/**
 * Register an observer to receive notification actions.
 *
 * The registration is weak, allowing the observer to be deallocated.  This will automatically terminate the registration.
 */
- (ObjectType)register:(ObjectType)observer;
/**
 * Remove the registration for an observer so it stops receiving notification actions.
 */
- (ObjectType)unregister:(ObjectType)observer;
/**
 * Notify each of the observers of an action that occurred.
 */
- (void)notify:(void ( ^ )(ObjectType observer))action;

@end

NS_ASSUME_NONNULL_END
CF_IMPLICIT_BRIDGING_DISABLED
