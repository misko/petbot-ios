

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>

#import "VideoViewController.h"
#import "PBViewController.h"
#import "GStreamerBackend.h"
#import "LoginViewController.h"
#import "SoundViewController.h"
#import "SelfieViewController.h"
#import "AppDelegate.h"
#include "tcp_utils.h"
#include "nice_utils.h"
#include "pb.h"

#import "UIColor+PBColor.h"

@interface VideoViewController () {
    GStreamerBackend *gst_backend;
    int media_width;
    int media_height;
    int bb_streamer_id;
    int ice_thread_pipes_to_child[2];
    int ice_thread_pipes_from_child[2];
    IBOutlet UIActivityIndicatorView *activityIndicator;
    AVAudioPlayer *player;
    UIVisualEffectView *blurEffectView;
    pb_nice_io * pbnio;
    NSString * status ;
    bool bye_pressed;
    bool petbot_found;
    int waiting_selfies;
    int seconds;
}
@end

@implementation VideoViewController


-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    NSArray * landscape_constraints = [NSArray arrayWithObjects:_selfieLandScapeVertical,_selfieLandScapeHorizontal, _alertLandScapeVertical,_alertLandScapeHorizontal, nil];
    NSArray * portrait_constraints = [NSArray arrayWithObjects:_selfiePortraitVertical,_selfiePortraitHorizontal,_alertPortraitVertical, _alertPortraitHorizontal, nil];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
         // do whatever
         if (UIInterfaceOrientationIsPortrait(orientation)){
             
             
             //portrait
             [NSLayoutConstraint deactivateConstraints:landscape_constraints];
             [NSLayoutConstraint activateConstraints:portrait_constraints];
         } else {
             
             //landscape
             [NSLayoutConstraint deactivateConstraints:portrait_constraints];
             [NSLayoutConstraint activateConstraints:landscape_constraints];
             //[_selfieLandScapeVertical enable
         }
     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         
     }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if(size.width > size.height) {
        
    } else {
        
    }
}

-(void)playSoundFromURL:(NSString *)url_string {
    
    NSLog(@"PLAY SOUND wtf %@",url_string);
    
    //play sound locally
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    NSURL *mp3URL = [NSURL URLWithString:url_string];
    
    NSData *audioData = [NSData dataWithContentsOfURL:mp3URL];
    NSError* error;
    player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    //player.volume=1;
    //[player setDelegate:self];
    //[player prepareToPlay];
    [player play];
}

- (IBAction)playSound:(id)sender {
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            NSMutableArray * files = [self pbserverLSWithType:@"mp3"];
            
            NSString * sound_fid = [[NSUserDefaults standardUserDefaults] stringForKey:@"alert_sound_fid"];
            bool found = false;
            for (NSArray * ar in files) {
                if ([ar[0] isEqualToString:sound_fid]) {
                    found=true;
                    break;
                }
            }
            if (sound_fid==nil || [sound_fid isEqualToString:@""] || found==false) {
                sound_fid = @"00000000000000000000000000000000"; //default alert sound
            }
            
                //NSMutableArray * file = [files objectAtIndex:0];
                //NSString * filekey = [file objectAtIndex:0];
                NSString * url = [NSString stringWithFormat:@"%s%@/%@",HTTPS_ADDRESS_PB_DL,pubsubserver_secret,sound_fid];
                //tell the petbot to play this!
                NSString * pb_sound_str = [NSString stringWithFormat:@"PLAYURL %@",url];
                
                [self send_msg:[pb_sound_str UTF8String] type:(PBMSG_SOUND | PBMSG_REQUEST | PBMSG_STRING)];
            
            NSString * device_mute_str =  [[NSUserDefaults standardUserDefaults] stringForKey:@"device_mute"];
            if (device_mute_str==nil || [device_mute_str isEqualToString:@""] || [device_mute_str isEqualToString:@"OFF"]) {
                [self playSoundFromURL:url];
            } else {
            }
        }
    );
}

- (IBAction)byePressed:(id)sender {
    NSLog(@"BYE PRESSED");
    bye_pressed=true;
    if (pbs!=nil) {
        free_pbsock(pbs);
        pbs=nil;
        [gst_backend quit];
    }
}


