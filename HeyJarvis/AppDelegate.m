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


#define kAudioFilePath [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/jarvis_speech.wav"]
#define kAudioFilePathConvert [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.mp3"]

@interface AppDelegate () <EZMicrophoneDelegate, NSUserNotificationCenterDelegate, NSApplicationDelegate, MicDelegate>{
    BOOL _hasSomethingToPlay;
    BOOL listening;
    float beginThreshold;
    float endThreshold;
    int secondTimeCount;
    int counter;
    float lastdbValue;
    
    int currentFrame;
    NSTimer* animTimer;
    
    BOOL animBool;
    
    NSMutableArray *dbValueQueue;
    NSUserNotification *notification;
}

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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    dbValueQueue = [[NSMutableArray alloc] init];
    [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    [self.microphone startFetchingAudio];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkForSound:) userInfo:nil repeats:YES];
    notification = [[NSUserNotification alloc] init];
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    listening = YES;
   // [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(countUpToTen) userInfo:nil repeats:YES];
    /* might want to calibrate on startup instead of this */
    beginThreshold = 3.0f;
    endThreshold = 1.5f;
}

-(void)countUpToTen{
    if (counter >= 10 && self.isRecording){
        counter = 0;
        [self toggleRecording:NO];
    } else if (self.isRecording){
        counter++;
    } else {
        return;
    }
}


- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

-(void)checkForSound:(NSTimer *) timer{
    if (!listening){
        lastdbValue = 0.f;
    } else {
        [dbValueQueue pushFloat:lastdbValue withMax:10];
    }
    NSLog(@"dbval:  %f ",lastdbValue);
    if (lastdbValue >= beginThreshold && !self.isRecording){
        [self changeStatus:1];
        notification.title = @"Jarvis";
        notification.informativeText = @"Listening...";
        //[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        [self toggleRecording:YES];
        secondTimeCount = 0;
        self.isRecording = YES;
    } else if (secondTimeCount > 4 && self.isRecording) {
        [self changeStatus:2];
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
   
//    NSTask *task = [[NSTask alloc] init];
//    [task setLaunchPath:@"/bin/bash"];
//    task.arguments = @[@"-c", @"/usr/local/bin/lame -h -b 192 ~/test.wav ~/test.mp3"];
//    NSPipe *outputPipe = [NSPipe pipe];
//    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
//    [task setStandardOutput:outputPipe];
//    [task launch];
//    [task setTerminationHandler:^(NSTask *task) {
        NSLog(@"ENCODING/UPLOADING");
        
        NSData * data = [[NSData alloc ]initWithContentsOfFile:kAudioFilePath];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.wit.ai/speech?v=20140508"]];
        [req setHTTPMethod:@"POST"];
        [req setCachePolicy:NSURLCacheStorageNotAllowed];
        [req setTimeoutInterval:15.0];
        [req setHTTPBody:data];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", @"EUOKNV6J5WMTO5TVFH5YB7UJZRAFQ3KD"] forHTTPHeaderField:@"Authorization"];
        [req setValue:@"audio/wav" forHTTPHeaderField:@"Content-type"];
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
                                   if ([object[@"msg_body"] length] == 0) {
                                       [self changeStatus:0];
                                   }
                                   //[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                                   //[sp startSpeakingString:object[@"msg_body"]];
                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                       [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
                                   });
                               }];
    //}];
}

-(ActionHandler *)action {
    if (!_action) {
        _action = [[ActionHandler alloc] init];
    }
    return _action;
}

-(void)muteMic:(BOOL)mute{
    if (mute){
        [disable setTitle:@"Test"];
        [self.microphone stopFetchingAudio];
        listening = NO;
        NSLog(@"Mic Mutted");
        [self changeStatus:3];
    } else {
        [disable setState:0];
        [self.microphone startFetchingAudio];
        listening = YES;
        NSLog(@"Mic Listening");
        [self changeStatus:0];
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


#pragma mark - EZMicrophoneDelegate
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        // Decibel Calculation.
        lastdbValue = [EZAudio RMS:buffer[0] length:bufferSize]*100;
        
    });
}

// Append the microphone data coming as a AudioBufferList with the specified buffer size to the recorder
-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as a buffer list that can be directly fed into the EZRecorder. This is happening on the audio thread - any UI updating needs a GCD main queue block.
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
        [self changeStatus:-1];
        listening = NO;
    } else {
        NSLog(@"setEnable");
        [sender setState:0];
        [self muteMic:NO];
        [self changeStatus:0];
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
    //statusHighlightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"logo2" ofType:@"png"]];
    
    //Sets the images in our NSStatusItem
    [statusItem setImage:statusImage];
    //[statusItem setAlternateImage:statusHighlightImage];
    
    
    //Tells the NSStatusItem what menu to load
    [statusItem setMenu:statusMenu];
    //Sets the tooptip for our item
    [statusItem setToolTip:@"Jarvis"];
    //Enables highlighting
    [statusItem setHighlightMode:YES];
}

- (void)changeStatus: (int) status {
    currentFrame = 0;

    switch (status) {
        case -1: // Not listening
        {
            if (animTimer) {
                [animTimer invalidate];
                animTimer = nil;
            }
            NSImage* image = [NSImage imageNamed:@"disabledlogo.png"];
            [statusItem setImage:image];
        }
            break;
        case 0: // Normal, nothing
        {
            if (animTimer) {
                [animTimer invalidate];
                animTimer = nil;
            }
            NSImage* image = [NSImage imageNamed:@"logo.png"];
            [statusItem setImage:image];
        }
            break;
        case 1: // Listening
        {
            if (animTimer) {
                [animTimer invalidate];
                animTimer = nil;
            }
            NSImage* image = [NSImage imageNamed:@"listenlogo.png"];
            [statusItem setImage:image];
        }
            break;
        case 2: // Processing
        {
            if (!animTimer) {
                animBool = YES;
                animTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/2.0 target:self selector:@selector(updateProcessingImage:) userInfo:nil repeats:YES];
            }
        }
            break;
        case 3: // Speaking
        {
            animBool = NO;
        }
            break;
        default:
            break;
    }
}

- (void)updateProcessingImage:(NSTimer*)timer
{
    //get the image for the current frame
    if (animBool) {
        NSImage* image = [NSImage imageNamed:[NSString stringWithFormat:@"processing%d.png",currentFrame]];
        [statusItem setImage:image];
        currentFrame = (currentFrame + 1) % 3;
    } else {
        NSImage* image = [NSImage imageNamed:[NSString stringWithFormat:@"speaking%d.png",currentFrame]];
        [statusItem setImage:image];
        currentFrame = (currentFrame + 1) % 2;
    }
}
@end
