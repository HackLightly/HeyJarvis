//
//  ActionHandler.m
//  HeyJarvis
//
//  Created by Geoffrey Yu on 2014-09-20.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ActionHandler.h"
#import <AppKit/NSSpeechRecognizer.h>

#define GREETING 0
#define TIME 1

@interface ActionHandler ()

typedef NS_ENUM(NSInteger, IntentType) {
    IntentTypeTest,

};

@property (nonatomic, strong) NSDictionary *intentTypes;

@end

@implementation ActionHandler

- (id) init {
    return self;
}

// Main entry point to action handler - pass in the response dictionary
- (void) handleAction:(NSDictionary *)witResponse
{
    // Parse dictionary to get intent and entities
    NSLog(@"Handle Action Called");
    int intentID = [self decodeIntent:witResponse];
    
    // Dispatch action
    switch (intentID) {
        case GREETING:
            [self sayGreeting];
            break;
        case TIME:
            [self sayTime];
            break;
    }
}

- (int) decodeIntent:(NSDictionary *)witResponse
{
    NSString *intent = [[witResponse valueForKey:@"outcome"] valueForKey:@"intent"];
    
    if ([intent isEqualToString:@"greeting"]){
        return GREETING;
    } else if ([intent isEqualToString:@"time"]) {
        return TIME;
    }
    
    return -1;
}

- (void) sayGreeting
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
    [sp startSpeakingString:@"Hello master! How can I help you today?"];
}

- (void) sayTime
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"HH:mm a"];
    
    NSDate *now = [[NSDate alloc] init];
    
    NSString *dateString = [format stringFromDate:now];
    [sp startSpeakingString:[NSString stringWithFormat:@"It's %@", dateString]];
}


@end
