//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "SoundViewController.h"
#include "tcp_utils.h"
#include "nice_utils.h"
#include "pb.h"

@interface SoundViewController () {
}
@property (strong, nonatomic) IBOutlet UIButton *doneButton;

@end

@implementation SoundViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLogin];
    [self connect:3];
}
/*
 
 dispatch_async(dispatch_get_main_queue(), ^{
 // code here
 /*NSLog(@"TO LOGIN...");
 if (pbs!=nil) {
 free_pbsock(pbs);
 }
[self performSegueWithIdentifier:@"unwindToStream" sender:self];
});*/

//SUCCESS,RESPONSE,CONFIG_GET,STRING

-(void) listenForEvents {
    pbmsg * m = recv_pbmsg(pbs);
    if (m==NULL) {
        NSLog(@"CONNECTION CLOSED UNEXPECTEDLY");
        if (pbs!=nil) {
            free_pbsock(pbs);
            pbs=nil;
        }
        return;
    }
    if ((m->pbmsg_type ^  (PBMSG_SUCCESS | PBMSG_RESPONSE | PBMSG_CONFIG_GET | PBMSG_STRING))==0) {
        [self parseConfig:[NSString stringWithUTF8String:m->pbmsg]];
    } else {
        fprintf(stderr,"WTF\n");
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
}

- (IBAction)touchDone:(id)sender {
    [_doneButton setEnabled:false];
    if (pbs!=NULL) {
        free_pbsock(pbs);
        pbs=NULL;
    }
    [self performSegueWithIdentifier:@"segueToStream" sender:self];
}

-(void) connect:(int)retries {
    fprintf(stderr, "pbstate: Connecting...");
#ifdef PBSSL
    SSL_CTX* ctx;
    OpenSSL_add_ssl_algorithms();
    SSL_load_error_strings();
    ctx = SSL_CTX_new (SSLv23_client_method());
    NSLog(@"Connecting to server ... %@ %s %@",pubsubserver_server,[[loginInfo objectForKey:@"server"] UTF8String],[loginInfo objectForKey:@"server"]);
    pbs = connect_to_server_with_key([pubsubserver_server UTF8String],pubsubserver_port,ctx,[pubsubserver_secret UTF8String]);
#else
    pbs = connect_to_server_with_key(pbhost,port,key);
#endif
    
    if (pbs==NULL) {
        if (retries >=0 ) {
            NSLog(@"RETRY RETRY");
            sleep(1);
            return [self connect:retries-1];
        }
        //TODO error handling!!!!
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToStream" sender:self];
            
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    pbmsg * m = new_pbmsg_from_str_wtype("all", PBMSG_CONFIG_GET | PBMSG_STRING | PBMSG_REQUEST);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
    
    
    
    
}

@end
