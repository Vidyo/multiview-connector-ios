//
//  CompositedViewController.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"
#import <Foundation/Foundation.h>
#import "CompositedViewController.h"
#import "AppSettings.h"
#import "Logger.h"

@interface CompositedViewController () {
@private
    enum VidyoConnectorState vidyoConnectorState;
    VCConnector   *vc;
    VCLocalCamera *lastSelectedCamera;
    AppSettings   *appSettings;
    Logger        *logger;
    UIImage       *callStartImage;
    UIImage       *callEndImage;
    BOOL          devicesSelected;
    CGFloat       keyboardOffset;
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
    [logger Log:@"CompositedViewController::viewDidLoad"];
    [super viewDidLoad];
    
    // Initialize the logger and app settings
    logger = [[Logger alloc] init];
    appSettings = [[AppSettings alloc] init];
    
    // Initialize the member variables
    vidyoConnectorState = VidyoConnectorStateDisconnected;
    lastSelectedCamera = nil;
    devicesSelected = YES;

    // Initialize the toggle connect button to the callStartImage
    callStartImage = [UIImage imageNamed:@"callStart.png"];
    callEndImage = [UIImage imageNamed:@"callEnd.png"];
    [toggleConnectButton setImage:callStartImage forState:UIControlStateNormal];

    // add border and border radius to controlsView
    [controlsView.layer setCornerRadius:10.0f];
    [controlsView.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    [controlsView.layer setBorderWidth:0.5f];
}

- (void)viewWillAppear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewWillAppear"];

    [super viewWillAppear:animated];

    // Construct the VidyoConnector
    vc = [[VCConnector alloc] init:(void*)&videoView
                       ViewStyle:VCConnectorViewStyleDefault
              RemoteParticipants:15
                   LogFileFilter:"info@VidyoClient info@VidyoConnector warning"
                     LogFileName:""
                        UserData:0];
    
