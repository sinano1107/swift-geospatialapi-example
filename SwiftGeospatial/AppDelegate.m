//
//  AppDelegate.m
//  SwiftGeospatial
//
//  Created by 長政輝 on 2022/11/26.
//

#import "AppDelegate.h"

//#import "ViewController.h"
#import "SwiftGeospatial-Swift.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.window = [[UIWindow alloc] init];
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
//    ViewController *viewController = [storyBoard instantiateInitialViewController];
    SwiftViewController *viewController = [storyBoard instantiateInitialViewController];
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
  return UIInterfaceOrientationMaskPortrait;
}

@end
