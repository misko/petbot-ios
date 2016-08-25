#import "ViewController.h"
#import "GStreamerBackend.h"


#include "tcp_utils.h"
#include "nice.h"

@interface ViewController () {
    GStreamerBackend *gst_backend;
    int media_width;
    int media_height;
    NSDictionary * loginArray;
    pbsock * pbs ;
}
- (IBAction)cookiePressed:(id)sender;
    
@end

@implementation ViewController
-(void)toLogin {
    dispatch_async(dispatch_get_main_queue(), ^{
        // code here
        [self performSegueWithIdentifier:@"segueToLogin" sender:self];
    });
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
    
    
    
    /* Make these constant for now, later tutorials will change them */
    media_width = 640;
    media_height = 480;

    gst_backend = [[GStreamerBackend alloc] init:self videoView:video_view serverInfo:[loginArray objectForKey:@"pubsubserver"] vc:self];
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



- (IBAction)cookiePressed:(id)sender {
}
@end
