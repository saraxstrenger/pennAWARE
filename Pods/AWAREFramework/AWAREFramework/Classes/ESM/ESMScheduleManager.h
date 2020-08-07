//
//  ESMScheduleManager.h
//  AWAREFramework
//
//  Created by Yuuki Nishiyama on 2018/03/27.
//
//  Modified by Sara Strenger June/July 2020
//

#import <Foundation/Foundation.h>
#import "ESMSchedule.h"
#import "ESMItem.h"

@interface ESMScheduleManager : NSObject

+ (ESMScheduleManager * _Nonnull) sharedESMScheduleManager;

@property BOOL debug;
@property  (assign, readwrite) NSNumber* _Nonnull waketime;
@property  (assign, readwrite) NSNumber* _Nonnull bedtime;

typedef void (^NotificationRemoveCompleteHandler)(void);

- (BOOL) setScheduleByConfig:(NSArray <NSDictionary * > * _Nonnull) config;
- (BOOL) addSchedule:(ESMSchedule * _Nonnull)schedule;
- (BOOL) addSchedule:(ESMSchedule * _Nonnull)schedule withNotification:(BOOL)notification;
- (BOOL) deleteScheduleWithId:(NSString * _Nonnull)scheduleId;
- (BOOL) deleteAllSchedules;
- (BOOL) deleteAllSchedulesWithNotification:(BOOL)notification;
- (NSArray<EntityESMSchedule *> * _Nullable) getESMSchedules;
- (NSArray * _Nonnull) getValidSchedules;
- (NSArray * _Nonnull) getValidSchedulesWithDatetime:(NSDate * _Nonnull)datetime;

- (BOOL) removeAllSchedulesFromDB;
- (BOOL) removeAllESMHitoryFromDB;

// - (void) removeAllNotifications;
- (void) removeESMNotificationsWithHandler:(NotificationRemoveCompleteHandler _Nullable)handler;
- (void) refreshESMNotifications;
- (BOOL) hasEsmValidOrFollowupsScheduled;


- (BOOL) saveESMAnswerWithTimestamp:(NSNumber * _Nonnull) timestamp
                           deviceId:(NSString * _Nonnull) deviceId
                            esmJson:(NSString * _Nonnull) esmJson
                         esmTrigger:(NSString * _Nonnull) esmTrigger
             esmExpirationThreshold:(NSNumber * _Nonnull) esmExpirationThreshold
             esmUserAnswerTimestamp:(NSNumber * _Nonnull) esmUserAnswerTimestamp
                      esmUserAnswer:(NSString * _Nonnull) esmUserAnswer
                          esmStatus:(NSNumber * _Nonnull) esmStatus;
- (void) bedtime:(NSNumber * _Nonnull)time;
- (void) waketime:(NSNumber * _Nonnull)time;
- (BOOL) addSchedule: (ESMSchedule * _Nonnull) schedule
                  withESMs: (NSString * _Nonnull) esmData
          withNotification:(BOOL) notification;

    
- (void) postponeCurrentSignal: (NSDictionary * _Nonnull) userInfo;
- (void) removePendingNotificationsForSchedule: (EntityESMSchedule * _Nonnull) schedule;

@end
