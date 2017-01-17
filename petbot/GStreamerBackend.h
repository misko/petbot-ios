//#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GStreamerBackendDelegate.h"
#import "VideoViewController.h"
#import "pb.h"

@interface GStreamerBackend : NSObject

/* Initialization method. Pass the delegate that will take care of the UI.
 * This delegate must implement the GStreamerBackendDelegate protocol.
 * Pass also the UIView object that will hold the video window. */
-(id) init:(id) uiDelegate videoView:(UIView*) video_view vvc:(VideoViewController *)vvc;

-(void) app_functionPBNIO:(pb_nice_io*)pbnio;
-(void) quit;
@end
