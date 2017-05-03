//
// VidyoConnectorAppDelegate.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"

@implementation VidyoConnectorAppDelegate

@synthesize inputParameters;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    inputParameters = NULL;

    // Register the application default settings from the Settings.bundle to the NSUserDefaults object.
    // Here, the user defaults are loaded only the first time the app is loaded and run.

    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if (!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
    } else {
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
        NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];

        for (NSDictionary *prefSpecification in preferences) {
            NSString *key = [prefSpecification objectForKey:@"Key"];
            if (key) {
                // Check if this key was already registered
                if (![standardUserDefaults objectForKey:key]) {
                    [standardUserDefaults setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
                
                    NSLog( @"writing as default %@ to the key %@", [prefSpecification objectForKey:@"DefaultValue"], key );
                }
            }
        }
    }
    return YES;
}

// Application launched from a different application with a URL.
// From the source application, this app can be started with the following code:
//     NSString *customURL = @"VidyoConnector://?token=123&resourceId=someResource&host=someHost&hideConfig=1";
//     [[UIApplication sharedApplication] openURL:[NSURL URLWithString:customURL]];
//
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

    NSLog(@"Calling Application Bundle ID: %@", sourceApplication);
    NSLog(@"URL scheme:%@", [url scheme]);
    NSLog(@"URL query: %@", [url query]);
    
    inputParameters = [[NSMutableDictionary alloc] initWithCapacity:10];

    // Parse the query input and register the pairs to the inputParameters dictionary

    NSArray *pairs = [[url query] componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray  *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
        // Add the input param to the dictionary
        [inputParameters setObject:val forKey:key];
        NSLog(@"Updating input parameter dictionary: key = %@, value = %@", key, val);
    }
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
	NSLog(@"applicationWillTerminate called");

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

@end
