//
//  PBNotifierView.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIColor+PBColor.h"
#import "PBNotifierView.h"

@implementation PBNotifierView

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setBackgroundColor:[UIColor PBBlue]];
}

@end