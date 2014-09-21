//
//  AppDelegate.m
//  HeyJarvis
//
//  Created by Hicham Abou Jaoude on 2014-09-19.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import "AppDelegate.h"
#import "ActionHandler.h"
#import <EZAudio/EZAudio.h>
#import <AFNetworking/AFNetworking.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/NSSpeechSynthesizer.h>
#import <Accelerate/Accelerate.h>
#import "NSMutableArray+Queue.h"


#define kAudioFilePath [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.wav"]
#define kAudioFilePathConvert [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.mp3"]

@interface AppDelegate () <EZMicrophoneDelegate, NSUserNotificationCenterDelegate, NSApplicationDelegate, MicDelegate, NSStreamDelegate>{
    BOOL _hasSomethingToPlay;
    BOOL listening;
    float beginThreshold;
    float endThreshold;
    int secondTimeCount;
    float lastdbValue;
    NSMutableArray *dbValueQueue;
    NSUserNotification *notification;
    NSOutputStream *outStream;
    NSInputStream *inStream;
    BOOL cleanUP;
    NSDate *start; // used to time requests
}

@property (atomic) NSOperationQueue* q;
@property (atomic) BOOL requestEnding;

@property (nonatomic,assign) BOOL isRecording;
@property (nonatomic, strong) AFHTTPSessionManager *afHTTPSessionManager;
@property (nonatomic, strong) AFHTTPRequestOperationManager *AFOpManager;
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;
@property (nonatomic,strong) EZMicrophone *microphone;
@property (nonatomic,strong) EZRecorder *recorder;
@property (nonatomic,strong) ActionHandler *action;
//@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

@synthesize requestEnding, q;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    q = [[NSOperationQueue alloc] init];
    [q setMaxConcurrentOperationCount:1];
    
    CFWriteStreamRef writeStream;
    CFReadStreamRef readStream;
    readStream = NULL;
    writeStream = NULL;
    CFStreamCreateBoundPair(NULL, &readStream, &writeStream, 65536);
    
    // convert to NSStream and set as property
    inStream = CFBridgingRelease(readStream);
    outStream = CFBridgingRelease(writeStream);
    
    [outStream setDelegate:self];
    [outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outStream open];
    
    dbValueQueue = [[NSMutableArray alloc] init];
    [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    [self.microphone startFetchingAudio];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkForSound:) userInfo:nil repeats:YES];
    notification = [[NSUserNotification alloc] init];
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    listening = YES;
    
    /* might want to calibrate on startup instead of this */
    beginThreshold = 3.0f;
    endThreshold = 1.5f;
    
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.wit.ai/speech?v=20140508"]];
    [req setHTTPMethod:@"POST"];
    [req setCachePolicy:NSURLCacheStorageNotAllowed];
    [req setTimeoutInterval:15.0];
    [req setHTTPBodyStream:inStream];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", @"EUOKNV6J5WMTO5TVFH5YB7UJZRAFQ3KD"] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"audio/" forHTTPHeaderField:@"Content-type"];
    [req setValue:@"chunked" forHTTPHeaderField:@"Transfer-encoding"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               
                               NSError *serializationError;
                               NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data
                                                                                      options:0
                                                                                        error:&serializationError];
                               NSLog(@"Object %@", object);
                               self.action.delegate = self;
                               [self.action handleAction:object];
                               NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
                               [sp setVolume:100.0];
                               [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
                               notification.title = @"Jarvis";
                               notification.informativeText = object[@"msg_body"];
                               //[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                               //[sp startSpeakingString:object[@"msg_body"]];
                               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                   [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
                               });
                           }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self endRequest];
    });
    
//    NSTask *task = [[NSTask alloc] init];
//    [task setLaunchPath:@"/bin/bash"];
//    task.arguments = @[@"-c", @"/usr/local/bin/lame -h -b 192 ~/test.wav ~/test.mp3"];
//    NSPipe *outputPipe = [NSPipe pipe];
//    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
//    [task setStandardOutput:outputPipe];
//    [task launch];
//    [task setTerminationHandler:^(NSTask *task) {
//        NSLog(@"ENCODING/UPLOADING");
//        
//        //NSData * data = [[NSData alloc ]initWithContentsOfFile:kAudioFilePathConvert];
//        
//    }];

    
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

