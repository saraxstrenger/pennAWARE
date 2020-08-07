
//
//  ESMScheduleManager.m
//  AWAREFramework
//
//  Created by Yuuki Nishiyama on 2018/03/27.
//
//  Modified by Sara Strenger June/July 2020
//

/**
 ESMScheduleManager handles ESM schdule.
 */

#import "ESMScheduleManager.h"
#import "ESMScrollViewController.h"
#import "EntityESMAnswerHistory+CoreDataClass.h"
#import <UserNotifications/UserNotifications.h>
#import "EntityESMAnswer.h"
#import "CoreDataHandler.h"
#import "AWAREUtils.h"
#import "AWAREKeys.h"
#import "AWAREEventLogger.h"

static ESMScheduleManager * sharedESMScheduleManager;

@implementation ESMScheduleManager{
    NSString * categoryNormalESM;
    NSMutableArray * contextObservers;
}

+ (ESMScheduleManager * _Nonnull)sharedESMScheduleManager{
    @synchronized(self){
        if (!sharedESMScheduleManager){
            sharedESMScheduleManager = [[ESMScheduleManager alloc] init];
        }
    }
    return sharedESMScheduleManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedESMScheduleManager == nil) {
            sharedESMScheduleManager= [super allocWithZone:zone];
            return sharedESMScheduleManager;
        }
    }
    return nil;
}


