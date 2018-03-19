//
//  CustomViewController.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"
#import <Foundation/Foundation.h>
#import "CustomViewController.h"
#import "AppSettings.h"
#import "Logger.h"

#define NUM_REMOTE_SLOTS 3

@interface CustomViewController () {
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
    NSMutableString* remoteSlots[NUM_REMOTE_SLOTS];
    NSMutableDictionary *remoteCamerasRenderedStatus;
    NSMutableDictionary *remoteCameras;
    UIView* remoteView[NUM_REMOTE_SLOTS];
}
@end

@implementation CustomViewController

@synthesize toggleConnectButton, cameraPrivacyButton, microphonePrivacyButton, layoutButton;
@synthesize localView, remoteView0, remoteView1, remoteView2, controlsView, toolbarView, toggleToolbarView;
@synthesize token, resourceId, host, displayName;
@synthesize connectionSpinner, toolbarStatusText, bottomControlSeparator, clientVersion;

#pragma mark -
#pragma mark View Lifecycle

// Called when the view is initially loaded
- (void)viewDidLoad {
    [logger Log:@"CustomViewController::viewDidLoad"];
    [super viewDidLoad];
    
    // Initialize the logger and app settings
    logger = [[Logger alloc] init];
    appSettings = [[AppSettings alloc] init];
    
    // Initialize the member variables
    vidyoConnectorState = VidyoConnectorStateDisconnected;
    lastSelectedCamera = nil;
    devicesSelected = YES;
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        remoteSlots[i] = [[NSMutableString alloc] initWithString:@"0"];
    }
    remoteCameras = [[NSMutableDictionary alloc] initWithCapacity:20];
    remoteCamerasRenderedStatus = [[NSMutableDictionary alloc] init];
    remoteView[0] = remoteView0;
    remoteView[1] = remoteView1;
    remoteView[2] = remoteView2;

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
    [logger Log:@"CustomViewController::viewWillAppear"];

    [super viewWillAppear:animated];

    // Construct the VidyoConnector
    vc = [[VCConnector alloc] init:nil
                       ViewStyle:VCConnectorViewStyleDefault
              RemoteParticipants:15
                   LogFileFilter:"info@VidyoClient info@VidyoConnector warning"
                     LogFileName:""
                        UserData:0];
    
    if (vc) {
        // Set the client version in the toolbar
        [clientVersion setText:[NSString stringWithFormat:@"v %@", [vc getVersion]]];

        // Register for log events
        if (![vc registerLogEventListener:self Filter:"info@VidyoClient info@VidyoConnector warning"]) {
            [logger Log:@"registerLogEventListener failed"];
        }
        if (![vc registerLocalCameraEventListener:self]) {
            [logger Log:@"registerLocalCameraEventListener failed"];
        }
        if (![vc registerLocalMicrophoneEventListener:self]) {
            [logger Log:@"registerLocalMicrophoneEventListener failed"];
        }
        if (![vc registerLocalSpeakerEventListener:self]) {
            [logger Log:@"registerLocalSpeakerEventListener failed"];
        }
        if (![vc registerRemoteCameraEventListener:self]) {
            [logger Log:@"registerRemoteCameraEventListener failed"];
        }
        if (![vc registerParticipantEventListener:self]) {
            [logger Log:@"registerParticipantEventListener failed"];
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
    [logger Log:@"CustomViewController::viewDidAppear"];
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
    [logger Log:@"CustomViewController::viewWillDisappear"];
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
    [logger Log:[NSString stringWithFormat:@"VidyoConnectorShowViewAt localView: x = %f, y = %f, w = %f, h = %f", localView.frame.origin.x, localView.frame.origin.y, localView.frame.size.width, localView.frame.size.height]];

    // Resize the rendered video.
    [vc showViewAt:&localView X:0 Y:0 Width:localView.frame.size.width Height:localView.frame.size.height];
    
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        if (![remoteSlots[i] isEqualToString:@"0"]) {
            [vc showViewAt:&remoteView[i] X:0 Y:0 Width:remoteView[i].frame.size.width Height:remoteView[i].frame.size.height];
            [logger Log:[NSString stringWithFormat:@"VidyoConnectorShowViewAt remoteView%d: x = %f, y = %f, w = %f, h = %f", i, remoteView[i].frame.origin.x, remoteView[i].frame.origin.y, remoteView[i].frame.size.width, remoteView[i].frame.size.height]];
        }
    }
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

        dispatch_async(dispatch_get_main_queue(), ^{
            for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
                if (![remoteSlots[i] isEqualToString:@"0"]) {
                    [remoteSlots[i] setString:@"0"];
                    [vc hideView:&remoteView[i]];
                }
            }

            [self refreshUI];
        });

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

    [self performSegueWithIdentifier:@"segueCustomToComposited" sender:self];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
            if (![remoteSlots[i] isEqualToString:@"0"]) {
                [remoteSlots[i] setString:@"0"];
                [vc hideView:&remoteView[i]];
            }
        }
        [self refreshUI];
    });
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

    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
            if (![remoteSlots[i] isEqualToString:@"0"]) {
                [remoteSlots[i] setString:@"0"];
                [vc hideView:&remoteView[i]];
            }
        }
        [self refreshUI];
    });
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc assignViewToLocalCamera:&localView LocalCamera:localCamera DisplayCropped:true AllowZoom:false];
            [self refreshUI];
        });
    }
}

