// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "DOLGeckoBridge.h"

#import <vector>

#import "Common/FileUtil.h"
#import "Common/IniFile.h"

#import "Core/ConfigManager.h"
#import "Core/GeckoCode.h"
#import "Core/GeckoCodeConfig.h"
#import "Core/Core.h"
#import "Core/System.h"

#import "FoundationStringUtil.h"

// MARK: - DOLGeckoCode Implementation

@implementation DOLGeckoCode
@end

// MARK: - Static State

static std::vector<Gecko::GeckoCode> s_codes;
static std::string s_gameId;
static std::string s_gametdbId;
static u16 s_revision;

// MARK: - DOLGeckoBridge Implementation

@implementation DOLGeckoBridge

+ (void)loadCodesForCurrentGame {
  s_gameId = SConfig::GetInstance().GetGameID();
  s_gametdbId = SConfig::GetInstance().GetGameTDBID();
  s_revision = SConfig::GetInstance().GetRevision();
  
  if (s_gameId.empty()) {
    s_codes.clear();
    return;
  }
  
  Common::IniFile gameIniLocal;
  gameIniLocal.Load(File::GetUserPath(D_GAMESETTINGS_IDX) + s_gameId + ".ini");
  
  const Common::IniFile gameIniDefault = SConfig::LoadDefaultGameIni(s_gameId, s_revision);
  
  s_codes = Gecko::LoadCodes(gameIniDefault, gameIniLocal);
}

+ (void)loadCodesForGameId:(NSString *)gameId gametdbId:(NSString *)gametdbId revision:(int)revision {
  s_gameId = FoundationToCppString(gameId);
  s_gametdbId = FoundationToCppString(gametdbId);
  s_revision = (u16)revision;
  
  if (s_gameId.empty()) {
    s_codes.clear();
    return;
  }
  
  Common::IniFile gameIniLocal;
  gameIniLocal.Load(File::GetUserPath(D_GAMESETTINGS_IDX) + s_gameId + ".ini");
  
  const Common::IniFile gameIniDefault = SConfig::LoadDefaultGameIni(s_gameId, s_revision);
  
  s_codes = Gecko::LoadCodes(gameIniDefault, gameIniLocal);
}

+ (NSArray<DOLGeckoCode *> *)codes {
  NSMutableArray<DOLGeckoCode *>* result = [NSMutableArray arrayWithCapacity:s_codes.size()];
  
  for (size_t i = 0; i < s_codes.size(); i++) {
    const auto& code = s_codes[i];
    
    DOLGeckoCode* geckoCode = [[DOLGeckoCode alloc] init];
    geckoCode.name = CppToFoundationString(code.name);
    geckoCode.creator = CppToFoundationString(code.creator);
    
    if (!code.notes.empty()) {
      // Join notes with newlines
      NSMutableString* notesStr = [NSMutableString string];
      for (size_t j = 0; j < code.notes.size(); j++) {
        if (j > 0) [notesStr appendString:@"\n"];
        [notesStr appendString:CppToFoundationString(code.notes[j])];
      }
      geckoCode.notes = notesStr;
    }
    
    geckoCode.enabled = code.enabled;
    geckoCode.userDefined = code.user_defined;
    geckoCode.codeIndex = i;
    
    [result addObject:geckoCode];
  }
  
  return result;
}

+ (NSInteger)codeCount {
  return s_codes.size();
}

+ (void)setEnabled:(BOOL)enabled forCodeAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)s_codes.size()) return;
  
  s_codes[index].enabled = enabled;
  [self saveCodes];
}

+ (void)saveCodes {
  if (s_gameId.empty()) return;
  
  const auto iniPath = std::string(File::GetUserPath(D_GAMESETTINGS_IDX)).append(s_gameId).append(".ini");
  
  Common::IniFile gameIniLocal;
  gameIniLocal.Load(iniPath);
  Gecko::SaveCodes(gameIniLocal, s_codes);
  gameIniLocal.Save(iniPath);
}

+ (void)downloadCodesWithCompletion:(void (^)(BOOL success, NSInteger downloadedCount, NSInteger addedCount, NSString * _Nullable errorMessage))completion {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    bool success;
    std::vector<Gecko::GeckoCode> downloadedCodes = Gecko::DownloadCodes(s_gametdbId, &success);
    
    if (!success) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(NO, 0, 0, @"Failed to download codes.");
      });
      return;
    }
    
    if (downloadedCodes.empty()) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(NO, 0, 0, @"No codes found for this game.");
      });
      return;
    }
    
    size_t addedCount = 0;
    
    for (const auto& code : downloadedCodes) {
      auto it = std::find(s_codes.begin(), s_codes.end(), code);
      
      if (it == s_codes.end()) {
        s_codes.push_back(code);
        addedCount++;
      }
    }
    
    [self saveCodes];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(YES, downloadedCodes.size(), addedCount, nil);
    });
  });
}

+ (BOOL)addCodeWithName:(NSString *)name creator:(NSString *)creator notes:(nullable NSString *)notes codeLines:(NSArray<NSString *> *)codeLines {
  Gecko::GeckoCode newCode;
  newCode.name = FoundationToCppString(name);
  newCode.creator = FoundationToCppString(creator);
  newCode.user_defined = true;
  newCode.enabled = false;
  
  if (notes) {
    newCode.notes.push_back(FoundationToCppString(notes));
  }
  
  for (NSString* line in codeLines) {
    Gecko::GeckoCode::Code codeLine;
    std::string lineStr = FoundationToCppString(line);
    
    // Parse the line (format: XXXXXXXX YYYYYYYY)
    if (lineStr.length() >= 17) {
      codeLine.address = strtoul(lineStr.substr(0, 8).c_str(), nullptr, 16);
      codeLine.data = strtoul(lineStr.substr(9, 8).c_str(), nullptr, 16);
      newCode.codes.push_back(codeLine);
    }
  }
  
  if (newCode.codes.empty()) {
    return NO;
  }
  
  s_codes.push_back(newCode);
  [self saveCodes];
  
  return YES;
}

+ (void)deleteCodeAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)s_codes.size()) return;
  
  s_codes.erase(s_codes.begin() + index);
  [self saveCodes];
}

+ (BOOL)isGameLoaded {
  return Core::IsRunning(Core::System::GetInstance()) && !s_gameId.empty();
}

+ (NSString *)currentGameId {
  return CppToFoundationString(s_gameId);
}

+ (NSString *)currentGameName {
  // Get the game name from the running instance
  const std::string& title = SConfig::GetInstance().GetTitleName();
  if (!title.empty()) {
    return CppToFoundationString(title);
  }
  return CppToFoundationString(s_gameId);
}

@end
