#ifndef VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
#define VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
//
// VidyoConnectorAppDelegate.h
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import <UIKit/UIKit.h>

enum VidyoConnectorState {
    VidyoConnectorStateConnected,
    VidyoConnectorStateDisconnected,
    VidyoConnectorStateDisconnectedUnexpected,
    VidyoConnectorStateFailure
};

@interface VidyoConnectorAppDelegate : UIResponder <UIApplicationDelegate> {
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) NSMutableDictionary *inputParameters;

@end

#endif // VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
