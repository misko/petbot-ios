//#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GStreamerBackendDelegate.h"



@interface GStreamerBackend : NSObject

/* Initialization method. Pass the delegate that will take care of the UI.
 * This delegate must implement the GStreamerBackendDelegate protocol.
 * Pass also the UIView object that will hold the video window. */
-(id) init:(id) uiDelegate videoView:(UIView*) video_view serverInfo:(NSDictionary *)loginInfo;


@end