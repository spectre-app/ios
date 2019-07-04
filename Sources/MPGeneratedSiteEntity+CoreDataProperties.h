//
//  MPGeneratedSiteEntity+CoreDataProperties.h
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 2017-04-30.
//  Copyright © 2017 Lyndir. All rights reserved.
//

#import "MPGeneratedSiteEntity+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MPGeneratedSiteEntity_CoreData<MPSiteEntity_CoreData>

+ (NSFetchRequest<MPGeneratedSiteEntity *> *)fetchRequest;

@property(nullable, nonatomic, copy) NSNumber *counter_;

@end

@interface MPGeneratedSiteEntity(CoreData)<MPGeneratedSiteEntity_CoreData>
@end

NS_ASSUME_NONNULL_END
