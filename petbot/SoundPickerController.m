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
    NSString * fid;
    NSString * name;
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
    NSString * label = [[[sounds objectAtIndex:indexPath.row] objectAtIndex:1] stringByDeletingPathExtension];
    
    scc->fid = [[sounds objectAtIndex:indexPath.row] objectAtIndex:0];
    scc->fn = [[sounds objectAtIndex:indexPath.row] objectAtIndex:1];
    [scc.ui_label setText:label];
    [scc.removeButton addTarget:self action:@selector(removeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    //[scc.selectButton setTitle:label forState:UIControlStateNormal];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"SELECTED!");
    SoundClipCell  * scc = [tableView cellForRowAtIndexPath:indexPath];
    fid=scc->fid;
    name=scc->fn;
    
    [self performSegueWithIdentifier:@"segueToSettings" sender:self];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"segueToSettings"]) {
        SoundViewController * svc = [segue destinationViewController];
        [svc setSoundFID:fid name:name];
    }
}


//END TABLE VIEW DATASOURCE
- (void)removeButtonPressed:(id)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:buttonPosition];
    if (indexPath != nil) {
        NSString * fid = [[sounds objectAtIndex:indexPath.row] objectAtIndex:0];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self removeFileFID:fid];
            sounds = [self pbserverLSWithType:@"mp3"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableView reloadData];
            });
        });
    }
}

- (IBAction)touchDone:(id)sender {
    [_doneButton setEnabled:false];
    [self performSegueWithIdentifier:@"segueToSettings" sender:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLogin];
    self.tableView.tableFooterView = [[UIView alloc] init] ;
}
@end
