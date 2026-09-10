// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "CpuEngineViewController.h"

#import <vector>

#import "Core/Config/MainSettings.h"
#import "Core/PowerPC/PowerPC.h"

#import "CpuEngineCell.h"
#import "LocalizationUtil.h"

@interface CpuEngineViewController ()

@end

@implementation CpuEngineViewController {
  NSInteger _lastSelected;
  std::vector<PowerPC::CPUCore> _cores_filtered;
  std::span<const PowerPC::CPUCore> _cores;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  const auto all = PowerPC::AvailableCPUCores();
  _cores_filtered.clear();
  for (size_t i = 0; i < all.size(); i++) {
    const auto c = all[i];
    if (c == PowerPC::CPUCore::Interpreter || c == PowerPC::CPUCore::CachedInterpreter ||
        c == PowerPC::CPUCore::InlineCachedInterpreter)
      _cores_filtered.push_back(c);
  }
  if (_cores_filtered.empty()) {
    _cores_filtered.push_back(PowerPC::CPUCore::Interpreter);
    _cores_filtered.push_back(PowerPC::CPUCore::CachedInterpreter);
  }
  _cores = _cores_filtered;

  const auto currentCore = Config::Get(Config::MAIN_CPU_CORE);
  _lastSelected = 0;
  for (NSInteger i = 0; i < static_cast<NSInteger>(_cores.size()); i++) {
    if (currentCore == _cores[i]) {
      _lastSelected = i;
      break;
    }
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return _cores.size();
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  CpuEngineCell* cell = [tableView dequeueReusableCellWithIdentifier:@"EngineCell" forIndexPath:indexPath];
  
  NSString* cpuCore;
  switch (_cores[indexPath.row]) {
    case PowerPC::CPUCore::Interpreter:
      cpuCore = @"Safe";
      break;
    case PowerPC::CPUCore::CachedInterpreter:
      cpuCore = @"Fast";
      break;
    case PowerPC::CPUCore::InlineCachedInterpreter:
      cpuCore = @"Fastest";
      break;
    default:
      cpuCore = @"Error";
      break;
  }
  
  cell.engineCell.text = DOLCoreLocalizedString(cpuCore);
  
  if (indexPath.row == _lastSelected) {
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
  } else {
    cell.accessoryType = UITableViewCellAccessoryNone;
  }
  
  return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  if (_lastSelected != indexPath.row) {
    Config::SetBaseOrCurrent(Config::MAIN_CPU_CORE, _cores[indexPath.row]);

    CpuEngineCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    CpuEngineCell* oldCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_lastSelected inSection:0]];
    oldCell.accessoryType = UITableViewCellAccessoryNone;
    
    _lastSelected = indexPath.row;
  }
  
  [tableView deselectRowAtIndexPath:indexPath animated:true];
}

@end
