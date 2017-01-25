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
#import "PBTextField.h"

@interface UserInfoViewController : PBViewController <NSURLConnectionDataDelegate>

@property (strong, nonatomic) IBOutlet PBTextField *usernameTextField;
@property (strong, nonatomic) IBOutlet PBTextField *emailTextField;
@property (strong, nonatomic) IBOutlet PBTextField *passwordTextField;
@property (strong, nonatomic) IBOutlet PBTextField *confirmTextField;
- (IBAction)continueClicked:(id)sender;
- (IBAction)usernameChanged:(id)sender;
@property (strong, nonatomic) IBOutlet PBButton *continueButton;
@property (strong, nonatomic) IBOutlet UILabel *status_label;

@property (strong, nonatomic) IBOutlet UIView *notifier;
- (IBAction)password_change:(id)sender;
- (IBAction)username_changed:(id)sender;

- (IBAction)email_change:(id)sender;
-(void)setDebugMode:(bool)x;

@end
