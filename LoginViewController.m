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
#import "ViewController.h"
#import "pb.h"

//http://stackoverflow.com/questions/37886600/ios-10-doesnt-print-nslogs - no NSLOG?

@interface LoginViewController () {
        NSDictionary * loginArray;
    IBOutlet UILabel *status_label;
}
@end

@implementation LoginViewController


- (void)viewDidLoad {
    [super viewDidLoad];
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
        ViewController * vc = [segue destinationViewController];
        [vc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

- (IBAction)loginPressed:(id)sender {
    //TODO should be ASYNC!!
    
    //build an info object and convert to json
    NSString *uniqueIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:_username_field.text, @"username", _password_field.text, @"password",  uniqueIdentifier, @"deviceID",nil];
    
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
        if (error) {
            NSLog(@"Error,%@", [error localizedDescription]);
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
            } else {
                fprintf(stderr,"Logged in!");
                [[NSUserDefaults standardUserDefaults] setValue:_username_field.text forKey:@"username"];
                [[NSUserDefaults standardUserDefaults] setValue:_password_field.text forKey:@"password"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [self performSegueWithIdentifier:@"streamSegue" sender:self];
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

@end