-(void)checkSelfie:(bool)activate {
    @synchronized(self) {
    NSString * selfieurl=nil;
    NSString * rmurl = nil;
    
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s%@", HTTPS_ADDRESS_PB_SELFIE_LAST, pubsubserver_secret]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    //send the request
    NSURLResponse * response;
    NSError * error;
    NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        waiting_selfies=0;
    } else {
        NSDictionary * d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            waiting_selfies=0;
        } else {
            NSNumber *status = d[@"status"];
            if ([status isEqual:@0]) {
                waiting_selfies=0;
            } else if ([status isEqual:@1]) {
                waiting_selfies = [[d objectForKey:@"count"] longValue];
                selfieurl =  d[@"selfie_url"];
                rmurl = d[@"rm_url"];
            } else {
                NSLog(@"Failed to get selfie status");
            }
        }
    }
    
    //run the corresponding event
    if (waiting_selfies>0) {
        if (activate) {
            waiting_selfies--;
            dispatch_async(dispatch_get_main_queue(), ^{
                AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                //[appDelegate showSelfieWithURL:selfieurl RMURL:rmurl from:self];
                [self showSelfieWithURL:selfieurl RMURL:rmurl from:self];
                if (waiting_selfies==0) {
                    [selfie_button setEnabled:true];
                }
            });
        }
    } else {
        if (activate) {
            [self send_msg:"selfie" type:( PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [selfie_button setEnabled:FALSE];
            });
        }
    }
    
    //set the final state as it should
    dispatch_async(dispatch_get_main_queue(), ^{
    if (waiting_selfies>0) {
        [selfie_button setHidden:true];
        [selfie_play_button setHidden:false];
        [selfie_play_button setTitle:[NSString stringWithFormat:@"%d",waiting_selfies] forState:UIControlStateNormal];
    } else {
        [selfie_button setHidden:false];
        [selfie_play_button setHidden:true];
    }
    });
    
    }
}

- (IBAction)selfiePressed:(id)sender {
    //first lets check if there is selfies waiting
    [selfie_button setEnabled:FALSE];
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self checkSelfie:true];
    });
    
}

- (IBAction)cookiePressed:(id)sender {
    [self send_msg:"cookie" type:(PBMSG_COOKIE | PBMSG_REQUEST | PBMSG_STRING)];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

-(void)toLogin {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // code here
        NSLog(@"TO LOGIN...");
        if (pbs!=nil) {
            free_pbsock(pbs);
        }
        [self performSegueWithIdentifier:@"segueToLogin" sender:self];
    });
}

- (IBAction)tapped:(id)sender {
    [self send_msg:"iterate" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
}

- (IBAction)swipeLeft:(id)sender {
    [self send_msg:"adjust_fx -1" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
}

- (IBAction)swipeRight:(id)sender {
    [self send_msg:"adjust_fx 1" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
}

- (IBAction)swipeDown:(id)sender {
    [self send_msg:"adjust_exp -1" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
}

- (IBAction)swipeUp:(id)sender {
    [self send_msg:"adjust_exp 1" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
}

- (IBAction)longPress:(UILongPressGestureRecognizer*)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self send_msg:"hflip" type:(PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING)];
    }
}





-(void) update_fps {
    uint frames_rendered = [gst_backend get_frames_rendered];
    guint64* jitter_stats = [gst_backend get_jitter_stats];
    if (jitter_stats!=NULL) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [fps_label setText:[NSString stringWithFormat:@"F %u, %lu/%lu/%lu, %d",frames_rendered,jitter_stats[0],jitter_stats[1],jitter_stats[2],seconds++]];
    });
    }
    if (pbs!=nil) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       [self update_fps];
                   });
    }
}

