//
//  Queue.m
//  
//
//  Created by Jami Boy Mohammad on 2014-09-20.
//
//

#import "NSMutableArray+Queue.h"

@implementation NSMutableArray(Queue)

-(void) shiftDown {
    for (int i = 0; i < self.count - 1; i++){
        [self replaceObjectAtIndex:i withObject:[self objectAtIndex:i+1]];
    }
    [self removeLastObject];
}

-(void) pushFloat:(float)insert withMax:(int)size {
    [self addObject:@(insert)];
    if (self.count > size) {
        [self shiftDown];
    }
}

-(NSDictionary*) evaluate {
    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    float sum = 0.0f;
    float low = MAXFLOAT;
    float peak = 0.0f;
    for (int i = 0; i < self.count; i++) {
        float val = [[self objectAtIndex:i] floatValue];
        sum += val;
        peak = (peak > val) ? peak : val;
        low = (low < val) ? low : val;
    }
    [result setValue:@(low) forKey:@"low"];
    [result setValue:@(sum/self.count) forKey:@"average"];
    [result setValue:@(peak) forKey:@"peak"];
    return result;
}

@end
