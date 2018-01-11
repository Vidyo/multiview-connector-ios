//
//  CustomViewController.m
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import "VidyoConnectorAppDelegate.h"
#import <Foundation/Foundation.h>
#import "CustomViewController.h"
#import "Logger.h"

#define NUM_REMOTE_SLOTS 3

@interface CustomViewController () {
@private
    VCConnector *vc;
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
    enum VidyoConnectorState vidyoConnectorState;
    CGFloat   keyboardOffset;

    NSMutableString*   remoteSlots[NUM_REMOTE_SLOTS];
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
    [super viewDidLoad];
    
    // Initialize the logger
    logger = [[Logger alloc] init];
    [logger Log:@"CustomViewController::viewDidLoad called."];
    
    // Initialize the member variables
    vidyoConnectorState = VidyoConnectorStateDisconnected;
    microphonePrivacy = NO;
    cameraPrivacy = NO;
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
}

- (void)viewWillAppear:(BOOL)animated {
    [logger Log:@"CustomViewController::viewWillAppear is called."];

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

        // If enableDebug is configured then enable debugging
        if (enableDebug) {
            [vc enableDebug:7776 LogFilter:"warning info@VidyoClient info@VidyoConnector"];
        }
        // Register for log callbacks
        if (![vc registerLogEventListener:self Filter:"info@VidyoClient info@VidyoConnector warning"]) {
            [logger Log:@"RegisterLogEventListener failed"];
        }
        if (![vc registerLocalCameraEventListener:self]) {
            [logger Log:@"RegisterLocalCameraEventListener failed"];
        }
        if (![vc registerLocalMicrophoneEventListener:self]) {
            [logger Log:@"RegisterLocalMicrophoneEventListener failed"];
        }
        if (![vc registerLocalSpeakerEventListener:self]) {
            [logger Log:@"RegisterLocalSpeakerEventListener failed"];
        }
        if (![vc registerRemoteCameraEventListener:self]) {
            [logger Log:@"RegisterRemoteCameraEventListener failed"];
        }
        if (![vc registerParticipantEventListener:self]) {
            [logger Log:@"RegisterParticipantEventListener failed"];
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
    [logger Log:@"CustomViewController::viewDidAppear called."];
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
    [logger Log:@"CustomViewController::viewWillDisappear called."];
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
    // Enable camera privacy so remote participants do not see a frozen frame
    [vc setCameraPrivacy:YES];
    [vc setMode:VCConnectorModeBackground];
}

- (void)appWillEnterForeground:(NSNotification*)notification {
    [vc setMode:VCConnectorModeForeground];

    // Check if camera privacy should be disabled
    if (!cameraPrivacy) {
        [vc setCameraPrivacy:NO];
    }
}

- (void)appWillTerminate:(NSNotification*)notification {
    // Deregister from any/all notifications.
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Uninitialize VidyoConnector
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
    [self RefreshUI];
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
    [logger Log:[NSString stringWithFormat:@"VidyoConnectorShowViewAt localView: x = %f, y = %f, w = %f, h = %f", localView.frame.origin.x, localView.frame.origin.y, localView.frame.size.width, localView.frame.size.height]];

    // Resize the VidyoConnector
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
- (void)ConnectorStateUpdated:(enum VidyoConnectorState)state statusText:(NSString *)statusText {
    vidyoConnectorState = state;
    
    // Execute this code on the main thread since it is updating the UI layout
    dispatch_async(dispatch_get_main_queue(), ^{
        // Set the status text in the toolbar
        [toolbarStatusText setText:statusText];

        if (vidyoConnectorState == VidyoConnectorStateConnected) {
            // Enable the toggle toolbar control
            toggleToolbarView.hidden = NO;

            if (!hideConfig) {
                // Update the view to hide the controls; this must be done on the main thread
                controlsView.hidden = YES;
            }
        } else {
            // VidyoConnector is disconnected
            
            // Disable the toggle toolbar control and display toolbar in case it is hidden
            toggleToolbarView.hidden = YES;
            toolbarView.hidden = NO;
            
            // Change image of toggleConnectButton to callStartImage
            [toggleConnectButton setImage:callStartImage forState:UIControlStateNormal];

            // If a return URL was provided as an input parameter, then return to that application
            if (returnURL) {
                // Provide a callstate of either 0 or 1, depending on whether the call was successful
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?callstate=%d", returnURL, (int)(vidyoConnectorState == VidyoConnectorStateDisconnected)]]];
            }
            // If the allow-reconnect flag is set to false and a normal (non-failure) disconnect occurred,
            // then disable the toggle connect button, in order to prevent reconnection.
            if (!allowReconnect && (vidyoConnectorState == VidyoConnectorStateDisconnected)) {
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
                if (![remoteSlots[i] isEqualToString:@"0"]) {
                    [remoteSlots[i] setString:@"0"];
                    [vc hideView:&remoteView[i]];
                }
            }

            [self RefreshUI];
        });

        [vc disconnect];
    } else {
        [toolbarStatusText setText:@"Connecting..."];
        BOOL status = [vc connect:[host.text UTF8String]
                            Token:[token.text UTF8String]
                      DisplayName:[displayName.text UTF8String]
                       ResourceId:[resourceId.text UTF8String]
                          ConnectorIConnect:self];

        if (status == NO) {
            [self ConnectorStateUpdated:VidyoConnectorStateFailure statusText:@"Connection failed"];
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

// Toggle the microphone privacy
- (IBAction)microphonePrivacyButtonPressed:(id)sender {
    microphonePrivacy = !microphonePrivacy;
    if (microphonePrivacy == NO) {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOnWhite.png"] forState:UIControlStateNormal];
    } else {
        [microphonePrivacyButton setImage:[UIImage imageNamed:@"microphoneOff.png"] forState:UIControlStateNormal];
    }
    [vc setMicrophonePrivacy:microphonePrivacy];
}

// Toggle the camera privacy
- (IBAction)cameraPrivacyButtonPressed:(id)sender {
    cameraPrivacy = !cameraPrivacy;
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
    [logger Log:@"Successfully connected."];
    [self ConnectorStateUpdated:VidyoConnectorStateConnected statusText:@"Connected"];
}

// Handle attempted connection failure.
-(void) onFailure:(VCConnectorFailReason)reason {
    [logger Log:@"Connection attempt failed."];

    // Update UI to reflect connection failed
    [self ConnectorStateUpdated:VidyoConnectorStateFailure statusText:@"Connection failed"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
            if (![remoteSlots[i] isEqualToString:@"0"]) {
                [remoteSlots[i] setString:@"0"];
                [vc hideView:&remoteView[i]];
            }
        }
        [self RefreshUI];
    });
}

//  Handle an existing session being disconnected.
-(void) onDisconnected:(VCConnectorDisconnectReason)reason {
    if (reason == VCConnectorDisconnectReasonDisconnected) {
        [logger Log:@"Succesfully disconnected."];
        [self ConnectorStateUpdated:VidyoConnectorStateDisconnected statusText:@"Disconnected"];
    } else {
        [logger Log:@"Unexpected disconnection."];
        [self ConnectorStateUpdated:VidyoConnectorStateDisconnectedUnexpected statusText:@"Unexepected disconnection"];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
            if (![remoteSlots[i] isEqualToString:@"0"]) {
                [remoteSlots[i] setString:@"0"];
                [vc hideView:&remoteView[i]];
            }
        }
        [self RefreshUI];
    });
}

// Handle a message being logged.
-(void) onLog:(VCLogRecord*)logRecord {
    [logger LogClientLib:logRecord.message];
}

-(void) onLocalCameraAdded:(VCLocalCamera *)localCamera {
    [logger Log:@"OnLocalCameraAdded"];
}

-(void) onLocalCameraRemoved:(VCLocalCamera *)localCamera {
    [logger Log:@"OnLocalCameraRemoved"];
}

-(void) onLocalCameraSelected:(VCLocalCamera *)localCamera {
    [logger Log:@"OnLocalCameraSelected"];
    if (localCamera) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc assignViewToLocalCamera:&localView LocalCamera:localCamera DisplayCropped:true AllowZoom:false];
            [self RefreshUI];
        });
    }
}

