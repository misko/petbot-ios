//#import <UIKit/UIKit.h>
#import "GStreamerBackendDelegate.h"
#import "PBViewController.h"
#import "PBButton.h"

@interface VideoViewController : PBViewController <GStreamerBackendDelegate> {
    IBOutlet UILabel *message_label;
    IBOutlet UIView *video_view;
    IBOutlet UIView *video_container_view;
    IBOutlet NSLayoutConstraint *video_width_constraint;
    IBOutlet NSLayoutConstraint *video_height_constraint;
    IBOutlet UILabel *pet_story;
    IBOutlet UIImageView *pet_img;
    IBOutlet UIView *main_view;
 
    IBOutlet PBButton *selfie_play_button;
    IBOutlet PBButton *selfie_button;
    IBOutlet UILabel *pet_name;
    IBOutlet UIView *pet_view;
    IBOutlet UILabel *connecting_message;
}
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *selfieLandScapeVertical;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *selfiePortraitHorizontal;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *selfieLandScapeHorizontal;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *selfiePortraitVertical;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *alertPortraitHorizontal;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *alertPortraitVertical;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *alertLandScapeVertical;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *alertLandScapeHorizontal;

    
/* From GStreamerBackendDelegate */
- (IBAction)showMenu:(id)sender;
-(void) gstreamerInitialized;
-(void) gstreamerSetUIMessage:(NSString *)message;
-(void) gstreamerHideLoadView;
-(void) setLoginArray:(NSDictionary *)dictionary;
-(void) toLogin;
- (IBAction)tapped:(id)sender;
- (IBAction)swipeLeft:(id)sender;
- (IBAction)swipeRight:(id)sender;
- (IBAction)swipeDown:(id)sender;
- (IBAction)swipeUp:(id)sender;
- (IBAction)longPress:(id)sender;
@end
