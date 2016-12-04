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

- (IBAction)touchDone:(id)sender {
    [_doneButton setEnabled:false];
    [self performSegueWithIdentifier:@"segueToSettings" sender:self];
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
    [scc.selectButton setTitle:label forState:UIControlStateNormal];
    
    return cell;
}


//END TABLE VIEW DATASOURCE


- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] init] ;
}
@end
