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
#import "petbot/pb-ios.h"

@interface UserInfoViewController () {
    NSMutableData * data;
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
- (NSInteger)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    return [httpResponse statusCode];
    
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



// Close the connection
- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    NSLog(@"Connection Closed.");
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
   if ( [dictionary objectForKey:@"status"]==0 ) {
        // WARN USER!
       NSLog(@"CHECK FAIL");
        [_continueButton setEnabled:FALSE];
    } else {
        // enable the button
        NSLog(@"CHECK PASS");
        [_continueButton setEnabled:TRUE];
    }
}

- (void)checkUsername {
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
    [_continueButton setEnabled:FALSE];
    // Do any additional setup after loading the view.
    
}
- (IBAction)continueClicked:(id)sender {
    //[self performSegueWithIdentifier:@"streamSegue" sender:self];
}

- (IBAction)usernameChanged:(id)sender {
    [self checkUsername];
}
@end