-(void) listenForEvents {
    while (true) {
        pbmsg * m = recv_pbmsg(pbs);
        if (m==NULL) {
            if (!bye_pressed) {
                status = @"PetBot connection closed";
            }
            if (pbs!=nil) {
                free_pbsock(pbs);
                pbs=nil;
                [gst_backend quit];
            }
            return;
        }
        
        if ( (m->pbmsg_type ^ (PBMSG_CLIENT | PBMSG_STRING))==0 && strncmp(m->pbmsg,"UPTIME",strlen("UPTIME"))==0) {
            if (petbot_found==false) {
                NSString *msg = [NSString stringWithUTF8String:m->pbmsg];
                NSArray * a = [msg componentsSeparatedByString:@" "];
                if ([a count]>=3) {
                    int uptime = [a[1] intValue];
                    if (uptime>20) {
                        petbot_found=true;
                        //semd ICE request
                        pbmsg * ice_request_m = make_ice_request(ice_thread_pipes_from_child,ice_thread_pipes_to_child);
                        send_pbmsg(pbs, ice_request_m);
                        [self setConnectingText:[NSString stringWithFormat:@"Negotiating with your PetBot..."] ];
                    } else {
                        [self setConnectingText:[NSString stringWithFormat:@"Found your PetBot..."] ];
                    }
                }
            }
        } else if ((m->pbmsg_type ^  (PBMSG_SUCCESS | PBMSG_RESPONSE | PBMSG_ICE | PBMSG_CLIENT | PBMSG_STRING))==0) {
            //[self gstreamerSetUIMessage:@"Negotiating with your PetBot..."];
            if (bb_streamer_id==0) {
                bb_streamer_id = m->pbmsg_from;
                fprintf(stderr,"BBSTREAMER ID %d\n",bb_streamer_id);
                recvd_ice_response(m,pbnio);
                if (pbnio->error!=NULL) {
                    
                    //something went wrong
                    NSString * s = [NSString stringWithFormat:@"ICE NEGOTATION FAILED : %@" ,[ NSString stringWithUTF8String:pbnio->error]];
                    [self send_msg_log:[s UTF8String]];
                    DDLogWarn(@"%@" , s);
                    status = s;
                    
                    if (pbs!=nil) {
                        free_pbsock(pbs);
                        pbs=nil;
                    }
                    [gst_backend quit];
                    return;
                } else {
                    DDLogWarn(@"ICE NEGOTIATION SUCCESS");
                }
                if (pbnio->ice_pair!=NULL) {
                    NSString * s = [NSString stringWithFormat:@"ICE PAIR %s",pbnio->ice_pair];
                    [self send_msg_log:[s UTF8String]];
                    if (debug_mode) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [message_label setText:s];
                        });
                    }
                    DDLogWarn(@"%@",s);
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [gst_backend app_functionPBNIO:pbnio];
                });
                fprintf(stderr,"LAUNCHED APP FUNCTION\n");
            } else {
                NSLog(@"OH OHHH...someone else connected");
                status = @"Someone else connected :(";
                
                if (pbs!=nil) {
                    free_pbsock(pbs);
                    pbs=nil;
                    [gst_backend quit];
                }
                return;
            }
        } else if ((m->pbmsg_type ^  (PBMSG_CLIENT | PBMSG_VIDEO | PBMSG_RESPONSE | PBMSG_STRING | PBMSG_SUCCESS))==0) {
            NSLog(@"ENABLE SELFIE BUTTON!");
            dispatch_async(dispatch_get_main_queue(), ^{
                [selfie_button setEnabled:true];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         10 * NSEC_PER_SEC),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                           ^{
                               [self checkSelfie:false];
                           });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         30 * NSEC_PER_SEC),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                           ^{
                               [self checkSelfie:false];
                           });
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         60 * NSEC_PER_SEC),
                           dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                           ^{
                               [self checkSelfie:false];
                           });
            //dispatch_async(dispatch_get_main_queue(), ^{
             //   [selfie_button setEnabled:TRUE];
            //});
        } else if ((m->pbmsg_type & PBMSG_DISCONNECTED) !=0) {
            if (m->pbmsg_from==bb_streamer_id) {
                PBPRINTF("The other side exited!\n");
                status = @"PetBot disconnected";
                if (pbs!=nil) {
                    free_pbsock(pbs);
                    pbs=nil;
                    [gst_backend quit];
                }
                return;
                //g_main_loop_quit(main_loop);
            } else {
                PBPRINTF("SOMEONE ELSE DISCONNETED %d vs %d\n",bb_streamer_id,m->pbmsg_from);
            }
        } else {
            PBPRINTF("WTF\n");
        }
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (status!=nil && [[segue identifier] isEqualToString:@"segueToLogin"]) {
        LoginViewController * lc = [segue destinationViewController];
        [lc setStatus:status setFlag:FALSE];
        status =nil;
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
    
    if ([[segue identifier] isEqualToString:@"segueToSound"]) {
        SoundViewController * svc = [segue destinationViewController];
        [svc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

-(void) lookForPetBot:(int)attempt {
    if (petbot_found==false) {
        //look for PetBot
        if (attempt==0) {
            [self setConnectingText:[NSString stringWithFormat:@"Looking for your PetBot..."] ];
        } else {
            [self setConnectingText:[NSString stringWithFormat:@"Looking for your PetBot... (x%d)",attempt] ];
        }
        [self send_msg:"UPTIME" type:(PBMSG_STRING)];
        //schedule a retry
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     5 * NSEC_PER_SEC),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                       ^{
                           [self lookForPetBot:attempt+1];
                       });
    }
    
}

-(void) connect:(int)maxRetries {
    DDLogWarn(@"START CONNECT");
    int retries=0;
    while (pbs==NULL && retries<=maxRetries) {
        if (retries>0) {
            sleep(1);
        }
        if (retries==0) {
            [self setConnectingText:[NSString stringWithFormat:@"Connecting to PetBot server..." ]];
        } else {
            [self setConnectingText:[NSString stringWithFormat:@"Connecting to PetBot server... (x%d)", retries+1] ];
        }
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
        retries++;
    }
    if (pbs==NULL) {
        //failed to connect!
        dispatch_async(dispatch_get_main_queue(), ^{
            status = @"Failed to connect to PB server, try again soon";
            [self performSegueWithIdentifier:@"segueToLogin" sender:self];
        });
        return;
    }
    
    
    if (debug_mode) {
        [self update_fps];
    }
    
    DDLogWarn(@"SET STUN");
    set_stun([ns_stun_server UTF8String], [ns_stun_port UTF8String], [ns_stun_username UTF8String], [ns_stun_password UTF8String]);
    
    //Ask for version first!
    [self lookForPetBot:0];
    
    //setup basic ICE
    int ret = pipe(ice_thread_pipes_to_child);
    assert(ret==0);
    ret= pipe(ice_thread_pipes_from_child);
    assert(ret==0);
    
    pbnio =  new_pbnio();
    pbnio->pipe_to_child=ice_thread_pipes_to_child[1];
    pbnio->pipe_to_parent=ice_thread_pipes_from_child[1];
    pbnio->pipe_from_parent=ice_thread_pipes_to_child[0];
    pbnio->pipe_from_child=ice_thread_pipes_from_child[0];
    pbnio->controlling=0;
    
    init_ice(pbnio);
    if (pbnio->error!=NULL) {
        //something went wrong
        NSString * s = [NSString stringWithFormat:@"ICE INITIALIZE FAILED : %@" ,[ NSString stringWithUTF8String:pbnio->error]];
        DDLogWarn(@"%@" , s);
        status = s;
        
        if (pbs!=nil) {
            free_pbsock(pbs);
            pbs=nil;
        }
        [gst_backend quit];
        return;
    } else {
        DDLogWarn(@"ICE INITIALIZE SUCCESS");
    }
    //start up the listener
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    
    
    
}

-(void)makeAndSendICE {
    //semd ICE request
    pbmsg * ice_request_m = make_ice_request(ice_thread_pipes_from_child,ice_thread_pipes_to_child);
    send_pbmsg(pbs, ice_request_m);
}

- (IBAction)abort_pressed:(id)sender {
    [self setConnectingText:@"Aborting!"];
    if (pbs!=nil) {
        free_pbsock(pbs);
        pbs=nil;
        [gst_backend quit];
    }
}

-(void)waitSFSPCA {
    //make the url request
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s", HTTPS_ADDRESS_PB_WAIT]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    //send the request
    NSURLResponse * response;
    NSError * error;
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
            if (![status isEqual:@1]) {
                NSLog(@"SERVER QUERY FAILED?");
            } else {
                NSDictionary * pet =  d[@"pet"];
                
                NSData *data = [NSData dataWithContentsOfURL : [NSURL URLWithString:pet[@"img"]]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Your code to run on the main queue/thread
                    [pet_story setText:pet[@"story"]];
                    [pet_name setText:[NSString stringWithFormat:@"Location: San Francisco, Name: %@", pet[@"name"]]];
                    [pet_img setImage:[UIImage imageWithData: data]];
                    pet_img.layer.cornerRadius=4.0f;
                    pet_img.layer.masksToBounds = YES;
                });
            }
        }
    }
}





