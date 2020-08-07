//
//  EntityESMResponse+CoreDataProperties.m
//  AppAuth
//
//  Created by Sara Strenger on 6/11/20.
//
//

#import "EntityESMResponse+CoreDataProperties.h"

@implementation EntityESMResponse (CoreDataProperties)

+ (NSFetchRequest<EntityESMResponse *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"EntityESMResponse"];
}

@dynamic number;
@dynamic body;
@dynamic timestamp;

@end