- (instancetype)init{
    self = [super init];
    if(self != nil){
        categoryNormalESM = @"category_normal_esm";
        _debug = NO;
        contextObservers = [[NSMutableArray alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        if( [defaults integerForKey: @"bedtime"]==0){
            [defaults setInteger: [NSNumber numberWithInt: 22].integerValue forKey: @"bedtime"];
        }
        [defaults synchronize];
        if( [defaults integerForKey: @"waketime"]==0){
            [defaults setInteger: [NSNumber numberWithInt: 8].integerValue forKey: @"waketime"];
        }
        [defaults synchronize];
        
        _bedtime=[NSNumber numberWithUnsignedInteger:[defaults integerForKey: @"bedtime"]];
        _waketime=[NSNumber numberWithUnsignedInteger:[defaults integerForKey: @"waketime"]];
        
       
        
        //fire hour is in between bedtime and waketime--> people hopefully sleep for more than 2 hrs
        int fireHour=(_bedtime.intValue+2)%24;
        
        //account for time being circular
        
        
        //want the reset period to be while the participant is sleeping--data from yesterday doesn't carry to next day
        NSDate * startDate= [AWAREUtils getTargetNSDate: [NSDate new]
                                                   hour: (float)fireHour
                                                nextDay:YES];
     
                
        //timer will go off every 24 hrs during sleep period
        NSTimer * updateLoggedAnswers=[[NSTimer alloc]initWithFireDate:startDate
                                                              interval:(double)24*60*60
                                                               repeats:YES
                                                                 block:^(NSTimer * _Nonnull timer) {
            
            //remove any saved answers from the previous day from the DB
            [self removeSavedAnswersFromDB];
            
            //remove any missed temporary esms from the DB.
            [self removeFollowupESMsFromDB];
            
            
            [AWAREEventLogger.shared logEvent: @{@"class":@"ESMScheduleManager", @"event": @"old answers cleared"}];
           
       }];
        
        
        
        [[NSRunLoop mainRunLoop] addTimer: updateLoggedAnswers forMode:NSDefaultRunLoopMode];


    }
    return self;
}

#pragma mark - Set Schedules


- (BOOL) setScheduleByConfig:(NSArray <NSDictionary * > * _Nonnull) config {
    
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    
    NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;

    
    
    float number = 0;
    
    
    //valid hours to send esms is between wake and sleep
    float validHours = [_bedtime intValue] - [_waketime intValue];

    //time is circular !
    if( [_bedtime intValue] < [_waketime intValue]){
        validHours+=24;
    }
    
    //NSLog(@"Waketime: %@, Bedtime: %@, Valid Hours: %f", _waketime, _bedtime, validHours);

       
   //finds time interval that breaks up the "day" evenly (wake hours)
    float segment = validHours/((int)[config count]);
    
    
    NSDictionary* last=[config lastObject];
    
    //adjusts segment time interval so the day is broken up around the n-1 surveys and not the bedtime survey
    if([last objectForKey:@"bedtime-survey"]!=nil){
       segment = validHours/((int)[config count]-1);
    }
       
       
    //first alert should come at midpoint of first "segment" of the day
    float startTime =(int)( [_waketime floatValue] + (float) segment / 2.0);
    
    float time=startTime;
    
    for (NSDictionary * schedule in config ) {
        
        //only puts one time into the array -> this is the time slot calculated with start time/interval which will evenly space the esms throughout the day. Note: the esms will appear in the order that they were put into the json file. So the first set of questions must come first in the json file and so on in order for them to be asked in the correct order.
        
        //casts hour to int for sake of my sanity? could probably be changed to float ngl but I don't want to deal with the stress of math while debugging lmao
        NSArray * hours =[NSArray arrayWithObjects: [NSNumber numberWithInt:time], nil];
        time += segment;
        
        //time doesn't go past 24 lol
        if(time>=24){
           time-=24;
        }
        
        NSNumber *offset=[NSNumber numberWithInt:0];
        
        //if last esm is bedtime survey reset the time so it comes 30 mins before bedtime
        if([schedule objectForKey:@"bedtime-survey"]!=nil){
            NSNumber * randomizationPeriod=[schedule objectForKey:@"randomize"];
            float bedtimeSurvey=_bedtime.floatValue-(randomizationPeriod.floatValue/60);
            if( bedtimeSurvey<0 ){
                bedtimeSurvey+=24;
            }
            hours=nil;
            hours =[NSArray arrayWithObjects: [NSNumber numberWithFloat:(bedtimeSurvey)], nil];
      
        }
        
        
        NSArray * esms = [schedule objectForKey:@"esms"];
        NSArray * followup_esms = [schedule objectForKey:@"followup_esms"];
        
        NSNumber * randomize_schedule = [schedule objectForKey:@"randomize"];
        NSNumber * expiration = [schedule objectForKey:@"expiration"];
        
        NSString * startDateStr = [schedule objectForKey:@"start_date"];
        NSString *   endDateStr = [schedule objectForKey:@"end_date"];
        
        
        NSString * notificationTitle = [schedule objectForKey:@"notification_title"];
        NSString * notificationBody = [schedule objectForKey:@"notification_body"];
        NSString * scheduleId = [schedule objectForKey:@"schedule_id"];
        
       
        
//        NSLog(@"Scheduled time: %@, ESM id: %@", hours[0], scheduleId);
        
        NSString * eventContext = [self convertToJSONStringWithArray:[schedule objectForKey:@"context"]];
        if(eventContext == nil) {
            eventContext = @"[]";
        }
        
        NSString *followup_title = [schedule objectForKey:@"followup_notif_title"];
        NSString *followup_body = [schedule objectForKey:@"followup_notif_body"];
        
        if(followup_title == nil){
            followup_title=@"";
        }
        if(followup_body == nil){
            followup_body=@"";
        }
        
        NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MM-dd-yyyy"];
        // [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        
        NSDate *startDate = [formatter dateFromString:startDateStr];
        NSDate *endDate   = [formatter dateFromString:endDateStr];
        
        if(startDate == nil){
            startDate = [[NSDate alloc] initWithTimeIntervalSince1970:0];
        }
        
        if(endDate == nil){
            endDate = [[NSDate alloc] initWithTimeIntervalSince1970:2147483647];
        }
        
        if(expiration == nil) expiration = @0;
        
        NSNumber * interface = [schedule objectForKey:@"interface"];
        if(interface == nil) interface = @0;
        
        NSNumber * delayTime = [schedule objectForKey:@"followup_delay"];
        if(delayTime==nil) delayTime=[NSNumber numberWithInt:30];
        
        for (NSNumber * hour in hours) {
            EntityESMSchedule * entityESMSchedule = (EntityESMSchedule *) [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([EntityESMSchedule class])
                inManagedObjectContext:context];
            entityESMSchedule.fire_hour  = hour;
            entityESMSchedule.expiration_threshold = expiration;
            entityESMSchedule.start_date = startDate;
            entityESMSchedule.end_date   = endDate;
            entityESMSchedule.notification_title = notificationTitle;
            entityESMSchedule.notification_body  = notificationBody;
            entityESMSchedule.randomize_schedule = randomize_schedule;
            entityESMSchedule.schedule_id = scheduleId;
            entityESMSchedule.contexts    = eventContext;
            entityESMSchedule.interface   = interface;
            entityESMSchedule.followup_notif_title=followup_title;
            entityESMSchedule.followup_notif_body=followup_body;
            entityESMSchedule.followup_json=[self convertToJSONStringWithArray: followup_esms];
            entityESMSchedule.followup=@(NO);
            entityESMSchedule.followup_delay = delayTime;
            entityESMSchedule.offset=offset;
            entityESMSchedule.extend=@(NO);

            
            if (![hour isEqualToNumber:@(-1)]) {
                [self setHourBasedNotification:entityESMSchedule datetime:[NSDate new]];
            }
            
            for (NSDictionary * esmDict in esms) {
                NSDictionary  * esm = [esmDict objectForKey:@"esm"];
                EntityESM     * entityEsm = (EntityESM *) [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([EntityESM class])
                                                                                    inManagedObjectContext:context];
                entityEsm.esm_type   = [esm objectForKey:@"esm_type"];
                entityEsm.esm_title  = [esm objectForKey:@"esm_title"];
                entityEsm.esm_submit = [esm objectForKey:@"esm_submit"];
                entityEsm.esm_instructions = [esm objectForKey:@"esm_instructions"];
                entityEsm.esm_radios     = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_radios"]];
                entityEsm.esm_checkboxes = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_checkboxes"]];
                entityEsm.esm_likert_max = [esm objectForKey:@"esm_likert_max"];
                entityEsm.esm_likert_max_label = [esm objectForKey:@"esm_likert_max_label"];
                entityEsm.esm_likert_min_label = [esm objectForKey:@"esm_likert_min_label"];
                entityEsm.esm_likert_step = [esm objectForKey:@"esm_likert_step"];
                entityEsm.esm_quick_answers = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_quick_answers"]];
                entityEsm.esm_expiration_threshold = [esm objectForKey:@"esm_expiration_threshold"];
                // entityEsm.esm_status    = [esm objectForKey:@"esm_status"];
                entityEsm.esm_status = @0;
                entityEsm.esm_trigger   = [esm objectForKey:@"esm_trigger"];
                entityEsm.esm_scale_min = [esm objectForKey:@"esm_scale_min"];
                entityEsm.esm_scale_max = [esm objectForKey:@"esm_scale_max"];
                entityEsm.esm_scale_start = [esm objectForKey:@"esm_scale_start"];
                entityEsm.esm_scale_max_label = [esm objectForKey:@"esm_scale_max_label"];
                entityEsm.esm_scale_min_label = [esm objectForKey:@"esm_scale_min_label"];
                entityEsm.esm_scale_step = [esm objectForKey:@"esm_scale_step"];
                entityEsm.esm_json = [self convertToJSONStringWithArray:@[esm]];
                entityEsm.esm_number = @(number);
                // for date&time picker
                entityEsm.esm_start_time = [esm objectForKey:@"esm_start_time"];
                entityEsm.esm_start_date = [esm objectForKey:@"esm_start_date"];
                entityEsm.esm_time_format = [esm objectForKey:@"esm_time_format"];
                entityEsm.esm_minute_step = [esm objectForKey:@"esm_minute_step"];
                // for web ESM url
                entityEsm.esm_url = [esm objectForKey:@"esm_url"];
                // for na
                entityEsm.esm_na = @([[esm objectForKey:@"esm_na"] boolValue]);
                entityEsm.esm_flows = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_flows"]];
                // NSLog(@"[%d][integration] %@",number, [esm objectForKey:@"esm_app_integration"]);
                entityEsm.esm_app_integration = [esm objectForKey:@"esm_app_integration"];
                // entityEsm.esm_schedule = entityESMSchedule;
                
                [entityESMSchedule addEsmsObject:entityEsm];
                
                number ++;
            }
           
            
        }
    }
    
    NSError * error = nil;
    if([context save:&error]){
        [self refreshESMNotifications];
        return YES;
    }else{
        if(error != nil) NSLog(@"%@", error.debugDescription);
        return NO;
    }
}

/**
 Add ESMSchdule to this ESMScheduleManager. The ESMSchduleManager **saves a schdule to the database** and ** set a UNNotification**.
 @param schedule ESMSchdule
 @return A status of data saving operation
 */
- (BOOL) addSchedule:(ESMSchedule * _Nonnull) schedule{
    return [self addSchedule:schedule withNotification:YES];
}

- (BOOL) addSchedule:(ESMSchedule * _Nonnull) schedule withNotification:(BOOL)notification{
    NSManagedObjectContext * manageContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    manageContext.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    
    NSDate * now = [NSDate new];
    NSArray * hours = schedule.fireHours;
    
    if(hours.count == 0){
        hours = @[@(-1)];
    }
    //////////////////////////////////////////////
    for (NSNumber * hour in hours) {
        EntityESMSchedule * entitySchedule = [[EntityESMSchedule alloc] initWithContext:manageContext];
        entitySchedule = [self transferESMSchedule:schedule toEntity:entitySchedule];
        entitySchedule.fire_hour = hour;
        // contexts
        entitySchedule.contexts = [self convertToJSONStringWithArray:schedule.contexts];
        // weekdays
        entitySchedule.weekdays = [self convertToJSONStringWithArray:schedule.weekdays];
        for (ESMItem * esmItem in schedule.esms) {
            EntityESM * entityESM = (EntityESM *)[NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([EntityESM class]) inManagedObjectContext:manageContext];
            [entitySchedule addEsmsObject:[self transferESMItem:esmItem toEntity:entityESM]];
        }
        /**  Hours Based ESM */
        if (hour.intValue != -1 && notification) {
            [self setHourBasedNotification:entitySchedule datetime:now];
        }
        if (hour.intValue == -1 && notification && ![entitySchedule.contexts isEqualToString:@""]){
            [self setContextBasedNotification:entitySchedule];
        }
        // NSLog(@"-> %@", entitySchedule.randomize_schedule);
    }
    
    for (NSDateComponents * timer in schedule.timers) {
        EntityESMSchedule * entitySchedule = [[EntityESMSchedule alloc] initWithContext:manageContext];
        entitySchedule = [self transferESMSchedule:schedule toEntity:entitySchedule];
        entitySchedule.timer = timer;
        for (ESMItem * esmItem in schedule.esms) {
            EntityESM * entityESM = (EntityESM *)[NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([EntityESM class]) inManagedObjectContext:manageContext];
            [entitySchedule addEsmsObject:[self transferESMItem:esmItem toEntity:entityESM]];
        }
        /**  Timer Based ESM */
        if( timer != nil && notification){
            [self setTimeBasedNotification:entitySchedule datetime:now];
        }
    }
    
    NSError * error = nil;
    bool saved = [manageContext save:&error];
    if (saved) {
    }else{
        if (error != nil) {
            NSLog(@"[ESMScheduleManager] data save error: %@", error.debugDescription);
        }
    }
    
    return saved;
}


/**
 Transfer parameters in ESMSchdule to EntityESMSchedule instance.

 @param schedule ESMSchdule
 @param entitySchedule EntityESMSchdule
 @return EntityESMSchdule which has parameters of ESMSchdule
 */
- (EntityESMSchedule *) transferESMSchedule:(ESMSchedule *)schedule toEntity:(EntityESMSchedule *)entitySchedule{
    entitySchedule.schedule_id = schedule.scheduleId;
    entitySchedule.expiration_threshold = schedule.expirationThreshold;
    entitySchedule.start_date = schedule.startDate;
    entitySchedule.end_date = schedule.endDate;
    entitySchedule.notification_body = schedule.notificationBody;
    entitySchedule.notification_title = schedule.notificationTitle;
    entitySchedule.interface = schedule.interface;
    entitySchedule.randomize_esm = schedule.randomizeEsm;
    entitySchedule.randomize_schedule = schedule.randomizeSchedule;
    entitySchedule.temporary = schedule.temporary;
    entitySchedule.repeat = @(schedule.repeat);
    entitySchedule.offset=schedule.offset;
    entitySchedule.followup=@(schedule.followup);
    entitySchedule.followup_delay=schedule.followupDelay;
    entitySchedule.extend=@(NO);
    return entitySchedule;
}


/**
Transfer parameters in ESMSchdule to EntityESMSchedule instance.

 @param esmItem ESMItem
 @param entityESM EntityESM
 @return EntityESM which has parameters of ESMItem
 */
- (EntityESM *) transferESMItem:(ESMItem *)esmItem toEntity:(EntityESM *)entityESM{
    entityESM.device_id = esmItem.device_id;
    entityESM.double_esm_user_answer_timestamp = esmItem.double_esm_user_answer_timestamp;
    entityESM.esm_checkboxes = esmItem.esm_checkboxes;
    entityESM.esm_expiration_threshold = esmItem.esm_expiration_threshold;
    entityESM.esm_flows = esmItem.esm_flows;
    entityESM.esm_instructions = esmItem.esm_instructions;
    entityESM.esm_json = esmItem.esm_json;
    entityESM.esm_likert_max = esmItem.esm_likert_max;
    entityESM.esm_likert_max_label = esmItem.esm_likert_max_label;
    entityESM.esm_likert_min_label = esmItem.esm_likert_min_label;
    entityESM.esm_likert_step = esmItem.esm_likert_step;
    entityESM.esm_minute_step = esmItem.esm_minute_step;
    entityESM.esm_na = esmItem.esm_na;
    entityESM.esm_number = esmItem.esm_number;
    entityESM.esm_quick_answers = esmItem.esm_quick_answers;
    entityESM.esm_radios = esmItem.esm_radios;
    entityESM.esm_scale_max = esmItem.esm_scale_max;
    entityESM.esm_scale_max_label = esmItem.esm_scale_max_label;
    entityESM.esm_scale_min = esmItem.esm_scale_min;
    entityESM.esm_scale_min_label = esmItem.esm_scale_min_label;
    entityESM.esm_scale_start = esmItem.esm_scale_start;
    entityESM.esm_scale_step = esmItem.esm_scale_step;
    entityESM.esm_start_date= esmItem.esm_start_date;
    entityESM.esm_start_time = esmItem.esm_start_time;
    entityESM.esm_status = esmItem.esm_status;
    entityESM.esm_submit = esmItem.esm_submit;
    entityESM.esm_time_format = esmItem.esm_time_format;
    entityESM.esm_title = esmItem.esm_title;
    entityESM.esm_trigger = esmItem.esm_trigger;
    entityESM.esm_type = esmItem.esm_type;
    entityESM.esm_url = esmItem.esm_url;
    entityESM.esm_user_answer = esmItem.esm_user_answer;
    entityESM.esm_app_integration = esmItem.esm_app_integration;
    return entityESM;
}


/**
 Delete ESMSchdule by a schedule ID

 @param scheduleId Schdule ID
 @return A status of data deleting operation
 */
- (BOOL) deleteScheduleWithId:(NSString * _Nonnull)scheduleId{
    // AWAREDelegate * delegate = (AWAREDelegate *) [UIApplication sharedApplication].delegate;
    NSManagedObjectContext * context = [CoreDataHandler sharedHandler].managedObjectContext;
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    NSFetchRequest *deleteRequest = [[NSFetchRequest alloc] init];
    [deleteRequest setEntity:[NSEntityDescription entityForName:NSStringFromClass([EntityESMSchedule class]) inManagedObjectContext:context]];
    [deleteRequest setIncludesPropertyValues:NO]; // fetch only a managed object ID
    [deleteRequest setPredicate: [NSPredicate predicateWithFormat:@"schedule_id == %@", scheduleId]];
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:deleteRequest error:&error];
    
    for (NSManagedObject *data in results) {
        [context deleteObject:data];
    }
    
    NSError *saveError = nil;
    BOOL deleted = [context save:&saveError];
    if (deleted) {
        return YES;
    }else{
        if (saveError!=nil) {
            NSLog(@"[ESMScheduleManager] data delete error: %@", error.debugDescription);
        }
        return YES;
    }
}

- (NSArray <EntityESMSchedule *> *)getESMSchedules{
    NSManagedObjectContext * context = [CoreDataHandler sharedHandler].managedObjectContext;
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    NSFetchRequest * request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([EntityESMSchedule class])];
    NSDate * currentDate = [NSDate new];
    [request setPredicate:[NSPredicate predicateWithFormat:@"start_date <= %@ AND end_date >= %@"
                                             argumentArray:@[currentDate,currentDate]]];
    NSError * error   = nil;
    NSArray * results = [context executeFetchRequest:request error:&error];
    if (error!=nil) {
        NSLog(@"[Error][ESMScheduleManager] %@", error.debugDescription);
        return nil;
    }
    return results;
}

