//
//  PBViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-10-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "tcp_utils.h"

#import <CocoaLumberjack/CocoaLumberjack.h>
static const DDLogLevel ddLogLevel = DDLogLevelWarning;

@interface PBViewController : UIViewController {
    NSArray * sounds;
    NSDictionary * loginArray;
    NSDictionary * loginInfo;
    NSDictionary * turnInfo;
    NSString * pubsubserver_secret;
    NSString * pubsubserver_server;
    NSString * pubsubserver_username;
    NSString * pubsubserver_protocol;
    
    NSString * ns_stun_server;
    NSString * ns_stun_port;
    NSString * ns_stun_username;
    NSString * ns_stun_password;
    
    int pubsubserver_port;
    pbsock * pbs;
    bool debug_mode;
}
-(void)setupLogin;
-(void)toastStatus:(bool)status Message:(NSString*)msg;
-(void)toastPinColor:(UIColor*)c Message:(NSString*)msg;
-(void)setLoginArray:(NSDictionary *)dictionary;
-(void)setDebug:(bool)d;
-(void)setSounds:(NSArray *)snds;
-(bool)updatesAllowed ;
-(NSMutableDictionary *)parseConfig:(NSString*)str;

//PBS ops
-(void)send_msg:(const char*)msg type:(int)ty;
-(void)send_msg_log:(const char*)msg;

//FILE OPS
-(NSMutableArray*)pbserverLSWithType:(NSString *)ty;
-(BOOL)removeFileFID:(NSString *)fid;

-(NSString *)secondsToStr:(float )sec;
-(void) uploadFile:(NSURL *)fileURL withFilename:(NSString *)filename withCallBack:(void (^)(BOOL ok))cb;
@end
