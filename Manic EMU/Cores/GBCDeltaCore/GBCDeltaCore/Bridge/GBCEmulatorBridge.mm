//
//  GBCEmulatorBridge.m
//  GBCDeltaCore
//
//  Created by Riley Testut on 4/11/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

#import "GBCEmulatorBridge.h"

// Cheats
#import "GBCCheat.h"

// Inputs
#include "GBCInputGetter.h"

// DeltaCore
#import <GBCDeltaCore/GBCDeltaCore.h>
#import <ManicEmuCore/DeltaCore.h>
#import <ManicEmuCore/ManicEmuCore-Swift.h>

// HACKY. Need to access private members to ensure save data loads properly.
// This redefines the private members as public so we can use them.
#define private public

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"

// Gambatte
#include "gambatte.h"
#include "cpu.h"

#pragma clang diagnostic pop

// Undefine private.
#undef private

@interface GBCEmulatorBridge () <MANCEmulatorBase>

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;
@property (nonatomic, copy, nonnull, readonly) NSURL *gameSaveDirectory;

@property (nonatomic, assign, readonly) std::shared_ptr<gambatte::GB> gambatte;
@property (nonatomic, assign, readonly) std::shared_ptr<GBCInputGetter> inputGetter;

@property (nonatomic, readonly) NSMutableSet<GBCCheat *> *cheats;

@end

@implementation GBCEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static GBCEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _gameSaveDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        
        std::shared_ptr<GBCInputGetter> inputGetter(new GBCInputGetter());
        _inputGetter = inputGetter;
        
        std::shared_ptr<gambatte::GB> gambatte(new gambatte::GB());
        gambatte->setInputGetter(inputGetter.get());
        gambatte->setSaveDir(_gameSaveDirectory.fileSystemRepresentation);
        
        _gambatte = gambatte;
        
        _cheats = [NSMutableSet set];
    }
    
    return self;
}

- (void)applyPalette:(const unsigned long[3][4])palette {
    // 遍历三个调色板 (0=BG, 1=SP1, 2=SP2)
    for (int palNum = 0; palNum < 3; palNum++) {
        // 遍历每个调色板的四个颜色
        for (int colorNum = 0; colorNum < 4; colorNum++) {
            // 设置调色板颜色
            _gambatte->setDmgPaletteColor(palNum, colorNum, palette[palNum][colorNum]);
        }
    }
}

