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
#define JOKE 10
#define STOP 11
#define PLACEHOLDER_SONG @"92891230914290vnsar32uhf09ashr39h1od9"

@interface ActionHandler () <NSSpeechSynthesizerDelegate> {
    NSUserNotification *notification;
}



typedef NS_ENUM(NSInteger, IntentType) {
    IntentTypeTest,

};

@property (nonatomic, strong) NSDictionary *intentTypes;

@end

@implementation ActionHandler

- (id) init {
    notification = [[NSUserNotification alloc] init];
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
        case TIME: {
            [self muteMicPLZ];
            [self sayTime];
        }
            break;
        case JOKE: {
            [self muteMicPLZ];
            [self tellAJoke]; //tell a joke!
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
                        songName = PLACEHOLDER_SONG;
                    }
                    [self playMusic:songName];
                }
            }
        }
            break;
        case LAUNCH: { //will not do anything if value is nil
            NSString *entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != nil) {
                NSString *applicationJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"application"];
                if (applicationJSON != nil) {
                    NSString *applicationName = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"application"]valueForKey:@"value"];
                    [self launchApplication:applicationName];
                }
            }
        }
            break;
        case SEARCH: { //will not do anything if value is nil
            NSString *entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != nil) {
                NSString *searchJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"search_query"];
                if (searchJSON != nil) {
                    NSString *searchText = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"search_query"]valueForKey:@"value"];
                    [self  search:searchText];
                }
            }
        }
            break;
        case STOP: {
            [self muteMicPLZ];
        }
            break;
        
        case WEATHER: {
            [self muteMicPLZ];
            [self sayWeather];
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
    else if ([intent isEqualToString:@"joke"]) {
        return JOKE;
    }
    else if ([intent isEqualToString:@"stop"]) {
        return STOP;
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

//a little something for fun!
- (void) tellAJoke
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    sp.delegate = self;
    [sp setVolume:100.0];
    [sp startSpeakingString:@"My End User License does not cover jokes. Don't you have something better to do?"];
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
    [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
    notification.title = @"Jarvis";
    notification.informativeText = [NSString stringWithFormat:@"It's %@", dateString];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
    });
}

- (void) sayWeather
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
    sp.delegate = self;
    
    NSString *weatherString = [self getWeatherString:[self getWeatherInformation:@"Waterloo"]];
    
    [sp startSpeakingString:weatherString];
}



- (void) playMusic: (NSString*)song
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"music" ofType:@"scpt"];
    NSArray *args;
    NSString *func;
    if ([song  isEqualToString:PLACEHOLDER_SONG]) {
        args = nil;
        func = @"playAny";
    }
    else {
        args = @[song];
        func = @"play";
    }
    [self executeScriptWithPath:path function:func andArguments:args];
}

- (void) launchApplication: (NSString*) application
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"launch" ofType:@"scpt"];
    NSArray *args = @[application];
    [self executeScriptWithPath:path function:@"start" andArguments:args];
}

- (void) search: (NSString*) searchTerm
{
    NSString *formattedUrl = [NSString stringWithFormat:@"%@%@", @"https://www.google.com/search?q=", [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"%20"]];
    NSArray *urlArg = @[formattedUrl];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"search" ofType:@"scpt"];
    [self executeScriptWithPath:path function:@"openInSafari" andArguments:urlArg];
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

- (NSDictionary*) makeGETRequest:(NSString *) url
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:@"GET"];
    [req setCachePolicy:NSURLCacheStorageNotAllowed];
    [req setTimeoutInterval:15.0];
    
    // send HTTP request
    NSURLResponse* response = nil;
    NSError *error = nil;
    NSData *data2 = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    
    NSError *serializationError;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data2
                                                           options:0
                                                             error:&serializationError];
    return object;
}

- (NSDictionary*) getWeatherInformation:(NSString *) locationQuery
{
    return [self makeGETRequest:
            [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/weather?units=metric&q=%@", locationQuery]];
}

- (NSString*) getWeatherDescriptionFromIcon:(NSString *) iconString
{
    NSString *description = @"It's";
    
    if ([iconString isEqualToString:@"01d"] || [iconString isEqualToString:@"01n"]) {
        description = @"It's currently clear and";
    }
    else if ([iconString isEqualToString:@"02d"] || [iconString isEqualToString:@"02n"] ||
             [iconString isEqualToString:@"03d"] || [iconString isEqualToString:@"03n"] ||
             [iconString isEqualToString:@"04d"] || [iconString isEqualToString:@"04n"]) {
        description = @"It's currently a little cloudy and";
    }
    else if ([iconString isEqualToString:@"09d"] || [iconString isEqualToString:@"09n"] ||
             [iconString isEqualToString:@"10d"] || [iconString isEqualToString:@"10n"] ||
             [iconString isEqualToString:@"11d"] || [iconString isEqualToString:@"11n"]) {
        description = @"It's currently raining and";
    }
    else if ([iconString isEqualToString:@"13d"] || [iconString isEqualToString:@"13n"]) {
        description = @"It's currently snowing and";
    }
    else if ([iconString isEqualToString:@"50d"] || [iconString isEqualToString:@"50n"]) {
        description = @"It's currently foggy and";
    }
    
    return description;
}

- (NSString*) getWeatherString:(NSDictionary*)weatherResponse
{
    NSString *icon = [[weatherResponse valueForKey:@"weather"][0] valueForKey:@"icon"];
    NSString *conditions = [self getWeatherDescriptionFromIcon:icon];
    
    int temperature = (int) lroundf([[[weatherResponse valueForKey:@"main"] valueForKey:@"temp"] floatValue]);
    NSLog(@"%d", temperature);
    
    return [NSString stringWithFormat:@"%@ %d degrees outside.", conditions, temperature];
}


@end
