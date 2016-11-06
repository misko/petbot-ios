//
//  SelfieView.m
//  petbot
//
//  Created by Misko Dzamba on 2016-10-28.
//  Copyright © 2016 PetBot. All rights reserved.
//

#include "SelfieView.h"


@interface SelfieView () {
    CALayer * playerLayer;
}

@end

@implementation SelfieView

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer:layer];
    //playerLayer.frame = self.bounds;
    //playerLayer.masksToBounds = TRUE;
    [playerLayer setFrame:self.bounds];
    playerLayer.cornerRadius = 4.0f;
    playerLayer.masksToBounds = YES;
    //playerLayer.bounds = self.bounds;
}



-(void)setPlayerLayer:(CALayer *)playerLayerX {
    playerLayer = playerLayerX;
}

@end