/**
 Delete all of ESMSchdule in the DB

 @return A status of data deleting operation
 */
- (BOOL)deleteAllSchedules{
    return [self deleteAllSchedulesWithNotification:YES];
}

- (BOOL) deleteAllSchedulesWithNotification:(BOOL)notification{
    // AWAREDelegate * delegate = (AWAREDelegate *) [UIApplication sharedApplication].delegate;
    NSManagedObjectContext * context = [CoreDataHandler sharedHandler].managedObjectContext;
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    NSFetchRequest *deleteRequest = [[NSFetchRequest alloc] init];
    [deleteRequest setEntity:[NSEntityDescription entityForName:NSStringFromClass([EntityESMSchedule class]) inManagedObjectContext:context]];
    [deleteRequest setIncludesPropertyValues:NO]; // fetch only a managed object ID
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:deleteRequest error:&error];
    
    for (NSManagedObject *data in results) {
        [context deleteObject:data];
    }
    
    NSError *saveError = nil;
    BOOL deleted = [context save:&saveError];
    
    if (deleted) {
        if(notification){
            [self removeESMNotificationsWithHandler:^{
                
            }];
        }
        return YES;
    }else{
        if (saveError!=nil) {
            NSLog(@"[ESMScheduleManager] data delete error: %@", error.debugDescription);
        }
        return YES;
    }
}




#pragma mark - Valid Schedule Retrieval

/**
 Get valid ESM schedules at the current time

 @return Valid ESM schedules as an NSArray
 */
- (NSArray * _Nonnull) getValidSchedules{
    return [self getValidSchedulesWithDatetime:[NSDate new]];
}


/**
 Get valid ESM schedules at a particular time

 @param datetime A NSDate for fetching valid ESMs from DB
 @return Valid ESM schedules as an NSArray from a paricular time
 */
