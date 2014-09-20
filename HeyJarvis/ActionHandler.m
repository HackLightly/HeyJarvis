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
#define DEFAULT_SONG @"Call Me Maybe"

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
        case MUSIC: {
            NSString *entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != nil) {
                NSString *songJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"song"];
                if (songJSON != nil) {
                    NSString *songName = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"song"]valueForKey:@"value"];
                    if ([songName rangeOfString:@"music"].location != NSNotFound ||
                        [songName rangeOfString:@"some music"].location != NSNotFound ||
                        [songName rangeOfString:@"tunes"].location != NSNotFound) {
                        //play default song = Call Me Maybe
                        songName = DEFAULT_SONG;
                    }
                    [self playMusic:songName];
                }
            }
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


- (void) playMusic: (NSString*)song
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"music" ofType:@"scpt"];
    NSArray *args = @[song];
    [self executeScriptWithPath:path function:@"play" andArguments:args];
}

//taken from https://stackoverflow.com/questions/6963072/execute-applescript-from-cocoa-app-with-params
- (BOOL) executeScriptWithPath:(NSString*)path function:(NSString*)functionName andArguments:(NSArray*)scriptArgumentArray
{
    BOOL executionSucceed = NO;
    
    NSAppleEventDescriptor  * thisApplication, *containerEvent;
    NSURL                   * pathURL = [NSURL fileURLWithPath:path];
    
    NSDictionary * appleScriptCreationError = nil;
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:pathURL error:&appleScriptCreationError];
    
    if (appleScriptCreationError)
    {
        NSLog([NSString stringWithFormat:@"Could not instantiate applescript %@",appleScriptCreationError]);
    }
    else
    {
        if (functionName && [functionName length])
        {
            /* If we have a functionName (and potentially arguments), we build
             * an NSAppleEvent to execute the script. */
            
            //Get a descriptor for ourself
            int pid = [[NSProcessInfo processInfo] processIdentifier];
            thisApplication = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID
                                                                             bytes:&pid
                                                                            length:sizeof(pid)];
            //Create the container event
            //We need these constants from the Carbon OpenScripting framework, but we don't actually need Carbon.framework...
            #define kASAppleScriptSuite 'ascr'
            #define kASSubroutineEvent  'psbr'
            #define keyASSubroutineName 'snam'
            containerEvent = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
                                                                      eventID:kASSubroutineEvent
                                                             targetDescriptor:thisApplication
                                                                     returnID:kAutoGenerateReturnID
                                                                transactionID:kAnyTransactionID];
            
            //Set the target function
            [containerEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:functionName]
                                    forKeyword:keyASSubroutineName];
            
            //Pass arguments - arguments is expecting an NSArray with only NSString objects
            if ([scriptArgumentArray count])
            {
                NSAppleEventDescriptor  *arguments = [[NSAppleEventDescriptor alloc] initListDescriptor];
                NSString                *object;
                
                for (object in scriptArgumentArray) {
                    [arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:object]
                                        atIndex:([arguments numberOfItems] + 1)]; //This +1 seems wrong... but it's not
                }
                
                [containerEvent setParamDescriptor:arguments forKeyword:keyDirectObject];
            }
            
            //Execute the event
            NSDictionary * executionError = nil;
            NSAppleEventDescriptor * result = [appleScript executeAppleEvent:containerEvent error:&executionError];
            if (executionError != nil)
            {
                NSLog([NSString stringWithFormat:@"error while executing script. Error %@",executionError]);
                
            }
            else
            {
                NSLog(@"Script execution has succeed. Result(%@)",result);
                executionSucceed = YES;
            }
        }
        else
        {
            NSDictionary * executionError = nil;
            NSAppleEventDescriptor * result = [appleScript executeAndReturnError:&executionError];
            
            if (executionError != nil)
            {
                NSLog([NSString stringWithFormat:@"error while executing script. Error %@",executionError]);
            }
            else
            {
                NSLog(@"Script execution has succeed. Result(%@)",result);
                executionSucceed = YES;
            }
        }
    }
    
    return executionSucceed;
}



@end
