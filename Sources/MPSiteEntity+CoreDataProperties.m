//
//  MPSiteEntity+CoreDataProperties.m
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 2017-04-30.
//  Copyright © 2017 Lyndir. All rights reserved.
//

#import "MPSiteEntity+CoreDataProperties.h"

@implementation MPSiteEntity (CoreData)

+ (NSFetchRequest<MPSiteEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MPSiteEntity"];
}

@dynamic content;
@dynamic lastUsed;
@dynamic loginGenerated_;
@dynamic loginName;
@dynamic name;
@dynamic requiresExplicitMigration_;
@dynamic type_;
@dynamic url;
@dynamic uses_;
@dynamic version_;
@dynamic questions;
@dynamic user;

@end
