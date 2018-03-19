#ifndef VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
#define VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
//
// VidyoConnectorAppDelegate.h
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import <UIKit/UIKit.h>

enum VidyoConnectorState {
    VidyoConnectorStateConnecting,
    VidyoConnectorStateConnected,
    VidyoConnectorStateDisconnecting,
    VidyoConnectorStateDisconnected,
    VidyoConnectorStateDisconnectedUnexpected,
    VidyoConnectorStateFailure,
    VidyoConnectorStateFailureInvalidResource
};

@interface VidyoConnectorAppDelegate : UIResponder <UIApplicationDelegate> {
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) NSMutableDictionary *urlParameters;

@end

#endif // VIDYOCONNECTORAPPDELEGATE_H_INCLUDED
