

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>

#import "VideoViewController.h"
#import "PBViewController.h"
#import "GStreamerBackend.h"
#import "LoginViewController.h"
#import "SoundViewController.h"
#import "AppDelegate.h"
#include "tcp_utils.h"
#include "nice_utils.h"
#include "pb.h"

@interface VideoViewController () {
    GStreamerBackend *gst_backend;
    int media_width;
    int media_height;
    int bb_streamer_id;
    NSString * petbot_state; //connecting, ice_request, ice_negotiate, streaming, logoff
    int ice_thread_pipes_to_child[2];
    int ice_thread_pipes_from_child[2];
    IBOutlet UIActivityIndicatorView *activityIndicator;
    AVAudioPlayer *player;
    UIVisualEffectView *blurEffectView;
    pb_nice_io * pbnio;
    NSString * status ;
}
@end

@implementation VideoViewController

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
            } else {
                NSMutableArray * files =  d[@"files"];
                return files;
            }
        }
    }
    return nil;
}

-(void)soundList {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        // the slow stuff to be done in the background
        NSMutableArray * files = [self pbserverLSWithType:@"mp3"];
        for (NSMutableArray * file in files) {
            NSString * filename = [file objectAtIndex:1];
            NSString * filekey = [file objectAtIndex:0];
            NSLog(@"FILENAME %@",filename);
            NSString * url = [NSString stringWithFormat:@"%s%@/%@",HTTPS_ADDRESS_PB_DL,pubsubserver_secret,filekey];
            NSLog(@"PLAY URL %@",url);
            [self playSoundFromURL:url];
            //NSLog(@"FILE %@ has %@\n",[file objectAtIndex:0] , [file objectAtIndex:1]);
        }
    });
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
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            NSMutableArray * files = [self pbserverLSWithType:@"mp3"];
            if ([files count]>0) {
                NSMutableArray * file = [files objectAtIndex:0];
                NSString * filekey = [file objectAtIndex:0];
                NSString * url = [NSString stringWithFormat:@"%s%@/%@",HTTPS_ADDRESS_PB_DL,pubsubserver_secret,filekey];
                //tell the petbot to play this!
                NSString * pb_sound_str = [NSString stringWithFormat:@"PLAYURL %@",url];
                pbmsg * m = new_pbmsg_from_str_wtype([pb_sound_str UTF8String], PBMSG_SOUND | PBMSG_REQUEST | PBMSG_STRING);
                send_pbmsg(pbs, m);
                free_pbmsg(m);
                [self playSoundFromURL:url];
            }
        }
    );
}

- (IBAction)byePressed:(id)sender {
    NSLog(@"BYE PRESSED");
    if (pbs!=nil) {
        free_pbsock(pbs);
        pbs=nil;
        [gst_backend quit];
    }
}



- (IBAction)selfiePressed:(id)sender {
    //first lets check if there is selfies waiting
    [selfie_button setEnabled:FALSE];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s%@", HTTPS_ADDRESS_PB_SELFIE_LAST, pubsubserver_secret]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        
        //send the request
        NSURLResponse * response;
        NSError * error;
        NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [selfie_button setEnabled:TRUE];
            });
        } else {
            NSDictionary * d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            if (error) {
                NSLog(@"Error,%@", [error localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [selfie_button setEnabled:TRUE];
                });
            } else {
                NSNumber *status = d[@"status"];
                if ([status isEqual:@0]) {
                    //lets get a new selfie!
                    //dont enable button until selfie is done????
                    pbmsg * m = new_pbmsg_from_str_wtype("selfie", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
                    send_pbmsg(pbs, m);
                    free_pbmsg(m);
                } else {
                    long selfies = [[d objectForKey:@"count"] longValue];
                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:(selfies-1)];
                    NSString * selfieurl =  d[@"selfie_url"];
                    NSString * rmurl = d[@"rm_url"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
                        [appDelegate showSelfieWithURL:selfieurl RMURL:rmurl from:self];
                        [selfie_button setEnabled:TRUE];
                    });
                    
                }
            }
        }
    });
    
}