-(void) onLocalCameraStateUpdated:(VCLocalCamera *)localCamera State:(VCDeviceState)state {
    [logger Log:@"OnLocalCameraStateUpdated"];
}

-(void) onLocalMicrophoneAdded:(VCLocalMicrophone*)localMicrophone {
    [logger Log:@"OnLocalMicrophoneAdded"];
}

-(void) onLocalMicrophoneRemoved:(VCLocalMicrophone*)localMicrophone {
    [logger Log:@"OnLocalMicrophoneRemoved"];
}

-(void) onLocalMicrophoneSelected:(VCLocalMicrophone*)localMicrophone {
    [logger Log:@"OnLocalMicrophoneSelected"];
}

-(void) onLocalMicrophoneStateUpdated:(VCLocalMicrophone*)localMicrophone State:(VCDeviceState)state {
    [logger Log:@"OnLocalMicrophoneStateUpdated"];
}

-(void) onLocalSpeakerAdded:(VCLocalSpeaker*)localSpeaker {
    [logger Log:@"OnLocalSpeakerAdded"];
}

-(void) onLocalSpeakerRemoved:(VCLocalSpeaker*)localSpeaker {
    [logger Log:@"OnLocalSpeakerRemoved"];
}

-(void) onLocalSpeakerSelected:(VCLocalSpeaker*)localSpeaker {
    [logger Log:@"OnLocalSpeakerSelected"];
}

-(void) onLocalSpeakerStateUpdated:(VCLocalSpeaker*)localSpeaker State:(VCDeviceState)state {
    [logger Log:@"OnLocalSpeakerStateUpdated"];
}

-(void) onRemoteCameraAdded:(VCRemoteCamera *)remoteCamera Participant:(VCParticipant *)participant {
    [remoteCameras setObject:remoteCamera forKey:[participant getId]];
    [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:NO] forKey:[participant getId]];
    
    for (int i = 0; i < NUM_REMOTE_SLOTS; ++i) {
        if ([remoteSlots[i] isEqualToString:@"0"]) {
            [remoteSlots[i] setString:[participant getId]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [vc assignViewToRemoteCamera:&remoteView[i] RemoteCamera:remoteCamera DisplayCropped:true AllowZoom:false];
                [self RefreshUI];
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
                    [self RefreshUI];
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
            [self RefreshUI];
        });

        // Assign slot 0 to the the loudest speaker's participant id
        [remoteSlots[0] setString:[participant getId]];
        
        // Set the RenderedStatus flag to YES of the remote camera which has now been rendered
        [remoteCamerasRenderedStatus setObject:[NSNumber numberWithBool:YES] forKey:[participant getId]];
        [logger Log:[NSString stringWithFormat:@"AssignViewToRemoteCamera %@ to slot 0", [participant getId]]];
    }
}

@end
