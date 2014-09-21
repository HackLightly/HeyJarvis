//
//  AppDelegate.h
//  HeyJarvis
//
//  Created by Hicham Abou Jaoude on 2014-09-19.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import <Cocoa/Cocoa.h>



@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    IBOutlet NSMenuItem *disable;
    NSImage *statusImage;
    NSImage *statusHighlightImage;
}


@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *aboutWindow;

-(IBAction)about:(id)sender;
-(IBAction)setDisable:(id)sender;
-(IBAction)setEnable:(id)sender;
-(void)muteMic:(BOOL)mute;
@end

