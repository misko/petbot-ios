//
//  PBButton.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBButton.h"

@implementation PBButton

- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.cornerRadius = 4.0f;
    self.layer.masksToBounds = YES;
    //self.layer.cornerRadius = 1.0f;
    [self setTitleColor:[UIColor PBTextWhite] forState:UIControlStateNormal];
    [self setBackgroundColor:[UIColor PBBlue]];
    //self.layer.borderColor = [UIColor PBBlue];
    [self setTitle:[[self.titleLabel text] uppercaseString] forState:UIControlStateNormal];
    
    
}

-(void)setEnabled:(bool)e {
    [super setEnabled:e];
    if (e) {
        [self setBackgroundColor:[UIColor PBBlue]];
    } else {
        [self setBackgroundColor:[UIColor PBGrey]];
        
    }
}
@end