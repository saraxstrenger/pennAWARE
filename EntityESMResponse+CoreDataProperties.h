//
//  EntityESMResponse+CoreDataProperties.h
//  AppAuth
//
//  Created by Sara Strenger on 6/11/20.
//
//

#import "EntityESMResponse+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface EntityESMResponse (CoreDataProperties)

+ (NSFetchRequest<EntityESMResponse *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *number;
@property (nullable, nonatomic, copy) NSString *body;
@property (nullable, nonatomic, copy) NSDate *timestamp;

@end

NS_ASSUME_NONNULL_END