-(void) onLocalCameraStateUpdated:(VCLocalCamera *)localCamera State:(VCDeviceState)state {
    [logger Log:[NSString stringWithFormat:@"onLocalCameraStateUpdated: name=%@ state=%ld", [localCamera getName], (long)state]];
}

-(void) onLocalMicrophoneAdded:(VCLocalMicrophone*)localMicrophone {
    [logger Log:[NSString stringWithFormat:@"onLocalMicrophoneAdded: %@", [localMicrophone getName]]];
}

-(void) onLocalMicrophoneRemoved:(VCLocalMicrophone*)localMicrophone {
    [logger Log:[NSString stringWithFormat:@"onLocalMicrophoneRemoved: %@", [localMicrophone getName]]];
}

-(void) onLocalMicrophoneSelected:(VCLocalMicrophone*)localMicrophone {
    [logger Log:[NSString stringWithFormat:@"onLocalMicrophoneSelected: %@", [localMicrophone getName]]];
}

-(void) onLocalMicrophoneStateUpdated:(VCLocalMicrophone*)localMicrophone State:(VCDeviceState)state {
    [logger Log:[NSString stringWithFormat:@"onLocalMicrophoneStateUpdated: name=%@ state=%ld", [localMicrophone getName], (long)state]];
}

-(void) onLocalSpeakerAdded:(VCLocalSpeaker*)localSpeaker {
    [logger Log:[NSString stringWithFormat:@"onLocalSpeakerAdded: %@", [localSpeaker getName]]];
}

-(void) onLocalSpeakerRemoved:(VCLocalSpeaker*)localSpeaker {
    [logger Log:[NSString stringWithFormat:@"onLocalSpeakerRemoved: %@", [localSpeaker getName]]];
}

-(void) onLocalSpeakerSelected:(VCLocalSpeaker*)localSpeaker {
    [logger Log:[NSString stringWithFormat:@"onLocalSpeakerSelected: %@", [localSpeaker getName]]];
}

-(void) onLocalSpeakerStateUpdated:(VCLocalSpeaker*)localSpeaker State:(VCDeviceState)state {
    [logger Log:[NSString stringWithFormat:@"onLocalSpeakerStateUpdated: name=%@ state=%ld", [localSpeaker getName], (long)state]];
}