-(void)checkForSound:(NSTimer *) timer{
    return;
    if (!listening){
        lastdbValue = 0.f;
    } else {
        [dbValueQueue pushFloat:lastdbValue withMax:10];
    }
    NSLog(@"dbval:  %f ",lastdbValue);
    if (lastdbValue >= beginThreshold && !self.isRecording){
        notification.title = @"Jarvis";
        notification.informativeText = @"Listening...";
        //[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        [self toggleRecording:YES];
        secondTimeCount = 0;
        self.isRecording = YES;
    } else if (secondTimeCount > 4 && self.isRecording) {
        self.isRecording = NO;
        secondTimeCount = 0;
        [self toggleRecording:NO];
    } else if (lastdbValue <= endThreshold){
        secondTimeCount++;
    }
}

-(void)convertFile{
    // Update recording state
    self.isRecording = NO;
    if (self.recorder){
        [self.recorder closeAudioFile];
    }
   
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    task.arguments = @[@"-c", @"/usr/local/bin/lame -h -b 192 ~/test.wav ~/test.mp3"];
    NSPipe *outputPipe = [NSPipe pipe];
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [task setStandardOutput:outputPipe];
    [task launch];
    [task setTerminationHandler:^(NSTask *task) {
        NSLog(@"ENCODING/UPLOADING");
        
        NSData * data = [[NSData alloc ]initWithContentsOfFile:kAudioFilePathConvert];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.wit.ai/speech?v=20140508"]];
        [req setHTTPMethod:@"POST"];
        [req setCachePolicy:NSURLCacheStorageNotAllowed];
        [req setTimeoutInterval:15.0];
        [req setHTTPBody:data];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", @"EUOKNV6J5WMTO5TVFH5YB7UJZRAFQ3KD"] forHTTPHeaderField:@"Authorization"];
        [req setValue:@"audio/mpeg3" forHTTPHeaderField:@"Content-type"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        [NSURLConnection sendAsynchronousRequest:req
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   
                                   NSError *serializationError;
                                   NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data
                                                                                          options:0
                                                                                            error:&serializationError];
                                   NSLog(@"Object %@", object);
                                   self.action.delegate = self;
                                   [self.action handleAction:object];
                                   NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
                                   [sp setVolume:100.0];
                                   [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
                                   notification.title = @"Jarvis";
                                   notification.informativeText = object[@"msg_body"];
                                   //[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                                   //[sp startSpeakingString:object[@"msg_body"]];
                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                       [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
                                   });
                               }];
    }];
}

-(ActionHandler *)action {
    if (!_action) {
        _action = [[ActionHandler alloc] init];
    }
    return _action;
}

-(void)muteMic:(BOOL)mute{
    if (mute){
        [self.microphone stopFetchingAudio];
        listening = NO;
        NSLog(@"Mic Mutted");
    } else {
        [self.microphone startFetchingAudio];
        listening = YES;
        NSLog(@"Mic Listening");
    }
}

-(void)toggleRecording:(BOOL)sender
{
    switch( sender )
    {
        case NO:{
            [self.recorder closeAudioFile];
            [self convertFile];
        }
            break;
        case YES:
            self.recorder = [EZRecorder recorderWithDestinationURL:[NSURL fileURLWithPath:kAudioFilePath]
                                                      sourceFormat:self.microphone.audioStreamBasicDescription
                                               destinationFileType:EZRecorderFileTypeWAV];
            break;
        default:
            break;
    }
    self.isRecording = sender;
}

-(NSData *)processBuffer: (AudioBufferList*) audioBufferList

{
    
    AudioBuffer sourceBuffer = audioBufferList->mBuffers[0];
    
    // we check here if the input data byte size has changed
    int currentBuffer =0;
    int maxBuf = 800;
    
    NSMutableData *data=[[NSMutableData alloc] init];
    // CMBlockBufferRef blockBuffer;
    // CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
    // NSLog(@"%@",blockBuffer);
    
    
    // audioBufferList->mBuffers[0].mData, audioBufferList->mBuffers[0].mDataByteSize
    for( int y=0; y<audioBufferList->mNumberBuffers; y++ )
    {
        if (currentBuffer < maxBuf){
            AudioBuffer audioBuff = audioBufferList->mBuffers[y];
            Float32 *frame = (Float32*)audioBuff.mData;
            
            
            [data appendBytes:frame length:audioBuff.mDataByteSize];
            currentBuffer += audioBuff.mDataByteSize;
        }
        else{
            break;
        }
        
    }
    
    return data;
    
    // copy incoming audio data to the audio buffer (no need since we are not using playback)
    //memcpy(inAudioBuffer.mData, audioBufferList->mBuffers[0].mData, audioBufferList->mBuffers[0].mDataByteSize);
}