/*
 * Methods from UIViewController
 */

-(void)setConnectingText:(NSString *)s {
    if ([NSThread isMainThread]) {
        [connecting_message setText:s];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [connecting_message setText:s];
        });
    }
}


-(void)showSelfieWithURL:(NSString *)selfieURL RMURL:(NSString*)rmURL from:(UIViewController *)from_vc {
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SelfieViewController *VC = [storyboard instantiateViewControllerWithIdentifier:@"SelfieView"];
    VC.selfieRMURL=rmURL;
    VC.selfieURL=selfieURL;
    VC.vvc = self;
    VC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    //[self.window.rootViewController presentViewController: VC animated:YES completion:nil];
    //[from_vc presentViewController: VC animated:YES completion:nil];
    [from_vc presentViewController: VC animated:YES completion:^{
        NSLog(@"DONE SELFIED CONTROL!");
    }];
}

-(void)viewDidAppear:(BOOL)animated {
    NSLog(@"APPEARED!");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (debug_mode==FALSE) {
        [message_label setHidden:TRUE];
        [fps_label setHidden:TRUE];
        seconds=0;
    }
    petbot_found=false;
    bye_pressed=false;
    [self setConnectingText:@"Connecting..."];
    
    [message_label setText:@""];
    [fps_label setText:@""];
    [pet_name setText:@""];
    [pet_story setText:@""];
    
    [selfie_play_button setBackgroundColor:[UIColor PBRed]];
    
    waiting_selfies=0;
    
    
    //do blur, and go to black for old style
    if (!UIAccessibilityIsReduceTransparencyEnabled()) {
        main_view.backgroundColor = [UIColor clearColor];
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = main_view.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [main_view addSubview:blurEffectView];
    } else {
        main_view.backgroundColor = [UIColor blackColor];
    }
    
    [self setupLogin];
    
    /* Make these constant for now, later tutorials will change them */
    media_width = 640;
    media_height = 480;
    bb_streamer_id=0;
    
    //set up gstreamer
    gst_backend = [[GStreamerBackend alloc] init:self videoView:video_view vvc:self];
    
    /* Start the bus monitoring task */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self connect:3];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self waitSFSPCA];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //play sound locally
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        NSString * mp3URL = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
        NSData *audioData = [NSData dataWithContentsOfFile:mp3URL];
        //NSData *audioData = [NSData dataWithContentsOfURL:mp3URL];
        NSError* error;
        player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
        [player play];
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self checkSelfie:false];
    });
    
}

