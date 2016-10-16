//
//  PBHollowButton.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBHollowButton.h"
#import <QuartzCore/QuartzCore.h>

@implementation PBHollowButton

- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.cornerRadius = 4.0f;
    self.layer.masksToBounds = YES;
    //self.layer.cornerRadius = 1.0f;
    [self setTitleColor:[UIColor PBBlue] forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor PBTextWhite]];
    self.layer.borderWidth= 1.0f;
    
    self.layer.borderColor = [[UIColor PBBlue] CGColor];
    [self setTitle:[[self.titleLabel text] uppercaseString] forState:UIControlStateNormal];
    
    
}

@end