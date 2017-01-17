//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "WifiInfoViewController.h"
#import "QRViewController.h"

#import "UIColor+PBColor.h"

#import "pb.h"

@interface WifiInfoViewController () {
    NSMutableData * imageData;
    NSDictionary * loginArray;
}

@end

@implementation WifiInfoViewController



-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"WifiInfoToQR"]) {
        QRViewController * qrvc = [segue destinationViewController];
        
        NSMutableDictionary * d = [[NSMutableDictionary alloc] initWithDictionary:loginArray copyItems:YES];
        [d setValue:[_ssidTextField text] forKey:@"wifiname"];
        [d setValue:[_keyTextField text] forKey:@"wifikey"];
        [qrvc setLoginArray:d];
        //ViewController.user = [self.users objectInListAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

-(void) setLoginArray:(NSDictionary *)dictionary {
    loginArray = dictionary;
}

- (IBAction)troubleshoot:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://petbot.com/help"]];
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait + UIInterfaceOrientationMaskPortraitUpsideDown;
}


- (IBAction)unwindToWifi:(UIStoryboardSegue *)segue {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [_troubleshoot_view setBackgroundColor:[UIColor PBGrey]];
    // Do any additional setup after loading the view.
    
}
@end