- (IBAction)showMenu:(id)sender {
            [self performSegueWithIdentifier:@"segueToSound" sender:self];
}


- (IBAction)unwindToStream:(UIStoryboardSegue *)segue {
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewDidLayoutSubviews
{
    CGFloat view_width = video_container_view.bounds.size.width;
    CGFloat view_height = video_container_view.bounds.size.height;

    CGFloat correct_height = view_width * media_height / media_width;
    CGFloat correct_width = view_height * media_width / media_height;

    if (correct_height < view_height) {
        video_height_constraint.constant = correct_height;
        video_width_constraint.constant = view_width;
    } else {
        video_width_constraint.constant = correct_width;
        video_height_constraint.constant = view_height;
    }
}

/*
 * Methods from GstreamerBackendDelegate
 */

-(void) gstreamerInitialized
{
    //dispatch_async(dispatch_get_main_queue(), ^{
    //    message_label.text = @"Ready";
    //});
}

-(void) gstreamerSetUIMessage:(NSString *)message
{
    //dispatch_async(dispatch_get_main_queue(), ^{
    //    message_label.text = message;
    //});
}


-(void) gstreamerHideLoadView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [pet_view setHidden:true];
        [blurEffectView setHidden:true];
    });
}

-(void) gstreamerShowLoadView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [pet_view setHidden:false];
        [blurEffectView setHidden:false];
    });
}



@end
