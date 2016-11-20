//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "UserInfoViewController.h"
#import "WifiInfoViewController.h"
#import "ViewController.h"
#import "UIColor+PBColor.h"
#import "pb.h"

@interface UserInfoViewController () {
    NSMutableData * data;
    NSString * username_err;
    NSString * password_err;
    NSString * email_err;
    BOOL usernameHasChanged;
}

@end

@implementation UserInfoViewController


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"userInfoToWifiInfo"]) {
        WifiInfoViewController * wivc = [segue destinationViewController];
        
        NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[_usernameTextField text], @"username", [_emailTextField text], @"email",[_passwordTextField text], @"password", nil];
        [wivc setLoginArray:d];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

// Check the response code that was returned
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    //NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    //return [httpResponse statusCode];
    
}



// Take a peak at the data returned.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)ddata {
    if(!data) {
        data = [NSMutableData data];
    }
    
    [data appendData:ddata];
    NSLog(@"Set data %@",[ddata description]);
    //How to get this information back up into the getGroups method
}

-(BOOL)checkButtonStatus{
    if (![username_err isEqualToString:@""]) {
        [_status_label setText:username_err];
        [_usernameTextField colorRed];
        return false;
    }
    [_usernameTextField colorBlue];
    if (![password_err isEqualToString:@""]) {
        [_status_label setText:password_err];
        [_passwordTextField colorRed];
        return false;
    }
    [_passwordTextField colorBlue];
    if (![email_err isEqualToString:@""]) {
        [_status_label setText:email_err];
        [_emailTextField colorRed];
        return false;
    }
    [_emailTextField colorBlue];
    [_status_label setText:@"PURRRFECT!"];
    return true;
    
}


// Close the connection
- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    NSLog(@"Connection Closed.");
    //NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(responseString);
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    int status =[[dictionary objectForKey:@"status"] intValue];
    
    if ( status == 0) {
        // WARN USER!
        NSLog(@"CHECK FAIL");
        username_err = [dictionary objectForKey:@"err_msg"];
    } else {
        // enable the button
        NSLog(@"CHECK PASS");
        username_err = @"";
    }
    [self checkButtonStatus];
    [data setLength:0];
    
}

- (void)checkUsername {
    NSLog(@"CHECK USERNAME");
    usernameHasChanged=false;
    username_err = @"CHECKING USERNAME";
    [self checkButtonStatus];
    //build an info object and convert to json
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:[_usernameTextField text], @"username", [_emailTextField text], @"email", nil];
    
     NSError *error;
    //convert object to data
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:kNilOptions error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString * url = [NSString stringWithFormat:@"%s", HTTPS_ADDRESS_SETUP_CHECK];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // print json:
    NSLog(@"JSON summary: %@", [[NSString alloc] initWithData:jsonData
                                                     encoding:NSUTF8StringEncoding]);
    
    NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    username_err = @"USERNAME EMPTY";
    password_err = @"PASSWORD EMPTY";
    email_err = @"INVALID EMAIL";
    usernameHasChanged = false;
    [_status_label setTextColor:[UIColor PBRed]];
    [_status_label setText:@""];
    //[_continueButton setEnabled:FALSE];
    [_notifier setBackgroundColor:[UIColor PBBlue]];
    //[self toastPinColor:[UIColor PBBlue] Message:@"(1) STEP ONE"];
    
    // Do any additional setup after loading the view.
    
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (IBAction)continueClicked:(id)sender {
    NSLog(@"CLICKED CONTINUE!");
    if (usernameHasChanged) {
        //check username
        NSLog(@"USERNAME HAS CHANGED");
        usernameHasChanged=false;
        [self checkUsername];
        return;
    }
    [self check_passwords];
    [self check_email];
    if ([self checkButtonStatus]) {
        [self performSegueWithIdentifier:@"userInfoToWifiInfo" sender:self];
    }
}

- (IBAction)usernameChanged:(id)sender {
    NSLog(@"CHECK USERNAME");
    [self checkUsername];
}

-(BOOL)check_passwords {
    NSString * password = [_passwordTextField text];
    NSString * password_confirm = [_confirmTextField text];
    if ([password length]<8) {
        password_err = @"PASSWORD TOO SHORT < 8";
        //[self checkButtonStatus];
        return false;
    }
    if (![password isEqualToString:password_confirm]) {
        password_err = @"PASSWORDS DO NOT MATCH";
        //[self checkButtonStatus];
        return false;
    }
    password_err = @"";
    return true;
}

-(BOOL)check_email {
    if ([self validateEmail:[_emailTextField text]]) {
        email_err = @"";
        return true;
    } else {
        email_err = @"INVALID EMAIL";
        return false;
    }
}

- (IBAction)password_change:(id)sender {
    [self check_passwords];
    [self checkButtonStatus];
}

//http://stackoverflow.com/questions/7123667/is-there-any-way-to-make-a-text-field-entry-must-be-email-in-xcode
- (BOOL)validateEmail:(NSString *)emailStr {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:emailStr];
}

- (IBAction)username_changed:(id)sender {
    usernameHasChanged=true;
}

- (IBAction)email_change:(id)sender {
    [self check_email];
    [self checkButtonStatus];
}

@end
