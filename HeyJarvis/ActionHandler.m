//
//  ActionHandler.m
//  HeyJarvis
//
//  Created by Geoffrey Yu on 2014-09-20.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ActionHandler.h"
#import "AppDelegate.h"
#import <AppKit/NSSpeechRecognizer.h>

#define GREETING 0
#define DAY_SUMMARY 1
#define SEARCH 2
#define NOTIFICATIONS 3
#define LAUNCH 4
#define REMIND 5
#define WEATHER 6
#define TIME 7
#define MESSAGE 8
#define MUSIC 9

@interface ActionHandler () <NSSpeechSynthesizerDelegate>

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
        case GREETING: {
            [self muteMicPLZ];
            [self sayGreeting];
        }
            break;
        case TIME:{
            [self muteMicPLZ];
            [self sayTime];
        }
            break;
    }
}

-(void)muteMicPLZ{
    if ([self.delegate respondsToSelector:@selector(muteMic:)]) {
        [self.delegate muteMic:YES];
    }
}

- (int) decodeIntent:(NSDictionary *)witResponse
{
    NSString *intent = [[witResponse valueForKey:@"outcome"] valueForKey:@"intent"];
    
    if ([intent isEqualToString:@"greeting"]){
        return GREETING;
    }
    else if ([intent isEqualToString:@"day_summary"]) {
        return DAY_SUMMARY;
    }
    else if ([intent isEqualToString:@"search"]) {
        return SEARCH;
    }
    else if ([intent isEqualToString:@"notifications"]) {
        return NOTIFICATIONS;
    }
    else if ([intent isEqualToString:@"launch"]) {
        return LAUNCH;
    }
    else if ([intent isEqualToString:@"remind"]) {
        return REMIND;
    }
    else if ([intent isEqualToString:@"weather"]) {
        return WEATHER;
    }
    else if ([intent isEqualToString:@"time"]) {
        return TIME;
    }
    else if ([intent isEqualToString:@"message"]) {
        return MESSAGE;
    }
    else if ([intent isEqualToString:@"music"]) {
        return MUSIC;
    }
    
    return -1;
}

- (void) sayGreeting
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    sp.delegate = self;
    [sp setVolume:100.0];
    [sp startSpeakingString:@"Hello master! How can I help you today?"];
}

-(void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking{
    if (finishedSpeaking){
        if ([self.delegate respondsToSelector:@selector(muteMic:)]) {
            [self.delegate muteMic:NO];
        }
    }
}

- (void) sayTime
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
     sp.delegate = self;
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"HH:mm a"];
    
    NSDate *now = [[NSDate alloc] init];
    
    NSString *dateString = [format stringFromDate:now];
    [sp startSpeakingString:[NSString stringWithFormat:@"It's %@", dateString]];
}


@end
