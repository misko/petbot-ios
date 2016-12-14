//
//  UIColor+PBColor.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-15.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "UIColor+PBColor.h"

@implementation UIColor (PBColor)
+ (UIColor*)PBBlue {
    //return [UIColor colorWithRed:74.0/255.0 green:144.0/255.0 blue:226.0/255.0 alpha:1];
    //4156d6
    return [UIColor colorWithRed:65.0/255.0 green:86.0/255.0 blue:214.0/255.0 alpha:1];
}
+ (UIColor*)PBRed {
    return [UIColor colorWithRed:219.0/255.0 green:93.0/255.0 blue:93.0/255.0 alpha:1];
}
+ (UIColor*)PBGreen {
    return [UIColor colorWithRed:90.0/255.0 green:205.0/255.0 blue:117.0/255.0 alpha:1];
}
+ (UIColor*)PBGrey {
    return [UIColor colorWithRed:194.0/255.0 green:201.0/255.0 blue:209.0/255.0 alpha:1];
}
+ (UIColor*)PBBlack {
    return [UIColor colorWithRed:70.0/255.0 green:70.0/255.0 blue:70.0/255.0 alpha:1];
}
+ (UIColor*)PBTextWhite {
    return [UIColor whiteColor];
    //return [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1];
}
@end
