//==============================================================================
// This file is part of Master Password.
// Copyright (c) 2011-2017, Maarten Billemont.
//
// Master Password is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Master Password is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You can find a copy of the GNU General Public License in the
// LICENSE file.  Alternatively, see <http://www.gnu.org/licenses/>.
//==============================================================================

@implementation MPiOSConfig

@dynamic helpHidden, siteInfoHidden, showSetup, actionsTipShown, typeTipShown, loginNameTipShown, traceMode, dictationSearch, allowDowngrade;
@dynamic developmentFuelRemaining, developmentFuelInvested, developmentFuelConsumption, developmentFuelChecked;

- (id)init {

    if (!(self = [super init]))
        return self;

    [self.defaults registerDefaults:@{
            NSStringFromSelector( @selector( helpHidden ) )       : @NO,
            NSStringFromSelector( @selector( siteInfoHidden ) )   : @YES,
            NSStringFromSelector( @selector( showSetup ) )        : @YES,
            NSStringFromSelector( @selector( appleID ) )          : @"510296984",
            NSStringFromSelector( @selector( actionsTipShown ) )  : @(!self.firstRun),
            NSStringFromSelector( @selector( typeTipShown ) )     : @(!self.firstRun),
            NSStringFromSelector( @selector( loginNameTipShown ) ): @NO,
            NSStringFromSelector( @selector( traceMode ) )        : @NO,
            NSStringFromSelector( @selector( dictationSearch ) )  : @NO,
            NSStringFromSelector( @selector( allowDowngrade ) )   : @NO,
    }];

    return self;
}

@end
