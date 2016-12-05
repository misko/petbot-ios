//
//  SoundPickerController.m
//  petbot
//
//  Created by Misko Dzamba on 2016-12-04.
//  Copyright © 2016 PetBot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SoundPickerController.h"
#import "SoundClipCell.h"

@interface SoundPickerController () {
}

@end

@implementation SoundPickerController
//TABLE VIEW DATASOURCE

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Select sound clip";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSLog(@"COUNT OF SOUNDS %d\n",[sounds count]);
    return [sounds count];
}

/*- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath {
    return @"SoundClipCell";
}*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    NSString *cellIdentifier = @"SoundClipCell";
    NSLog(@"GETTING CELL %d\n",indexPath.row);
    
    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    SoundClipCell * scc = cell;
    NSString * label = [[sounds objectAtIndex:indexPath.row] objectAtIndex:1];
    
    scc->fid = [[sounds objectAtIndex:indexPath.row] objectAtIndex:0];
    scc->fn = [[sounds objectAtIndex:indexPath.row] objectAtIndex:1];
    [scc.ui_label setText:label];
    //[scc.selectButton setTitle:label forState:UIControlStateNormal];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"SELECTED!");
    SoundClipCell  * scc = [tableView cellForRowAtIndexPath:indexPath];
    [[NSUserDefaults standardUserDefaults] setValue:scc->fid forKey:@"alert_sound_fid"];
    [[NSUserDefaults standardUserDefaults] setValue:scc->fn forKey:@"alert_sound_fn"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self performSegueWithIdentifier:@"segueToSettings" sender:self];
    
}


//END TABLE VIEW DATASOURCE


- (IBAction)touchDone:(id)sender {
    [_doneButton setEnabled:false];
    [self performSegueWithIdentifier:@"segueToSettings" sender:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] init] ;
}
@end
