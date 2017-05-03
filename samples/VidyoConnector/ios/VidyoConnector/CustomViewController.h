#ifndef CUSTOMVIEWCONTROLLER_H_INCLUDED
#define CUSTOMVIEWCONTROLLER_H_INCLUDED
//
//  CustomViewController.h
//
//  Copyright © 2017 Vidyo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Lmi/VidyoClient/VidyoConnector_Objc.h>

@interface CustomViewController : UIViewController <UITextFieldDelegate, IConnect, IRegisterLogEventListener, IRegisterLocalCameraEventListener, IRegisterRemoteCameraEventListener, IRegisterParticipantEventListener>

@property (weak, nonatomic) IBOutlet UITextField *host;
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UITextField *token;
@property (weak, nonatomic) IBOutlet UITextField *resourceId;
@property (weak, nonatomic) IBOutlet UILabel     *toolbarStatusText;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectionSpinner;

@property (weak, nonatomic) IBOutlet UIButton *toggleConnectButton;
@property (weak, nonatomic) IBOutlet UIButton *microphonePrivacyButton;
@property (weak, nonatomic) IBOutlet UIButton *cameraPrivacyButton;
@property (weak, nonatomic) IBOutlet UIButton *layoutButton;

@property (weak, nonatomic) IBOutlet UIView  *controlsView;
@property (weak, nonatomic) IBOutlet UIView  *toolbarView;
@property (weak, nonatomic) IBOutlet UIView  *toggleToolbarView;
@property (weak, nonatomic) IBOutlet UILabel *bottomControlSeparator;
@property (weak, nonatomic) IBOutlet UIView  *localView;
@property (weak, nonatomic) IBOutlet UIView  *remoteView0;
@property (weak, nonatomic) IBOutlet UIView  *remoteView1;
@property (weak, nonatomic) IBOutlet UIView  *remoteView2;
@property (weak, nonatomic) IBOutlet UILabel *clientVersion;

- (IBAction)toggleConnectButtonPressed:(id)sender;
- (IBAction)cameraPrivacyButtonPressed:(id)sender;
- (IBAction)microphonePrivacyButtonPressed:(id)sender;
- (IBAction)cameraSwapButtonPressed:(id)sender;
- (IBAction)layoutButtonPressed:(id)sender;
- (IBAction)toggleToolbar:(UITapGestureRecognizer *)sender;

@end

#endif // CUSTOMVIEWCONTROLLER_H_INCLUDED
