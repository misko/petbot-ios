//
//  PBNotifierCircle.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBNotifierCircle.h"

@implementation PBNotifierCircle

- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.cornerRadius = 12.0f;
    self.layer.masksToBounds = YES;
    //self.layer.cornerRadius = 1.0f;
    //[self setTitleColor:[UIColor PBTextWhite] forState:UIControlStateNormal];
    //[self setBackgroundColor:[UIColor PBTextWhite]];
    [self setTextColor:[UIColor PBTextWhite]];
    //[self setText:[self.text uppercaseString]];
    [self setFont:[UIFont systemFontOfSize:16]];
    self.layer.borderColor = [[UIColor PBTextWhite] CGColor];
    
    self.layer.borderWidth= 2.0f;
    
    /*//space out the string? //MISKO
     NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:self.text];
     //the value paramenter defines your spacing amount, and range is the range of characters in your string the spacing will apply to. Here we want it to apply to the whole string so we take it from 0 to text.length.
     [text addAttribute:NSKernAttributeName value:[NSNumber numberWithDouble:2] range:NSMakeRange(0, text.length)];
     [self setAttributedText:text];*/
}

@end