- (IBAction)cookiePressed:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("cookie", PBMSG_COOKIE | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
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
    pbmsg * m = new_pbmsg_from_str_wtype("iterate", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)swipeLeft:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("adjust_fx -1", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)swipeRight:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("adjust_fx 1", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)swipeDown:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("adjust_exp -1", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)swipeUp:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("adjust_exp 1", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)longPress:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("iterate 1", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}



-(void) listenForEvents {
    pbmsg * m = recv_pbmsg(pbs);
    if (m==NULL) {
        NSLog(@"CONNECTION CLOSED UNEXPECTEDLY");
        if (pbs!=nil) {
            free_pbsock(pbs);
            pbs=nil;
            [gst_backend quit];
        }
        return;
    }
    if ((m->pbmsg_type ^  (PBMSG_SUCCESS | PBMSG_RESPONSE | PBMSG_ICE | PBMSG_CLIENT | PBMSG_STRING))==0) {
        
        [self gstreamerSetUIMessage:@"Negotiating with your PetBot..."];
        fprintf(stderr,"GOT A ICE RESPONSE BACK!\n");
        [self ice_negotiate:m];
    } else if ((m->pbmsg_type ^  (PBMSG_CLIENT | PBMSG_VIDEO | PBMSG_RESPONSE | PBMSG_STRING | PBMSG_SUCCESS))==0) {
        NSLog(@"ENABLE SELFIE BUTTON!");
        dispatch_async(dispatch_get_main_queue(), ^{
            [selfie_button setEnabled:TRUE];
        });
    } else if ((m->pbmsg_type & PBMSG_DISCONNECTED) !=0) {
        if (m->pbmsg_from==bb_streamer_id) {
            fprintf(stderr,"The other side exited!\n");
            if (pbs!=nil) {
                free_pbsock(pbs);
                pbs=nil;
                [gst_backend quit];
            }
            return;
            //g_main_loop_quit(main_loop);
        } else {
            fprintf(stderr,"SOMEONE ELSE DISCONNETED %d vs %d\n",bb_streamer_id,m->pbmsg_from);
        }
    } else {
        fprintf(stderr,"WTF\n");
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (status!=nil && [[segue identifier] isEqualToString:@"segueToLogin"]) {
        LoginViewController * lc = [segue destinationViewController];
        [lc setStatus:status];
        status =nil;
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
    
    if ([[segue identifier] isEqualToString:@"segueToSound"]) {
        SoundViewController * svc = [segue destinationViewController];
        [svc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
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
            status = @"Failed to connect to PB server, try again soon";
            [self performSegueWithIdentifier:@"segueToLogin" sender:self];
            
        });
        return;
    }
    
    //start up the listener
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    int ret = pipe(ice_thread_pipes_to_child);
    assert(ret==0);
    ret= pipe(ice_thread_pipes_from_child);
    assert(ret==0);
    //start_nice_thread(0,ice_thread_pipes_from_child,ice_thread_pipes_to_child);
    
    //int * params = (int*)x;
    //get our string from the child thread
    pbnio =  new_pbnio();
    //init_ice(1, from_child[1], to_child[0]);
    pbnio->pipe_to_child=ice_thread_pipes_to_child[1];
    pbnio->pipe_to_parent=ice_thread_pipes_from_child[1];
    pbnio->pipe_from_parent=ice_thread_pipes_to_child[0];
    pbnio->pipe_from_child=ice_thread_pipes_from_child[0];
    pbnio->controlling=0;
    init_ice(pbnio);
    //pbnio->other_nice = m->pbmsg;
    
    //int to_parent = ice_thread_pipes_from_child[1];
    //int from_parent = ice_thread_pipes_to_child[0];
    //init_ice(controlling, to_parent, from_parent);
    //start_nice_client(pbs);
    
    petbot_state = @"pbstate: ice_request";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self ice_request];
    });
}

-(void) ice_request {
    pbmsg * ice_request_m = make_ice_request(ice_thread_pipes_from_child,ice_thread_pipes_to_child);
    fprintf(stderr,"make the ice request!\n");
    send_pbmsg(pbs, ice_request_m);
    fprintf(stderr,"made the ice request\n");
}

-(void) ice_negotiate:(pbmsg *)m {
    bb_streamer_id = m->pbmsg_from;
    fprintf(stderr,"BBSTREAMER ID %d\n",bb_streamer_id);
    //recvd_ice_response(m,ice_thread_pipes_from_child,ice_thread_pipes_to_child);
    recvd_ice_response(m,pbnio);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [gst_backend app_functionPBNIO:pbnio];
    });
    fprintf(stderr,"LAUNCHED APP FUNCTION\n");
}
- (IBAction)abort_pressed:(id)sender {
    NSLog(@"ABORT PRESSED");
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

        NSLog(@"WAIT SFSPCA %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
        NSDictionary * d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
        } else {
            NSNumber *status = d[@"status"];
            if ([status isEqual:@0]) {
                NSLog(@"SERVER QUERY FAILED?");
            } else {
                NSDictionary * pet =  d[@"pet"];
                
                
                
                NSLog(@"STORY IS %@",pet[@"story"]);
                NSData *data = [NSData dataWithContentsOfURL : [NSURL URLWithString:pet[@"img"]]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [pet_story setText:@"WTF"];
                    // Your code to run on the main queue/thread
                    [pet_story setText:pet[@"story"]];
                    [pet_name setText:[NSString stringWithFormat:@"Location: San Francisco, Name: %@", pet[@"name"]]];
                    [pet_img setImage:[UIImage imageWithData: data]];
                    pet_img.layer.cornerRadius=4.0f;
                    pet_img.layer.masksToBounds = YES;
                });
                for (NSArray *aDay in pet){
                    //Do something
                    NSLog(@"P Array: %@", aDay);
                }
            }
        }
    }
}


/*
 * Methods from UIViewController
 */


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [pet_name setText:@""];
    [pet_story setText:@""];
    if (!UIAccessibilityIsReduceTransparencyEnabled()) {
        main_view.backgroundColor = [UIColor clearColor];
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        //UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
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
    petbot_state = @"connecting";
    bb_streamer_id=0;
    
    
    //[self soundList];
    [self gstreamerSetUIMessage:@"Trying to connect to PetBot..."];
    //activityIndicator.transform = CGAffineTransformMakeScale(2, 2);
    
    
    gst_backend = [[GStreamerBackend alloc] init:self videoView:video_view serverInfo:[loginArray objectForKey:@"pubsubserver"] vvc:self];
    /* Start the bus monitoring task */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self connect:3];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self waitSFSPCA];
    });
    
    //play sound locally
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    NSString * mp3URL = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
    NSData *audioData = [NSData dataWithContentsOfFile:mp3URL];
    //NSData *audioData = [NSData dataWithContentsOfURL:mp3URL];
    NSError* error;
    player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    [player play];
}

- (IBAction)longPressSound:(UILongPressGestureRecognizer*)sender {
     if (sender.state == UIGestureRecognizerStateBegan) {
            [self performSegueWithIdentifier:@"segueToSound" sender:self];
     }
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
    dispatch_async(dispatch_get_main_queue(), ^{
        message_label.text = @"Ready";
    });
}

-(void) gstreamerSetUIMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        message_label.text = message;
    });
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
