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
#import <EventKit/EKEventStore.h>
#import <EventKit/EKEvent.h>
#import <stdlib.h>

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
#define PLACEHOLDER_SONG @"9289dsf3914290vnsar32uhf09ashr39h1od9"
#define PLACEHOLDER_TIME 92719272

@interface ActionHandler () <NSSpeechSynthesizerDelegate> {
    NSUserNotification *notification;
}

@property (nonatomic, strong) EKEventStore *store;
@property (nonatomic, strong) NSArray *acknowledge;
@property (nonatomic, strong) NSArray *jokes;
@property (nonatomic, strong) NSArray *greetings;

@end

@implementation ActionHandler

- (id) init {
    notification = [[NSUserNotification alloc] init];
    self.store = [[EKEventStore alloc] init];
    [self.store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        if (error){
            NSLog(@"Error %@:", error);
        }
    }];
    self.acknowledge = [[NSArray alloc] initWithObjects:@"Got it!", @"OK!", @"Understood.", @"No problem.", @"Alright!", nil];
    self.jokes = [[NSArray alloc] initWithObjects:@"Have you ever tried eating a clock? It's very time consuming.", @"Want to hear a joke backwards? Start laughing.", @"When is a door not a door? When it's ajar.", @"Did you hear about the ATM that got addicted to money? It suffered from withdrawals.", @"Why should you not write with a broken pencil? Because it's pointless.", nil];
    self.greetings = [[NSArray alloc] initWithObjects: @"Mister Stark? Is that you?", @"Hello master! How can I help you today?", @"Good day to you.", @"Greetings.", @"Hello there. What can I do for you?", nil];
    return self;
}

// Main entry point to action handler - pass in the response dictionary
- (void) handleAction:(NSDictionary *)witResponse
{
    //Guard against nil API response
    if (witResponse == nil) {
        return;
    }
    
    //Check confidence threshold
    NSDictionary *outcome = [witResponse valueForKey:@"outcome"];
    double intentConfidence = [[outcome valueForKey:@"confidence"] doubleValue];
    
    //Guard against bad input
    if (intentConfidence < 0.5) {
        NSLog(@"Skipped intent: %@ due to low confidence: %@", [outcome valueForKey:@"intent"], [outcome valueForKey:@"confidence"]);
        return;
    }
    
    // Parse dictionary to get intent and entities
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
            id entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != [NSNull null]) {
                id songJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"song"];
                if (songJSON != [NSNull null]) {
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
            id entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != [NSNull null]) {
                id applicationJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"application"];
                if (applicationJSON != [NSNull null]) {
                    int index = [self getRandArrayIndex:self.acknowledge];
                    NSString *applicationName = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"application"]valueForKey:@"value"];
                    NSString *message = [NSString stringWithFormat:@"%@ Launching %@", self.acknowledge[index], applicationName];
                    [self sayString:message];
                    [self launchApplication:applicationName];
                }
            }
        }
            break;
        case SEARCH: { //will not do anything if value is nil
            id entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != [NSNull null]) {
                id searchJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"search_query"];
                if (searchJSON != [NSNull null]) {
                    int index = [self getRandArrayIndex:self.acknowledge];
                    NSString *searchText = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"search_query"]valueForKey:@"value"];
                    NSString *message = [NSString stringWithFormat:@"%@ Searching for %@", self.acknowledge[index], searchText];
                    [self sayString:message];
                    [self  search:searchText];
                }
            }
        }
            break;
        case STOP: {
            [self muteMicPLZ];
            NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
            [sp setVolume:100.0];
            [sp startSpeakingString:@"OK. I'll be waiting"];
        }
            break;
        
        case WEATHER: {
            [self muteMicPLZ];
            [self sayWeather];
        }
            break;
        
        case DAY_SUMMARY: {
            [self muteMicPLZ];
            [self sayDaySummary];
        }
            break;
        case REMIND: {
            id entities = [[witResponse valueForKey:@"outcome"] valueForKey:@"entities"];
            if (entities != [NSNull null]) {
                id taskJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"task"];
                if (taskJSON != [NSNull null]) {
                    id taskText = [[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"task"] valueForKey:@"value"];
                    NSString *timeText = nil;
                    if (taskText != [NSNull null]) {
                        id  timeJSON = [[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"datetime"];
                        double secondOffset = PLACEHOLDER_TIME;
                        if (timeJSON != [NSNull null]) {
                            timeText = [[[[[witResponse valueForKey:@"outcome"] valueForKey:@"entities"] valueForKey:@"datetime"] valueForKey:@"value"] valueForKey:@"from"];
//                            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
//                            [dateFormat setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'AAAZ"];
//                            NSDate *date = [dateFormat dateFromString:timeText];
                            NSDate *dateFromText = [self parseWithDate:timeText];
                            NSDate *dateNow = [NSDate date];
                            double secondOffset1 = [dateFromText timeIntervalSince1970];
                            double secondOffset2 = [dateNow timeIntervalSince1970];
                            secondOffset = secondOffset1 - secondOffset2;
                        }
                        int index = [self getRandArrayIndex:self.acknowledge];
                        NSString *message = [NSString stringWithFormat:@"%@ Reminder set.", self.acknowledge[index]];

                        [self sayString:message];
                        [self createReminder:taskText timeOffset:secondOffset];
                    }
                    //do nothing if there is no reminder(task) text
                }
            }
        }
            break;
    }
}

