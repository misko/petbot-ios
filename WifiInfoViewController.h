//
//  SetupViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBViewController.h"

@interface WifiInfoViewController : PBViewController
@property (strong, nonatomic) IBOutlet UITextField *ssidTextField;
@property (strong, nonatomic) IBOutlet UITextField *keyTextField;
@property (strong, nonatomic) IBOutlet UIView *troubleshoot_view;


-(void) setLoginArray:(NSDictionary *)dictionary;

- (IBAction)troubleshoot:(id)sender;


@end
