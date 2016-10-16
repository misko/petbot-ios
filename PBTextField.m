//
//  PBTextField.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBTextField.h"
#import <QuartzCore/QuartzCore.h>

@implementation PBTextField

- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.cornerRadius = 4.0f;
    self.layer.masksToBounds = YES;
    [self setBorderStyle:UITextBorderStyleRoundedRect];
    self.layer.borderColor=[[UIColor PBBlue]CGColor];
    self.layer.borderWidth= 1.0f;
    
    //self.layer.cornerRadius = 1.0f;
    //[self setTitleColor:[UIColor PBTextWhite] forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor PBTextWhite]];
    //self.layer.borderColor = [UIColor PBBlue];
}


@end