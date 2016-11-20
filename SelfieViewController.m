//
//  SelfieViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-28.
//  Copyright © 2016 PetBot. All rights reserved.
//


#include "SelfieViewController.h"
#include "PBHollowButton.h"

#import <CRToast/CRToast.h>

@import AVFoundation;
@import AVKit;

@interface SelfieViewController () {
    AVPlayerViewController *playerViewController;
    AVPlayerLayer *avpl;
    AVPlayer * player ;
    IBOutlet UIView *subview;
    IBOutlet PBHollowButton *saveButton;
    IBOutlet PBHollowButton *deleteButton;
    IBOutlet UIActivityIndicatorView *activityIndicator;
    NSURL * local_url;
    NSURL * remote_url;
}



@end

@implementation SelfieViewController


- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

-(void)viewDidAppear:(BOOL)animated {
    NSLog(@"SELFIE VIEW APPEAERD");
    [player play];
}

-(void)shareVideoWithURL:(NSURL *)url {
    //urlToShare = [NSURL URLWithString:urlToDownload];
    NSArray* dataToShare = @[@"HERE IS A SELFIE!", url];
    UIActivityViewController* activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:dataToShare
                                      applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypePrint,UIActivityTypeCopyToPasteboard,UIActivityTypeAssignToContact];
    
    activityViewController.completionHandler = ^(NSString *activityType, BOOL completed) {
        if (completed) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    };
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

-(void)getURL:(NSURL*) url {
NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
[request setURL:url];
[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:nil];
}

-(void)downloadVideoWithURL:(NSURL *)url rmURL:(NSURL*)rmURL {
    //download the file in a seperate thread.
    remote_url = url;
    NSLog(@"DOWNLOAD %@",url);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Downloading Started");
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if ( urlData ) {
            NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString  *documentsDirectory = [paths objectAtIndex:0];
            
            NSString *local_path = [documentsDirectory stringByAppendingPathComponent:@"selfie.mov"];
            
            local_url = [NSURL fileURLWithPath:local_path isDirectory:NO];
            NSError *error;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL success = [fileManager removeItemAtPath:local_path error:&error];
            
            //saving is done on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [urlData writeToURL:local_url atomically:YES];
                NSLog(@"File Saved !");
                
                [saveButton setEnabled:TRUE];
                [deleteButton setEnabled:TRUE];
                [activityIndicator setHidden:TRUE];
                
                [self startPlayerWithURL:local_url];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
            });
        }
        
        //test with the broken selfie first
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getURL:rmURL];
        });
        
    });
}

/*- (void)sendVideo {
    
    //- (IBAction) shareVideo {
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //NSString *documentsDirectory = [paths objectAtIndex:0];
    //NSString *URL = [documentsDirectory stringByAppendingPathComponent:demoName];
    [self downloadVideoWithURL:[NSURL URLWithString:@"https://petbot.ca:5000/static/selfie.mov"]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *URL = [documentsDirectory stringByAppendingPathComponent:@"selfie.mov"];
    
    NSString* someText = @"selfie.mov";
    NSURL *urlToShare = [NSURL fileURLWithPath:URL isDirectory:NO];
    NSArray* dataToShare = @[someText, urlToShare];
    
    UIActivityViewController* activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:dataToShare
                                      applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypePrint,UIActivityTypeCopyToPasteboard,UIActivityTypeAssignToContact];
    
    activityViewController.completionHandler = ^(NSString *activityType, BOOL completed) {
        //if (completed) {
        [self dismissViewControllerAnimated:YES completion:nil];
        //}
    };
    
    [self presentViewController:activityViewController animated:YES completion:nil];
    //}
}*/


-(void)startPlayerWithURL:(NSURL*)url {
    AVURLAsset *asset = [AVURLAsset assetWithURL: url];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset: asset];
    
    
    player = [[AVPlayer alloc] initWithPlayerItem: item];
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[player currentItem]];
    playerViewController.player = player;
    playerViewController.showsPlaybackControls = YES;
    
    //[playerViewController.view setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width)];
    //[playerViewController.view setFrame:[_videoview frame]];
    avpl = [AVPlayerLayer playerLayerWithPlayer:player];
    
    [avpl setFrame:self.videoview.bounds];
    avpl.videoGravity = AVLayerVideoGravityResizeAspect;
    //avpl.videoGravity = AVLayerVideoGravityResizeAspectFill;
    //CALayer *superlayer = self.videoview.layer;
    //[superlayer addSublayer:avpl];
    [_videoview.layer addSublayer:avpl];
    [_videoview setPlayerLayer:avpl];
    
    //avpl.frame = self.videoview.frame;
    
    //[self.videoview.layer addSublayer: avpl];
    //[playerViewController.view setFrame:[_videoview bounds]];
    //playerViewController.view.layer.masksToBounds=TRUE;
    
    
    
    //[self.view addSubview:playerViewController.view];
    
    [player play];
}


-(void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor clearColor]];
    [subview setBackgroundColor:[UIColor clearColor]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    [blurEffectView setFrame:self.view.bounds];
    //[self.view addSubview:blurEffectView];
    [self.view insertSubview:blurEffectView atIndex:0];
    

    
    [self downloadVideoWithURL:[NSURL URLWithString:_selfieURL] rmURL:[NSURL URLWithString:_selfieRMURL]];
    /*
    playerViewController = [[AVPlayerViewController alloc] init];
    NSURL *url = [NSURL URLWithString:@"https://petbot.ca:5000/static/selfie.mov"];
    
    //https://petbot.ca:5000/static/big_buck_bunny.mp4
    //NSURL *url = [NSURL URLWithString:@"https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"];
    //NSURL *url = [NSURL URLWithString:@"http://techslides.com/demos/sample- videos/small.mp4"];
     */
    


}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}


- (IBAction)savePressed:(id)sender {
    [self shareVideoWithURL:local_url];
}


- (IBAction)deletePressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    NSLog(@"did become active notification");
    [player play];
}

- (void)appWillEnterForeground:(NSNotification *)notification {
    NSLog(@"will enter foreground notification");
}

@end
