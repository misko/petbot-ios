//
//  PBNotifierLabel.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBNotifierLabel.h"

@implementation PBNotifierLabel

- (void)awakeFromNib {
    [super awakeFromNib];
    //self.layer.cornerRadius = 4.0f;
    self.layer.masksToBounds = YES;
    //self.layer.cornerRadius = 1.0f;
    //[self setTitleColor:[UIColor PBTextWhite] forState:UIControlStateNormal];
    //[self setBackgroundColor:[UIColor PBTextWhite]];
    [self setTextColor:[UIColor PBTextWhite]];
    //[self setText:[self.text uppercaseString]];
    [self setFont:[UIFont systemFontOfSize:16]];
    //self.layer.borderColor = [UIColor PBBlue];
    
    
    /*//space out the string? //MISKO
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:self.text];
    //the value paramenter defines your spacing amount, and range is the range of characters in your string the spacing will apply to. Here we want it to apply to the whole string so we take it from 0 to text.length.
    [text addAttribute:NSKernAttributeName value:[NSNumber numberWithDouble:2] range:NSMakeRange(0, text.length)];
    [self setAttributedText:text];*/
}

@end