-(void) onRemoteCameraAdded:(VCRemoteCamera *)remoteCamera Participant:(VCParticipant *)participant {
    [remoteCameras setObject:remoteCamera forKey:[participant getId]];
    [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:NO] forKey:[participant getId]];
    
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        if ([remoteSlots[i] isEqualToString:@"0"]) {
            [remoteSlots[i] setString:[participant getId]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [vc assignViewToRemoteCamera:&remoteView[i] RemoteCamera:remoteCamera DisplayCropped:true AllowZoom:false];
                [self refreshUI];
            });
            
            [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:YES] forKey:[participant getId]];
            break;
        }
    }
}

-(void) onRemoteCameraRemoved:(VCRemoteCamera *)remoteCamera Participant:(VCParticipant *)participant {
    dispatch_async(dispatch_get_main_queue(), ^{
    
    [remoteCameras removeObjectForKey:[participant getId]];
    [remoteCamerasRenderedStatus removeObjectForKey:[participant getId]];
    
    // Scan through the renderer slots and if this participant's camera
    // is being rendered in a slot, then clear the slot and hide the camera.
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        if ([remoteSlots[i] isEqualToString:[participant getId]]) {
            [remoteSlots[i] setString:@"0"];
            [vc hideView:&remoteView[i]];
            
            // If a remote camera is not rendered in a slot, replace it in the slot that was just cleaered
            for (NSString* participantId in remoteCameras) {
                if ( ![[remoteCamerasRenderedStatus objectForKey:participantId] boolValue] ) {
                    [remoteSlots[i] setString:participantId];
                    
                    //dispatch_async(dispatch_get_main_queue(), ^{
                    VCRemoteCamera *r = (VCRemoteCamera*)[remoteCameras objectForKey:participantId];
                    [logger Log:[NSString stringWithFormat:@"remoteCamera monitor replace %@ %@", [r getId], [r getName]]];
                    
                    [vc assignViewToRemoteCamera:&remoteView[i] RemoteCamera:r DisplayCropped:true AllowZoom:false];
                    [self refreshUI];
                    [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:YES] forKey:[participant getId]];
                    //});
                    break;
                }
            }
            break;
        }
    }
    });
}

-(void) onRemoteCameraStateUpdated:(VCRemoteCamera *)remoteCamera Participant:(VCParticipant *)participant State:(VCDeviceState)state {}

-(void) onParticipantJoined:(VCParticipant *)participant {}

-(void) onParticipantLeft:(VCParticipant *)participant {}

-(void) onDynamicParticipantChanged:(NSMutableArray *)participants RemoteCameras:(NSMutableArray *)remoteCameras {}

-(void) onLoudestParticipantChanged:(VCParticipant *)participant AudioOnly:(BOOL)audioOnly {
    // Check if the loudest speaker is being rendered in one of the slots
    BOOL found = NO;
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        if ([remoteSlots[i] isEqualToString:[participant getId]]) {
            found = YES;
            break;
        }
    }
    
    // First check if the participant's camera has been added to the remoteCameras dictionary
    if ([remoteCameras objectForKey:[participant getId]] == nil) {
        [logger Log:@"Warning: loudest speaker participant does not have a camera in remoteCameras"];
    } else if (!found) {
        // The loudest speaker is not being rendered in one of the slots so
        // hide the slot 0 remote camera and assign loudest speaker to slot 0.
        
        // Set the RenderedStatus flag to NO of the remote camera which is being hidden
        [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:NO] forKey:remoteSlots[0]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc assignViewToRemoteCamera:&remoteView0 RemoteCamera:[remoteCameras objectForKey:[participant getId]] DisplayCropped:YES AllowZoom:NO];
            [self refreshUI];
        });

        // Assign slot 0 to the the loudest speaker's participant id
        [remoteSlots[0] setString:[participant getId]];
        
        // Set the RenderedStatus flag to YES of the remote camera which has now been rendered
        [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:YES] forKey:[participant getId]];
        [logger Log:[NSString stringWithFormat:@"AssignViewToRemoteCamera %@ to slot 0", [participant getId]]];
    }
}

@end
