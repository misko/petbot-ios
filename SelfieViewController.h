//
//  SelfieViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-10-28.
//  Copyright © 2016 PetBot. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "PBViewController.h"
#import "SelfieView.h"
#import "PBButton.h"

@interface SelfieViewController : PBViewController
@property (strong, nonatomic) IBOutlet SelfieView *videoview;
- (IBAction)deletePressed:(id)sender;
@property (strong, nonatomic) NSString *selfieURL;
@property (strong, nonatomic) NSString *selfieRMURL;


@end
