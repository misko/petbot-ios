//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//
#import "UIColor+PBColor.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>
#import "RecordCell.h"
#import "PBTextField.h"
#import "SoundClipCell.h"
#import "SwitchCell.h"
#import "ValueCell.h"
#import "ButtonCell.h"
#import "SliderCell.h"
#import "SoundViewController.h"
#import "SoundPickerController.h"
#import "PBButton.h"
#include "tcp_utils.h"
#include "nice_utils.h"
#include "pb.h"

@interface SoundViewController () {
    
    NSArray *names_selfie;
    NSArray *names_sound;
    NSArray *names_system;
    
    NSArray *labels_selfie;
    NSArray *labels_sound;
    NSArray *labels_system;
    
    NSArray *types_selfie;
    NSArray *types_sound;
    NSArray *types_system;
    NSArray *sections;
    
    NSDictionary * config;
    NSArray * sounds;
    bool selecting_selfie_sound;
    bool selecting_alert_sound;
    
    UILabel * ui_selfie_timeout_text;
    UILabel * ui_selfie_length_text;
    
    NSURL * outputFileURL;
    AVAudioPlayer *player;
    AVAudioRecorder *recorder;
    UIProgressView * record_progress;
    NSTimer * record_timer;
    
    RecordCell * rc ;
    
    int max_record_time;
}
@property (strong, nonatomic) IBOutlet UISlider *volumeSlider;
@property (strong, nonatomic) IBOutlet UIButton *doneButton;

@end

@implementation SoundViewController


//TABLE VIEW DATASOURCE
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString * section_label = [sections[section] lowercaseString];
    if ([section_label isEqualToString:@"system"]) {
        return [labels_system count];
    } else if ([section_label isEqualToString:@"sound"]) {
        return [labels_sound count];
    } else if ([section_label isEqualToString:@"selfie"]) {
        return [labels_selfie count];
    }
    return 0;
}

- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = nil;
    NSArray * cell_types;
    NSString * section_label = [sections[indexPath.section] lowercaseString];
    
    if ([section_label isEqualToString:@"system"]) {
        cell_types=types_system;
    } else if ([section_label isEqualToString:@"sound"]) {
        cell_types=types_sound;
    } else if ([section_label isEqualToString:@"selfie"]) {
        cell_types=types_selfie;
    }
    return cell_types[indexPath.row];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return sections[section];
}

