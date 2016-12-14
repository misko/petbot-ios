//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "QRViewController.h"
#import "WifiInfoViewController.h"
#import "LoginViewController.h"
#import "pb.h"
#import "tcp_utils.h"

@interface QRViewController () {
    NSMutableData * imageData;
    NSDictionary * loginArray;
    NSString * qr_string;
    NSString * status_str;
}

@end

@implementation QRViewController


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"QRToWifiInfo"]) {
        WifiInfoViewController * wivc = [segue destinationViewController];
        
        [wivc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
    if (status_str!=nil && [[segue identifier] isEqualToString:@"segueToLogin"]) {
        LoginViewController * lc = [segue destinationViewController];
        [lc setStatus:status_str setFlag:TRUE];
        status_str =nil;
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

-(void) setLoginArray:(NSDictionary *)dictionary {
    loginArray = dictionary;
}

// Check the response code that was returned
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    //NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    //return [httpResponse statusCode];
    
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}



// Take a peak at the data returned.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(!imageData) {
        imageData = [NSMutableData data];
    }
    
    [imageData appendData:data];
    //NSLog(@"Set data %@",[data description]);
    //How to get this information back up into the getGroups method
}



// Close the connection
- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    NSLog(@"Connection Closed.");
    
    _qrImageView.image = [UIImage imageWithData:imageData];
}

- (void)updateQR {
    imageData = NULL;
    
    NSString * username = [loginArray objectForKey:@"username"];
    NSString * email = [loginArray objectForKey:@"email"];
    NSString * password = [loginArray objectForKey:@"password"];
    
    NSString * wifiname = [loginArray objectForKey:@"wifiname"];
    NSString * wifikey = [loginArray objectForKey:@"wifikey"];
    
    NSString * wait_time = @"40";
    
    //NSString * lengths = [NSString stringWithFormat:@"%ld:%ld:%ld:%ld:%lu", [username length], [email length], [password length], [wifiname length], [wifikey length]];
    //NSString * string = [NSString stringWithFormat:@"%@:%@:%@:%@:%@", username, email, password, wifiname, wifikey];
    //NSString * qr_string = [NSString stringWithFormat:@"SETUP:%@:%@", lengths, string];
    qr_string = [NSString stringWithFormat:@"SETUP:%ld:%@:%ld:%@:%ld:%@:%ld:%@:%ld:%@:%ld:%@", [username length], username, [email length], email, [password length], password, [wifiname length], wifiname, [wifikey length], wifikey, [wait_time length], wait_time ];
    [self listenOnHash];
    
    //build an info object and convert to json
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:qr_string, @"text", nil];
    
     NSError *error;
    //convert object to data
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:kNilOptions error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString * url = [NSString stringWithFormat:@"%s", HTTPS_ADDRESS_QRCODE_JSON];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    // print json:
   //NSLog(@"JSON summary: %@", [[NSString alloc] initWithData:jsonData
     //                                                encoding:NSUTF8StringEncoding]);
    
    NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

- (void)listenOnHash {
    int hash_int = pbmsg_hash([qr_string UTF8String]);
    NSString *hash = [NSString stringWithFormat:@"%d",hash_int];
    
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:hash, @"key",@"50",@"timeout", nil];
    
    NSLog(@"Listening on hash %@",hash);
    
    //convert object to data
    NSError * error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:kNilOptions error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%s", HTTPS_ADDRESS_PB_LISTEN]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:jsonData];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               // optionally update the UI to say 'done'
                               if (!error) {
                                   NSError *error;
                                   NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                                   
                                   int status =[[dictionary objectForKey:@"status"] intValue];
                                   
                                   if ( status == 0) {
                                       // WARN USER!
                                       NSLog(@"CHECK RETURN FORM LISTEN - FAIL");
                                   } else {
                                       // enable the button
                                       NSLog(@"CHECK RETURN FORM LISTEN  - PASS");
                                       NSString * username = [loginArray objectForKey:@"username"];
                                       NSString * password = [loginArray objectForKey:@"password"];
                                       [[NSUserDefaults standardUserDefaults] setValue:username forKey:@"username"];
                                       [[NSUserDefaults standardUserDefaults] setValue:password forKey:@"password"];
                                       [[NSUserDefaults standardUserDefaults] synchronize];
                                       status_str = @"Setup Complete";
                                       [self performSegueWithIdentifier:@"segueToLogin" sender:self];
                                   }
                                   // update the UI here (and only here to the extent it depends on the json)
                               } else {
                                   // update the UI to indicate error
                               }
                               
                               
                           }];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

-(void)viewDidAppear:(BOOL)animated {
    status_str=nil;
    [self updateQR];
}
@end