- (NSArray * _Nonnull) getValidSchedulesWithDatetime:(NSDate * _Nonnull)datetime{
    
    // Fetch vaild schedules by date and expiration
    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[NSEntityDescription entityForName:NSStringFromClass([EntityESMSchedule class])
                               inManagedObjectContext:[CoreDataHandler sharedHandler].managedObjectContext]];
    [req setPredicate:[NSPredicate predicateWithFormat:@"(start_date <= %@) AND (end_date >= %@)", datetime, datetime]];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"start_date" ascending:NO];
    NSSortDescriptor *sortBySID = [[NSSortDescriptor alloc] initWithKey:@"schedule_id" ascending:NO];
    [req setSortDescriptors:@[sort,sortBySID]];
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:req
                                                                                               managedObjectContext:[CoreDataHandler sharedHandler].managedObjectContext
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:nil];
    NSError *error = nil;
    if (![fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    NSArray * periodValidSchedules = [fetchedResultsController fetchedObjects];
    
    
    /////// Fetch ESM answer history from Today
    NSFetchRequest *historyReq = [[NSFetchRequest alloc] init];
    [historyReq setEntity:[NSEntityDescription entityForName:NSStringFromClass([EntityESMAnswerHistory class])
                                      inManagedObjectContext:[CoreDataHandler sharedHandler].managedObjectContext]];
    NSNumber * now = @(datetime.timeIntervalSince1970);
    NSNumber * start = @([AWAREUtils getTargetNSDate:[NSDate new] hour:0.0 nextDay:false].timeIntervalSince1970);
    [historyReq setPredicate:[NSPredicate predicateWithFormat:@"(timestamp >= %@) && (timestamp <= %@)", start, now]]; //(timestamp >= %@) &&
    NSSortDescriptor *historySort = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    [historyReq setSortDescriptors:@[historySort]];
    NSFetchedResultsController *historyFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:historyReq
                                                                                                      managedObjectContext:[CoreDataHandler sharedHandler].managedObjectContext
                                                                                                        sectionNameKeyPath:nil
                                                                                                                 cacheName:nil];
    NSError * historyError = nil;
    if (![historyFetchedResultsController performFetch:&historyError]) {
        NSLog(@"Unresolved error %@, %@", historyError, [historyError userInfo]);
    }
    NSArray * answerHistory = [historyFetchedResultsController fetchedObjects];
    
    
    ///////////////////////////////////////////////////////////
    NSMutableArray * validSchedules = [[NSMutableArray alloc] init];
    if (periodValidSchedules==nil) {
        
        return validSchedules;
        
    }
    
    for (EntityESMSchedule * schedule in periodValidSchedules) {
        NSNumber * hour = schedule.fire_hour;
        NSDateComponents * timer = (NSDateComponents *)schedule.timer;
        NSString * contexts = schedule.contexts;
        if (contexts == nil || [contexts isEqualToString:@""]) {
            contexts = nil;
        }
        
        bool isValidSchedule = NO;
        
        /**  Hours Based ESM */
        if (hour.intValue != -1) {
            isValidSchedule = [self isValidHourBasedESMSchedule:schedule history:answerHistory targetDatetime:datetime];
        }
        
        /**  Timer Based ESM */
        if( timer != nil ){
            isValidSchedule = [self isValidTimerBasedESMSchedule:schedule history:answerHistory targetDatetime:datetime];
        } else if(hour.intValue == -1){
            isValidSchedule = YES;
        }
        
        /** Context **/
//        if( contexts != nil ){
//            isValidSchedule = [self isValidContextBasedESMSchedule:schedule];
//        }
        
        if (isValidSchedule) {
            [validSchedules addObject:schedule];
        }
    }
    
    
    if(_debug){
        for( EntityESMSchedule * schedule in validSchedules){
            NSLog(@"VALID SCHEDULE: %@", schedule.schedule_id);
        }
        if(validSchedules.count==0){
            NSLog(@"NO VALID SCHEDULES");
        }
    }

    return validSchedules;
}



/**
 Validate an ESM Schdule

 @param schedule EntityESMSchdule
 @param history An array list of EntityESMAnswerHistory
 @param datetime A target datetime
 @return vaild or invaild
 */
- (BOOL) isValidHourBasedESMSchedule:(EntityESMSchedule  *)schedule history:(NSArray *)history targetDatetime:(NSDate *)datetime{

    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM/dd/yyyy HH:mm"];
    [NSTimeZone resetSystemTimeZone];
    
    NSString * scheduleId = schedule.schedule_id;
    if(scheduleId == nil){
        if (_debug) NSLog(@"[ESMScheduleManager] (invalid) Schdule ID is Empty");
        return NO;
    }
    
    NSNumber * randomize = schedule.randomize_schedule;
    if(randomize == nil) randomize = @0;
    NSNumber * expiration = schedule.expiration_threshold;
    if(expiration == nil) expiration = @0;

    NSDate * now = [NSDate date];
    NSNumber * fireHour = schedule.fire_hour;
    NSDate * targetDateInToday       = [AWAREUtils getTargetNSDate:now
                                                              hour:[fireHour floatValue]
                                                            minute: [schedule.offset intValue]
                                                            second: 0
                                                           nextDay:NO];
    
    NSDate * targetDateInNextday     = [AWAREUtils getTargetNSDate:now
                                                              hour:[fireHour floatValue]
                                                            minute: [schedule.offset intValue]
                                                            second: 0
                                                           nextDay:YES];
    //NSLog(@"Schedule: %@ offset: %@ randomize: %@", schedule.schedule_id, schedule.offset, schedule.randomize_schedule);
    double nowUnix = now.timeIntervalSince1970;
    
    /// randomize mode -> need to make a buffer ////
//    if (randomize.intValue > 0) {
        ////// start/end time based validation /////
        int validRange = 60 * (expiration.intValue); // min
        NSDate * validStartDateToday   = targetDateInToday;
        NSDate * validEndDateToday     = [targetDateInToday   dateByAddingTimeInterval:validRange];
        
        NSDate * validStartDateNextday = targetDateInNextday;
        NSDate * validEndDateNextday   = [targetDateInNextday dateByAddingTimeInterval:validRange];
        

    if(schedule.extend.boolValue){
        
        validEndDateToday=[validEndDateToday dateByAddingTimeInterval:5*60];
        validEndDateNextday=[validEndDateNextday dateByAddingTimeInterval:5*60];
        //NSLog(@"%@ is extended until %@", schedule.schedule_id, validEndDateToday);

    }else{
         //NSLog(@"%@ is not extended", schedule.schedule_id);
    }
    
        if ( ((nowUnix  >= validStartDateToday.timeIntervalSince1970) && (nowUnix  <= validEndDateToday.timeIntervalSince1970 )) ||
             ((nowUnix  >= validStartDateNextday.timeIntervalSince1970) && (nowUnix  <= validEndDateNextday.timeIntervalSince1970 )) ){
            if (_debug) NSLog(@"[ESMScheduleManager] (valid) start < now < end");
            
        }else{
            if (_debug) NSLog(@"[ESMScheduleManager] (invalid) out of term");
            return NO;
        }


    
    /////  history based validation  //////
    if (history != nil) {
        for (EntityESMAnswerHistory * answeredESM in history) {
            NSString * historyScheduleId = answeredESM.schedule_id;
            NSNumber * historyFireHour   = answeredESM.fire_hour;
           // if([scheduleId isEqualToString:historyScheduleId]) NSLog(@"\nhistory id: %@, history hour: %@, \nschedule id: %@, schedule hour: %@", historyScheduleId, historyFireHour, scheduleId, fireHour);
            if ([scheduleId isEqualToString:historyScheduleId] && [fireHour isEqualToNumber:historyFireHour]) {
              if (_debug) NSLog(@"[ESMScheduleManager] (invalid) => schedule id=%@, fire-hour=%@, time=%@", scheduleId, fireHour, answeredESM.timestamp);
                return NO;
            }else{
                if (_debug) NSLog(@"[ESMScheduleManager] (valid) schedule id=%@, fire-hour=%@", scheduleId, fireHour);
            }
        }
    }
    
    if([expiration isEqualToNumber:@0]){
        return YES;
    }
    
   // NSLog(@"%@ is valid", schedule.schedule_id);

    //NSLog(@"[id:%@][hour:%@][randomize:%@][expiration:%@]",scheduleId,fireHour,randomize,expiration);
    return YES;
}


- (BOOL) isValidTimerBasedESMSchedule:(EntityESMSchedule  *)schedule history:(NSArray *)history targetDatetime:(NSDate *)datetime{
    return YES;
}




#pragma mark - Notifications

///////////////// UNNotifications ///////////////////////

/**
 set an hour based UNNotification

 @param schedule EntityESMSchedule
 @param datetime A target time
 */
