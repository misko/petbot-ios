//
//  PBViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-10-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "tcp_utils.h"

@interface PBViewController : UIViewController {
    
    NSDictionary * loginArray;
    NSDictionary * loginInfo;
    NSString * pubsubserver_secret;
    NSString * pubsubserver_server;
    NSString * pubsubserver_username;
    NSString * pubsubserver_protocol;
    int pubsubserver_port;
    pbsock * pbs;
}
-(void)setupLogin;
-(void)toastStatus:(bool)status Message:(NSString*)msg;
-(void)toastPinColor:(UIColor*)c Message:(NSString*)msg;
-(void)setLoginArray:(NSDictionary *)dictionary;
-(NSDictionary *)parseConfig:(NSString*)str;
@end