#pragma mark - EZMicrophoneDelegate
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blo?cking that audio flow.
    NSData *data = [NSData dataWithBytes:buffer[0] length:bufferSize];
    

        // Decibel Calculation.
        lastdbValue = [EZAudio RMS:buffer[0] length:bufferSize]*100;
        

}

- (void) cleanUp {
    cleanUP = YES;
    NSLog(@"Cleaning up");
    if (outStream) {
        NSLog(@"Cleaning up output stream");
        [outStream close];
        [outStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        outStream = nil;
        inStream = nil;
        
        start = [NSDate date];
    }
    
    [q cancelAllOperations];
    [q setSuspended:NO];
    
}

-(void)endRequest {
    NSLog(@"Ending request");
    requestEnding = YES;
    if (q.operationCount <= 0) {
        [self cleanUp];
    }
}

// DELEGATE STREAM

-(void)stream:(NSStream *)s handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream open completed");
            break;
        case NSStreamEventHasBytesAvailable:
            NSLog(@"Stream has bytes available");
            break;
        case NSStreamEventHasSpaceAvailable:
            if (s == outStream) {
                            NSLog(@"outStream has space, resuming dispatch");
                if ([q isSuspended]) {
                    [q setSuspended:NO];
                }
            }
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"Stream error occurred");
            [self cleanUp];
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"Stream end encountered");
            [self cleanUp];
            break;
        case NSStreamEventNone:
            NSLog(@"Stream event none");
            break;
    }
}


// Append the microphone data coming as a AudioBufferList with the specified buffer size to the recorder
-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as a buffer list that can be directly fed into the EZRecorder. This is happening on the audio thread - any UI updating needs a GCD main queue block.
    
    //NSInputStream *instream = [[NSInputStream alloc] initWithFileAtPath:<#(NSString *)#>]
    NSData *data = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
    if (cleanUP){
        return;
    }
    [q addOperationWithBlock:^{
        if (outStream) {
            [q setSuspended:YES];
            
            NSLog(@"Uploading %u bytes", (unsigned int)[data length]);
            [outStream write:[data bytes] maxLength:[data length]];
        }
        
        NSUInteger cnt = q.operationCount;
        NSLog(@"Operation count: %d", cnt);
        if (requestEnding && cnt <= 1) {
            [self cleanUp];
        }
    }];
    if( self.isRecording ){
        [self.recorder appendDataFromBufferList:bufferList
                                 withBufferSize:bufferSize];
        

    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - menubar

-(IBAction)about:(id)sender {
    NSLog(@"about");
    [self.aboutWindow makeKeyAndOrderFront:NSApp];
}

- (IBAction)setDisable:(id)sender {
    
    if (listening){
        NSLog(@"setDisable");
        [sender setState:1];
        [self muteMic:YES];
        listening = NO;
    } else {
        NSLog(@"setEnable");
        [sender setState:0];
        [self muteMic:NO];
        listening = YES;
    }

}


- (IBAction)calibrate:(id) sender {
    NSLog(@"calibrate");
    NSDictionary* values = [dbValueQueue evaluate];
    NSLog(@"AVERAGE: %f", [[values objectForKey:@"average"] floatValue]);
    NSLog(@"PEAK: %f", [[values objectForKey:@"peak"] floatValue]);
    NSLog(@"LOW: %f", [[values objectForKey:@"low"] floatValue]);

    beginThreshold = [[values objectForKey:@"peak"] floatValue];
    endThreshold = [[values objectForKey:@"average"] floatValue];
}

- (void) awakeFromNib{
    
    //Create the NSStatusBar and set its length
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //Used to detect where our files are
    NSBundle *bundle = [NSBundle mainBundle];
    
    //Allocates and loads the images into the application which will be used for our NSStatusItem
    statusImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"logo" ofType:@"png"]];
    statusHighlightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"logo2" ofType:@"png"]];
    
    //Sets the images in our NSStatusItem
    [statusItem setImage:statusImage];
    [statusItem setAlternateImage:statusHighlightImage];
    
    //Tells the NSStatusItem what menu to load
    [statusItem setMenu:statusMenu];
    //Sets the tooptip for our item
    [statusItem setToolTip:@"Jarvis"];
    //Enables highlighting
    [statusItem setHighlightMode:YES];
}

@end
