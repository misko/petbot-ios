//
//  PBViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#include "PBViewController.h"

#import <CRToast/CRToast.h>

@interface PBViewController () {
}

@end

@implementation PBViewController

-(void)toastStatus:(bool)status message:(NSString*)msg {
    NSDictionary *options = @{
                              kCRToastTextKey : msg,
                              kCRToastTextAlignmentKey : @(NSTextAlignmentCenter),
                              kCRToastBackgroundColorKey : status ? [UIColor greenColor] : [UIColor redColor],
                              kCRToastAnimationInTypeKey : @(CRToastAnimationTypeGravity),
                              kCRToastAnimationOutTypeKey : @(CRToastAnimationTypeGravity),
                              kCRToastAnimationInDirectionKey : @(CRToastAnimationDirectionTop),
                              kCRToastAnimationOutDirectionKey : @(CRToastAnimationDirectionTop),
                              kCRToastNotificationTypeKey : @(CRToastTypeNavigationBar),
                              kCRToastTimeIntervalKey : [NSNumber numberWithInt:3],
                              //kCRToastImageKey : [UIImage imageNamed:@"alert_icon.png"]
                              kCRToastImageKey : status ? [UIImage imageNamed:@"white_checkmark.png"] : [UIImage imageNamed:@"alert_icon.png"]
                              };
    
    [CRToastManager showNotificationWithOptions:options
                                completionBlock:^{
                                    NSLog(@"Completed");
                                }];
}

-(void)toast_success {

}

@end