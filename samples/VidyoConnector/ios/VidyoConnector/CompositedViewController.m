//
//  CompositedViewController.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"
#import <Foundation/Foundation.h>
#import "CompositedViewController.h"
#import "Logger.h"

enum VIDYO_CONNECTOR_STATE {
    VC_CONNECTED,
    VC_DISCONNECTED,
    VC_DISCONNECTED_UNEXPECTED,
    VC_CONNECTION_FAILURE
};

@interface CompositedViewController () {
@private
    Connector *vc;
    Logger    *logger;
    UIImage   *callStartImage;
    UIImage   *callEndImage;
    BOOL      microphonePrivacy;
    BOOL      cameraPrivacy;
    BOOL      hideConfig;
    BOOL      autoJoin;
    BOOL      allowReconnect;
    BOOL      enableDebug;
    NSString  *returnURL;
    NSMutableDictionary *inputParameters;
    enum VIDYO_CONNECTOR_STATE vidyoConnectorState;
    CGFloat   keyboardOffset;
}
@end

@implementation CompositedViewController

@synthesize toggleConnectButton, cameraPrivacyButton, microphonePrivacyButton, layoutButton;
@synthesize videoView, controlsView, toolbarView, toggleToolbarView;
@synthesize token, resourceId, host, displayName;
@synthesize connectionSpinner, toolbarStatusText, bottomControlSeparator, clientVersion;

#pragma mark -
#pragma mark View Lifecycle

// Called when the view is initially loaded
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize the logger
    logger = [[Logger alloc] init];
    [logger Log:@"CompositedViewController::viewDidLoad called."];
    
    // Initialize the member variables
    vidyoConnectorState = VC_DISCONNECTED;
    microphonePrivacy = NO;
    cameraPrivacy = NO;

    // Initialize the toggle connect button to the callStartImage
    callStartImage = [UIImage imageNamed:@"callStart.png"];
    callEndImage = [UIImage imageNamed:@"callEnd.png"];
    [toggleConnectButton setImage:callStartImage forState:UIControlStateNormal];

    // add border and border radius to controlsView
    [controlsView.layer setCornerRadius:10.0f];
    [controlsView.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    [controlsView.layer setBorderWidth:0.5f];

    // Load the configuration parameters either from the user defaults or the input parameters
    inputParameters = [(VidyoConnectorAppDelegate *)[[UIApplication sharedApplication] delegate] inputParameters];
    if (inputParameters) {
        host.text        = [inputParameters  objectForKey:@"host"];
        token.text       = [inputParameters  objectForKey:@"token"];
        displayName.text = [inputParameters  objectForKey:@"displayName"];
        resourceId.text  = [inputParameters  objectForKey:@"resourceId"];
        hideConfig       = [[inputParameters objectForKey:@"hideConfig"]     isEqualToString:@"1"];
        autoJoin         = [[inputParameters objectForKey:@"autoJoin"]       isEqualToString:@"1"];
        allowReconnect   = [[inputParameters objectForKey:@"allowReconnect"] isEqualToString:@"0"] ? NO : YES;
        enableDebug      = [[inputParameters objectForKey:@"enableDebug"]    isEqualToString:@"1"];
        returnURL        = [inputParameters  objectForKey:@"returnURL"];
    } else {
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        host.text        = [standardUserDefaults  stringForKey:@"host"];
        token.text       = [standardUserDefaults  stringForKey:@"token"];
        displayName.text = [standardUserDefaults  stringForKey:@"displayName"];
        resourceId.text  = [standardUserDefaults  stringForKey:@"resourceId"];
        hideConfig       = [[standardUserDefaults stringForKey:@"hideConfig"]  isEqualToString:@"1"];
        autoJoin         = [[standardUserDefaults stringForKey:@"autoJoin"]    isEqualToString:@"1"];
        enableDebug      = [[standardUserDefaults stringForKey:@"enableDebug"] isEqualToString:@"1"];
        allowReconnect   = YES;
        returnURL        = NULL;
    }

    // Hide the controls view if hideConfig is enabled
    controlsView.hidden = hideConfig;

    // Initialize VidyoConnector
    [VidyoClientConnector Initialize];
}

