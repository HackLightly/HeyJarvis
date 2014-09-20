//
//  AppDelegate.m
//  HeyJarvis
//
//  Created by Hicham Abou Jaoude on 2014-09-19.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import "AppDelegate.h"
#import <EZAudio/EZAudio.h>
#import <AFNetworking/AFNetworking.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/NSSpeechSynthesizer.h>
#import <Accelerate/Accelerate.h>


#define kAudioFilePath [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.wav"]
#define kAudioFilePathConvert [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),@"/test.mp3"]

@interface AppDelegate () <EZMicrophoneDelegate>{
    BOOL _hasSomethingToPlay;
    int secondTimeCount;
    float lastdbValue;
}

@property (nonatomic,assign) BOOL isRecording;
@property (nonatomic, strong) AFHTTPSessionManager *afHTTPSessionManager;
@property (nonatomic, strong) AFHTTPRequestOperationManager *AFOpManager;
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;
@property (nonatomic,strong) EZMicrophone *microphone;
@property (nonatomic,strong) EZRecorder *recorder;
@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    [self.microphone startFetchingAudio];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkForSound:) userInfo:nil repeats:YES];
}

-(void)checkForSound:(NSTimer *) timer{
    NSLog(@"dbval:  %f",lastdbValue);
    if (lastdbValue >= 2.f && !self.isRecording){
        [self toggleRecording:YES];
        secondTimeCount = 0;
        self.isRecording = YES;
    } else if (secondTimeCount > 4 && self.isRecording) {
        self.isRecording = NO;
        secondTimeCount = 0;
        [self toggleRecording:NO];
    } else if (lastdbValue <= 1.f){
        secondTimeCount++;
    }
}

-(void)playFile {
    
    // Update recording state
    self.isRecording = NO;
    if (self.recorder){
        [self.recorder closeAudioFile];
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    task.arguments = @[@"-c", @"/usr/local/bin/lame -h -b 192 ~/test.wav ~/test.mp3"];
    NSPipe *outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleted:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[outputPipe fileHandleForReading]];
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    
    [task launch];
    
}

- (void)readCompleted:(NSNotification *)notification {
    NSLog(@"ENCODING");
    
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[notification object]];
}

-(void)toggleRecording:(BOOL)sender
{
    switch( sender )
    {
        case NO:{
            [self.recorder closeAudioFile];
            [self playFile];
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

@end
