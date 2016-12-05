//
//  SliderCell.h
//  petbot
//
//  Created by Misko Dzamba on 2016-12-03.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "PBTextField.h"

@interface RecordCell : UITableViewCell {
}
@property (strong, nonatomic) IBOutlet PBTextField *ui_sound_name;
@property (strong, nonatomic) IBOutlet UIButton *ui_play_button;
@property (strong, nonatomic) IBOutlet UIButton *ui_record_button;
@property (strong, nonatomic) IBOutlet UIButton *ui_upload_button;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@end
