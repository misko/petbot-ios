//
//  SetupViewController.h
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBViewController.h"
#import "PBHollowButton.h"

@interface SoundViewController : PBViewController <UITableViewDelegate, UITableViewDataSource, AVAudioRecorderDelegate>


@property (strong, nonatomic) IBOutlet UITableView *tableview;
-(void) setLoginArray:(NSDictionary *)dictionary;
@end
