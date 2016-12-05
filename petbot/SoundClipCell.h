//
//  SliderCell.h
//  petbot
//
//  Created by Misko Dzamba on 2016-12-03.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import <UIKit/UIKit.h>

@interface SoundClipCell : UITableViewCell {
    @public NSString * fid;
    @public NSString * fn;
}
@property (strong, nonatomic) IBOutlet UILabel *ui_label;
@property (strong, nonatomic) IBOutlet UIButton *removeButton;
@end
