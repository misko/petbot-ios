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

-(BOOL)removeFileFID:(NSString *)fid {
    NSError *error;
    //make the url request
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s%@/%@", HTTPS_ADDRESS_PB_RM, pubsubserver_secret,fid]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
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
                return true;
            } else {
                NSLog(@"SERVER FAILED TO RESPOND PROPERLY");
            }
        }
    }
    return false;
}


-(bool)updatesAllowed {
    NSString * x = [loginArray objectForKey:@"updates_allowed"];
    if (x!=nil) {
        if (![x isEqualToString:@""] ) {
            return true;
        } else {
            return false;
        }
    }
    return false;
}

-(NSMutableArray*)pbserverLSWithType:(NSString *)ty {
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"mp3", @"file_type", @"1", @"start_idx", @"50", @"end_idx",nil];
    
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
                NSMutableArray * files =  [NSMutableArray arrayWithArray:d[@"files"]];
                [files sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    NSArray *array1 = (NSArray *)obj1;
                    NSArray *array2 = (NSArray *)obj2;
                    NSString *num1String = [array1 objectAtIndex:1];
                    NSString *num2String = [array2 objectAtIndex:1];
                    
                    return [num1String compare:num2String];
                }];
                //[files sortUsingFunction:compareSound context:nil];
                /*NSArray *sortedArray = [files sortUsingComparator:<#^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2)cmptr#> {
                    return 0;
                }];*/
                //NSArray *sortedArray = [files sortedArrayUsingSelector:@selector(compareSound:)];
                return files;
            } else {
                NSLog(@"SERVER FAILED TO RESPOND PROPERLY");
            }
        }
    }
    return nil;
}

-(void)setLoginArray:(NSDictionary *)dictionary {
    loginArray = dictionary;
}
- (void)setupLogin {
    self->loginInfo=[loginArray objectForKey:@"pubsubserver"];
    
    pubsubserver_port = [[self->loginInfo objectForKey:@"port"] intValue];
    pubsubserver_secret = [self->loginInfo objectForKey:@"secret"];
    pubsubserver_server = [self->loginInfo objectForKey:@"server"];
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
    [CRToastManager dismissAllNotifications:true];
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
    
    [CRToastManager dismissAllNotifications:true];
    [CRToastManager showNotificationWithOptions:options
                                completionBlock:^{
                                    NSLog(@"Completed");
                                }];
}

-(void)toast_success {

}

-(NSString *)secondsToStr:(float )sec {
    if (sec>(60*60)) {
        return [NSString stringWithFormat:@"%dhr", (int)(sec/(60*60))];
    } else if (sec>60) {
        return [NSString stringWithFormat:@"%dm", (int)(sec/60)];
    }
    return [NSString stringWithFormat:@"%ds", (int)sec];
}


/*^(BOOL ok) {
[self populateSounds];
}];
*/
-(void) uploadFile:(NSURL *)fileURL withFilename:(NSString *)filename withCallBack:(void (^)(BOOL ok))cb {
    NSString *urlString = [NSString stringWithFormat:@"%s%@",HTTPS_ADDRESS_PB_UL,pubsubserver_secret];
    NSMutableURLRequest * request= [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    NSString *boundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    NSMutableData *postbody = [NSMutableData data];
    [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postbody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@.m4a\"\r\n", filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [postbody appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *data = [[NSData alloc] initWithContentsOfURL:fileURL];
    [postbody appendData:[NSData dataWithData:data]];
    [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:postbody];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        NSString * returnString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"filename is %@",filename);
        NSLog(@"%@", returnString);
        if(data==nil || error) {
            cb(false);
        } else {
            cb(true);
        }
    }];
    
    //NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    return ;
}

-(void)setSounds:(NSArray *)snds {
    //NSLog(@"Someone called login array");
    sounds=snds;
}



@end
