//
//  PBViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-10-13.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PBViewController : UIViewController

-(void)toastStatus:(bool)status Message:(NSString*)msg;
-(void)toastPinColor:(UIColor*)c Message:(NSString*)msg;
@end
