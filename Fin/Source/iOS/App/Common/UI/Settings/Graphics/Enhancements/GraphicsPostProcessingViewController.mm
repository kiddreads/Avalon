// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "GraphicsPostProcessingViewController.h"

#import "DOLConfigBridge.h"

#import "LocalizationUtil.h"

static NSString* const kShaderCellId = @"ShaderCell";
static NSString* const kDefaultShaderName = @"default_pre_post_process";

@interface GraphicsPostProcessingViewController ()
@property (nonatomic, copy) NSArray<NSString*>* shaderNames;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation GraphicsPostProcessingViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self rebuildShaderList];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self rebuildShaderList];
  [self.tableView reloadData];
}

- (void)rebuildShaderList {
  NSMutableArray<NSString*>* names = [NSMutableArray arrayWithObject:DOLCoreLocalizedString(@"None")];
  NSString* dirPath = [DOLConfigBridge shadersDirectoryPath];
  if (dirPath.length > 0) {
    NSError* err = nil;
    NSArray<NSString*>* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&err];
    if (files) {
      for (NSString* file in files) {
        if (![file.pathExtension isEqualToString:@"glsl"])
          continue;
        NSString* name = file.stringByDeletingPathExtension;
        if (name.length > 0 && ![name isEqualToString:kDefaultShaderName])
          [names addObject:name];
      }
      [names sortUsingComparator:^NSComparisonResult(NSString* a, NSString* b) {
        if (a == names.firstObject) return NSOrderedAscending;
        if (b == names.firstObject) return NSOrderedDescending;
        return [a caseInsensitiveCompare:b];
      }];
    }
  }
  self.shaderNames = names;

  NSString* current = [DOLConfigBridge postProcessingShader];
  if (!current || current.length == 0) {
    self.selectedIndex = 0;
  } else {
    NSInteger idx = [names indexOfObject:current];
    self.selectedIndex = (idx != NSNotFound) ? idx : 0;
  }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return (NSInteger)self.shaderNames.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kShaderCellId forIndexPath:indexPath];
  UILabel* label = cell.textLabel ?: (UILabel*)[cell viewWithTag:1];
  if (label)
    label.text = self.shaderNames[indexPath.row];
  cell.accessoryType = (indexPath.row == self.selectedIndex) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
  return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  if (indexPath.row == self.selectedIndex)
    return;
  self.selectedIndex = indexPath.row;
  NSString* name = (indexPath.row == 0) ? @"" : self.shaderNames[indexPath.row];
  [DOLConfigBridge setPostProcessingShader:name];
  [tableView reloadData];
  [self.navigationController popViewControllerAnimated:YES];
}

@end
