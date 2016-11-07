//
//  AppDelegate.h
//  petbot
//
//  Created by Misko Dzamba on 2016-04-13.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#define SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
@interface AppDelegate : UIResponder <UIApplicationDelegate,UNUserNotificationCenterDelegate>


@property (strong, nonatomic) UIWindow *window;

-(void)showSelfieWithURL:(NSString *)selfieURL RMURL:(NSString*)rmURL from:(UIViewController *)from_vc;
@end

