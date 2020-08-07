//
//  bedAndWakeTimes.h
//  Pods
//
//  Created by Sara Strenger on 6/3/20.
//


#import <Foundation/Foundation.h>


@interface BedeWakeTimes : NSObject
{
    NSNumber *bedHour;
    NSNumber *wakeHour;
}


-(void)setBedTime:(NSNumber *) bed;
-(void)setWakeTime:(NSNumber *) wake;
-(NSNumber *) bedTime
-(NSNumber *) wakeTime
@end



