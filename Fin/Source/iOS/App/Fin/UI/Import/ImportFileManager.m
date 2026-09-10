// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "ImportFileManager.h"

#import "Swift.h"

#import "GameFileCacheManager.h"

@implementation ImportFileManager

+ (ImportFileManager*)shared {
  static ImportFileManager* sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (void)importFileAtUrl:(NSURL*)url {
  BOOL didStartAccess = [url startAccessingSecurityScopedResource];
  
  NSString* sourcePath = [url path];
  NSString* softwareFolder = [UserFolderUtil getSoftwareFolder];
  NSString* destinationPath = [softwareFolder stringByAppendingPathComponent:[sourcePath lastPathComponent]];
  
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:softwareFolder]) {
    [fileManager createDirectoryAtPath:softwareFolder withIntermediateDirectories:YES attributes:nil error:nil];
  }
  
  if (![fileManager fileExistsAtPath:destinationPath]) {
    NSError* error = nil;
    [fileManager copyItemAtPath:sourcePath toPath:destinationPath error:&error];
  }
  
  if (didStartAccess) {
    [url stopAccessingSecurityScopedResource];
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:DOLImportFileFinishedNotification object:self userInfo:nil];
}

@end
