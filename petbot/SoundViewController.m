//
//  SetupViewController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-05-09.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import "RecordCell.h"

#import "SwitchCell.h"
#import "ValueCell.h"
#import "ButtonCell.h"
#import "SliderCell.h"
#import "SoundViewController.h"
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
    
    if ([cellIdentifier isEqualToString:@"TitleCell"] || [cellIdentifier isEqualToString:@"ButtonCell"] || [cellIdentifier isEqualToString:@"SwitchCell"] || [cellIdentifier isEqualToString:@"ValueCell"]) {
        cell.textLabel.text = [cell_labels objectAtIndex:indexPath.row];
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
            [sc setEditing:false];
        }
    }

    //system stuff
    if ([cell_name isEqualToString:@"version"]) {
        if ([config objectForKey:@"version"]!=nil) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@\t%@",[cell_labels objectAtIndex:indexPath.row],[config objectForKey:@"version"]];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%@\t%@",[cell_labels objectAtIndex:indexPath.row],@"?"];
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
    
    
    if ([cellIdentifier isEqualToString:@"SwitchCell"]) {
        SwitchCell * sc = cell;
        [sc.ui_switch addTarget:self action:@selector(changeSwitch:) forControlEvents:UIControlEventValueChanged];
        //[ addTarget:<#(nullable id)#> action:<#(nonnull SEL)#> forControlEvents:<#(UIControlEvents)#>];
    }
    
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

- (void)viewDidLoad {
    [super viewDidLoad];
    config = [NSMutableDictionary dictionary];
    [self setupLogin];
    [self connect:3];
    labels_selfie = [NSArray arrayWithObjects:@"take selfie automatically",@"selfie timeout",@"selfie length",@"selfie sensitivity",@"",@"motion sensitivity",@"", nil];
    types_selfie = [NSArray arrayWithObjects:@"SwitchCell",@"ValueCell",@"ValueCell",@"TitleCell",@"SliderCell",@"TitleCell",@"SliderCell", nil];
    names_selfie = [NSArray arrayWithObjects:@"selfie_enable",@"selfie_timeout",@"selfie_length",@"selfie_sensitivity",@"selfie_sensitivity_slider",@"motion_sensitivity",@"motion_sensitivity_slider",nil];
    labels_sound = [NSArray arrayWithObjects:@"Volume",@"",@"selfie sound",@"alert sound",@"record",nil];
    types_sound = [NSArray arrayWithObjects:@"TitleCell",@"SliderCell",@"ButtonCell",@"ButtonCell",@"RecordCell", nil];
    names_sound = [NSArray arrayWithObjects:@"volume",@"volume_slider",@"selfie_sound",@"alert_sound",@"record", nil];
    
    labels_system = [NSArray arrayWithObjects:@"LED",@"update",@"Version",@"help", nil];
    types_system = [NSArray arrayWithObjects:@"SwitchCell",@"ButtonCell",@"TitleCell",@"ButtonCell", nil];
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

@end