- (NSDate *)parseWithDate:(NSString *)dateString
{
    NSDateFormatter *rfc3339TimestampFormatterWithTimeZone = [[NSDateFormatter alloc] init];
    [rfc3339TimestampFormatterWithTimeZone setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] init]];
    [rfc3339TimestampFormatterWithTimeZone setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.AAAZ"];
    
    NSDate *theDate = nil;
    NSError *error = nil;
    if (![rfc3339TimestampFormatterWithTimeZone getObjectValue:&theDate forString:dateString range:nil error:&error]) {
        NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
    }
    return theDate;
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
    [self sayFromArray:self.greetings];
}

//a little something for fun!
- (void) tellAJoke
{
    [self sayFromArray:self.jokes];
}

-(void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking{
    if (finishedSpeaking){
        if ([self.delegate respondsToSelector:@selector(muteMic:)]) {
            [self.delegate muteMic:NO];
        }
    }
}

- (void) sayString:(NSString *) speak
{
    [self muteMicPLZ];
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    sp.delegate = self;
    [sp setVolume:100.0];
    [sp startSpeakingString:speak];
}

- (void) sayFromArray:(NSArray *) speechOptions
{
    int index = [self getRandArrayIndex:speechOptions];
    [self sayString:speechOptions[index]];
}

- (int) getRandArrayIndex:(NSArray *) speechOptions
{
    return arc4random_uniform([speechOptions count] - 1);
}

- (void) sayTime
{
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
     sp.delegate = self;
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
     [format setDateFormat:@"hh:mm a"];
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
    //NSDictionary *weatherInfo = [self getWeatherInformation:@"Waterloo"];
    
    NSDictionary *weatherInfo = [self makeGETRequest:@"http://api.openweathermap.org/data/2.5/weather?units=metric&id=6176823"];
    NSLog(@"%@", weatherInfo);
    NSString *weatherString = [self getWeatherString:weatherInfo];
    
    [sp startSpeakingString:weatherString];
}

- (void) sayDaySummary
{
    NSArray *events = [[NSArray alloc] initWithArray:[self getEvents]];
    NSString *weatherString = [self getWeatherString:[self makeGETRequest:@"http://api.openweathermap.org/data/2.5/weather?units=metric&id=6176823"]];
    NSString *eventsString;
    NSString *eventsDescriptor;
    
    unsigned long eventsCount = [events count];
    
    if (eventsCount < 1) {
        // No events
        eventsString = @"You have no more events scheduled for today.";
    }
    else if (eventsCount == 1) {
        eventsString = @"You have one more event scheduled for today.";
    }
    else {
        // More than one event
        eventsString = [NSString stringWithFormat:@"You have %lu more events scheduled for today.", eventsCount];
    }
    
    if (eventsCount >= 1) {
        EKEvent *nextEvent = events[0];
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"hh:mm a"];
        
        NSString *eventTime = [format stringFromDate:[nextEvent startDate]];
        
        eventsString = [NSString stringWithFormat:@"%@ Your next event is: %@, at %@", eventsString, [nextEvent title], eventTime];
    }
    
    if (eventsCount <= 2) {
        eventsDescriptor = @"The rest of your day is looking pretty good!";
    }
    else {
        eventsDescriptor = @"It seems like you have a busy day ahead of you.";
    }
    
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
    sp.delegate = self;
    
    [sp startSpeakingString:[NSString stringWithFormat:@"%@ %@ %@", eventsDescriptor, weatherString, eventsString]];
}

- (NSArray*) getEvents
{
    // Get the appropriate calendar
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar]; //calwithid -> caltimezone
    NSDate *rightNow = [NSDate date];
    
    NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"EST"];
    //[NSTimeZone setDefaultTimeZone:sourceTimeZone];
    [calendar setTimeZone:sourceTimeZone];
    
    NSDate *endOfDay = [calendar dateBySettingHour:23 minute:59 second:59 ofDate:rightNow options:NSCalendarMatchStrictly];
    
    // Create the predicate from the event store's instance method
    NSPredicate *predicate = [self.store predicateForEventsWithStartDate:rightNow
                                                            endDate:endOfDay
                                                          calendars:nil];
    NSLog(@"right now: %@ end: %@",rightNow, endOfDay);
    // Fetch all events that match the predicate
    return [[self.store eventsMatchingPredicate:predicate] sortedArrayUsingSelector:@selector(compareStartDateWithEvent:)];
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
    [self.delegate muteMic:NO];
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

- (void) createReminder: (NSString*) task timeOffset:(double) seconds {
    NSString *func = @"remind";
    NSArray *arg = @[task];
    if (seconds != 0 && seconds != PLACEHOLDER_TIME) {
        func = @"remindWithTime";
        arg = @[task, [NSString stringWithFormat:@"%d",seconds]];
        NSLog(@"seconds: %f", seconds);
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:@"remind" ofType:@"scpt"];
    [self executeScriptWithPath:path function:func andArguments:arg];

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
