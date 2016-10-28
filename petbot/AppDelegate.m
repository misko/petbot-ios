//
//  AppDelegate.m
//  petbot
//
//  Created by Misko Dzamba on 2016-04-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "AppDelegate.h"
//http://ashishkakkad.com/2016/09/push-notifications-in-ios-10-objective-c/
//http://api.shephertz.com/tutorial/Push-Notification-iOS/
#import <UserNotifications/UserNotifications.h>
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // Let the device know we want to receive push notifications
    // Register for Push Notitications, if running on iOS 8
    [self registerForRemoteNotifications:application];
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
    application.applicationIconBadgeNumber = 0;
    //self.textView.text = [userInfo description];
    // We can determine whether an application is launched as a result of the user tapping the action
    // button or whether the notification was delivered to the already-running application by examining
    // the application state.
    
    if (application.applicationState == UIApplicationStateActive)
    {
        // Nothing to do if applicationState is Inactive, the iOS already displayed an alert view.
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Did receive a Remote Notification" message:[NSString stringWithFormat:@"Your App name received this notification while it was running:\n%@",[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]]delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alertView show];
    }    
}


-(void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    // Prepare the Device Token for Registration (remove spaces and < >)
    NSString *devToken = [[[[deviceToken description]
                            stringByReplacingOccurrencesOfString:@"<"withString:@""]
                           stringByReplacingOccurrencesOfString:@">" withString:@""]
                          stringByReplacingOccurrencesOfString: @" " withString: @""];
    NSLog(@"My token is: %@\n", devToken);
}
-(void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error

{
    NSLog(@"Failed to get token, error: %@\n", error);
}  

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}



@end

@implementation NSURLRequest(DataController)
+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}
@end
