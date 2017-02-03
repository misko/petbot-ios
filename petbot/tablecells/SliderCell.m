//
//  SliderCell.m
//  petbot
//
//  Created by Misko Dzamba on 2016-12-03.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import "SliderCell.h"

@implementation SliderCell


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    
    return self;
}

- (IBAction)sliderChange:(UISlider*)sender {
    [_sliderLabel setText:[NSString stringWithFormat:@"%.0f\%",100*[_ui_slider value]]];
}

-(void)layoutSubviews{
    [super layoutSubviews];
    [_ui_slider addTarget:self action:@selector(sliderChange:) forControlEvents:UIControlEventValueChanged];
}

/*
 - (void)setSelected:(BOOL)selected animated:(BOOL)animated
 {
 [super setSelected:selected animated:animated];
 
 // Configure the view for the selected state
 }*/

@end