- (void)viewWillAppear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewWillAppear is called."];

    [super viewWillAppear:animated];
    
    // Construct the VidyoConnector
    vc = [[Connector alloc] init:(void*)&videoView
                       ViewStyle:CONNECTORVIEWSTYLE_Default
              RemoteParticipants:16
                   LogFileFilter:"info@VidyoClient info@VidyoConnector warning"
                     LogFileName:""
                        UserData:0];
    
    if (vc) {
        // Set the client version in the toolbar
        [clientVersion setText:[NSString stringWithFormat:@"v %@", [vc GetVersion]]];

        // If enableDebug is configured then enable debugging
        if (enableDebug) {
            [vc EnableDebug:7776 LogFilter:"warning info@VidyoClient info@VidyoConnector"];
        }
        // Register for log callbacks
        if (![vc RegisterLogEventListener:self Filter:"info@VidyoClient info@VidyoConnector warning"]) {
            [logger Log:@"RegisterLogEventListener failed"];
        }
        // If configured to auto-join, then simulate a click of the toggle connect button
        if (autoJoin) {
            [self toggleConnectButtonPressed:nil];
        }
    } else {
        // Log error and ignore interaction events (text input, button press) to prevent further VidyoConnector calls
        [logger Log:@"ERROR: VidyoConnector construction failed ..."];
        [toolbarStatusText setText:@"VidyoConnector Failed"];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewDidAppear called."];
    [super viewDidAppear:animated];

    // Refresh the user interface
    if (vc) {
        [self RefreshUI];
    }

    // Register for OS notifications about this app running in background/foreground, etc.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewWillDisappear called."];
    [super viewWillDisappear:animated];

    // Unregister from notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillTerminateNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

#pragma mark -
#pragma mark Application Lifecycle

- (void)appDidEnterBackground:(NSNotification*)notification {
    [vc SetMode:CONNECTORMODE_Background];
}

- (void)appWillEnterForeground:(NSNotification*)notification {
    [vc SetMode:CONNECTORMODE_Foreground];
}

- (void)appWillTerminate:(NSNotification*)notification {
    // Deregister from any/all notifications.
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Set the VidyoConnector to nil so it is garbage collected
    vc = nil;

    // Uninitialize VidyoConnector
    [VidyoClientConnector Uninitialize];

    // Close the log file
    [logger Close];
}

#pragma mark -
#pragma mark Device Rotation

// The device interface orientation has changed
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

    // Refresh the user interface
    [self RefreshUI];
}

#pragma mark -
#pragma mark Virtual Keyboad

// The keyboard pops up for first time or switching from one text box to another.
// Only want to move the view up when keyboard is first shown.
-(void)keyboardWillShow:(NSNotification *)notification {
    layoutButton.enabled = NO;

    // Animate the current view out of the way
    if (self.view.frame.origin.y >= 0) {
        // Determine the keyboard coordinates and dimensions
        CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
        
        // Move the view only if the keyboard popping up blocks any text field
        if ((controlsView.frame.origin.y + bottomControlSeparator.frame.origin.y) > keyboardRect.origin.y) {
            keyboardOffset = controlsView.frame.origin.y + bottomControlSeparator.frame.origin.y - keyboardRect.origin.y;
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:0.3]; // to slide up the view
            
            // move the view's origin up so that the text field that will be hidden come above the keyboard
            CGRect rect = self.view.frame;
            rect.origin.y -= keyboardOffset;
            self.view.frame = rect;

            [UIView commitAnimations];
        }
    }
}

