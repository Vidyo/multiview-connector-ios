//
//  WelcomeViewController.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"
#import "WelcomeViewController.h"
#import <Lmi/VidyoClient/VidyoConnector_Objc.h>

@interface WelcomeViewController ()

@end

@implementation WelcomeViewController

- (void)viewDidAppear:(BOOL)animated {
    // Display the welcome screen.
    [super viewDidAppear:animated];

    // If launched by a different app, then segue immediately.
	// ...In other words, if not launched by a different app, then delay the segue.
    if (nil == [(VidyoConnectorAppDelegate *)[[UIApplication sharedApplication] delegate] inputParameters]) {
        [NSThread sleepForTimeInterval:1.0];
    }

    // Load the configuration parameters either from the user defaults or the input parameters
    NSMutableDictionary *inputParameters = [(VidyoConnectorAppDelegate *)[[UIApplication sharedApplication] delegate] inputParameters];
    BOOL customLayout = NO;

    if (inputParameters) {
        customLayout = [[inputParameters objectForKey:@"customLayout"] isEqualToString:@"1"];
    } else {
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        customLayout = [[standardUserDefaults stringForKey:@"customLayout"] isEqualToString:@"1"];
    }

    // Initialize VidyoClient Library
    [VCConnectorPkg vcInitialize];

    // Navigate to either the CompositedViewController or CustomViewController
    if (customLayout) {
        [self performSegueWithIdentifier:@"segueWelcomeToCustom" sender:self];
    } else {
        [self performSegueWithIdentifier:@"segueWelcomeToComposited" sender:self];
    }
}

@end
