//
//  SetupViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WifiInfoViewController : UIViewController 
@property (strong, nonatomic) IBOutlet UITextField *ssidTextField;
@property (strong, nonatomic) IBOutlet UITextField *keyTextField;


-(void) setLoginArray:(NSDictionary *)dictionary;



@end