// The keyboard is about to be hidden so move the view down if it previously has been moved up.
-(void)keyboardWillHide {
    layoutButton.enabled = YES;

    if (self.view.frame.origin.y < 0) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3]; // to slide down the view
        
        // revert back to the normal state
        CGRect rect = self.view.frame;
        rect.origin.y += keyboardOffset;
        self.view.frame = rect;

        [UIView commitAnimations];
    }
    [self RefreshUI];
}

#pragma mark -
#pragma mark Text Fields and Editing

// User finished editing a text field; save in user defaults
- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If no input parameters (app self started), then save text updates to user defaults
    if (!inputParameters) {
        if (textField == host) {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"host"];
        } else if (textField == token) {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"token"];
        } else if (textField == displayName) {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"displayName"];
        } else if (textField == resourceId) {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"resourceId"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [[self view] endEditing:YES];
}

#pragma mark -
#pragma mark App UI Updates

// Refresh the UI
- (void)RefreshUI {
    [logger Log:[NSString stringWithFormat:@"VidyoConnectorShowViewAt: x = %f, y = %f, w = %f, h = %f", videoView.frame.origin.x, videoView.frame.origin.y, videoView.frame.size.width, videoView.frame.size.height]];

    // Resize the VidyoConnector
    [vc ShowViewAt:NULL X:0 Y:0 Width:videoView.frame.size.width Height:videoView.frame.size.height];
}

// The state of the VidyoConnector connection changed, reconfigure the UI.
// If connected, show the video in the entire window.
// If disconnected, show the video in the preview pane.
- (void)ConnectorStateUpdated:(enum VIDYO_CONNECTOR_STATE)state statusText:(NSString *)statusText {
    vidyoConnectorState = state;
    
    // Execute this code on the main thread since it is updating the UI layout
    dispatch_async(dispatch_get_main_queue(), ^{
        // Set the status text in the toolbar
        [toolbarStatusText setText:statusText];

        if (vidyoConnectorState == VC_CONNECTED) {
            // Disable the toggle toolbar control
            toggleToolbarView.hidden = NO;

            if (!hideConfig) {
                // Update the view to hide the controls; this must be done on the main thread
                controlsView.hidden = YES;
            }
        } else {
            // VidyoConnector is disconnected
            
            // Activate the toggle toolbar control
            toggleToolbarView.hidden = YES;
            
            // Change image of toggleConnectButton to callStartImage
            [toggleConnectButton setImage:callStartImage forState:UIControlStateNormal];

            // If a return URL was provided as an input parameter, then return to that application
            if (returnURL) {
                // Provide a callstate of either 0 or 1, depending on whether the call was successful
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?callstate=%d", returnURL, (int)(vidyoConnectorState == VC_DISCONNECTED)]]];
            }
            // If the allow-reconnect flag is set to false and a normal (non-failure) disconnect occurred,
            // then disable the toggle connect button, in order to prevent reconnection.
            if (!allowReconnect && (vidyoConnectorState == VC_DISCONNECTED)) {
                [toggleConnectButton setEnabled:NO];
                [toolbarStatusText setText:@"Call ended"];
            }
            if (!hideConfig) {
                // Update the view to display the controls; this must be done on the main thread
                controlsView.hidden = NO;
            }
        }
        // Stop the spinner animation
        [connectionSpinner stopAnimating];

        // Show the layout button
        layoutButton.hidden = NO;
    });
}

#pragma mark -
#pragma mark Button Event Handlers