- (void) setHourBasedNotification:(EntityESMSchedule *)schedule datetime:(NSDate *) datetime {
       
    NSNumber * randomize = schedule.randomize_schedule;
    if(randomize == nil) randomize = @0;

    NSNumber * fireHour   = schedule.fire_hour;
    NSNumber * expiration = schedule.expiration_threshold;
    NSDate   * fireDate   = [AWAREUtils getTargetNSDate:[NSDate new]
                                                   hour:[fireHour floatValue]
                                                nextDay:YES];
    NSDate   * originalFireDate = [AWAREUtils getTargetNSDate:[NSDate new]
                                                         hour:[fireHour floatValue]
                                                      nextDay:YES];
    NSString * scheduleId = schedule.schedule_id;
    NSNumber * interface  = schedule.interface;
    bool repeat = YES;
    if (schedule.repeat!=nil) {
        repeat = schedule.repeat.boolValue;
    }

    int randomMin=0;
    //if date is randomized, find a random minute in the valid random hour (within the interval) and add it to the fire date
    if(![randomize isEqualToNumber:@0]){
        
        // Make a random date -> will be in random period AFTER fire hour
        randomMin = (int)[self randomNumberBetween:0 maxNumber:randomize.intValue];
        fireDate = [AWAREUtils getTargetNSDate:[NSDate new] hour:[fireHour floatValue] minute:(randomMin) second:0 nextDay:YES];
    }

    NSDate * expirationTime = [fireDate dateByAddingTimeInterval: (expiration.integerValue) * 60];
    //NSDate * inspirationTimer= fireDate;
    
   
    //if fire time and expiration are in between right now (aka now would be
//    if(inspirationTime.timeIntervalSinceNow <= 24*60*60
//       && expirationTime.timeIntervalSinceNow >= 24*60*60){
//
////        fireDate=[fireDate dateByAddingTimeInterval:-60*60*24]; // <- temporary solution
//    }
    
    // Check an answering condition
    
    
    NSLog(@"[ID:%@][FIRE_TIME:%@] [EXPIRATION_TIME:%@]", scheduleId, fireDate, expirationTime);
    
    
    NSNumber *offset = [NSNumber numberWithInt:randomMin];
    NSDictionary * userInfo = [[NSDictionary alloc] initWithObjects:@[originalFireDate, randomize, offset, scheduleId,expiration, fireDate, interface]
        forKeys:@[@"original_fire_date", @"randomize", @"offset", @"schedule_id", @"expiration_threshold",@"fire_date",@"interface"]];

    // If the value is 0-23
    //Send/schedule notification to send to the user
    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
    content.title = schedule.notification_title;
    content.body  = schedule.notification_body;
    content.sound = [UNNotificationSound defaultSound];
    content.categoryIdentifier = @("default");
    content.userInfo = userInfo;
    content.badge = @(1);

    schedule.offset = offset;
    schedule.extend=0;
    
    
    //save ESM (offset)
    NSManagedObjectContext * manageContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
          manageContext.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
       NSError * error = nil;
       bool saved = [manageContext save:&error];
       if (saved) {
       }else{
           if (error != nil) {
               NSLog(@"[ESMScheduleManager followup] data save error: %@", error.debugDescription);
           }
       }
    
    
    //SET NOTIFICATION
    
    NSString *notificationId = [NSString stringWithFormat: @"%@_%@_%@", KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER, fireHour.stringValue, schedule.schedule_id];

    
    //get time for trigger
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:fireDate];
    UNCalendarNotificationTrigger * trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:repeat];
            
        
    UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:notificationId content:content trigger:trigger];
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];

    [center removePendingNotificationRequestsWithIdentifiers:@[notificationId]];
    [center removeDeliveredNotificationsWithIdentifiers:@[notificationId]];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error!=nil) {
            NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
        }else{
            if (self->_debug){
                NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd",trigger.dateComponents.hour,trigger.dateComponents.minute);
            }
        }
    }];
       
    
    
    //SECONDARY NOTIFICATION
    
    NSDate * secondaryFire = [fireDate dateByAddingTimeInterval: (expiration.intValue-5)*60];

    userInfo = [[NSDictionary alloc] initWithObjects:@[secondaryFire, scheduleId, offset, expiration]
    forKeys:@[@"fire_date", @"schedule_id", @"offset", @"expiration_threshold"]];

    UNMutableNotificationContent * content2 = [[UNMutableNotificationContent alloc] init];
    
    content2.title=schedule.notification_title;
    content2.body = @"There are 5 minutes remaining to answer the current survey. Press and hold this notification to extend by 5 minutes.";
    content2.sound = [UNNotificationSound defaultSound];
    content2.categoryIdentifier = @("postpone");
    content2.userInfo = userInfo;
    content2.badge = @(1);
    
    NSDateComponents * components2 = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:secondaryFire];
    UNCalendarNotificationTrigger*trigger2 = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components2 repeats:NO];
    NSString * secondNotificationId = [NSString stringWithFormat:@"SECONDARY_%@_%@",schedule.schedule_id,offset.stringValue];
    
    UNNotificationRequest    * secondRequest = [UNNotificationRequest requestWithIdentifier:secondNotificationId content:content2 trigger:trigger2];
    
    
    [center removePendingNotificationRequestsWithIdentifiers:@[secondNotificationId]];
    [center removeDeliveredNotificationsWithIdentifiers:@[secondNotificationId]];
    [center addNotificationRequest:secondRequest withCompletionHandler:^(NSError * _Nullable error) {
           if (error!=nil) {
               NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
           }else{
               if (self->_debug){
                   NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd",trigger.dateComponents.hour,trigger.dateComponents.minute);
               }
           }
    }];
       
    
}



/**
 Set a time based notifiation

 @param schedule EntityESMSchdule
 @param datetime A target datetime of the notification (NSDate)
 */
- (void) setTimeBasedNotification:(EntityESMSchedule *)schedule datetime:(NSDate *)datetime{
    
    NSNumber * randomize = schedule.randomize_schedule;
    if(randomize == nil) randomize = @0;
    
    NSNumber * fireHour   = schedule.fire_hour;
    NSNumber * expiration = schedule.expiration_threshold;
    NSDate   * fireDate   = [AWAREUtils getTargetNSDate:[NSDate new] hour:[fireHour floatValue] nextDay:YES];
    NSDate   * originalFireDate = [AWAREUtils getTargetNSDate:[NSDate new] hour:[fireHour floatValue] nextDay:YES];
    NSString * scheduleId = schedule.schedule_id;
    NSNumber * interface  = schedule.interface;
    bool repeat = YES;
    if (schedule.repeat!=nil) {
        repeat = schedule.repeat.boolValue;
    }
    
    NSDictionary * userInfo = [[NSDictionary alloc] initWithObjects:@[originalFireDate, randomize, scheduleId,expiration,fireDate,interface]
                                                            forKeys:@[@"original_fire_date", @"randomize",
                                                                      @"schedule_id", @"expiration_threshold",@"fire_date",@"interface"]];
    
    
    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
    content.title = schedule.notification_title;
    content.body = schedule.notification_body;
    content.sound = [UNNotificationSound defaultSound];
    content.categoryIdentifier = categoryNormalESM;
    content.userInfo = userInfo;
    content.badge = @(1);
    
    NSDateComponents * components = (NSDateComponents *)schedule.timer;
    if (components !=nil) {
        UNCalendarNotificationTrigger * trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:repeat];
        NSString * requestId = [NSString stringWithFormat:@"%@_%zd_%zd_%@",KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER,components.hour,components.minute, schedule.schedule_id];
        UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:requestId content:content trigger:trigger];
        
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center removePendingNotificationRequestsWithIdentifiers:@[requestId]];
        [center removeDeliveredNotificationsWithIdentifiers:@[requestId]];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error!=nil) {
                NSLog(@"[ESMScheduleManager:TimerBasedNotification] %@", error.debugDescription);
            }else{
                if(self->_debug)NSLog(@"[ESMScheduleManager:TimerBasedNotification] Set a notification");
            }
        }];
       
    }
}

/**
 Set a time based notifiation
 
 @param schedule EntityESMSchdule
 */
