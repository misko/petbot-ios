//
//  LoginViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import <CRToast/CRToast.h>



#import "UIColor+PBColor.h"
#import "LoginViewController.h"
#import "SelfieViewController.h"
#import "VideoViewController.h"
#import "pb.h"

@import AVFoundation;
@import AVKit;

//http://stackoverflow.com/questions/37886600/ios-10-doesnt-print-nslogs - no NSLOG?

@interface LoginViewController () {
    IBOutlet UILabel *status_label;
    NSString * status ;
    AVPlayerViewController *playerViewController;
}
@end

@implementation LoginViewController


-(void)viewDidAppear:(BOOL)animated {
    //[super viewDidAppear:<#animated#>];
    if (status!=nil) {
        [self toastStatus:false Message:status];
        status=nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
 
    
    playerViewController = [[AVPlayerViewController alloc] init];


    
    
    NSString * username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    NSString * password = [[NSUserDefaults standardUserDefaults] stringForKey:@"password"];
    if (username!=nil){
        [_username_field setText:username];
    }
    if (password!=nil) {
        [_password_field setText:password];
    }
    
    [status_label setText:@""];
    [status_label setTextColor:[UIColor PBRed]];
    
    
    [_username_field colorBlue];
    [_password_field colorBlue];
    //[[UIButton appearance] setBackgroundColor:[UIColor PBBlue]];
    //[self toastStatus:true message:@"Hello there"];
    

    // Do any additional setup after loading the view.

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"streamSegue"]) {
        VideoViewController * vvc = [segue destinationViewController];
        [vvc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

-(void)DownloadVideo {
    //download the file in a seperate thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Downloading Started");
        NSString *urlToDownload = @"https://petbot.ca:5000/static/selfie.mov";
        NSURL  *url = [NSURL URLWithString:urlToDownload];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if ( urlData )
        {
            NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString  *documentsDirectory = [paths objectAtIndex:0];
            
            NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory,@"selfie.mov"];
            
            //saving is done on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [urlData writeToFile:filePath atomically:YES];
                NSLog(@"File Saved !");
            });
        }
        
    });
}

- (IBAction)loginPressed:(id)sender {
    [_login_button setEnabled:FALSE];
    //return;
    //TODO should be ASYNC!!
    
    //build an info object and convert to json
    NSString *uniqueIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceToken"];
    if (deviceToken==nil) {
        deviceToken=uniqueIdentifier;
    }
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:_username_field.text, @"username", _password_field.text, @"password",  deviceToken, @"deviceID",nil];
    
    //convert object to data
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:0 error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    //NSString * url = [NSString stringWithFormat:@"%s", HTTPS_ADDRESS_QRCODE_JSON];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", HTTPS_ADDRESS_AUTH]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // print json:
    NSLog(@"JSON summary: %@", [[NSString alloc] initWithData:jsonData
                                                     encoding:NSUTF8StringEncoding]);

    
    //NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //[NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
    {
        
        [_login_button setEnabled:TRUE];
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
            [self toastStatus:false Message:@"Failed to connect to PB server"];
            [status_label setText:@"Failed to connect"];
        }
        else
        {
            NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
            loginArray = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            NSLog(@"Statuses: %@", loginArray[@"status"]);
            NSNumber *status = loginArray[@"status"];
            if ([status isEqual:@0]) {
                fprintf(stderr,"Not logged in!");
                [status_label setText:@"Username/Password wrong"];
                [_username_field colorRed];
                [_password_field colorRed];
            } else if ([status isEqual:@1]) {
                fprintf(stderr,"Logged in!");
                [[NSUserDefaults standardUserDefaults] setValue:_username_field.text forKey:@"username"];
                [[NSUserDefaults standardUserDefaults] setValue:_password_field.text forKey:@"password"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [self performSegueWithIdentifier:@"streamSegue" sender:self];
            } else {
                [self toastStatus:false Message:@"Failed to connect to PB server"];
            }
            for (NSArray *aDay in loginArray){
                //Do something
                NSLog(@"Array: %@", aDay);
            }
        }
    }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [_username_field resignFirstResponder];
    [_password_field resignFirstResponder];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (IBAction)unwindToLogin:(UIStoryboardSegue *)segue {
    
}

- (IBAction)backToTheStart:(UIStoryboardSegue *)segue {
    
    // grab a reference
    //ViewController *viewController2 = segue.sourceViewController;
    
    // access public properties from ViewController2 here
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void) setStatus:(NSString *)statusx {
    status = statusx;
}
@end
