# multiview-connector-ios
Vidyo.io iOS app featuring ability to switch between composited and custom layouts. This app highlights some important items which are not found in the standard VidyoConnector iOS app (found here: https://developer.vidyo.io/packages) :
1. How to create a custom layout video chat. The custom layout view controller has 4 views - 1 for the local camera (preview) and 3 for cameras of remote participants.
2. How to properly release a Connector object when switching between view controllers.

## Clone Repository
git clone https://github.com/Vidyo/multiview-connector-ios.git

## Acquire Framework
1. Download the latest Vidyo.io iOS SDK package: https://static.vidyo.io/latest/package/VidyoClient-iOSSDK.zip
2. Copy the framework located at VidyoClient-iOSSDK/lib/ios/VidyoClientIOS.framework to the lib/ios directory under where this repository was cloned.

> Note: VidyoClientIOS.framework is available in SDK versions 4.1.5.x and later.
> The version of the SDK that you are acquiring is highlighted in the blue box here: https://developer.vidyo.io/documentation/latest

## Build and Run Application
1. Open the project samples/VidyoConnector/ios/VidyoConnector-iOS.xcodeproj in Xcode 8.0 or later.
2. Connect an iOS device to your computer via USB.
3. Select the iOS device as the build target of your application.
4. Build and run the application on the iOS device.
5. The layout that you are currently using is displayed in blue in the center of the screen: either "Custom Layout" or "Composited Layout". You can switch between layouts by clicking on that text.

## Known Problems
1. When running with SDK 4.1.11.4 and lower, updating the form (host, resource, etc) after switching between custom and composited layout views may cause a crash.
