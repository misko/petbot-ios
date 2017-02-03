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
#import "UserInfoViewController.h"
#import "pb.h"

@import AVFoundation;
@import AVKit;

//http://stackoverflow.com/questions/37886600/ios-10-doesnt-print-nslogs - no NSLOG?

@interface LoginViewController () {
    IBOutlet UILabel *status_label;
    NSString * status ;
    BOOL success;
    AVPlayerViewController *playerViewController;
    bool long_press;
}
@end

@implementation LoginViewController


-(void)viewDidAppear:(BOOL)animated {
    if (status!=nil) {
        [self toastStatus:success Message:status];
        status=nil;
    }
    [_login_button setEnabled:TRUE];
    [status_label setText:@""];
    
    NSString * username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    NSString * password = [[NSUserDefaults standardUserDefaults] stringForKey:@"password"];
    if (username!=nil && ![username isEqualToString:@""]){
        [_username_field setText:username];
    }
    if (password!=nil && ![password isEqualToString:@""]) {
        [_password_field setText:password];
    }
    [_username_field colorBlue];
    [_password_field colorBlue];
}

-(void)pressSetup:(id)sender {
    long_press=false;
    [self performSegueWithIdentifier:@"mainToUserInfo" sender:self];
}

- (void)longPressSetup:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateEnded ) {
        long_press=true;
        [self performSegueWithIdentifier:@"mainToUserInfo" sender:self];
    }
}

-(void)pressLogin:(id)sender {
    [_login_button setEnabled:FALSE];
    debug_mode=false;
    NSLog(@"LOGIN PRESS");
    [self login];
}

- (void)longPressLogin:(UILongPressGestureRecognizer*)gesture {
    [_login_button setEnabled:FALSE];
    debug_mode=true;
     if ( gesture.state == UIGestureRecognizerStateEnded ) {
    NSLog(@"LOGIN TAP");
    [self login];
     }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [_login_button setEnabled:TRUE];
    playerViewController = [[AVPlayerViewController alloc] init];

    [status_label setText:@""];
    [status_label setTextColor:[UIColor PBRed]];
    
    NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [_versionLabel setText:appVersionString];
    [_versionLabel setTextColor:[UIColor PBRed]];
    
    UITapGestureRecognizer *tapPress = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pressSetup:)];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressSetup:)];
    [self.setup_button addGestureRecognizer:longPress];
    [self.setup_button addGestureRecognizer:tapPress];
    
    UITapGestureRecognizer *tapPressLogin = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pressLogin:)];
    UILongPressGestureRecognizer *longPressLogin = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressLogin:)];
    [self.login_button addGestureRecognizer:longPressLogin];
    [self.login_button addGestureRecognizer:tapPressLogin];
}
- (IBAction)forgetMePressed:(id)sender {
    //only do if able to deauth properly1!!!
    [_forgetme_button setEnabled:FALSE];
    
    //build an info object and convert to json
    NSString *uniqueIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"deviceToken"];
    if (deviceToken==nil) {
        deviceToken=uniqueIdentifier;
    }
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:deviceToken, @"deviceID",nil];
    
    //convert object to data
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:0 error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    //NSString * url = [NSString stringWithFormat:@"%s", HTTPS_ADDRESS_QRCODE_JSON];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", HTTPS_ADDRESS_DEAUTH]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // print json:
    NSLog(@"JSON summary: %@", [[NSString alloc] initWithData:jsonData
                                                     encoding:NSUTF8StringEncoding]);
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         [_forgetme_button setEnabled:TRUE];
         if (error) {
             NSLog(@"Error,%@", [error localizedDescription]);
             [self toastStatus:false Message:@"Failed to connect to PB server"];
             [status_label setText:[error localizedDescription]];
         } else {
             NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
             NSDictionary * response = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
             NSNumber *status = response[@"status"];
             if ([status isEqual:@0]) {
                 [self toastStatus:false Message:@"Failed to connect to PB server"];
             } else if ([status isEqual:@1]) {
                 [[NSUserDefaults standardUserDefaults] setValue:@"" forKey:@"username"];
                 [[NSUserDefaults standardUserDefaults] setValue:@"" forKey:@"password"];
                 [_username_field setText:@""];
                 [_password_field setText:@""];
                 [[NSUserDefaults standardUserDefaults] synchronize];
             } else {
                 [self toastStatus:false Message:@"Failed to connect to PB server"];
             }
         }
     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"streamSegue"]) {
        VideoViewController * vvc = [segue destinationViewController];
        [vvc setLoginArray:loginArray];
        [vvc setDebug:debug_mode];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    } else if ([[segue identifier] isEqualToString:@"mainToUserInfo"]) {
        UserInfoViewController * uivc = [segue destinationViewController];
        [uivc setDebugMode:long_press];
    }
}

- (void)login {
    //[_login_button setEnabled:FALSE];
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
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", HTTPS_ADDRESS_AUTH]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];

     [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
            [self toastStatus:false Message:@"Failed to connect to PB server"];
            [status_label setText:[error localizedDescription]];
            [_login_button setEnabled:TRUE];
        } else {
            loginArray = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            NSNumber *status = loginArray[@"status"];
            if ([status isEqual:@0]) {
                if ([loginArray objectForKey:@"err_msg"]!=nil) {
                    [status_label setText:@"Username or password invalid"];
                    [_username_field colorRed];
                    [_password_field colorRed];
                } else {
                    [status_label setText:@"Server error :("];
                }
                [_login_button setEnabled:TRUE];
            } else if ([status isEqual:@1]) {
                [[NSUserDefaults standardUserDefaults] setValue:_username_field.text forKey:@"username"];
                [[NSUserDefaults standardUserDefaults] setValue:_password_field.text forKey:@"password"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [self performSegueWithIdentifier:@"streamSegue" sender:self];
            } else {
                [self toastStatus:false Message:@"Failed to connect to PB server"];
                [_login_button setEnabled:TRUE];
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
    
}

-(void) setStatus:(NSString *)statusx setFlag:(BOOL)successx {
    status = statusx;
    success = successx;
}
@end