- (void) setContextBasedNotification:(EntityESMSchedule *)schedule{
    NSString * contextsString = schedule.contexts;
    NSData * contextsData = [contextsString dataUsingEncoding:NSUTF8StringEncoding];
    NSError * error = nil;
    NSArray * contexts = [NSJSONSerialization JSONObjectWithData:contextsData options:0 error:&error];
    if (error!=nil) {
        return;
    }
    if (contexts==nil || contexts.count == 0) {
        return;
    }
    for (NSString * context in contexts) {
        //NSLog(@"context: %@",context);

        NSString * title = schedule.notification_title;
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:context
                                                                        object:nil
                                                                         queue:[NSOperationQueue currentQueue]
                                                                    usingBlock:^(NSNotification * _Nonnull note) {
            UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
            content.title = title;
            content.sound = [UNNotificationSound defaultSound];
            content.badge = @1;

            UNNotificationTrigger * trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
            UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:@"aware.esm.context.notification" content:content trigger:trigger];

            [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[@"aware.esm.context.notification"]];
            [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[@"aware.esm.context.notification"]];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {

            }];
            
        }];
        [contextObservers addObject:observer];

    }
}

- (void) sendContextBasedESMNotification:(NSNotification *)notification{
    
    NSLog(@"%@",notification.debugDescription);
    
}

/**
 Set a time based notifiation
 
 @param schedule EntityESMSchdule
 */
- (BOOL) isValidContextBasedESMSchedule:(EntityESMSchedule *)schedule {
    
    return YES;
}


/**
 Remove pending notification schedules which has KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER.
 
 @note This operation is aynchroized!!
 */
-(void)removeESMNotificationsWithHandler:(NotificationRemoveCompleteHandler)handler {
    
    NSDate * now = [NSDate new];
    
    for (id observer in contextObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
    [contextObservers removeAllObjects];
    
    // Get ESMs from SQLite by using CoreData
    NSArray * esmSchedules = [self getValidSchedulesWithDatetime:now];
    if(esmSchedules == nil) return;
    
    // remove all old notifications from UNUserNotificationCenter
    UNUserNotificationCenter * center = [UNUserNotificationCenter currentNotificationCenter];
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        if (requests != nil) {
            for (UNNotificationRequest * request in requests) {
                NSString * identifier = request.identifier;
                if (identifier!=nil) {
                    if ([identifier hasPrefix:KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER] || [identifier hasPrefix:@"FOLLOWUP_"] || [identifier hasPrefix: @"SECONDARY_"] || [identifier hasPrefix:@"expirationNotification"]) {
                        
                        if (self->_debug) NSLog(@"[ESMScheduleManager] remove pending notification: %@", identifier);
                        [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];
                    }
                }
            }
        }
        if (handler != nil) {
            handler();
        }
    }];
}


/**
 Refresh notifications times
 */
- (void) refreshESMNotifications{
    NSDate * now = [NSDate new];
    
    for (id observer in contextObservers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
    [contextObservers removeAllObjects];
    
    // Get ESMs from SQLite by using CoreData
    NSArray <EntityESMSchedule*>* esmSchedules = [self getValidSchedulesWithDatetime:now];
    if(esmSchedules == nil) return;
    
    // remove all old notifications from UNUserNotificationCenter
    UNUserNotificationCenter * center = [UNUserNotificationCenter currentNotificationCenter];
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        
//        for (UNNotificationRequest * request in requests) {
//            NSString * identifer = request.identifier;
//            if ([identifer hasPrefix:KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER]) {
//                if (self->_debug){
//                    NSLog(@"[ESMScheduleManager] remove pending notification: %@", identifer);
//                }
//                [center removePendingNotificationRequestsWithIdentifiers:@[identifer]];
//            }
//        }
        
        //////// Set new UNNotifications /////////
        for (int i=0; i<esmSchedules.count; i++) {
            //NSLog(@"new notification set for [%@]", esmSchedules[i].schedule_id);
            EntityESMSchedule * schedule = esmSchedules[i];

            NSNumber * hour = schedule.fire_hour;
            NSDateComponents * timer = (NSDateComponents *)schedule.timer;
            // NSString * contexts = schedule.contexts;
            
            /**  Hours Based ESM */
            if (hour.intValue != -1) {
                [self setHourBasedNotification:schedule datetime:now];
            }

            /**  Timer Based ESM */
            if( timer != nil ){
                [self setTimeBasedNotification:schedule datetime:now];
            }
            
            /** Context Based ESM */
//            if (![contexts isEqualToString:@""]){
//                [self setContextBasedNotification:schedule];
//            }
        }
    }];
}


////////////// DEBUG ////////////////




    //used to determine if the app can reload ESMs without messing up data collection
- (BOOL) hasEsmValidOrFollowupsScheduled {
    
    //if there is currently a valid schedule, return yes
    if([self getValidSchedules].count>0) return YES;
    
    NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    NSFetchRequest * request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([EntityESMSchedule class])];
    NSDate * currentDate = [NSDate new];
  
    //get active schedules
    [request setPredicate:[NSPredicate predicateWithFormat:@"followup==1 AND start_date <= %@ AND end_date >= %@"
                                             argumentArray:@[currentDate,currentDate,]]];
    
    
    NSError * error   = nil;
    NSArray <EntityESMSchedule*>* results = [context executeFetchRequest:request error:&error];
    if (error!=nil) {
        NSLog(@"[Error][ESMScheduleManager] %@", error.debugDescription);
        return nil;
    }
    
    if(results.count>0) return YES;
    
    
    NSArray <EntityESMSchedule *> * currentSchedules=[self getValidSchedules];
    
    
    /*
    * if a followup esm schedule exists among the active schedules, return yes
    * (the followup will not be rescheduled if the app refreshes it's ESMs)
    */
    for (EntityESMSchedule * schedule in currentSchedules){
        if (schedule.followup.boolValue) return YES;
    }
    
    return NO;
}


/**
 Remove all pending/delivded notifications from the UNUserNotificationCenter for a debug
 */
//- (void) removeAllNotifications {
//    UNUserNotificationCenter * notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
//    [notificationCenter removeAllDeliveredNotifications];
//    [notificationCenter removeAllPendingNotificationRequests];
//}





- (BOOL) saveESMAnswerWithTimestamp:(NSNumber *) timestamp
                           deviceId:(NSString *) deviceId
                            esmJson:(NSString *) esmJson
                         esmTrigger:(NSString *) esmTrigger
             esmExpirationThreshold:(NSNumber *) esmExpirationThreshold
             esmUserAnswerTimestamp:(NSNumber *) esmUserAnswerTimestamp
                      esmUserAnswer:(NSString *) esmUserAnswer
                          esmStatus:(NSNumber *) esmStatus {
    NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    EntityESMAnswer * answer = (EntityESMAnswer *)
    [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([EntityESMAnswer class])
                                  inManagedObjectContext:context];
    // add special data to dic from each uielements
    answer.device_id   = deviceId;
    answer.timestamp   = timestamp;
    answer.esm_json    = esmJson;
    answer.esm_trigger = esmTrigger;
    answer.esm_user_answer = esmUserAnswer;
    answer.esm_expiration_threshold = esmExpirationThreshold;
    answer.double_esm_user_answer_timestamp = esmUserAnswerTimestamp;
    answer.esm_status  = esmStatus;
    
    NSError * error = nil;
    [context save:&error];
    if(error != nil){
        NSLog(@"%@", error.debugDescription);
        return NO;
    }else{
        return YES;
    }
}


