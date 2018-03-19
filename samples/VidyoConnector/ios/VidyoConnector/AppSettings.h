//
//  AppSettings.h
//  VidyoConnector-iOS
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#ifndef AppSettings_h
#define AppSettings_h

@interface AppSettings : NSObject

@property(nonatomic, readwrite) NSString *host;
@property(nonatomic, readwrite) NSString *token;
@property(nonatomic, readwrite) NSString *displayName;
@property(nonatomic, readwrite) NSString *resourceId;
@property(nonatomic, readwrite) NSString *experimentalOptions;
@property(nonatomic, readwrite) NSString *returnURL;

@property(nonatomic, readwrite) BOOL enableDebug;
@property(nonatomic, readwrite) BOOL cameraPrivacy;
@property(nonatomic, readwrite) BOOL microphonePrivacy;
@property(nonatomic, readwrite) BOOL hideConfig;
@property(nonatomic, readwrite) BOOL autoJoin;
@property(nonatomic, readwrite) BOOL allowReconnect;

-(void) extractURLParameters:(NSMutableDictionary *)urlParameters;
-(void) extractDefaultParameters;
-(void) setUserDefault:(NSString*)key value:(NSString*)value;
-(BOOL) toggleDebug;
-(BOOL) toggleCameraPrivacy;
-(BOOL) toggleMicrophonePrivacy;

@end

#endif /* AppSettings_h */


