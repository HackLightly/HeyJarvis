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


#define kAudioFilePath [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.wav"]
#define kAudioFilePathConvert [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.mp3"]

@interface AppDelegate () <EZMicrophoneDelegate, NSUserNotificationCenterDelegate, NSApplicationDelegate>{
    BOOL _hasSomethingToPlay;
    int secondTimeCount;
    float lastdbValue;
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
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    [self.microphone startFetchingAudio];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkForSound:) userInfo:nil repeats:YES];
    notification = [[NSUserNotification alloc] init];
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

-(void)checkForSound:(NSTimer *) timer{
    NSLog(@"dbval:  %f ",lastdbValue);
    if (lastdbValue >= 3.f && !self.isRecording){
        notification.title = @"Jarvis";
        notification.informativeText = @"Listening...";
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        [self toggleRecording:YES];
        secondTimeCount = 0;
        self.isRecording = YES;
    } else if (secondTimeCount > 4 && self.isRecording) {
        self.isRecording = NO;
        secondTimeCount = 0;
        [self toggleRecording:NO];
    } else if (lastdbValue <= 1.5f){
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
        
        // send HTTP request
        NSURLResponse* response = nil;
        NSError *error = nil;
        NSData *data2 = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
        
        NSError *serializationError;
        NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data2
                                                               options:0
                                                                 error:&serializationError];
        NSLog(@"Object %@", object);
        self.action = [[ActionHandler alloc] init];
        [self.action handleAction:object];
        NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
        [sp setVolume:100.0];
        [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
        notification.title = @"Jarvis";
        notification.informativeText = object[@"msg_body"];
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        //[sp startSpeakingString:object[@"msg_body"]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             [NSUserNotificationCenter.defaultUserNotificationCenter removeAllDeliveredNotifications];
        });

    }];
}

- (void)readCompleted:(NSNotification *)notification {
    
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
    
    // send HTTP request
    NSURLResponse* response = nil;
    NSError *error = nil;
    NSData *data2 = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    
    NSError *serializationError;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data2
                                                           options:0
                                                             error:&serializationError];
    NSLog(@"Object %@", object);
    
    NSSpeechSynthesizer *sp = [[NSSpeechSynthesizer alloc] init];
    [sp setVolume:100.0];
    //[sp startSpeakingString:object[@"msg_body"]];
    
}

-(void)toggleRecording:(BOOL)sender
{
    switch( sender )
    {
        case NO:{
            [self.recorder closeAudioFile];
            [self performSelectorInBackground:@selector(convertFile) withObject:nil];
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

-(IBAction)helloWorld:(id)sender {
    NSLog(@"HEY");
}


- (void) awakeFromNib{
    
    //Create the NSStatusBar and set its length
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //Used to detect where our files are
    NSBundle *bundle = [NSBundle mainBundle];
    
    //Allocates and loads the images into the application which will be used for our NSStatusItem
    statusImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"logo" ofType:@"png"]];
    statusHighlightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"logo" ofType:@"png"]];
    
    //Sets the images in our NSStatusItem
    [statusItem setImage:statusImage];
    [statusItem setAlternateImage:statusHighlightImage];
    
    //Tells the NSStatusItem what menu to load
    [statusItem setMenu:statusMenu];
    //Sets the tooptip for our item
    [statusItem setToolTip:@"My Custom Menu Item"];
    //Enables highlighting
    [statusItem setHighlightMode:YES];
}

@end
