//
//  MPStoredSiteEntity+CoreDataProperties.m
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 2017-05-01.
//  Copyright © 2017 Lyndir. All rights reserved.
//

#import "MPStoredSiteEntity+CoreDataProperties.h"

@implementation MPStoredSiteEntity(CoreData)

+ (NSFetchRequest<MPStoredSiteEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MPStoredSiteEntity"];
}

@dynamic contentObject;

@end