- (void)setExtraParameters:(NSDictionary<NSString *,id> *)paramaters {
    NSNumber *palette = paramaters[@"palette"];
    if ([palette isKindOfClass:NSNumber.class]) {
        NSInteger pInt = palette.integerValue;
        if (pInt == 0) {
            // 重置调色板
            unsigned long colors[3][4] = {
                {0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000},
                {0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000},
                {0xFFFFFF, 0xAAAAAA, 0x555555, 0x000000}
            };
            [self applyPalette:colors];
        } else if(pInt == 1) {
            unsigned long colors[3][4] = { // Original Game Boy
                {0x578200, 0x317400, 0x005121, 0x00420C},
                {0x578200, 0x317400, 0x005121, 0x00420C},
                {0x578200, 0x317400, 0x005121, 0x00420C}
            };
            [self applyPalette:colors];
        } else if(pInt == 2) {
            unsigned long colors[3][4] = { //Light
                {0x01CBDF, 0x01B6D5, 0x269BAD, 0x00778D},
                {0x01CBDF, 0x01B6D5, 0x269BAD, 0x00778D},
                {0x01CBDF, 0x01B6D5, 0x269BAD, 0x00778D}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 3) {
            unsigned long colors[3][4] = { //Pocket
                {0xA7B19A, 0x86927C, 0x535f49, 0x2A3325},
                {0xA7B19A, 0x86927C, 0x535f49, 0x2A3325},
                {0xA7B19A, 0x86927C, 0x535f49, 0x2A3325}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 4) {
            unsigned long colors[3][4] = { //Blue
                {0xFFFFFF, 0x63A5FF, 0x0000FF, 0x000000},
                {0xFFFFFF, 0xFF8484, 0x943A3A, 0x000000},
                {0xFFFFFF, 0x7BFF31, 0x008400, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 5) {
            unsigned long colors[3][4] = { //Brown
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000},
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000},
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 6) {
            unsigned long colors[3][4] = { //Dark Blue
                {0xFFFFFF, 0x8C8CDE, 0x52528C, 0x000000},
                {0xFFFFFF, 0xFF8484, 0x943A3A, 0x000000},
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 7) {
            unsigned long colors[3][4] = { //Dark Brown
                {0xFFE6C5, 0xCE9C84, 0x846B29, 0x5A3108},
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000},
                {0xFFFFFF, 0xFFAD63, 0x843100, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 8) {
            unsigned long colors[3][4] = { //Dark Green
                {0xFFFFFF, 0x7BFF31, 0x0063C5, 0x000000},
                {0xFFFFFF, 0xFF8484, 0x943A3A, 0x000000},
                {0xFFFFFF, 0xFF8484, 0x943A3A, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 9) {
            unsigned long colors[3][4] = { //Grayscale
                {0xFFFFFF, 0xA5A5A5, 0x525252, 0x000000},
                {0xFFFFFF, 0xA5A5A5, 0x525252, 0x000000},
                {0xFFFFFF, 0xA5A5A5, 0x525252, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 10) {
            unsigned long colors[3][4] = { //Green
                {0xFFFFFF, 0x52FF00, 0xFF4200, 0x000000},
                {0xFFFFFF, 0x52FF00, 0xFF4200, 0x000000},
                {0xFFFFFF, 0x52FF00, 0xFF4200, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 11) {
            unsigned long colors[3][4] = { //Inverted
                {0x000000, 0x008484, 0xFFDE00, 0xFFFFFF},
                {0x000000, 0x008484, 0xFFDE00, 0xFFFFFF},
                {0x000000, 0x008484, 0xFFDE00, 0xFFFFFF}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 12) {
            unsigned long colors[3][4] = { //Orange
                {0xFFFFFF, 0xFFFF00, 0xFF0000, 0x000000},
                {0xFFFFFF, 0xFFFF00, 0xFF0000, 0x000000},
                {0xFFFFFF, 0xFFFF00, 0xFF0000, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 13) {
            unsigned long colors[3][4] = { //Pastel Mix
                {0xFFFFA5, 0xFF9494, 0x9494FF, 0x000000},
                {0xFFFFA5, 0xFF9494, 0x9494FF, 0x000000},
                {0xFFFFA5, 0xFF9494, 0x9494FF, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 14) {
            unsigned long colors[3][4] = { //Red
                {0xFFFFFF, 0xFF8484, 0x943A3A, 0x000000},
                {0xFFFFFF, 0x7BFF31, 0x008400, 0x000000},
                {0xFFFFFF, 0x63A5FF, 0x0000FF, 0x000000}
            };
            [self applyPalette:colors];
            
        } else if(pInt == 15) {
            unsigned long colors[3][4] = { //Yellow
                {0xFFFFFF, 0xFFFF00, 0x7B4A00, 0x000000},
                {0xFFFFFF, 0x63A5FF, 0x0000FF, 0x000000},
                {0xFFFFFF, 0x7BFF31, 0x008400, 0x000000}
            };
            [self applyPalette:colors];
        }
    }
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    gambatte::LoadRes result = self.gambatte->load(gameURL.fileSystemRepresentation, gambatte::GB::MULTICART_COMPAT);
    NSLog(@"Started Gambatte with result: %@", @(result));
}

- (void)stop
{
    self.gambatte->reset();
}

- (void)pause
{
    
}

- (void)resume
{
    
}

#pragma mark - Game Loop -

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    size_t samplesCount = 35112;
    
    // Each audio frame = 2 16-bit channel frames (32-bits total per audio frame).
    // Additionally, Gambatte may return up to 2064 audio samples more than requested, so we need to add 2064 to the requested audioBuffer size.
    gambatte::uint_least32_t audioBuffer[samplesCount + 2064];
    size_t samples = samplesCount;
    
    while (self.gambatte->runFor((gambatte::uint_least32_t *)self.videoRenderer.videoBuffer, 160, audioBuffer, samples) == -1)
    {
        [self.audioRenderer.audioBuffer writeBuffer:(uint8_t *)audioBuffer size:samples * 4];
        
        samples = samplesCount;
    }
    
    [self.audioRenderer.audioBuffer writeBuffer:(uint8_t *)audioBuffer size:samples * 4];
    
    if (processVideo)
    {
        [self.videoRenderer processFrame];
    }
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input value:(double)value playerIndex:(NSInteger)playerIndex
{
    self.inputGetter->activateInput((unsigned)input);
}

- (void)deactivateInput:(NSInteger)input playerIndex:(NSInteger)playerIndex
{
    self.inputGetter->deactivateInput((unsigned)input);
}

- (void)resetInputs
{
    self.inputGetter->resetInputs();
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)URL
{
    self.gambatte->saveState(NULL, 0, URL.fileSystemRepresentation);
}

- (void)loadSaveStateFromURL:(NSURL *)URL
{
    self.gambatte->loadState(URL.fileSystemRepresentation);
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)URL
{
    // Cannot directly set the URL for saving game saves, so we save it to the temporary directory and then move it to the correct place.
    
    self.gambatte->saveSavedata();
    
    NSString *gameFilename = self.gameURL.lastPathComponent.stringByDeletingPathExtension;
    NSURL *temporarySaveURL = [self.gameSaveDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sav", gameFilename]];
    
    if ([self safelyCopyFileAtURL:temporarySaveURL toURL:URL])
    {
        NSURL *rtcURL = [[URL URLByDeletingPathExtension] URLByAppendingPathExtension:@"rtc"];
        NSURL *temporaryRTCURL = [self.gameSaveDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.rtc", gameFilename]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryRTCURL.path])
        {
            [self safelyCopyFileAtURL:temporaryRTCURL toURL:rtcURL];
        }
    }
}

- (void)loadGameSaveFromURL:(NSURL *)URL
{
    NSString *gameFilename = self.gameURL.lastPathComponent.stringByDeletingPathExtension;
    NSURL *temporarySaveURL = [self.gameSaveDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sav", gameFilename]];
    
    if ([self safelyCopyFileAtURL:URL toURL:temporarySaveURL])
    {
        NSURL *rtcURL = [[URL URLByDeletingPathExtension] URLByAppendingPathExtension:@"rtc"];
        NSURL *temporaryRTCURL = [self.gameSaveDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.rtc", gameFilename]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:rtcURL.path])
        {
            [self safelyCopyFileAtURL:rtcURL toURL:temporaryRTCURL];
        }
    }
    
    // Hacky pointer manipulation to obtain the underlying CPU struct, then explicitly call loadSavedata().
    gambatte::CPU *cpu = (gambatte::CPU *)self.gambatte->p_;
    (*cpu).loadSavedata();
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(CheatType)type
{
    NSArray<NSString *> *codes = [cheatCode componentsSeparatedByString:@"\n"];
    for (NSString *code in codes)
    {
        GBCCheat *cheat = [[GBCCheat alloc] initWithCode:code type:type];
        if (cheat == nil)
        {
            return NO;
        }
        
        [self.cheats addObject:cheat];
    }
    
    return YES;
}

- (void)resetCheats
{
    [self.cheats removeAllObjects];
    
    self.gambatte->setGameGenie("");
    self.gambatte->setGameShark("");
}

- (void)updateCheats
{
    NSMutableString *gameGenieCodes = [NSMutableString string];
    NSMutableString *gameSharkCodes = [NSMutableString string];
    
    for (GBCCheat *cheat in self.cheats.copy)
    {
        NSMutableString *codes = nil;
        
        if ([cheat.type isEqualToString:CheatTypeGameGenie])
        {
            codes = gameGenieCodes;
        }
        else if ([cheat.type isEqualToString:CheatTypeGameShark])
        {
            codes = gameSharkCodes;
        }
        
        [codes appendString:cheat.code];
        [codes appendString:@";"];
    }
    
    self.gambatte->setGameGenie([gameGenieCodes UTF8String]);
    self.gambatte->setGameShark([gameSharkCodes UTF8String]);
}

#pragma mark - Private -

- (BOOL)safelyCopyFileAtURL:(NSURL *)URL toURL:(NSURL *)destinationURL
{
    NSError *error = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path])
    {
        if (![[NSFileManager defaultManager] removeItemAtPath:destinationURL.path error:&error])
        {
            NSLog(@"%@", error);
            return NO;
        }
    }
    
    // Copy saves to ensure data is never lost.
    if (![[NSFileManager defaultManager] copyItemAtURL:URL toURL:destinationURL error:&error])
    {
        NSLog(@"%@", error);
        return NO;
    }
    
    return YES;
}

#pragma mark - Getters/Setters -

- (NSTimeInterval)frameDuration
{
    return (1.0 / 60.0);
}

@end
