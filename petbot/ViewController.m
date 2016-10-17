

#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import "GStreamerBackend.h"


#include "tcp_utils.h"
#include "nice_utils.h"
#include "pb.h"

@interface ViewController () {
    GStreamerBackend *gst_backend;
    int media_width;
    int media_height;
    NSDictionary * loginArray;
    NSDictionary * loginInfo;
    const char * pubsubserver_secret;
    const char * pubsubserver_server;
    const char * pubsubserver_username;
    const char * pubsubserver_protocol;
    int bb_streamer_id;
    int pubsubserver_port;
    pbsock * pbs;
    NSString * petbot_state; //connecting, ice_request, ice_negotiate, streaming, logoff
    int ice_thread_pipes_to_child[2];
    int ice_thread_pipes_from_child[2];
    
    AVAudioPlayer *player;
}
@end

@implementation ViewController

-(NSMutableArray*)pbserverLSWithType:(NSString *)ty {
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"mp3", @"file_type", @"1", @"start_idx", @"10", @"end_idx",nil];
    
    //make the json payload
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:0 error:&error];
    
    //make the url request
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%s%s", HTTPS_ADDRESS_PB_LS, pubsubserver_secret]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    //send the request
    NSURLResponse * response;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
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
                int start_idx = [d[@"start_idx"] intValue];
                int end_idx = [d[@"end_idx"] intValue];
                NSMutableArray * files =  d[@"files"];
                NSDictionary * f1 = [files objectAtIndex:0];
                NSLog(@"HERE ARE SOEM KEYS");
                NSLog(@"HERE ARE SOEM KEYS %@",d[@"start_idx"]);
                for (NSArray *key in d){
                    //Do something
                    NSLog(@"Array: %@", key);
                }
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
            NSString * url = [NSString stringWithFormat:@"%s%s/%@",HTTPS_ADDRESS_PB_DL,pubsubserver_secret,filekey];
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
                NSString * url = [NSString stringWithFormat:@"%s%s/%@",HTTPS_ADDRESS_PB_DL,pubsubserver_secret,filekey];
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
    [gst_backend quit];
}

- (IBAction)selfiePressed:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("selfie", PBMSG_VIDEO | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

- (IBAction)cookiePressed:(id)sender {
    pbmsg * m = new_pbmsg_from_str_wtype("cookie", PBMSG_COOKIE | PBMSG_REQUEST | PBMSG_STRING);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
}

-(void)toLogin {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // code here
        free_pbsock(pbs);
        [self performSegueWithIdentifier:@"segueToLogin" sender:self];
    });
}



-(void) listenForEvents {
    pbmsg * m = recv_pbmsg(pbs);
    if (m==NULL) {
        fprintf(stderr,"CONNECTION CLOSED UNEXPECTEDLY");
        [gst_backend quit];
        return;
    }
    if ((m->pbmsg_type ^  (PBMSG_SUCCESS | PBMSG_RESPONSE | PBMSG_ICE | PBMSG_CLIENT | PBMSG_STRING))==0) {
        fprintf(stderr,"GOT A ICE RESPONSE BACK!\n");
        [self ice_negotiate:m];
    } else if ((m->pbmsg_type & PBMSG_DISCONNECTED) !=0) {
        if (m->pbmsg_from==bb_streamer_id) {
            fprintf(stderr,"The other side exited!\n");
            [gst_backend quit];
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

-(void) connect {
    fprintf(stderr, "pbstate: Connecting...");
#ifdef PBSSL
    SSL_CTX* ctx;
    OpenSSL_add_ssl_algorithms();
    SSL_load_error_strings();
    ctx = SSL_CTX_new (SSLv23_client_method());
    pbs = connect_to_server_with_key(pubsubserver_server,pubsubserver_port,ctx,pubsubserver_secret);
#else
    pbs = connect_to_server_with_key(pbhost,port,key);
#endif
    if (pbs==NULL) {
        //TODO error handling!!!!
        exit(1);
    }
    
    //start up the listener
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    int ret = pipe(ice_thread_pipes_to_child);
    assert(ret==0);
    ret= pipe(ice_thread_pipes_from_child);
    assert(ret==0);
    start_nice_thread(0,ice_thread_pipes_from_child,ice_thread_pipes_to_child);
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
    recvd_ice_response(m,ice_thread_pipes_from_child,ice_thread_pipes_to_child);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [gst_backend app_function];
    });
    fprintf(stderr,"LAUNCHED APP FUNCTION\n");
}


/*
 * Methods from UIViewController
 */

-(void)setLoginArray:(NSDictionary *)dictionary {
    NSLog(@"Someone called login array");
    loginArray = dictionary;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self->loginInfo=[loginArray objectForKey:@"pubsubserver"];
    
    /* Make these constant for now, later tutorials will change them */
    media_width = 640;
    media_height = 480;
    petbot_state = @"connecting";
    //TODO check for errors here?
    //self->loginInfo=loginInfo;
    pubsubserver_port = [[self->loginInfo objectForKey:@"port"] intValue];
    pubsubserver_secret = [[self->loginInfo objectForKey:@"secret"] UTF8String];
    pubsubserver_server = [[self->loginInfo objectForKey:@"server"] UTF8String];
    pubsubserver_username = [[self->loginInfo objectForKey:@"username"] UTF8String];
    bb_streamer_id=0;
    
    
    //[self soundList];
    
    fprintf(stderr,"MAKING new connection.... \n");
    
    gst_backend = [[GStreamerBackend alloc] init:self videoView:video_view serverInfo:[loginArray objectForKey:@"pubsubserver"] vc:self];
    /* Start the bus monitoring task */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self connect];
    });
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



@end
