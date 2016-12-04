//
//  SliderCell.h
//  petbot
//
//  Created by Misko Dzamba on 2016-12-03.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import <UIKit/UIKit.h>

@interface ValueCell : UITableViewCell {
}
@property (strong, nonatomic) IBOutlet UILabel *ui_label;
@property (strong, nonatomic) IBOutlet UIStepper *ui_stepper;
@end
