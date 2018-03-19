//
//  AppSettings.m
//  VidyoConnector-iOS
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "AppSettings.h"

@implementation AppSettings

@synthesize host, token, displayName, resourceId, enableDebug, cameraPrivacy, microphonePrivacy, experimentalOptions, hideConfig, autoJoin, allowReconnect, returnURL;

// Parameters are assigned either values that are stored in the standard user defaults or simply their default value.
-(void) extractDefaultParameters {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    host                = [standardUserDefaults  stringForKey:@"host"];
    token               = [standardUserDefaults  stringForKey:@"token"];
    displayName         = [standardUserDefaults  stringForKey:@"displayName"];
    resourceId          = [standardUserDefaults  stringForKey:@"resourceId"];
    hideConfig          = [[standardUserDefaults stringForKey:@"hideConfig"]  isEqualToString:@"1"];
    autoJoin            = [[standardUserDefaults stringForKey:@"autoJoin"]    isEqualToString:@"1"];
    enableDebug         = [[standardUserDefaults stringForKey:@"enableDebug"] isEqualToString:@"1"];
    microphonePrivacy   = NO;
    cameraPrivacy       = NO;
    allowReconnect      = YES;
    returnURL           = NULL;
    experimentalOptions = NULL;
}

// Parameters are assigned from URL parameters that are passed into this app.
-(void) extractURLParameters:(NSMutableDictionary *)urlParameters {
    host                = [urlParameters  objectForKey:@"host"];
    token               = [urlParameters  objectForKey:@"token"];
    displayName         = [urlParameters  objectForKey:@"displayName"];
    resourceId          = [urlParameters  objectForKey:@"resourceId"];
    hideConfig          = [[urlParameters objectForKey:@"hideConfig"] isEqualToString:@"1"];
    autoJoin            = [[urlParameters objectForKey:@"autoJoin"] isEqualToString:@"1"];
    allowReconnect      = [[urlParameters objectForKey:@"allowReconnect"] isEqualToString:@"0"] ? NO : YES;
    enableDebug         = [[urlParameters objectForKey:@"enableDebug"] isEqualToString:@"1"];
    cameraPrivacy       = [[urlParameters objectForKey:@"cameraPrivacy"] isEqualToString:@"1"];
    microphonePrivacy   = [[urlParameters objectForKey:@"microphonePrivacy"] isEqualToString:@"1"];
    returnURL           = [urlParameters  objectForKey:@"returnURL"];
    experimentalOptions = [urlParameters  objectForKey:@"experimentalOptions"];
}

// Store a standard user default as a key/value pair.
-(void) setUserDefault:(NSString*)key value:(NSString*)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(BOOL) toggleDebug {
    enableDebug = !enableDebug;
    return enableDebug;
}

-(BOOL) toggleCameraPrivacy {
    cameraPrivacy = !cameraPrivacy;
    return cameraPrivacy;
}

-(BOOL) toggleMicrophonePrivacy {
    microphonePrivacy = !microphonePrivacy;
    return microphonePrivacy;
}

@end