- (void) postponeCurrentSignal: (NSDictionary *) userInfo {
    
    
    
    NSDate * initialFireDate = [userInfo objectForKey:@"fire_date"];
    NSNumber * expiration = [userInfo objectForKey:@"expiration_threshold"];

    NSDate *expirationTime;
    if(initialFireDate !=nil && expiration != nil) expirationTime = [initialFireDate dateByAddingTimeInterval: expiration.intValue * 60];
    
    //if the dictionary did not parse or the schedule has already expired
    if(expirationTime==nil || expirationTime.timeIntervalSinceNow <0){
        //no valid schedules--notification is probably expired
        UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
        content.title = @"Signal Expired";
        content.body  = @"This ESM survey has already expired";
        content.sound = [UNNotificationSound defaultSound];
        content.categoryIdentifier = categoryNormalESM;
        content.badge = @(1);

        UNTimeIntervalNotificationTrigger * trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];

        NSString *notificationId = @"expirationNotification";

        UNNotificationRequest    * request = [UNNotificationRequest requestWithIdentifier:notificationId content:content trigger:trigger];
        UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
        [center removePendingNotificationRequestsWithIdentifiers:@[notificationId]];
        [center removeDeliveredNotificationsWithIdentifiers:@[notificationId]];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
           if (error!=nil) {
               NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
           }else{
               if (self->_debug){
                   NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: now");
               }
           }
        }];
        
        return;
    }
    
    //VALID SCHEULES EXIST TO BE POSTPONED
    NSArray <EntityESMSchedule *> * schedules =[self getValidSchedulesWithDatetime:[userInfo objectForKey:@"fire_date"]];
    
    NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    
    EntityESMSchedule * schedule=schedules[0];
    schedule.extend=@(1);
    
    NSError *saveError = nil;
    BOOL saved = [context save:&saveError];
    if (!saved && saveError!=nil) {
            NSLog(@"[ESMScheduleManager] data delete error: %@", saveError.debugDescription);
    }
    //NSLog(@"signal postponed for: %@", [userInfo objectForKey:@"schedule_id"]);
    
    
    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Final Reminder";
    content.body  = @"There are 5 minutes remaining on the current ESM survey";
    content.sound = [UNNotificationSound defaultSound];
    content.categoryIdentifier = categoryNormalESM;
    content.badge = @(1);
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate * fireDate = [AWAREUtils getTargetNSDate:[NSDate new]
                                               hour:schedule.fire_hour.floatValue
                                             minute:schedule.offset.intValue+schedule.expiration_threshold.intValue
                                             second: 0
                                            nextDay:YES];
    
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:fireDate];
    UNCalendarNotificationTrigger * trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:NO];

    NSString *notificationId = @"expirationNotification";
    
    UNNotificationRequest    * request = [UNNotificationRequest requestWithIdentifier:notificationId content:content trigger:trigger];
    
    
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[notificationId]];
    [center removeDeliveredNotificationsWithIdentifiers:@[notificationId]];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
       if (error!=nil) {
           NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
       }else{
           if (self->_debug){
               NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd",trigger.dateComponents.hour,trigger.dateComponents.minute);
           }
           
           
            //NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd", trigger.dateComponents.hour,trigger.dateComponents.minute);
           
           
       }
    }];
    
    
}





#pragma mark - MISC

- (NSInteger)randomNumberBetween:(int)min maxNumber:(int)max {
    return min + arc4random_uniform(max - min + 1);
}

- (NSString *) convertToJSONStringWithArray:(NSArray *) array {
    if (array == nil) return @"";
    
    NSError * error = nil;
    NSData  * jsonData = [NSJSONSerialization dataWithJSONObject:array options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"[EntityESM] Convert Error to JSON-String from NSArray: %@", error.debugDescription);
        return @"";
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (jsonString != nil) {
        return jsonString;
    }else{
        return @"";
    }
}

- (NSString *) convertToJSONStringWithDictionary:(NSDictionary *) dictionary{
    if (dictionary == nil) return @"";
    
    NSError * error = nil;
    NSData  * jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (error != nil) {
        NSLog(@"[EntityESM] Convert Error to JSON-String from NSDictionary: %@", error.debugDescription);
        return @"";
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (jsonString != nil) {
        return jsonString;
    }else{
        return @"";
    }
}

- (void) bedtime: (NSNumber * _Nonnull) time {
    [self setBedtime:time];
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    
    [defaults setInteger: time.integerValue forKey: @"bedtime"];
    [defaults synchronize];
    if(self -> _debug) NSLog(@"bedtime recorded: %@", time);
}

- (void) waketime: (NSNumber * _Nonnull) time {
    [self setWaketime:time];
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    [defaults setInteger: time.integerValue forKey: @"waketime"];
    [defaults synchronize];
    if(self -> _debug) NSLog(@"waketime recorded: %@", time);
}



//esmData is json
- (BOOL) addSchedule:(ESMSchedule * _Nonnull) schedule
            withESMs: (NSString * _Nonnull) esmData
    withNotification:(BOOL)notification{
    
    
    NSManagedObjectContext * manageContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    manageContext.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
    
    
    NSDate * now = [NSDate new];
        
    //calculate hour and minute of followup esm by adding x minutes to it
    NSDate *fireDate = [now dateByAddingTimeInterval: schedule.followupDelay.intValue*60];
    NSDate * endDate = [fireDate dateByAddingTimeInterval: (schedule.expirationThreshold.intValue +11)*60];

    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:fireDate];
    
    NSNumber * hour = [NSNumber numberWithInteger:[components hour]];
    NSNumber * minute = [NSNumber numberWithInteger:[components minute]];
    
    //set offset from the hour to the minute x minutes after submission
    schedule.offset = minute;

    //////////////////////////////////////////////

    //new entity schedule for followup q's
    EntityESMSchedule * entitySchedule = [[EntityESMSchedule alloc] initWithContext:manageContext];
    entitySchedule = [self transferESMSchedule:schedule
                                      toEntity:entitySchedule];
    
    
    entitySchedule.start_date=[NSDate new];
    entitySchedule.end_date = endDate;
    //set to calculated hour
    entitySchedule.fire_hour = hour;
    entitySchedule.followup_json=@"";
    // contexts
    entitySchedule.contexts = [self convertToJSONStringWithArray:schedule.contexts];
    // weekdays
    entitySchedule.weekdays = [self convertToJSONStringWithArray:schedule.weekdays];
    
    //add esms from json of followup esms
    
     NSError *error = nil;
       NSData *data = [esmData dataUsingEncoding:NSUTF8StringEncoding];
       NSArray * esms = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &error];

    if (!esms) {
      NSLog(@"Error parsing JSON: %@", error);
    }
    
