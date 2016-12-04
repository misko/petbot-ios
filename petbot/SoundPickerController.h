//
//  SoundPickerController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-12-04.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBViewController.h"

@interface SoundPickerController : PBViewController <UITableViewDelegate, UITableViewDataSource>
@property (strong, nonatomic) IBOutlet UIButton *doneButton;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
