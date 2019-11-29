//
//  MPStoredSiteEntity+CoreDataProperties.h
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 2017-05-01.
//  Copyright © 2017 Lyndir. All rights reserved.
//

#import "MPStoredSiteEntity+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MPStoredSiteEntity_CoreData<MPSiteEntity_CoreData>

+ (NSFetchRequest<MPStoredSiteEntity *> *)fetchRequest;

@property(nullable, nonatomic, retain) NSData *contentObject;

@end

@interface MPStoredSiteEntity (CoreData) <MPStoredSiteEntity_CoreData>
@end

NS_ASSUME_NONNULL_END
