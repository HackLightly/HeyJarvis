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

@interface ActionHandler : NSObject {
}
- (id) init;
- (void) handleAction: (NSDictionary*)witResponse;

@end

#endif