//    for( EntityESM * esm in esms){
//         [entitySchedule addEsmsObject:esm];
//    }
    
    double number=0;
    
    for (NSDictionary * esmDict in esms) {
        NSDictionary  * esm = [esmDict objectForKey:@"esm"];
        EntityESM     * entityEsm = (EntityESM *) [NSEntityDescription insertNewObjectForEntityForName: NSStringFromClass([EntityESM class])
                     inManagedObjectContext:manageContext];
        entityEsm.esm_type   = [esm objectForKey:@"esm_type"];
        entityEsm.esm_title  = [esm objectForKey:@"esm_title"];
        entityEsm.esm_submit = [esm objectForKey:@"esm_submit"];
        entityEsm.esm_instructions = [esm objectForKey:@"esm_instructions"];
        entityEsm.esm_radios     = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_radios"]];
        entityEsm.esm_checkboxes = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_checkboxes"]];
        entityEsm.esm_likert_max = [esm objectForKey:@"esm_likert_max"];
        entityEsm.esm_likert_max_label = [esm objectForKey:@"esm_likert_max_label"];
        entityEsm.esm_likert_min_label = [esm objectForKey:@"esm_likert_min_label"];
        entityEsm.esm_likert_step = [esm objectForKey:@"esm_likert_step"];
        entityEsm.esm_quick_answers = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_quick_answers"]];
        entityEsm.esm_expiration_threshold = [esm objectForKey:@"esm_expiration_threshold"];
        // entityEsm.esm_status    = [esm objectForKey:@"esm_status"];
        entityEsm.esm_status = @0;
        entityEsm.esm_trigger   = [esm objectForKey:@"esm_trigger"];
        entityEsm.esm_scale_min = [esm objectForKey:@"esm_scale_min"];
        entityEsm.esm_scale_max = [esm objectForKey:@"esm_scale_max"];
        entityEsm.esm_scale_start = [esm objectForKey:@"esm_scale_start"];
        entityEsm.esm_scale_max_label = [esm objectForKey:@"esm_scale_max_label"];
        entityEsm.esm_scale_min_label = [esm objectForKey:@"esm_scale_min_label"];
        entityEsm.esm_scale_step = [esm objectForKey:@"esm_scale_step"];
        entityEsm.esm_json = [self convertToJSONStringWithArray:@[esm]];
        entityEsm.esm_number = @(number);
        // for date&time picker
        entityEsm.esm_start_time = [esm objectForKey:@"esm_start_time"];
        entityEsm.esm_start_date = [esm objectForKey:@"esm_start_date"];
        entityEsm.esm_time_format = [esm objectForKey:@"esm_time_format"];
        entityEsm.esm_minute_step = [esm objectForKey:@"esm_minute_step"];
        // for web ESM url
        entityEsm.esm_url = [esm objectForKey:@"esm_url"];
        // for na
        entityEsm.esm_na = @([[esm objectForKey:@"esm_na"] boolValue]);
        entityEsm.esm_flows = [self convertToJSONStringWithArray:[esm objectForKey:@"esm_flows"]];
        // NSLog(@"[%d][integration] %@",number, [esm objectForKey:@"esm_app_integration"]);
        entityEsm.esm_app_integration = [esm objectForKey:@"esm_app_integration"];
        // entityEsm.esm_schedule = entityESMSchedule;
        
        [entitySchedule addEsmsObject:entityEsm];
        //NSLog(@"Added esm-->id:%@ number:%f", entityEsm.esm_title, number);
        number ++;
    }
    //NSLog(@"ESMs added: %f", number);
   
 
    /**  Hours Based ESM */
    if (hour.intValue != -1 && notification) {
        
        NSLog(@"ID: %@, firehour: %@, fire offset: %@", entitySchedule.schedule_id, entitySchedule.fire_hour, entitySchedule.offset);
        
//        [self setHourBasedNotification:entitySchedule datetime:now];
        
        
           
       NSDictionary * userInfo = [[NSDictionary alloc] initWithObjects:@[fireDate, entitySchedule.randomize_esm, entitySchedule.offset, entitySchedule.schedule_id,entitySchedule.expiration_threshold,  entitySchedule.interface]
              forKeys:@[@"fire_date", @"randomize", @"offset", @"schedule_id", @"expiration_threshold",@"interface"]];
       
       UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc] init];
       content.title = entitySchedule.notification_title;
       content.body  = entitySchedule.notification_body;
       content.sound = [UNNotificationSound defaultSound];
       content.categoryIdentifier = categoryNormalESM;
       content.userInfo = userInfo;
       content.badge = @(1);

       NSCalendar *calendar = [NSCalendar currentCalendar];
       NSDateComponents *components = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:fireDate];
       UNCalendarNotificationTrigger * trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:NO];

       NSString *notificationId = [NSString stringWithFormat:@"FOLLOWUP_%@_%@_%@",KEY_AWARE_NOTIFICATION_DEFAULT_REQUEST_IDENTIFIER,entitySchedule.fire_hour.stringValue,entitySchedule.schedule_id];

       UNNotificationRequest    * request = [UNNotificationRequest requestWithIdentifier:notificationId content:content trigger:trigger];
       UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
       [center removePendingNotificationRequestsWithIdentifiers:@[notificationId]];
       [center removeDeliveredNotificationsWithIdentifiers:@[notificationId]];
       [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
          if (error!=nil) {
              NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
          }else{
              if (self->_debug){
                  NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd",trigger.dateComponents.hour,trigger.dateComponents.minute);
              }
          }
       }];
        
        //SECONDARY NOTIFICATION
        
        NSDate * secondaryFire = [fireDate dateByAddingTimeInterval: (entitySchedule.expiration_threshold.intValue-5)*60];

        UNMutableNotificationContent * content2 = [[UNMutableNotificationContent alloc] init];
        
        content2.title=entitySchedule.notification_title;
        content2.body = @"There are 5 minutes remaining to answer the current survey. Press and hold this notification to extend by 5 minutes.";
        content2.sound = [UNNotificationSound defaultSound];
        content2.categoryIdentifier = @("postpone");
        content2.userInfo = userInfo;
        content2.badge = @(1);
        
        NSDateComponents * components2 = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:secondaryFire];
        UNCalendarNotificationTrigger*trigger2 = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components2 repeats:NO];
        NSString * secondNotificationId = [NSString stringWithFormat:@"SECONDARY_%@_%@",entitySchedule.schedule_id,entitySchedule.offset.stringValue];
        
        UNNotificationRequest    * secondRequest = [UNNotificationRequest requestWithIdentifier:secondNotificationId content:content2 trigger:trigger2];
        
        [center removePendingNotificationRequestsWithIdentifiers:@[secondNotificationId]];
        [center removeDeliveredNotificationsWithIdentifiers:@[secondNotificationId]];
        [center addNotificationRequest:secondRequest withCompletionHandler:^(NSError * _Nullable error) {
            if (error!=nil) {
                NSLog(@"[ESMScheduleManager:HourBasedNotification] %@", error.debugDescription);
            }else{
                if (self->_debug){
                    NSLog(@"[ESMScheduleManager:HourBasedNotification] Set a notification: %zd:%zd",trigger.dateComponents.hour,trigger.dateComponents.minute);
                }
            }
        }];
        
    }
    
    // error checking for data and schedules (I think)
    error = nil;
    bool saved = [manageContext save:&error];
    if (saved) {
    }else{
        if (error != nil) {
            NSLog(@"[ESMScheduleManager followup] data save error: %@", error.debugDescription);
        }
    }
    
    return saved;
}


#pragma mark - Entity Removal

/**
 Remove all ESM Schdules from database.
 
 @note This method remove all of schedule entities from SQLite. Please use care fully.
 
 @return A state of the remove offeration success or not.
 */
- (BOOL) removeAllSchedulesFromDB {
    // AWAREDelegate *delegate=(AWAREDelegate*)[UIApplication sharedApplication].delegate;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([EntityESMSchedule class])];
    NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    
    NSError *deleteError = nil;
    [[CoreDataHandler sharedHandler].managedObjectContext executeRequest:delete error:&deleteError];
    if(deleteError != nil){
        NSLog(@"[ESMScheduleManager:removeNotificationScheduleFromSQLite] Error: A delete query is failed");
        return NO;
    }
    
    return YES;
}

/**
 Remove all ESM answer histories

 @return A status of the removing ESM history
 */
- (BOOL) removeAllESMHitoryFromDB {
    NSFetchRequest       * request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass([EntityESMAnswerHistory class])];
    NSBatchDeleteRequest * delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    
    NSError *deleteError = nil;
    [[CoreDataHandler sharedHandler].managedObjectContext executeRequest:delete error:&deleteError];
    if(deleteError != nil){
        NSLog(@"[ESMScheduleManager:removeESMHistoryFromSQLite] Error: A delete query is failed");
        return NO;
    }
    return YES;
}


- (bool) removeFollowupESMsFromDB {
        
        //NSLog(@"FOLLOWUPS REMOVED");
        NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EntityESMSchedule"];
        [request setPredicate:[NSPredicate predicateWithFormat: @"followup==1"]];
        NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];

        NSError *deleteError = nil;
        
        BOOL deleted=[context.persistentStoreCoordinator executeRequest:delete withContext:context error:&deleteError];
        
         if (deleted) {
                   return YES;
         }else{
            if (deleteError!=nil) {
                NSLog(@"[ESMScheduleManager] data delete error: %@", deleteError.debugDescription);
            }
            return NO;
        }
    
}



- (bool) removeSavedAnswersFromDB {
        
        NSManagedObjectContext * context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        context.persistentStoreCoordinator = [CoreDataHandler sharedHandler].persistentStoreCoordinator;
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EntityESMResponse"];
        NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];

        NSError *deleteError = nil;
        
        BOOL deleted=[context.persistentStoreCoordinator executeRequest:delete withContext:context error:&deleteError];
        
         if (deleted) {
                   return YES;
         }else{
            if (deleteError!=nil) {
                NSLog(@"[ESMScheduleManager] data delete error: %@", deleteError.debugDescription);
            }
            return NO;
        }
    
}


- (void) removePendingNotificationsForSchedule: (EntityESMSchedule *) schedule{
    
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
    NSString * secondaryID = [NSString stringWithFormat:@"SECONDARY_%@_%@", schedule.schedule_id, schedule.offset.stringValue];
    NSString * finalID = @"expirationNotification";

    [center removePendingNotificationRequestsWithIdentifiers:@[secondaryID, finalID]];
    
}


@end
