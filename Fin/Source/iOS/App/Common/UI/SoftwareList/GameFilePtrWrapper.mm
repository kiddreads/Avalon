// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "GameFilePtrWrapper.h"

#import "Common/FileUtil.h"
#import "FoundationStringUtil.h"
#import "UICommon/GameFile.h"

@implementation GameFilePtrWrapper

+ (instancetype)wrapperWithPath:(NSString*)path {
  if (!path.length) return nil;
  GameFilePtrWrapper* w = [[GameFilePtrWrapper alloc] init];
  w.gameFile = std::make_shared<UICommon::GameFile>(FoundationToCppString(path));
  if (!w.gameFile->IsValid()) return nil;
  return w;
}

- (NSString*)displayName {
  if (!_gameFile) return @"";
  return CppToFoundationString(
      _gameFile->GetName(UICommon::GameFile::Variant::LongAndPossiblyCustom));
}

- (UIImage*)coverImage {
  if (!_gameFile) return [UIImage imageNamed:@"NoCover"];
  const UICommon::GameCover& cover = _gameFile->GetCoverImage();
  if (cover.buffer.empty()) {
    return [UIImage imageNamed:@"NoCover"];
  }
  NSData* data = [NSData dataWithBytes:cover.buffer.data() length:cover.buffer.size()];
  UIImage* image = [UIImage imageWithData:data];
  return image ?: [UIImage imageNamed:@"NoCover"];
}

- (NSString*)filePath {
  if (!_gameFile) return @"";
  return CppToFoundationString(_gameFile->GetFilePath());
}

- (NSString*)gameID {
  if (!_gameFile) return @"";
  return CppToFoundationString(_gameFile->GetGameID());
}

- (NSInteger)discNumber {
  return _gameFile ? static_cast<NSInteger>(_gameFile->GetDiscNumber()) : 0;
}

- (BOOL)isNKit {
  return _gameFile ? _gameFile->IsNKit() : NO;
}

- (BOOL)deleteFile {
  if (!_gameFile) return NO;
  return File::Delete(_gameFile->GetFilePath());
}

@end
