//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "SetupViewController.h"
#import "ViewController.h"
#import "pb.h"

@interface SetupViewController () {
    NSMutableData * imageData;
}

@end

@implementation SetupViewController



// Check the response code that was returned
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    //NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    //return [httpResponse statusCode];
    
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


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}


// Close the connection
- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    NSLog(@"Connection Closed.");
    
    _qrImageView.image = [UIImage imageWithData:imageData];
}

- (IBAction)pressSetupQR:(id)sender {
    imageData = NULL;
    NSString * qr_string = [NSString stringWithFormat:@"SETUP:%@:%@:%@", [_emailTextField text],[_ssidTextField text],[_keyTextField text]];
    //build an info object and convert to json
    NSDictionary *newDatasetInfo = [NSDictionary dictionaryWithObjectsAndKeys:qr_string, @"text", nil];
    
     NSError *error;
    //convert object to data
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:newDatasetInfo options:kNilOptions error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
      // NSURL *someURLSetBefore = [NSURL URLWithString:@"http://localhost:3000/messaging"];
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
    // Do any additional setup after loading the view.
    
}
@end
