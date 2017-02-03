//
//  AppDelegate.m
//  petbot
//
//  Created by Misko Dzamba on 2016-04-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "AppDelegate.h"
#import "tcp_utils.h"
//http://ashishkakkad.com/2016/09/push-notifications-in-ios-10-objective-c/
//http://api.shephertz.com/tutorial/Push-Notification-iOS/
#import <UserNotifications/UserNotifications.h>
#import "SelfieViewController.h"


#import <Antenna.h>
#import <DDAntennaLogger.h>
#import <DDLog.h>


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // Let the device know we want to receive push notifications
    // Register for Push Notitications, if running on iOS 8
    //NSLog(@"LAUNCHED WITH OPTIONS?");
    pbssl_setup();
    
    
    [self registerForRemoteNotifications:application];
    if (launchOptions != nil) {
        [self.window makeKeyAndVisible];
        // Launched from push notification
        /*UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Did receive a Remote Notification" message:@"HELLO" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alertView show];*/
        NSDictionary *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        //[self showSelfie:@"SELFIE1"];
        if (notification!=nil) {
            NSString * selfieURL = [notification objectForKey:@"mediaUrl"];
            NSString * selfieRMURL = [notification objectForKey:@"rmUrl"];
            [self showSelfieWithURL:selfieURL RMURL:selfieRMURL from:self.window.rootViewController];
        }
        NSLog(@"LAUNCHED WITH OPTIONS?");
    }
    
    
    NSURL *logUrl = [NSURL URLWithString:@"http://159.203.252.147:3205/log/"];
    [[Antenna sharedLogger] addChannelWithURL:logUrl method:@"POST"];
    [[Antenna sharedLogger] startLoggingApplicationLifecycleNotifications];
    
    DDAntennaLogger *logger = [[DDAntennaLogger alloc] initWithAntenna:[Antenna sharedLogger]];
    [DDLog addLogger:logger];
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; // To see them in the Xcode debugger
    
    return YES;
}

- (void)registerForRemoteNotifications:(UIApplication *)application {
    if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0")){
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
            if(!error){
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
        }];
    }
    else {
        if ([application respondsToSelector:@selector(registerUserNotificationSettings:)])
        {
            UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes categories:nil];
            [application registerUserNotificationSettings:settings];
            [application registerForRemoteNotifications];
        }
        else
        {
            // Register for Push Notifications, if running iOS version < 8
            [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)];
        }
    }
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"didReceiveRemoteNotification");
    //[UIApplication sharedApplication].applicationIconBadgeNumber
    //long badge = [[userInfo objectForKey:@"badge"] longValue];
    //[[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];
    //application.applicationIconBadgeNumber = 0;
    //self.textView.text = [userInfo description];
    // We can determine whether an application is launched as a result of the user tapping the action
    // button or whether the notification was delivered to the already-running application by examining
    // the application state.
    
    NSString * selfieURL = [userInfo objectForKey:@"mediaUrl"];
    NSString * selfieRMURL = [userInfo objectForKey:@"rmUrl"];
    if (application.applicationState == UIApplicationStateActive) {
        NSLog(@"from INSIDE APP!");
        // Nothing to do if applicationState is Inactive, the iOS already displayed an alert view.
        /*UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Did receive a Remote Notification" message:[NSString stringWithFormat:@"Your App name received this notification while it was running:\n%@",[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]]delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
         [alertView show];*/
        //[[[[UIApplication sharedApplication] keyWindow] subviews] lastObject];
        //UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
        //if ([top isKindOfClass:[UINavigationController class]]) {
        //    top = [(UINavigationController*) top visibleViewController];
        //}
        //[self.window makeKeyAndVisible];
        UIViewController *topRootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topRootViewController.presentedViewController)
        {
            topRootViewController = topRootViewController.presentedViewController;
        }
        [self showSelfieWithURL:selfieURL RMURL:selfieRMURL from:topRootViewController];
    }    else {
        NSLog(@"from OUTSIDE APP!");
        /*UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Did receive a Remote Notification" message:[NSString stringWithFormat:@"Your App name received this notification while it was running:\n%@",[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]]delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
         [alertView show];*/
        
        [self showSelfieWithURL:selfieURL RMURL:selfieRMURL from:self.window.rootViewController];
    }
    //[self showSelfieWithURL:selfieURL RMURL:selfieRMURL from:self.window.rootViewController];
}

-(void)showSelfieWithURL:(NSString *)selfieURL RMURL:(NSString*)rmURL from:(UIViewController *)from_vc {
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SelfieViewController *VC = [storyboard instantiateViewControllerWithIdentifier:@"SelfieView"];
    VC.selfieRMURL=rmURL;
    VC.selfieURL=selfieURL;
    VC.vvc = nil;
    VC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    //[self.window.rootViewController presentViewController: VC animated:YES completion:nil];
    //[from_vc presentViewController: VC animated:YES completion:nil];
    [from_vc presentViewController: VC animated:YES completion:nil];
}

-(void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken");
    // Prepare the Device Token for Registration (remove spaces and < >)
    NSString *devToken = [[[[deviceToken description]
                            stringByReplacingOccurrencesOfString:@"<"withString:@""]
                           stringByReplacingOccurrencesOfString:@">" withString:@""]
                          stringByReplacingOccurrencesOfString: @" " withString: @""];
    NSLog(@"My token is: %@\n", devToken);
    [[NSUserDefaults standardUserDefaults] setObject:devToken forKey:@"deviceToken"];
}
-(void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error

{
    NSLog(@"Failed to get token, error: %@\n", error);
}


- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    NSLog(@"IN WILL PRESENT!");
    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound);
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    NSLog(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    NSLog(@"applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    NSLog(@"applicationDidBecomeActive");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"applicationWillTerminate");
}





@end

@implementation NSURLRequest(DataController)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}
@end
