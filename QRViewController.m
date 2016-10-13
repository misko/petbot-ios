//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "QRViewController.h"
#import "WifiInfoViewController.h"
#import "ViewController.h"
#import "petbot/pb-ios.h"

@interface QRViewController () {
    NSMutableData * imageData;
    NSDictionary * loginArray;
}

@end

@implementation QRViewController



-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"QRToWifiInfo"]) {
        WifiInfoViewController * wivc = [segue destinationViewController];
        
        [wivc setLoginArray:loginArray];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

-(void) setLoginArray:(NSDictionary *)dictionary {
    loginArray = dictionary;
}

// Check the response code that was returned
- (NSInteger)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    return [httpResponse statusCode];
    
}



// Take a peak at the data returned.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(!imageData) {
        imageData = [NSMutableData data];
    }
    
    [imageData appendData:data];
    NSLog(@"Set data %@",[data description]);
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
    
    NSString * wait_time = @"20";
    
    //NSString * lengths = [NSString stringWithFormat:@"%ld:%ld:%ld:%ld:%lu", [username length], [email length], [password length], [wifiname length], [wifikey length]];
    //NSString * string = [NSString stringWithFormat:@"%@:%@:%@:%@:%@", username, email, password, wifiname, wifikey];
    //NSString * qr_string = [NSString stringWithFormat:@"SETUP:%@:%@", lengths, string];
    NSString * qr_string = [NSString stringWithFormat:@"SETUP:%ld:%@:%ld:%@:%ld:%@:%ld:%@:%ld:%@:%ld:%@", [username length], username, [email length], email, [password length], password, [wifiname length], wifiname, [wifikey length], wifikey, [wait_time length], wait_time ];
    
    
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
    NSLog(@"JSON summary: %@", [[NSString alloc] initWithData:jsonData
                                                     encoding:NSUTF8StringEncoding]);
    
    NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateQR];
    // Do any additional setup after loading the view.
    
}
@end