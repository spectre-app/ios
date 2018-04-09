//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import <Foundation/Foundation.h>

CF_IMPLICIT_BRIDGING_ENABLED
#pragma clang assume_nonnull begin

@interface Observers<__covariant ObjectType> : NSObject

- (ObjectType)register:(ObjectType)observer;
- (ObjectType)unregister:(ObjectType)observer;
- (void)notify:(void ( ^ )(ObjectType observer))action;

@end

#pragma clang assume_nonnull end
CF_IMPLICIT_BRIDGING_DISABLED
