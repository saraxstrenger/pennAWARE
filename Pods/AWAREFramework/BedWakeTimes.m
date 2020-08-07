//
//  bedAndWakeTimes.m
//  AppAuth
//
//  Created by Sara Strenger on 6/3/20.
//

#import "BedWakeTimes.h"

@implementation BedWakeTimes

-(void)setBedTime:(NSNumber *) bed;
{
    bedTime = bed;
}

-(void)setWakeTime:(NSNumber *) wake;
{
    wakeTime = wake;
}
-(NSNumber *) bedTime
{
    return bedTime;
}
-(NSNumber *) wakeTime
{
    return wakeTime;
}

@end
