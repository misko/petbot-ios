//
//  LoginViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBViewController.h"
#import "PBTextField.h"


@interface LoginViewController : PBViewController
@property (strong, nonatomic) IBOutlet PBTextField *username_field;
@property (strong, nonatomic) IBOutlet PBTextField *password_field;
@property (strong, nonatomic) IBOutlet UIButton *login_button;

@end