- (void)changeSwitch:(id)sender{
    if([sender isOn]){
        NSLog(@"Switch is ON");
    } else{
        NSLog(@"Switch is OFF");
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    NSString *cellIdentifier = nil;
    NSString * section_label = [sections[indexPath.section] lowercaseString];
    
    
    NSArray * cell_types;
    NSArray * cell_labels;
    NSArray * cell_names;
    

    if ([section_label isEqualToString:@"system"]) {
        cell_types=types_system;
        cell_labels=labels_system;
        cell_names=names_system;
    } else if ([section_label isEqualToString:@"sound"]) {
        cell_types=types_sound;
        cell_labels=labels_sound;
        cell_names=names_sound;
    } else if ([section_label isEqualToString:@"selfie"]) {
        cell_types=types_selfie;
        cell_labels=labels_selfie;
        cell_names=names_selfie;
    }
    
    NSString * cell_name = cell_names[indexPath.row];
    
    cellIdentifier = cell_types[indexPath.row];
    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    if ([cellIdentifier isEqualToString:@"TitleCell"] || [cellIdentifier isEqualToString:@"ButtonCell"] || [cellIdentifier isEqualToString:@"SwitchCell"] || [cellIdentifier isEqualToString:@"ValueCell"] || [cellIdentifier isEqualToString:@"DetailCell"] || [cellIdentifier isEqualToString:@"DetailRightCell"])  {
        NSString * label =[cell_labels objectAtIndex:indexPath.row];
        NSArray * parts = [label componentsSeparatedByString:@"/"];
        
        cell.textLabel.text = parts[0];
        if ([parts count]>1) {
            cell.detailTextLabel.text = parts[1];
        }
    }
    
    
    
    //handle each item properly
    
    //sound stuff
    if ([cell_name isEqualToString:@"volume_slider"]) {
        SliderCell * sc = cell;
        if ([config objectForKey:@"master_volume"]!=nil) {
            [sc.ui_slider setEnabled:true];
            [sc.ui_slider setValue:[[config objectForKey:@"master_volume"] floatValue]/63];
            [sc.ui_slider addTarget:self action:@selector(volumeChange:) forControlEvents:UIControlEventValueChanged];
        } else {
            [sc.ui_slider setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"selfie_sound"]) {
        ButtonCell * bc = cell;
        if (sounds!=nil && [config objectForKey:@"selfie_sound"]!=nil) {
            [bc.ui_button addTarget:self action:@selector(selfieSoundSelect:) forControlEvents:UIControlEventTouchUpInside];
            [bc.ui_button setEnabled:true];
        } else {
            [bc.ui_button setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"alert_sound"]) {
        ButtonCell * bc = cell;
        if (sounds!=nil) {
            [bc.ui_button addTarget:self action:@selector(alertSoundSelect:) forControlEvents:UIControlEventTouchUpInside];
            [bc.ui_button setEnabled:true];
        } else {
            [bc.ui_button setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"record"]) {
        rc = cell;
        [rc.ui_record_button addTarget:self action:@selector(recordTapped:) forControlEvents:UIControlEventTouchUpInside];
        [rc.ui_play_button addTarget:self action:@selector(playTapped:) forControlEvents:UIControlEventTouchUpInside];
        [rc.ui_upload_button addTarget:self action:@selector(uploadTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        
    }

    //system stuff
    if ([cell_name isEqualToString:@"version"]) {
        if ([config objectForKey:@"version"]!=nil) {
            cell.detailTextLabel.text = [config objectForKey:@"version"];
        } else {
            cell.detailTextLabel.text = @"?";
        }
    }
    if ([cell_name isEqualToString:@"led_enable"]) {
        SwitchCell * sc = cell;
        if ([config objectForKey:@"led"]!=nil) {
            [sc.ui_switch setOn:[[config objectForKey:@"led"] intValue]==1];
            [sc.ui_switch setEnabled:true];
        } else {
            [sc.ui_switch setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"update"]) {
        ButtonCell * bc = cell;
        [bc.ui_button addTarget:self action:@selector(updateButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    if ([cell_name isEqualToString:@"help"]) {
        ButtonCell * bc = cell;
        [bc.ui_button addTarget:self action:@selector(helpButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    //selfie stuff
    if ([cell_name isEqualToString:@"selfie_timeout"]) {
        ValueCell * vc = cell;
        ui_selfie_timeout_text = vc.ui_label;
        if ([config objectForKey:@"selfie_timeout"]!=nil) {
            [vc.ui_stepper setMaximumValue:24];
            [vc.ui_stepper setMinimumValue:1];
            [vc.ui_stepper setValue:[[config objectForKey:@"selfie_timeout"] floatValue]/(60*60)];
            [vc.ui_label setText:[self secondsToStr:[vc.ui_stepper value]*60*60]];
            [vc.ui_stepper addTarget:self action:@selector(selfieTimeoutChange:) forControlEvents:UIControlEventValueChanged];
            [vc.ui_stepper setEnabled:true];
        } else {
            [vc.ui_stepper setEnabled:false];
        }
        
    }
    if ([cell_name isEqualToString:@"selfie_length"]) {
        ValueCell * vc = cell;
        ui_selfie_length_text = vc.ui_label;
        if ([config objectForKey:@"selfie_length"]!=nil) {
            [vc.ui_stepper setMaximumValue:50];
            [vc.ui_stepper setMinimumValue:15];
            [vc.ui_stepper setValue:[[config objectForKey:@"selfie_length"] floatValue]];
            [vc.ui_label setText:[self secondsToStr:[vc.ui_stepper value]]];
            [vc.ui_stepper addTarget:self action:@selector(selfieLengthChange:) forControlEvents:UIControlEventValueChanged];
            [vc.ui_stepper setEnabled:true];
        } else {
            [vc.ui_stepper setEnabled:false];
        }
        
    }
    if ([cell_name isEqualToString:@"selfie_enable"]) {
        SwitchCell * sc = cell;
        if ([config objectForKey:@"selfie_enable"]!=nil) {
            [sc.ui_switch setEnabled:true];
            [sc.ui_switch setOn:[[config objectForKey:@"selfie_enable"] intValue]==1];
        } else {
            [sc.ui_switch setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"selfie_sensitivity_slider"]) {
        SliderCell * sc = cell;
        if ([config objectForKey:@"selfie_pet_sensitivity"]!=nil) {
            [sc.ui_slider setEnabled:true];
            [sc.ui_slider setValue:[[config objectForKey:@"selfie_pet_sensitivity"] floatValue]];
            [sc.ui_slider addTarget:self action:@selector(selfieSensitivityChange:) forControlEvents:UIControlEventValueChanged];
        } else {
            [sc.ui_slider setEnabled:false];
        }
    }
    if ([cell_name isEqualToString:@"motion_sensitivity_slider"]) {
        SliderCell * sc = cell;
        if ([config objectForKey:@"selfie_mot_sensitivity"]!=nil) {
            [sc.ui_slider setEnabled:true];
            [sc.ui_slider setValue:[[config objectForKey:@"selfie_mot_sensitivity"] floatValue]];
            [sc.ui_slider addTarget:self action:@selector(motionSensitivityChange:) forControlEvents:UIControlEventValueChanged];
        } else {
            [sc.ui_slider setEnabled:false];
        }
        
        [sc.ui_slider setEnabled:false];// mot is messed up in basic firmware
    }
    
    /*if ([cellIdentifier isEqualToString:@"SwitchCell"]) {
        SwitchCell * sc = cell;
        [sc.ui_switch addTarget:self action:@selector(changeSwitch:) forControlEvents:UIControlEventValueChanged];
        //[ addTarget:<#(nullable id)#> action:<#(nonnull SEL)#> forControlEvents:<#(UIControlEvents)#>];
    }*/
    NSLog(@"PROCESSED %@\n",cell_name);
    
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = [self cellIdentifierForIndexPath:indexPath];
    static NSMutableDictionary *heightCache;
    if (!heightCache)
        heightCache = [[NSMutableDictionary alloc] init];
    NSNumber *cachedHeight = heightCache[cellIdentifier];
    if (cachedHeight)
        return cachedHeight.floatValue;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    CGFloat height = cell.bounds.size.height;
    heightCache[cellIdentifier] = @(height);
    return height;
}


/*- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    
    NSString * section_label = [sections[indexPath.section] lowercaseString];
    NSString *cellIdentifier;
    
    NSArray * cell_types;
    NSArray * cell_labels;
    NSArray * cell_names;
    
    
    if ([section_label isEqualToString:@"system"]) {
        cell_types=types_system;
        cell_labels=labels_system;
        cell_names=names_system;
    } else if ([section_label isEqualToString:@"sound"]) {
        cell_types=types_sound;
        cell_labels=labels_sound;
        cell_names=names_sound;
    } else if ([section_label isEqualToString:@"selfie"]) {
        cell_types=types_selfie;
        cell_labels=labels_selfie;
        cell_names=names_selfie;
    }
    
    NSString * cell_name = cell_names[indexPath.row];
    
    if ([cell_name isEqualToString:@"record"]) {
        return 175;
    }
    return 100;
}*/

//END TABLE VIEW DATASOURCE


- (IBAction)unwindToSettings:(UIStoryboardSegue *)segue {
    
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"toSoundPicker"]) {
        SoundPickerController * spc = [segue destinationViewController];
        [spc setSounds:sounds];
    }
}

-(IBAction)selfieSensitivityChange:(UISlider*)sender {
    NSString * set_selfie_sensitivity = [NSString stringWithFormat:@"selfie_pet_sensitivity\t%f",[sender value]];
    [self send_msg:[set_selfie_sensitivity UTF8String] type:(PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_REQUEST)];
}

-(IBAction)motionSensitivityChange:(UISlider*)sender {
    NSString * set_motion_sensitivity = [NSString stringWithFormat:@"selfie_mot_sensitivity\t%f",[sender value]];
    [self send_msg:[set_motion_sensitivity UTF8String] type:(PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_REQUEST)];
}

-(IBAction)selfieLengthChange:(UIStepper*)sender {
    NSLog(@"SELFIE LENGTH CHANGE");
    [ui_selfie_length_text setText:[self secondsToStr:[sender value]]];
    NSString * set_vol_string = [NSString stringWithFormat:@"selfie_length\t%d",(int)([sender value])];
    [self send_msg:[set_vol_string UTF8String] type:(PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_REQUEST)];
}
-(IBAction)selfieTimeoutChange:(UIStepper*)sender {
    NSLog(@"SELFIE TIMEOUT CHANGE");
    [ui_selfie_timeout_text setText:[self secondsToStr:[sender value]*60*60]];
    NSString * set_vol_string = [NSString stringWithFormat:@"selfie_timeout\t%d",(int)([sender value]*60*60)];
    [self send_msg:[set_vol_string UTF8String] type:(PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_REQUEST)];
}

-(IBAction)selfieSoundSelect:(id)sender {
    selecting_selfie_sound=true;
    selecting_alert_sound=false;
    [self performSegueWithIdentifier:@"toSoundPicker" sender:self];
}

-(IBAction)alertSoundSelect:(id)sender {
    selecting_selfie_sound=false;
    selecting_alert_sound=true;
    [self performSegueWithIdentifier:@"toSoundPicker" sender:self];
}

-(IBAction)updateButton:(id)sender {
    NSLog(@"GOING TO UPDATE!");
}

-(IBAction)helpButton:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://petbot.com/help"]];
}

- (IBAction)volumeChange:(UISlider*)sender {
    int int_value = [sender value]*63;
    [sender setValue:((float)int_value)/63];
    NSLog(@"SLIDER CHANGE %d",int_value);
    
    NSString * set_vol_string = [NSString stringWithFormat:@"master_volume\t%d",int_value];
    pbmsg * m = new_pbmsg_from_str_wtype([set_vol_string UTF8String], PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_REQUEST);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
    
    //play a beep after change?
    NSString * url = [NSString stringWithFormat:@"%s%@",HTTPS_ADDRESS_PB_STATIC,@"beep.mp3"];
    NSString * pb_sound_str = [NSString stringWithFormat:@"PLAYURL %@",url];
    [self send_msg:[pb_sound_str UTF8String] type:(PBMSG_SOUND | PBMSG_REQUEST | PBMSG_STRING)];
    
}

-(void)setupSound {
    // Disable Stop/Play button when application launches
    //[_stopButton setEnabled:NO];
    //[_playButton setEnabled:NO];
    
    // Set the audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"petbot_sound_clip.mp4a",
                               nil];
    outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
    
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    
    // Initiate and prepare the recorder
    recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:NULL];
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    sounds = nil;
    
    config = [NSMutableDictionary dictionary];
    [self setupLogin];
    [self connect:3];
    [self setupSound];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sounds = [self pbserverLSWithType:@"mp3"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableview reloadData];
        });
    });
    labels_selfie = [NSArray arrayWithObjects:@"Enable/Take selfies automatically",@"Frequency/Minimum time between selfies",@"Duration/Length of each selfie",@"Sensitivity/Higher values trigger with greater confidence",@"",@"Motion/Higher values trigger more often",@"", nil];
    types_selfie = [NSArray arrayWithObjects:@"SwitchCell",@"ValueCell",@"ValueCell",@"DetailCell",@"SliderCell",@"DetailCell",@"SliderCell", nil];
    names_selfie = [NSArray arrayWithObjects:@"selfie_enable",@"selfie_timeout",@"selfie_length",@"selfie_sensitivity",@"selfie_sensitivity_slider",@"motion_sensitivity",@"motion_sensitivity_slider",nil];
    
    labels_sound = [NSArray arrayWithObjects:@"Volume/Loudness on PetBot",@"",@"Selfie Sound/Played when a selfie is triggered",@"Alert Sound/Played when you press sound alert",@"Record/Upload your voice to your petbot!",nil];
    types_sound = [NSArray arrayWithObjects:@"DetailCell",@"SliderCell",@"ButtonCell",@"ButtonCell",@"RecordCell", nil];
    names_sound = [NSArray arrayWithObjects:@"volume",@"volume_slider",@"selfie_sound",@"alert_sound",@"record", nil];
    
    labels_system = [NSArray arrayWithObjects:@"LED enable",@"Update/Retrieve the latest PetBot firmeware",@"Version",@"Help/Our online manual and troubleshooting", nil];
    types_system = [NSArray arrayWithObjects:@"SwitchCell",@"ButtonCell",@"DetailRightCell",@"ButtonCell", nil];
    names_system = [NSArray arrayWithObjects:@"led_enable",@"update",@"version",@"help", nil];
    
    sections = [NSArray arrayWithObjects:@"System",@"Sound",@"Selfie", nil];
}
/*
 
 dispatch_async(dispatch_get_main_queue(), ^{
 // code here
 /*NSLog(@"TO LOGIN...");
 if (pbs!=nil) {
 free_pbsock(pbs);
 }
[self performSegueWithIdentifier:@"unwindToStream" sender:self];
});*/

//SUCCESS,RESPONSE,CONFIG_GET,STRING

-(void) listenForEvents {
    pbmsg * m = recv_pbmsg(pbs);
    if (m==NULL) {
        NSLog(@"CONNECTION CLOSED UNEXPECTEDLY");
        if (pbs!=nil) {
            free_pbsock(pbs);
            pbs=nil;
        }
        return;
    }
    if ((m->pbmsg_type ^ (PBMSG_CONFIG_SET | PBMSG_STRING | PBMSG_RESPONSE | PBMSG_SUCCESS))==0) {
        //just set something... lets check it?
    }
    if ((m->pbmsg_type ^  (PBMSG_SUCCESS | PBMSG_RESPONSE | PBMSG_CONFIG_GET | PBMSG_STRING))==0) {
        config = [self parseConfig:[NSString stringWithUTF8String:m->pbmsg]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableview reloadData];
        });
    } else {
        //fprintf(stderr,"WTF\n");
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
}

- (IBAction)touchDone:(id)sender {
    [_doneButton setEnabled:false];
    if (pbs!=NULL) {
        free_pbsock(pbs);
        pbs=NULL;
    }
    [self performSegueWithIdentifier:@"segueToStream" sender:self];
}

-(void) connect:(int)retries {
    fprintf(stderr, "pbstate: Connecting...");
#ifdef PBSSL
    SSL_CTX* ctx;
    OpenSSL_add_ssl_algorithms();
    SSL_load_error_strings();
    ctx = SSL_CTX_new (SSLv23_client_method());
    NSLog(@"Connecting to server ... %@ %s %@",pubsubserver_server,[[loginInfo objectForKey:@"server"] UTF8String],[loginInfo objectForKey:@"server"]);
    pbs = connect_to_server_with_key([pubsubserver_server UTF8String],pubsubserver_port,ctx,[pubsubserver_secret UTF8String]);
#else
    pbs = connect_to_server_with_key(pbhost,port,key);
#endif
    
    if (pbs==NULL) {
        if (retries >=0 ) {
            NSLog(@"RETRY RETRY");
            sleep(1);
            return [self connect:retries-1];
        }
        //TODO error handling!!!!
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToStream" sender:self];
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    pbmsg * m = new_pbmsg_from_str_wtype("all", PBMSG_CONFIG_GET | PBMSG_STRING | PBMSG_REQUEST);
    send_pbmsg(pbs, m);
    free_pbmsg(m);
    
    
    
    
}


-(IBAction)uploadTapped:(id)sender {
    NSLog(@"Upload tapped");
    if ([[rc.ui_sound_name text] isEqualToString:@""]) {
        [rc.ui_sound_name colorRed];
        [self toastStatus:false Message:@"Sound clip name cannot be blank!"];
        return ;
    }
    
    [rc.ui_sound_name colorBlue];
    [self uploadFile:outputFileURL withFilename:[rc.ui_sound_name text] withCallBack:^(BOOL ok) {
        NSLog(@"Upload done?");
        dispatch_async(dispatch_get_main_queue(), ^{
            sounds=nil;
            [_tableview reloadData];
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sounds = [self pbserverLSWithType:@"mp3"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableview reloadData];
            });
        });
    }];
    /*^
     */
}


- (IBAction)playTapped:(id)sender {
    if (recorder.recording) {
        [self stopRecording];
    }
    [rc.progressView setProgressTintColor:[UIColor PBBlue]];
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    if(error) {
        NSLog(@"Error: AudioSession cannot use speakers");
    }
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:recorder.url error:nil];
        [player setDelegate:self];
        [player play];
        
        if (record_timer!=nil) {
            [record_timer invalidate];
            record_timer=nil;
        }
        record_timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

-(void)startRecording {
    
    [rc.progressView setProgressTintColor:[UIColor PBRed]];
    if (record_timer!=nil) {
        [record_timer invalidate];
        record_timer=nil;
    }
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    
    // Start recording
    [recorder record];
    record_timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    [rc.ui_record_button setTitle:@"Record Done" forState:UIControlStateNormal];
    
    [rc.ui_play_button setEnabled:NO];
}

-(void)stopRecording {
    
    if (record_timer!=nil) {
        [record_timer invalidate];
        record_timer=nil;
    }
    // stop recording
    [recorder stop];
    [rc.ui_record_button setTitle:@"Record" forState:UIControlStateNormal];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    [rc.ui_play_button setEnabled:YES];
}

//audio delegates
- (IBAction)recordTapped:(id)sender {
    // Stop the audio player before recording
    if (player.playing) {
        [player stop];
    }
    
    if (!recorder.recording) {
        [self startRecording];
    } else {
        [self stopRecording];
    }
    
    //[_stopButton setEnabled:YES];
}

- (void)updateProgress {
    // Update the slider about the music time
    if([recorder isRecording]) {
        [rc.progressView setProgress:recorder.currentTime/SOUND_MAX_RECORD];
        if (recorder.currentTime>SOUND_MAX_RECORD) {
            [self recordTapped:nil];
        }
    } else if ([player isPlaying]) {
        [rc.progressView setProgress:player.currentTime/SOUND_MAX_RECORD];
    }
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Done"
     message: @"Finish playing the recording!"
     delegate: nil
     cancelButtonTitle:@"OK"
     otherButtonTitles:nil];
     [alert show];*/
    
    if (record_timer!=nil) {
        [record_timer invalidate];
        record_timer=nil;
    }
}


- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)avrecorder successfully:(BOOL)flag{
    //[_recordPauseButton setTitle:@"Record" forState:UIControlStateNormal];
    
    [rc.ui_play_button setEnabled:YES];
}


@end
