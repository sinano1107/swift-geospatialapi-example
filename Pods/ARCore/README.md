# ARCore SDK for iOS

This pod contains the ARCore SDK for iOS.

## Getting Started

*   *Cloud Anchors Quickstart*:
    https://developers.google.com/ar/develop/ios/cloud-anchors/quickstart
*   *Augmented Faces Quickstart*:
    https://developers.google.com/ar/develop/ios/augmented-faces/quickstart
*   *Geospatial Quickstart*:
    https://developers.google.com/ar/develop/ios/geospatial/quickstart
*   *Reference*: https://developers.google.com/ar/reference/ios
*   *Code samples*: Sample apps are available for download at
    https://github.com/google-ar/arcore-ios-sdk/tree/master/Examples. Be sure to
    follow any instructions in README files.

## Installation

ARCore requires a deployment target that is >= 11.0. Also, you must be building
with at least version 15.0 of the iOS SDK. ARCore binaries no longer contain
bitcode, which is deprecated with Xcode 14, so if you are building with Xcode 13
then you must disable bitcode for your project. The SDK can be installed using
either CocoaPods or Swift Package Manager; see below for details.

### Using CocoaPods

To integrate ARCore SDK for iOS into your Xcode project using CocoaPods, specify
it in your `Podfile`:

```
target 'YOUR_APPLICATION_TARGET_NAME_HERE'
platform :ios, '11.0'
pod 'ARCore/SUBSPEC_NAME_HERE' ~> VERSION_HERE
```

Then, run the following command:

```
$ pod install
```

### Using Swift Package Manager (Beta)

Swift Package Manager support is currently in Beta, and ARCore can be integrated
as a local package. To integrate this way:
1) Download the pod bundle (ARCore-$VERSION.tar.gz) and unzip it.
2) Add the directory as a local package by either going to "File > Add Packages"
   and clicking "Add Local", or simply dragging the folder into your project.
3) After package resolution, add the appropriate component libraries of ARCore
   as dependencies of your app by going to
   "Build Phases > Link Binary With Libraries" and adding them.
4) You will need to add the flag "-ObjC" to "Other Linker Flags". We recommend
   setting "Other Linker Flags" to "$(inherited) -ObjC". Also make sure that the
   Build Settings "Enable Modules" and "Link Frameworks Automatically" are set
   to "Yes" (ARCore relies on auto-linking), and "Enable Bitcode" is set to "No"
   (ARCore binaries do not contain bitcode).
5) Import ARCore somewhere in your code, using either `#import` or `@import` in
   Objective-C or just `import` in Swift. This is necessary for auto-linking to
   find the required system frameworks and libraries.

### Additional Steps

Before you can start using the ARCore Cloud Anchors API or the ARCore Geospatial
API, you will need to create a project in the
[Google Developer Console](https://console.developers.google.com/) and enable
the
[ARCore API](https://console.cloud.google.com/apis/library/arcore).

## License and Terms of Service

By using the ARCore SDK for iOS you accept Google's **ARCore Additional Terms of
Service** at
[https://developers.google.com/ar/develop/terms](https://developers.google.com/ar/develop/terms)
