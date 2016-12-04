//
//  PBViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#include "PBViewController.h"

#include "pb.h"
#import <CRToast/CRToast.h>

@interface PBViewController () {
}

@end

@implementation PBViewController
-(NSMutableDictionary *)parseConfig:(NSString*)str {
    /*selfie_cat_sensitivity  0.8000
     selfie_pet_sensitivity  0.8000
     selfie_mot_sensitivity  0.8000
     stddev_multiplier       5
     selfie_timeout  14400
     selfie_length   25
     master_volume   50
     pb_color_fx     0
     pb_exposure     0
     pb_hflip        0
     pb_vflip        0
     pb_white_balance        0
     VERSION 1412431*/
    NSArray * ar = [str componentsSeparatedByString:@"\n"];
    NSMutableDictionary * d = [NSMutableDictionary dictionary];
    for (NSString * line in ar) {
        NSArray * line_to_bits = [line componentsSeparatedByString:@"\t"];
        if ([line_to_bits count]==2) {
            [d setValue:line_to_bits[1] forKey:[line_to_bits[0] lowercaseString]];
        }
    }
    return d;
}



-(void)send_msg:(const char*)msg type:(int)ty {
    pbmsg * m = new_pbmsg_from_str_wtype(msg, ty);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

-(NSMutableArray*)pbserverLSWithType:(NSString *)ty {
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"mp3", @"file_type", @"1", @"start_idx", @"10", @"end_idx",nil];
    
    //make the json payload
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:0 error:&error];
    
    //make the url request
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s%@", HTTPS_ADDRESS_PB_LS, pubsubserver_secret]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    //send the request
    NSURLResponse * response;
    NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        NSLog(@"Error,%@", [error localizedDescription]);
    } else {
        //parse the return json
        NSDictionary * d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
        } else {
            NSNumber *status = d[@"status"];
            if ([status isEqual:@0]) {
                NSLog(@"SERVER QUERY FAILED?");
            } else if ([status isEqual:@1]) {
                NSMutableArray * files =  d[@"files"];
                return files;
            } else {
                NSLog(@"SERVER FAILED TO RESPOND PROPERLY");
            }
        }
    }
    return nil;
}

- (void)setupLogin {
    
    self->loginInfo=[loginArray objectForKey:@"pubsubserver"];
    
    //TODO check for errors here?
    //self->loginInfo=loginInfo;
    pubsubserver_port = [[self->loginInfo objectForKey:@"port"] intValue];
    pubsubserver_secret = [self->loginInfo objectForKey:@"secret"];
    pubsubserver_server = [self->loginInfo objectForKey:@"server"];
    NSLog(@"server in load is %@ %@",pubsubserver_server,[self->loginInfo objectForKey:@"server"]);
    pubsubserver_username = [self->loginInfo objectForKey:@"username"];
}

-(void)toastStatus:(bool)status Message:(NSString*)msg {
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
                              kCRToastImageKey : status ? [UIImage imageNamed:@"white_checkmark.png"] : [UIImage imageNamed:@"alert_icon.png"],
                              kCRToastForceUserInteractionKey : @NO
                              };
    
    [CRToastManager showNotificationWithOptions:options
                                completionBlock:^{
                                    NSLog(@"Completed");
                                }];
}

-(void)toastPinColor:(UIColor*)c Message:(NSString*)msg {
    NSDictionary *options = @{
                              kCRToastTextKey : msg,
                              kCRToastTextAlignmentKey : @(NSTextAlignmentCenter),
                              kCRToastBackgroundColorKey : c,
                              kCRToastAnimationInTypeKey : @(CRToastAnimationTypeGravity),
                              kCRToastAnimationOutTypeKey : @(CRToastAnimationTypeGravity),
                              kCRToastAnimationInDirectionKey : @(CRToastAnimationDirectionTop),
                              kCRToastAnimationOutDirectionKey : @(CRToastAnimationDirectionTop),
                              kCRToastNotificationTypeKey : @(CRToastTypeNavigationBar),
                              //kCRToastTimeIntervalKey : [NSNumber numberWithInt:3],
                              kCRToastForceUserInteractionKey : @YES
                              };
    
    [CRToastManager showNotificationWithOptions:options
                                completionBlock:^{
                                    NSLog(@"Completed");
                                }];
}

-(void)toast_success {

}


-(void)setLoginArray:(NSDictionary *)dictionary {
    NSLog(@"Someone called login array");
    loginArray = dictionary;
}



@end
