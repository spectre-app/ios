//
//  OPElementGeneratedEntity.m
//  MasterPassword
//
//  Created by Maarten Billemont on 16/01/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

#import "OPElementGeneratedEntity.h"
#import "OPAppDelegate.h"


@implementation OPElementGeneratedEntity

@dynamic counter;

- (id)content {

    assert(self.type & OPElementTypeClassCalculated);
    
    if (![self.name length])
        return nil;
    
    if (self.type & OPElementTypeClassCalculated)
        return OPCalculateContent(self.type, self.name, [OPAppDelegate get].keyPhrase, self.counter);
    
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Unsupported type: %d", self.type] userInfo:nil];
}

@end
