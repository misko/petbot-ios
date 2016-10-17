//#import <UIKit/UIKit.h>
#import "GStreamerBackendDelegate.h"

@interface ViewController : UIViewController <GStreamerBackendDelegate> {
    IBOutlet UILabel *message_label;
    IBOutlet UIView *video_view;
    IBOutlet UIView *video_container_view;
    IBOutlet NSLayoutConstraint *video_width_constraint;
    IBOutlet NSLayoutConstraint *video_height_constraint;
    IBOutlet UILabel *pet_story;
    IBOutlet UIImageView *pet_img;
    IBOutlet UIView *main_view;
 
    IBOutlet UILabel *pet_name;
    IBOutlet UIView *pet_view;
}


/* From GStreamerBackendDelegate */
-(void) gstreamerInitialized;
-(void) gstreamerSetUIMessage:(NSString *)message;
-(void) gstreamerHideLoadView;
-(void) setLoginArray:(NSDictionary *)dictionary;
-(void) toLogin;

@end