// The Connect button was pressed.
// If not in a call, attempt to connect to the backend service.
// If in a call, disconnect.
- (IBAction)toggleConnectButtonPressed:(id)sender {

    // If the toggleConnectButton is the callEndImage, then either user is connected to a resource or is in the process
    // of connecting to a resource; call VidyoConnectorDisconnect to disconnect or abort the connection attempt
    if ([toggleConnectButton imageForState:UIControlStateNormal] == callEndImage) {
        [toolbarStatusText setText:@"Disconnecting..."];

        [vc Disconnect];
    } else {
        // Abort the Connect call if resourceId is invalid. It cannot contain empty spaces or "@".
        if ( [[resourceId text] containsString:@" "] || [[resourceId text] containsString:@"@"] ) {
            [toolbarStatusText setText:@"Invalid Resource ID"];
        } else {
            [toolbarStatusText setText:@"Connecting..."];
            BOOL status = [vc Connect:[host.text UTF8String]
                                Token:[token.text UTF8String]
                          DisplayName:[displayName.text UTF8String]
                           ResourceId:[resourceId.text UTF8String]
                              Connect:self];
            
            if (status == NO) {
                [self ConnectorStateUpdated:VC_CONNECTION_FAILURE statusText:@"Connection failed"];
            } else {
                // Change image of toggleConnectButton to callEndImage
                [toggleConnectButton setImage:callEndImage forState:UIControlStateNormal];

                // Hide the layout button
                layoutButton.hidden = YES;

                // Start the spinner animation
                [connectionSpinner startAnimating];
            }
            [logger Log:[NSString stringWithFormat:@"VidyoConnectorConnect status = %d", status]];
        }
    }
}

// Toggle the microphone privacy
- (IBAction)microphonePrivacyButtonPressed:(id)sender {
    microphonePrivacy = !microphonePrivacy;
    if (microphonePrivacy == NO) {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOnWhite.png"] forState:UIControlStateNormal];
    } else {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOff.png"] forState:UIControlStateNormal];
    }
    [vc SetMicrophonePrivacy:microphonePrivacy];
}

// Toggle the camera privacy
- (IBAction)cameraPrivacyButtonPressed:(id)sender {
    cameraPrivacy = !cameraPrivacy;
    if (cameraPrivacy == NO) {
        [cameraPrivacyButton setImage:[UIImage imageNamed:@"cameraOnWhite.png"] forState:UIControlStateNormal];
    } else {
        [cameraPrivacyButton setImage:[UIImage imageNamed:@"cameraOff.png"] forState:UIControlStateNormal];
    }
    [vc SetCameraPrivacy:cameraPrivacy];
}

// Handle the camera swap button being pressed. Cycle the camera.
- (IBAction)cameraSwapButtonPressed:(id)sender {
    [vc CycleCamera];
}

- (IBAction)toggleToolbar:(UITapGestureRecognizer *)sender {
    if (vidyoConnectorState == VC_CONNECTED) {
        toolbarView.hidden = !toolbarView.hidden;
    }
}

- (IBAction)layoutButtonPressed:(id)sender {
    // Disable the VidyoConnector; all devices are released
    [vc Disable];
    vc = nil;

    [self performSegueWithIdentifier:@"segueCompositedToCustom" sender:self];
}

#pragma mark -
#pragma mark VidyoConnector Event Handlers

//  Handle successful connection.
-(void) OnSuccess {
    [logger Log:@"Successfully connected."];
    [self ConnectorStateUpdated:VC_CONNECTED statusText:@"Connected"];
}

// Handle attempted connection failure.
-(void) OnFailure:(ConnectorFailReason)reason {
    [logger Log:@"Connection attempt failed."];

    // Update UI to reflect connection failed
    [self ConnectorStateUpdated:VC_CONNECTION_FAILURE statusText:@"Connection failed"];
}

//  Handle an existing session being disconnected.
-(void) OnDisconnected:(ConnectorDisconnectReason)reason {
    if (reason == CONNECTORDISCONNECTREASON_Disconnected) {
        [logger Log:@"Succesfully disconnected."];
        [self ConnectorStateUpdated:VC_DISCONNECTED statusText:@"Disconnected"];
    } else {
        [logger Log:@"Unexpected disconnection."];
        [self ConnectorStateUpdated:VC_DISCONNECTED_UNEXPECTED statusText:@"Unexepected disconnection"];
    }
}

// Handle a message being logged.
-(void) OnLog:(LogRecord*)logRecord {
    [logger LogClientLib:logRecord->message];
}

@end