    if (vc) {
        // Set the client version in the toolbar
        [clientVersion setText:[NSString stringWithFormat:@"v %@", [vc getVersion]]];

        // Register for local camera events
        if (![vc registerLocalCameraEventListener:self]) {
            [logger Log:@"registerLocalCameraEventListener failed"];
        }
        // Register for log events
        if (![vc registerLogEventListener:self Filter:"info@VidyoClient info@VidyoConnector warning"]) {
            [logger Log:@"registerLogEventListener failed"];
        }
        // Apply the app settings
        [self applyAppSettings];
    } else {
        // Log error and ignore interaction events (text input, button press) to prevent further VidyoConnector calls
        [logger Log:@"ERROR: VidyoConnector construction failed ..."];
        [toolbarStatusText setText:@"VidyoConnector Failed"];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewDidAppear"];
    [super viewDidAppear:animated];

    // Refresh the user interface
    if (vc) {
        [self refreshUI];
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

    // Begin listening for URL event notifications, which is triggered by the app delegate.
    // This notification will be triggered in all but the first time that a URL event occurs.
    // It is not necessary to handle the first occurance because applyAppSettings is viewDidLoad.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyAppSettings)
                                                 name:@"handleGetURLEvent"
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [logger Log:@"CompositedViewController::viewWillDisappear"];
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
    if (vc) {
        if (vidyoConnectorState == VidyoConnectorStateConnected ||
            vidyoConnectorState == VidyoConnectorStateConnecting) {
            // Connected or connecting to a resource.
            // Enable camera privacy so remote participants do not see a frozen frame.
            [vc setCameraPrivacy:YES];
        } else {
            // Not connected to a resource.
            // Release camera, mic, and speaker from this app while backgrounded.
            [vc selectLocalCamera:nil];
            [vc selectLocalMicrophone:nil];
            [vc selectLocalSpeaker:nil];
            devicesSelected = NO;
        }
        [vc setMode:VCConnectorModeBackground];
    }
}

- (void)appWillEnterForeground:(NSNotification*)notification {
    if (vc) {
        [vc setMode:VCConnectorModeForeground];

        if (!devicesSelected) {
            // Devices have been released when backgrounding (in appDidEnterBackground). Re-select them.
            devicesSelected = YES;

            // Select the previously selected local camera and default mic/speaker
            [vc selectLocalCamera:lastSelectedCamera];
            [vc selectDefaultMicrophone];
            [vc selectDefaultSpeaker];
        }

        // Reestablish camera and microphone privacy states
        [vc setCameraPrivacy:[appSettings cameraPrivacy]];
        [vc setMicrophonePrivacy:[appSettings microphonePrivacy]];
    }
}

- (void)appWillTerminate:(NSNotification*)notification {
    // Deregister from any/all notifications.
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Release the devices.
    lastSelectedCamera = nil;
    [vc disable];

    // Set the VidyoConnector to nil in order to decrement reference count and cleanup.
    vc = nil;

    // Uninitialize the Vidyo Client library; this should be done once throughout the lifetime of the application.
    [VCConnectorPkg uninitialize];

    // Close the log file
    [logger Close];
}

#pragma mark -
#pragma mark Device Rotation

// The device interface orientation has changed
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

    // Refresh the user interface
    [self refreshUI];
}

#pragma mark -
#pragma mark Virtual Keyboad

// The keyboard pops up for first time or switching from one text box to another.
// Only want to move the view up when keyboard is first shown.
-(void)keyboardWillShow:(NSNotification *)notification {
    // Disable the layout button when the keyboard is displayed
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
    // Enable the layout button when the keyboard is hidden
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
    [self refreshUI];
}

#pragma mark -
#pragma mark Text Fields and Editing

// User finished editing a text field; save in user defaults
- (void)textFieldDidEndEditing:(UITextField *)textField {
    // If no URL parameters (app self started), then save text updates to user defaults
    NSMutableDictionary *urlParameters = [(VidyoConnectorAppDelegate *)[[UIApplication sharedApplication] delegate] urlParameters];
    if (!urlParameters) {
        if (textField == host) {
            [appSettings setUserDefault:@"host" value:textField.text];
        } else if (textField == token) {
            [appSettings setUserDefault:@"token" value:textField.text];
        } else if (textField == displayName) {
            [appSettings setUserDefault:@"displayName" value:textField.text];
        } else if (textField == resourceId) {
            [appSettings setUserDefault:@"resourceId" value:textField.text];
        }
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

// Apply supported settings/preferences.
- (void)applyAppSettings {
    // If connected to a call, then do not apply the new settings.
    if (vidyoConnectorState == VidyoConnectorStateConnected) {
        return;
    }

    // Load the configuration parameters either from the user defaults or the URL parameters
    NSMutableDictionary *urlParameters = [(VidyoConnectorAppDelegate *)[[UIApplication sharedApplication] delegate] urlParameters];
    if (urlParameters) {
        [appSettings extractURLParameters:urlParameters];
    } else {
        [appSettings extractDefaultParameters];
    }

    // Populate the form.
    host.text        = [appSettings host];
    token.text       = [appSettings token];
    displayName.text = [appSettings displayName];
    resourceId.text  = [appSettings resourceId];

    // Hide the controls view if hideConfig is enabled
    controlsView.hidden = [appSettings hideConfig];

    // If enableDebug is configured then enable debugging
    if ([appSettings enableDebug]) {
        [vc enableDebug:7776 LogFilter:"warning info@VidyoClient info@VidyoConnector"];
        [clientVersion setHidden:NO];
    }
    // If cameraPrivacy is configured then mute the camera
    if ([appSettings cameraPrivacy]) {
        [appSettings toggleCameraPrivacy]; // toggle prior to simulating click
        [self cameraPrivacyButtonPressed:nil];
    }
    // If microphonePrivacy is configured then mute the microphone
    if ([appSettings microphonePrivacy]) {
        [appSettings toggleMicrophonePrivacy]; // toggle prior to simulating click
        [self microphonePrivacyButtonPressed:nil];
    }
    // Set experimental options if any exist
    if ([appSettings experimentalOptions]) {
        [vc setAdvancedOptions:[[appSettings experimentalOptions] UTF8String]];
    }
    // If configured to auto-join, then simulate a click of the toggle connect button
    if ([appSettings autoJoin]) {
        [self toggleConnectButtonPressed:nil];
    }
}

// Refresh the UI
- (void)refreshUI {
    [logger Log:[NSString stringWithFormat:@"VidyoConnectorShowViewAt: x = %f, y = %f, w = %f, h = %f", videoView.frame.origin.x, videoView.frame.origin.y, videoView.frame.size.width, videoView.frame.size.height]];

    // Resize the rendered video.
    [vc showViewAt:&videoView X:0 Y:0 Width:videoView.frame.size.width Height:videoView.frame.size.height];
}

// The state of the VidyoConnector connection changed, reconfigure the UI.
// If connected, show the video in the entire window.
// If disconnected, show the video in the preview pane.
- (void)changeState:(enum VidyoConnectorState)state {
    vidyoConnectorState = state;
    
    // Execute this code on the main thread since it is updating the UI layout.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Set the status text in the toolbar.
        [self updateToolbarStatus];

        switch (vidyoConnectorState) {
            case VidyoConnectorStateConnecting:
                // Change image of toggleConnectButton to callEndImage
                [toggleConnectButton setImage:callEndImage forState:UIControlStateNormal];

                // Start the spinner animation
                [connectionSpinner startAnimating];

                // Hide the layout button
                layoutButton.hidden = YES;
                break;

            case VidyoConnectorStateConnected:
                if (![appSettings hideConfig]) {
                    // Update the view to hide the controls.
                    controlsView.hidden = YES;
                }
                // Enable the toggle toolbar control
                toggleToolbarView.hidden = NO;
                // Stop the spinner animation
                [connectionSpinner stopAnimating];
                break;

            case VidyoConnectorStateDisconnecting:
                break;

            case VidyoConnectorStateDisconnected:
            case VidyoConnectorStateDisconnectedUnexpected:
            case VidyoConnectorStateFailure:
            case VidyoConnectorStateFailureInvalidResource:
                // VidyoConnector is disconnected

                // Disable the toggle toolbar control and display toolbar in case it is hidden
                toggleToolbarView.hidden = YES;
                toolbarView.hidden = NO;

                // Change image of toggleConnectButton to callStartImage
                [toggleConnectButton setImage:callStartImage forState:UIControlStateNormal];

                // If a return URL was provided as a URL parameter, then return to that application
                if ([appSettings returnURL]) {
                    // Provide a callstate of either 0 or 1, depending on whether the call was successful
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?callstate=%d", [appSettings returnURL], (int)(vidyoConnectorState == VidyoConnectorStateDisconnected)]]];
                }
                // If the allow-reconnect flag is set to false and a normal (non-failure) disconnect occurred,
                // then disable the toggle connect button, in order to prevent reconnection.
                if (![appSettings allowReconnect] && (vidyoConnectorState == VidyoConnectorStateDisconnected)) {
                    [toggleConnectButton setEnabled:NO];
                    [toolbarStatusText setText:@"Call ended"];
                }
                if (![appSettings hideConfig]) {
                    // Update the view to display the controls.
                    controlsView.hidden = NO;
                }

                // Stop the spinner animation
                [connectionSpinner stopAnimating];

                // Show the layout button
                layoutButton.hidden = NO;

                break;
        }
    });
}

// Update the text displayed in the Toolbar Status UI element
- (void)updateToolbarStatus {
    NSString* statusText = @"";

    switch (vidyoConnectorState) {
        case VidyoConnectorStateConnecting:
            statusText = @"Connecting...";
            break;
        case VidyoConnectorStateConnected:
            statusText = @"Connected";
            break;
        case VidyoConnectorStateDisconnecting:
            statusText = @"Disconnecting...";
            break;
        case VidyoConnectorStateDisconnected:
            statusText = @"Disconnected";
            break;
        case VidyoConnectorStateDisconnectedUnexpected:
            statusText = @"Unexpected disconnection";
            break;
        case VidyoConnectorStateFailure:
            statusText = @"Connection failed";
            break;
        case VidyoConnectorStateFailureInvalidResource:
            statusText = @"Invalid Resource ID";
            break;
        default:
            statusText = @"Unexpected state";
            break;
    }
    [toolbarStatusText setText:statusText];
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
        [self changeState:VidyoConnectorStateDisconnecting];
        [vc disconnect];
    } else {
        // Abort the Connect call if resourceId is invalid. It cannot contain empty spaces or "@".

        // First, trim leading and trailing white space.
        NSString *trimmedResourceId = [[resourceId text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ( [trimmedResourceId containsString:@" "] || [trimmedResourceId containsString:@"@"] ) {
            [self changeState:VidyoConnectorStateFailureInvalidResource];
        } else {
            [self changeState:VidyoConnectorStateConnecting];

            BOOL status = [vc connect:[[[host text] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]] UTF8String]
                                Token:[[[token text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] UTF8String]
                          DisplayName:[[[displayName text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] UTF8String]
                           ResourceId:[trimmedResourceId UTF8String]
                              ConnectorIConnect:self];
            if (!status) {
                [self changeState:VidyoConnectorStateFailure];
            }
            [logger Log:[NSString stringWithFormat:@"VidyoConnectorConnect status = %d", status]];
        }
    }
}

// Toggle the microphone privacy
- (IBAction)microphonePrivacyButtonPressed:(id)sender {
    BOOL microphonePrivacy = [appSettings toggleMicrophonePrivacy];
    if (microphonePrivacy == NO) {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOnWhite.png"] forState:UIControlStateNormal];
    } else {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOff.png"] forState:UIControlStateNormal];
    }
    [vc setMicrophonePrivacy:microphonePrivacy];
}

// Toggle the camera privacy
- (IBAction)cameraPrivacyButtonPressed:(id)sender {
    BOOL cameraPrivacy = [appSettings toggleCameraPrivacy];
    if (cameraPrivacy == NO) {
        [cameraPrivacyButton setImage:[UIImage imageNamed:@"cameraOnWhite.png"] forState:UIControlStateNormal];
    } else {
        [cameraPrivacyButton setImage:[UIImage imageNamed:@"cameraOff.png"] forState:UIControlStateNormal];
    }
    [vc setCameraPrivacy:cameraPrivacy];
}

// Handle the camera swap button being pressed. Cycle the camera.
- (IBAction)cameraSwapButtonPressed:(id)sender {
    [vc cycleCamera];
}

- (IBAction)toggleToolbar:(UITapGestureRecognizer *)sender {
    if (vidyoConnectorState == VidyoConnectorStateConnected) {
        toolbarView.hidden = !toolbarView.hidden;
    }
}

- (IBAction)layoutButtonPressed:(id)sender {
    // Disable the VidyoConnector; all devices are released
    [vc disable];
    vc = nil;

    [self performSegueWithIdentifier:@"segueCompositedToCustom" sender:self];
}

#pragma mark -
#pragma mark VidyoConnector Event Handlers

//  Handle successful connection.
-(void) onSuccess {
    [logger Log:@"onSuccess: Successfully connected."];
    [self changeState:VidyoConnectorStateConnected];
}

// Handle attempted connection failure.
-(void) onFailure:(VCConnectorFailReason)reason {
    [logger Log:@"onFailure: Connection attempt failed."];
    [self changeState:VidyoConnectorStateFailure];
}

//  Handle an existing session being disconnected.
-(void) onDisconnected:(VCConnectorDisconnectReason)reason {
    if (reason == VCConnectorDisconnectReasonDisconnected) {
        [logger Log:@"onDisconnected: Succesfully disconnected."];
        [self changeState:VidyoConnectorStateDisconnected];
    } else {
        [logger Log:@"onDisconnected: Unexpected disconnection."];
        [self changeState:VidyoConnectorStateDisconnectedUnexpected];
    }
}

// Handle a message being logged.
-(void) onLog:(VCLogRecord*)logRecord {
    [logger LogClientLib:logRecord.message];
}

-(void) onLocalCameraAdded:(VCLocalCamera*)localCamera {
    [logger Log:[NSString stringWithFormat:@"onLocalCameraAdded: %@", [localCamera getName]]];
}

-(void) onLocalCameraRemoved:(VCLocalCamera*)localCamera {
    [logger Log:[NSString stringWithFormat:@"onLocalCameraRemoved: %@", [localCamera getName]]];
}

-(void) onLocalCameraSelected:(VCLocalCamera*)localCamera {
    [logger Log:[NSString stringWithFormat:@"onLocalCameraSelected: %@", localCamera ? [localCamera getName] : @"none"]];

    // If a camera is selected, then update lastSelectedCamera.
    // localCamera will be nil only when backgrounding app while disconnected.
    if (localCamera) {
        lastSelectedCamera = localCamera;
    }
}

-(void) onLocalCameraStateUpdated:(VCLocalCamera*)localCamera State:(VCDeviceState)state {
    [logger Log:[NSString stringWithFormat:@"onLocalCameraStateUpdated: name=%@ state=%ld", [localCamera getName], (long)state]];
}

@end
