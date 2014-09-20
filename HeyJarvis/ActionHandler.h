//
//  ActionHandler.h
//  HeyJarvis
//
//  Created by Geoffrey Yu on 2014-09-20.
//  Copyright (c) 2014 Hicham Abou Jaoude. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#ifndef HeyJarvis_ActionHandler_h
#define HeyJarvis_ActionHandler_h


@protocol MicDelegate <NSObject>
- (void)muteMic:(BOOL)mute;
@end

@interface ActionHandler : NSObject {
}

@property (nonatomic, weak) id <MicDelegate> delegate;

- (id) init;
- (void) handleAction: (NSDictionary*)witResponse;

@end

#endif
