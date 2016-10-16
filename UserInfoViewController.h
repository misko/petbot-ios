//
//  SetupViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBViewController.h"
#import "PBButton.h"

@interface UserInfoViewController : PBViewController <NSURLConnectionDataDelegate>
@property (strong, nonatomic) IBOutlet UITextField *usernameTextField;
@property (strong, nonatomic) IBOutlet UITextField *emailTextField;
@property (strong, nonatomic) IBOutlet UITextField *passwordTextField;
@property (strong, nonatomic) IBOutlet UITextField *confirmTextField;
- (IBAction)continueClicked:(id)sender;
- (IBAction)usernameChanged:(id)sender;
@property (strong, nonatomic) IBOutlet PBButton *continueButton;

@property (strong, nonatomic) IBOutlet UIView *notifier;


@end
