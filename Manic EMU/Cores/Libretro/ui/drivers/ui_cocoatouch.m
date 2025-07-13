/* RetroArch - A frontend for libretro.
 *  Copyright (C) 2011-2016 - Daniel De Matteis
 *
 * RetroArch is free software: you can redistribute it and/or modify it under the terms
 * of the GNU General Public License as published by the Free Software Found-
 * ation, either version 3 of the License, or (at your option) any later version.
 *
 * RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with RetroArch.
 * If not, see <http://www.gnu.org/licenses/>.
 */

#import "LibretroCore.h"

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <boolean.h>

#include <file/file_path.h>
#include <queues/task_queue.h>
#include <string/stdstring.h>
#include <retro_timers.h>

#include "cocoa/cocoa_common.h"
#include "cocoa/apple_platform.h"
#include "../ui_companion_driver.h"
#include "../../audio/audio_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../retroarch.h"
#include "../../tasks/task_content.h"
#include "../../verbosity.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif

#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import <MetricKit/MetricKit.h>
#import <MetricKit/MXMetricManager.h>

#ifdef HAVE_MFI
#import <GameController/GCMouse.h>
#endif

#ifdef HAVE_SDL2
#define SDL_MAIN_HANDLED
#include "SDL.h"
#endif

#if defined(HAVE_COCOA_METAL) || defined(HAVE_COCOATOUCH)
#import "JITSupport.h"
id<ApplePlatform> apple_platform;
#else
static id apple_platform;
#endif
static CFRunLoopObserverRef iterate_observer;

static void ui_companion_cocoatouch_event_command(
      void *data, enum event_command cmd) { }

static struct string_list *ui_companion_cocoatouch_get_app_icons(void)
{
   static struct string_list *list = NULL;
   static dispatch_once_t onceToken;

   dispatch_once(&onceToken, ^{
         union string_list_elem_attr attr;
         attr.i = 0;
         NSDictionary *iconfiles = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
         NSString *primary;
         const char *cstr;
#if TARGET_OS_TV
         primary = iconfiles[@"CFBundlePrimaryIcon"];
#else
         primary = iconfiles[@"CFBundlePrimaryIcon"][@"CFBundleIconName"];
#endif
         list = string_list_new();
         cstr = [primary cStringUsingEncoding:kCFStringEncodingUTF8];
         if (cstr)
            string_list_append(list, cstr, attr);

         NSArray<NSString *> *alts;
#if TARGET_OS_TV
         alts = iconfiles[@"CFBundleAlternateIcons"];
#else
         alts = [iconfiles[@"CFBundleAlternateIcons"] allKeys];
#endif
         NSArray<NSString *> *sorted = [alts sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
         for (NSString *str in sorted)
         {
            cstr = [str cStringUsingEncoding:kCFStringEncodingUTF8];
            if (cstr)
               string_list_append(list, cstr, attr);
         }
      });

   return list;
}

static void ui_companion_cocoatouch_set_app_icon(const char *iconName)
{
   NSString *str;
   if (!string_is_equal(iconName, "Default"))
      str = [NSString stringWithCString:iconName encoding:NSUTF8StringEncoding];
   [[UIApplication sharedApplication] setAlternateIconName:str completionHandler:nil];
}

static uintptr_t ui_companion_cocoatouch_get_app_icon_texture(const char *icon)
{
   static NSMutableDictionary<NSString *, NSNumber *> *textures = nil;
   static dispatch_once_t once;
   dispatch_once(&once, ^{
      textures = [NSMutableDictionary dictionaryWithCapacity:6];
   });

   NSString *iconName = [NSString stringWithUTF8String:icon];
   if (!textures[iconName])
   {
      UIImage *img = [UIImage imageNamed:iconName];
      if (!img)
      {
         RARCH_LOG("could not load %s\n", icon);
         return 0;
      }
      NSData *png = UIImagePNGRepresentation(img);
      if (!png)
      {
         RARCH_LOG("could not get png for %s\n", icon);
         return 0;
      }

      uintptr_t item;
      gfx_display_reset_textures_list_buffer(&item, TEXTURE_FILTER_MIPMAP_LINEAR,
                                             (void*)[png bytes], (unsigned int)[png length], IMAGE_TYPE_PNG,
                                             NULL, NULL);
      textures[iconName] = [NSNumber numberWithUnsignedLong:item];
   }

   return [textures[iconName] unsignedLongValue];
}

static void rarch_draw_observer(CFRunLoopObserverRef observer,
    CFRunLoopActivity activity, void *info)
{
   uint32_t runloop_flags;
   int          ret   = runloop_iterate();

   if (ret == -1)
   {
      ui_companion_cocoatouch_event_command(
            NULL, CMD_EVENT_MENU_SAVE_CURRENT_CONFIG);
//      main_exit(NULL);
//      exit(0); //禁止杀死应用
      return;
   }

   task_queue_check();

   runloop_flags = runloop_get_flags();
   if (!(runloop_flags & RUNLOOP_FLAG_IDLE))
      CFRunLoopWakeUp(CFRunLoopGetMain());
}

void rarch_start_draw_observer(void)
{
   if (iterate_observer && CFRunLoopObserverIsValid(iterate_observer))
       return;

   if (iterate_observer != NULL)
      CFRelease(iterate_observer);
   iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting,
                                              true, 0, rarch_draw_observer, 0);
   CFRunLoopAddObserver(CFRunLoopGetMain(), iterate_observer, kCFRunLoopCommonModes);
}

void rarch_stop_draw_observer(void)
{
    if (!iterate_observer || !CFRunLoopObserverIsValid(iterate_observer))
        return;
    CFRunLoopObserverInvalidate(iterate_observer);
    CFRelease(iterate_observer);
    iterate_observer = NULL;
}

void get_ios_version(int *major, int *minor)
{
   static int savedMajor, savedMinor;
   static dispatch_once_t onceToken;

   dispatch_once(&onceToken, ^ {
         NSArray *decomposed_os_version = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
         if (decomposed_os_version.count > 0)
            savedMajor = (int)[decomposed_os_version[0] integerValue];
         if (decomposed_os_version.count > 1)
            savedMinor = (int)[decomposed_os_version[1] integerValue];
      });
   if (major) *major = savedMajor;
   if (minor) *minor = savedMinor;
}

bool ios_running_on_ipad(void)
{
   return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

/* Input helpers: This is kept here because it needs ObjC */
static void handle_touch_event(NSArray* touches)
{
#if !TARGET_OS_TV
   unsigned i;
   cocoa_input_data_t *apple = (cocoa_input_data_t*)
      input_state_get_ptr()->current_data;
   float scale               = cocoa_screen_get_native_scale();

   if (!apple)
      return;

   apple->touch_count = 0;

   for (i = 0; i < touches.count && (apple->touch_count < MAX_TOUCHES); i++)
   {
      UITouch      *touch = [touches objectAtIndex:i];
      CGPoint       coord = [touch locationInView:[touch view]];
      if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
      {
         apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
         apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
      }
   }
#endif
}

#ifndef HAVE_APPLE_STORE
/* iOS7 Keyboard support */
@interface UIEvent(iOS7Keyboard)
@property(readonly, nonatomic) long long _keyCode;
@property(readonly, nonatomic) _Bool _isKeyDown;
@property(retain, nonatomic) NSString *_privateInput;
@property(nonatomic) long long _modifierFlags;
- (struct __IOHIDEvent { }*)_hidEvent;
@end

@interface UIApplication(iOS7Keyboard)
- (void)handleKeyUIEvent:(UIEvent*)event;
- (id)_keyCommandForEvent:(UIEvent*)event;
@end
#endif

@interface RApplication : UIApplication
@end

@implementation RApplication

#ifndef HAVE_APPLE_STORE
/* Keyboard handler for iOS 7. */

/* This is copied here as it isn't
 * defined in any standard iOS header */
enum
{
   NSAlphaShiftKeyMask                  = 1 << 16,
   NSShiftKeyMask                       = 1 << 17,
   NSControlKeyMask                     = 1 << 18,
   NSAlternateKeyMask                   = 1 << 19,
   NSCommandKeyMask                     = 1 << 20,
   NSNumericPadKeyMask                  = 1 << 21,
   NSHelpKeyMask                        = 1 << 22,
   NSFunctionKeyMask                    = 1 << 23,
   NSDeviceIndependentModifierFlagsMask = 0xffff0000U
};

/* This is specifically for iOS 9, according to the private headers */
-(void)handleKeyUIEvent:(UIEvent *)event
{
    /* This gets called twice with the same timestamp
     * for each keypress, that's fine for polling
     * but is bad for business with events. */
    static double last_time_stamp;

    if (last_time_stamp == event.timestamp)
       return [super handleKeyUIEvent:event];

    last_time_stamp        = event.timestamp;

    /* If the _hidEvent is NULL, [event _keyCode] will crash.
     * (This happens with the on screen keyboard). */
    if (event._hidEvent)
    {
        NSString       *ch = (NSString*)event._privateInput;
        uint32_t character = 0;
        uint32_t mod       = 0;
        NSUInteger mods    = event._modifierFlags;

        if (mods & NSAlphaShiftKeyMask)
           mod |= RETROKMOD_CAPSLOCK;
        if (mods & NSShiftKeyMask)
           mod |= RETROKMOD_SHIFT;
        if (mods & NSControlKeyMask)
           mod |= RETROKMOD_CTRL;
        if (mods & NSAlternateKeyMask)
           mod |= RETROKMOD_ALT;
        if (mods & NSCommandKeyMask)
           mod |= RETROKMOD_META;
        if (mods & NSNumericPadKeyMask)
           mod |= RETROKMOD_NUMLOCK;

        if (ch && ch.length != 0)
        {
            unsigned i;
            character = [ch characterAtIndex:0];

            apple_input_keyboard_event(event._isKeyDown,
                  (uint32_t)event._keyCode, 0, mod,
                  RETRO_DEVICE_KEYBOARD);

            for (i = 1; i < ch.length; i++)
                apple_input_keyboard_event(event._isKeyDown,
                      0, [ch characterAtIndex:i], mod,
                      RETRO_DEVICE_KEYBOARD);
        }

        apple_input_keyboard_event(event._isKeyDown,
              (uint32_t)event._keyCode, character, mod,
              RETRO_DEVICE_KEYBOARD);
    }

    [super handleKeyUIEvent:event];
}

/* This is for iOS versions < 9.0 */
- (id)_keyCommandForEvent:(UIEvent*)event
{
   /* This gets called twice with the same timestamp
    * for each keypress, that's fine for polling
    * but is bad for business with events. */
   static double last_time_stamp;

   if (last_time_stamp == event.timestamp)
      return [super _keyCommandForEvent:event];
   last_time_stamp = event.timestamp;

   /* If the _hidEvent is null, [event _keyCode] will crash.
    * (This happens with the on screen keyboard). */
   if (event._hidEvent)
   {
      NSString       *ch = (NSString*)event._privateInput;
      uint32_t character = 0;
      uint32_t mod       = 0;
      NSUInteger mods    = event._modifierFlags;

      if (mods & NSAlphaShiftKeyMask)
         mod |= RETROKMOD_CAPSLOCK;
      if (mods & NSShiftKeyMask)
         mod |= RETROKMOD_SHIFT;
      if (mods & NSControlKeyMask)
         mod |= RETROKMOD_CTRL;
      if (mods & NSAlternateKeyMask)
         mod |= RETROKMOD_ALT;
      if (mods & NSCommandKeyMask)
         mod |= RETROKMOD_META;
      if (mods & NSNumericPadKeyMask)
         mod |= RETROKMOD_NUMLOCK;

      if (ch && ch.length != 0)
      {
         unsigned i;
         character = [ch characterAtIndex:0];

         apple_input_keyboard_event(event._isKeyDown,
               (uint32_t)event._keyCode, 0, mod,
               RETRO_DEVICE_KEYBOARD);

         for (i = 1; i < ch.length; i++)
            apple_input_keyboard_event(event._isKeyDown,
                  0, [ch characterAtIndex:i], mod,
                  RETRO_DEVICE_KEYBOARD);
      }

      apple_input_keyboard_event(event._isKeyDown,
            (uint32_t)event._keyCode, character, mod,
            RETRO_DEVICE_KEYBOARD);
   }

   return [super _keyCommandForEvent:event];
}
#else
- (void)handleUIPress:(UIPress *)press withEvent:(UIPressesEvent *)event down:(BOOL)down
{
   NSString       *ch;
   uint32_t character = 0;
   uint32_t mod       = 0;
   NSUInteger mods    = 0;
   if (@available(iOS 13.4, tvOS 13.4, *))
   {
      ch = (NSString*)press.key.characters;
      mods = event.modifierFlags;
   }

   if (mods & UIKeyModifierAlphaShift)
      mod |= RETROKMOD_CAPSLOCK;
   if (mods & UIKeyModifierShift)
      mod |= RETROKMOD_SHIFT;
   if (mods & UIKeyModifierControl)
      mod |= RETROKMOD_CTRL;
   if (mods & UIKeyModifierAlternate)
      mod |= RETROKMOD_ALT;
   if (mods & UIKeyModifierCommand)
      mod |= RETROKMOD_META;
   if (mods & UIKeyModifierNumericPad)
      mod |= RETROKMOD_NUMLOCK;

   if (ch && ch.length != 0)
   {
      unsigned i;
      character = [ch characterAtIndex:0];

      apple_input_keyboard_event(down,
                                 (uint32_t)press.key.keyCode, 0, mod,
                                 RETRO_DEVICE_KEYBOARD);

      for (i = 1; i < ch.length; i++)
         apple_input_keyboard_event(down,
                                    0, [ch characterAtIndex:i], mod,
                                    RETRO_DEVICE_KEYBOARD);
   }

   if (@available(iOS 13.4, tvOS 13.4, *))
      apple_input_keyboard_event(down,
                                 (uint32_t)press.key.keyCode, character, mod,
                                 RETRO_DEVICE_KEYBOARD);
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
   for (UIPress *press in presses)
      [self handleUIPress:press withEvent:event down:YES];
   [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
   for (UIPress *press in presses)
      [self handleUIPress:press withEvent:event down:NO];
   [super pressesEnded:presses withEvent:event];
}
#endif

#define GSEVENT_TYPE_KEYDOWN 10
#define GSEVENT_TYPE_KEYUP 11

- (void)sendEvent:(UIEvent *)event
{
   [super sendEvent:event];
   if (@available(iOS 13.4, tvOS 13.4, *))
   {
      if (event.type == UIEventTypeHover)
         return;
   }
   if (event.allTouches.count)
      handle_touch_event(event.allTouches.allObjects);

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
   {
      int major, minor;
      get_ios_version(&major, &minor);

      if ((major < 7) && [event respondsToSelector:@selector(_gsEvent)])
      {
         /* Keyboard event hack for iOS versions prior to iOS 7.
          *
          * Derived from:
                  * http://nacho4d-nacho4d.blogspot.com/2012/01/
                  * catching-keyboard-events-in-ios.html
                  */
         const uint8_t *eventMem = objc_unretainedPointer([event performSelector:@selector(_gsEvent)]);
         int           eventType = eventMem ? *(int*)&eventMem[8] : 0;

         switch (eventType)
         {
            case GSEVENT_TYPE_KEYDOWN:
              case GSEVENT_TYPE_KEYUP:
               apple_input_keyboard_event(eventType == GSEVENT_TYPE_KEYDOWN,
                     *(uint16_t*)&eventMem[0x3C], 0, 0, RETRO_DEVICE_KEYBOARD);
               break;
         }
      }
   }
#endif
}

@end

#ifdef HAVE_COCOA_METAL
@implementation MetalLayerView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)init {
    self = [super init];
    if (self)
        [self setupMetalLayer];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self)
        [self setupMetalLayer];
    return self;
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (void)setupMetalLayer {
    self.metalLayer.device = MTLCreateSystemDefaultDevice();
    self.metalLayer.contentsScale = cocoa_screen_get_native_scale();
    self.metalLayer.opaque = YES;
}

@end
#endif

#if TARGET_OS_IOS
@interface RetroArch_iOS () <MXMetricManagerSubscriber, UIPointerInteractionDelegate>
@end
#endif

@implementation RetroArch_iOS

#pragma mark - ApplePlatform
-(id)renderView { return _renderView; }
-(bool)hasFocus
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

- (void)setViewType:(apple_view_type_t)vt
{
   if (vt == _vt)
      return;

   _vt = vt;
   if (_renderView != nil)
   {
      [_renderView removeFromSuperview];
      _renderView = nil;
   }

   switch (vt)
   {
#ifdef HAVE_COCOA_METAL
       case APPLE_VIEW_TYPE_VULKAN:
         _renderView = [MetalLayerView new];
#if TARGET_OS_IOS
         _renderView.multipleTouchEnabled = YES;
#endif
         break;
       case APPLE_VIEW_TYPE_METAL:
         {
            MetalView *v = [MetalView new];
            v.paused                = YES;
            v.enableSetNeedsDisplay = NO;
#if TARGET_OS_IOS
            v.multipleTouchEnabled  = YES;
#endif
            _renderView = v;
         }
         break;
#endif
       case APPLE_VIEW_TYPE_OPENGL_ES:
         _renderView = (BRIDGE GLKView*)glkitview_init();
         break;

       case APPLE_VIEW_TYPE_NONE:
       default:
         return;
   }

   _renderView.translatesAutoresizingMaskIntoConstraints = NO;
   UIView *rootView = [CocoaView get].view;
   [rootView addSubview:_renderView];
#if TARGET_OS_IOS
   if (@available(iOS 13.4, *))
   {
      [_renderView addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
      _renderView.userInteractionEnabled = YES;
   }
#endif
   [[_renderView.topAnchor constraintEqualToAnchor:rootView.topAnchor] setActive:YES];
   [[_renderView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor] setActive:YES];
   [[_renderView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor] setActive:YES];
   [[_renderView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor] setActive:YES];
   [_renderView layoutIfNeeded];
}

- (apple_view_type_t)viewType { return _vt; }

- (void)setVideoMode:(gfx_ctx_mode_t)mode
{
#ifdef HAVE_COCOA_METAL
   MetalView *metalView = (MetalView*) _renderView;
   CGFloat scale        = [[UIScreen mainScreen] scale];
   [metalView setDrawableSize:CGSizeMake(
         _renderView.bounds.size.width * scale,
         _renderView.bounds.size.height * scale
         )];
#endif
}

- (void)setCursorVisible:(bool)v { /* no-op for iOS */ }
- (bool)setDisableDisplaySleep:(bool)disable
{
#if TARGET_OS_TV
   [[UIApplication sharedApplication] setIdleTimerDisabled:disable];
   return YES;
#else
   return NO;
#endif
}
+ (RetroArch_iOS*)get {
    return (RetroArch_iOS*)[[LibretroCore sharedInstance] retroArch_iOS];
}

-(NSString*)documentsDirectory
{
   if (_documentsDirectory == nil)
   {
#if TARGET_OS_IOS
      NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#elif TARGET_OS_TV
      NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#endif
      _documentsDirectory = paths.firstObject;
   }
   return _documentsDirectory;
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification
{
   NSNumber *type = notification.userInfo[AVAudioSessionInterruptionTypeKey];
   if (![type isKindOfClass:[NSNumber class]])
      return;

   if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan)
   {
      RARCH_LOG("AudioSession Interruption Began\n");
      audio_driver_stop();
   }
   else if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded)
   {
      RARCH_LOG("AudioSession Interruption Ended\n");
      audio_driver_start(false);
   }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
   char arguments[]   = "retroarch";
   char       *argv[] = {arguments,   NULL};
   int argc           = 1;
   apple_platform     = self;

   if ([NSUserDefaults.standardUserDefaults boolForKey:@"restore_default_config"])
   {
      [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"restore_default_config"];
      [NSUserDefaults.standardUserDefaults setObject:@"" forKey:@FILE_PATH_MAIN_CONFIG];

      // Get the Caches directory path
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
      NSString *cachesDirectory = [paths firstObject];

      // Define the original and new file paths
      NSString *originalPath = [cachesDirectory stringByAppendingPathComponent:@"RetroArch/config/retroarch.cfg"];
      NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
      [dateFormatter setDateFormat:@"HHmm-yyMMdd"];
      NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
      NSString *newPath = [cachesDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"RetroArch/config/RetroArch-%@.cfg", timestamp]];

      // File manager instance
      NSFileManager *fileManager = [NSFileManager defaultManager];

      // Check if the file exists and rename it
      if ([fileManager fileExistsAtPath:originalPath])
      {
          NSError *error = nil;
          if ([fileManager moveItemAtPath:originalPath toPath:newPath error:&error])
              NSLog(@"File renamed to %@", newPath);
          else
              NSLog(@"Error renaming file: %@", error.localizedDescription);
      }
      else
          NSLog(@"File does not exist at path %@", originalPath);
   }

   [self setDelegate:self];

   /* Setup window */
   self.window        = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   [self.window makeKeyAndVisible];

   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];

   [self showGameView];

   rarch_main(argc, argv, NULL);

   uico_driver_state_t *uico_st     = uico_state_get_ptr();
   rarch_setting_t *appicon_setting = menu_setting_find_enum(MENU_ENUM_LABEL_APPICON_SETTINGS);
   struct string_list *icons;
   if (               appicon_setting
		   && uico_st->drv
		   && uico_st->drv->get_app_icons
		   && (icons = uico_st->drv->get_app_icons())
		   && icons->size > 1)
   {
      int i;
      size_t _len    = 0;
      char *options = NULL;
      const char *icon_name;

      appicon_setting->default_value.string = icons->elems[0].data;
      icon_name = [[application alternateIconName] cStringUsingEncoding:kCFStringEncodingUTF8]; /* need to ask uico_st for this */
      for (i = 0; i < (int)icons->size; i++)
      {
         _len += strlen(icons->elems[i].data) + 1;
         if (string_is_equal(icon_name, icons->elems[i].data))
            appicon_setting->value.target.string = icons->elems[i].data;
      }
      options = (char*)calloc(_len, sizeof(char));
      string_list_join_concat(options, _len, icons, "|");
      if (appicon_setting->values)
         free((void*)appicon_setting->values);
      appicon_setting->values = options;
   }

   rarch_start_draw_observer();

#if TARGET_OS_TV
   update_topshelf();
#endif

#if TARGET_OS_IOS
   if (@available(iOS 13.0, *))
      [MXMetricManager.sharedManager addSubscriber:self];
#endif

#ifdef HAVE_MFI
   extern void *apple_gamecontroller_joypad_init(void *data);
   apple_gamecontroller_joypad_init(NULL);
   if (@available(macOS 11, iOS 14, tvOS 14, *))
   {
      [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidConnectNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note)
       {
         GCMouse *mouse = note.object;
         mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float delta_x, float delta_y)
         {
            cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
            if (!apple)
               return;
            apple->window_pos_x      += (int16_t)delta_x;
            apple->window_pos_y      -= (int16_t)delta_y;
         };
         mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed)
         {
            cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
            if (!apple)
               return;
            if (pressed)
                apple->mouse_buttons |= (1 << 0);
            else
                apple->mouse_buttons &= ~(1 << 0);
         };
         mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed)
         {
            cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
            if (!apple)
               return;
            if (pressed)
                apple->mouse_buttons |= (1 << 1);
            else
                apple->mouse_buttons &= ~(1 << 1);
         };
      }];
   }
#endif
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#if TARGET_OS_TV
   update_topshelf();
#endif
   rarch_stop_draw_observer();
   command_event(CMD_EVENT_SAVE_FILES, NULL);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
   rarch_stop_draw_observer();
   retroarch_main_quit();
}

- (void)applicationWillResignActive:(UIApplication *)application
{
   self.bgDate = [NSDate date];
   rarch_stop_draw_observer();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
   rarch_start_draw_observer();
   NSError *error;
   settings_t *settings            = config_get_ptr();
   bool ui_companion_start_on_boot = settings->bools.ui_companion_start_on_boot;

   if (settings->bools.audio_respect_silent_mode)
       [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
   else
       [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];

   if (!ui_companion_start_on_boot)
      [self showGameView];

#ifdef HAVE_CLOUDSYNC
   if (self.bgDate)
   {
      if (   [[NSDate date] timeIntervalSinceDate:self.bgDate] > 60.0f
          && (   !(runloop_get_flags() & RUNLOOP_FLAG_CORE_RUNNING)
              || retroarch_ctl(RARCH_CTL_IS_DUMMY_CORE, NULL)))
         task_push_cloud_sync();
      self.bgDate = nil;
   }
#endif
}

-(BOOL)openRetroArchURL:(NSURL *)url
{
   if ([url.host isEqualToString:@"topshelf"])
   {
      NSURLComponents *comp = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
      NSString *ns_path, *ns_core_path;
      char path[PATH_MAX_LENGTH];
      char core_path[PATH_MAX_LENGTH];
      content_ctx_info_t content_info = { 0 };
      for (NSURLQueryItem *q in comp.queryItems)
      {
         if ([q.name isEqualToString:@"path"])
            ns_path = q.value;
         else if ([q.name isEqualToString:@"core_path"])
            ns_core_path = q.value;
      }
      if (!ns_path || !ns_core_path)
         return NO;
      fill_pathname_expand_special(path, [ns_path UTF8String], sizeof(path));
      fill_pathname_expand_special(core_path, [ns_core_path UTF8String], sizeof(core_path));
      RARCH_LOG("TopShelf told us to open %s with %s\n", path, core_path);
      return task_push_load_content_with_new_core_from_companion_ui(core_path, path,
                                                                    NULL, NULL, NULL,
                                                                    &content_info, NULL, NULL);
   }
   return NO;
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if ([[url scheme] isEqualToString:@"retroarch"])
        return [self openRetroArchURL:url];

   NSFileManager *manager = [NSFileManager defaultManager];
   NSString     *filename = (NSString*)url.path.lastPathComponent;
   NSError         *error = nil;
   settings_t *settings   = config_get_ptr();
   char fullpath[PATH_MAX_LENGTH] = {0};
   fill_pathname_join_special(fullpath, settings->paths.directory_core_assets, [filename UTF8String], sizeof(fullpath));
   NSString  *destination = [NSString stringWithUTF8String:fullpath];
   /* Copy file to documents directory if it's not already
    * inside Documents directory */
   if ([url startAccessingSecurityScopedResource])
   {
      if (![[url path] containsString: self.documentsDirectory])
         if (![manager fileExistsAtPath:destination])
            [manager copyItemAtPath:[url path] toPath:destination error:&error];
      [url stopAccessingSecurityScopedResource];
   }
   task_push_dbscan(
      settings->paths.directory_playlist,
      settings->paths.path_content_database,
      fullpath,
      false,
      false,
      NULL);
   return true;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
#if TARGET_OS_IOS
   [self setToolbarHidden:![[viewController toolbarItems] count] animated:YES];
#endif
}

- (void)showGameView
{
   [self popToRootViewControllerAnimated:NO];

#if TARGET_OS_IOS
   [self setToolbarHidden:true animated:NO];
   [[UIApplication sharedApplication] setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
   [[UIApplication sharedApplication] setIdleTimerDisabled:true];
#endif

   [self.window setRootViewController:[CocoaView get]];

   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
         command_event(CMD_EVENT_AUDIO_START, NULL);
         });
}

- (void)supportOtherAudioSessions { }

#if TARGET_OS_IOS
- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads API_AVAILABLE(ios(13.0))
{
    for (MXMetricPayload *payload in payloads)
    {
        NSString *json = [[NSString alloc] initWithData:[payload JSONRepresentation] encoding:kCFStringEncodingUTF8];
        RARCH_LOG("Got Metric Payload:\n%s\n", [json cStringUsingEncoding:kCFStringEncodingUTF8]);
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0))
{
    for (MXDiagnosticPayload *payload in payloads)
    {
        NSString *json = [[NSString alloc] initWithData:[payload JSONRepresentation] encoding:kCFStringEncodingUTF8];
        RARCH_LOG("Got Diagnostic Payload:\n%s\n", [json cStringUsingEncoding:kCFStringEncodingUTF8]);
    }
}

- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region API_AVAILABLE(ios(13.4))
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
   if (!apple)
      return nil;
   if (apple->mouse_grabbed)
      return [UIPointerStyle hiddenPointerStyle];
   return nil;
}

- (UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction
                       regionForRequest:(UIPointerRegionRequest *)request
                          defaultRegion:(UIPointerRegion *)defaultRegion API_AVAILABLE(ios(13.4))
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*) input_state_get_ptr()->current_data;
   if (!apple || apple->mouse_grabbed)
      return nil;
   CGPoint location = [apple_platform.renderView convertPoint:[request location] fromView:nil];
   apple->touches[0].screen_x = (int16_t)(location.x * [[UIScreen mainScreen] scale]);
   apple->touches[0].screen_y = (int16_t)(location.y * [[UIScreen mainScreen] scale]);
   apple->window_pos_x = (int16_t)(location.x * [[UIScreen mainScreen] scale]);
   apple->window_pos_y = (int16_t)(location.y * [[UIScreen mainScreen] scale]);
   return [UIPointerRegion regionWithRect:[apple_platform.renderView bounds] identifier:@"game view"];
}
#endif

static BOOL LibretroInitial = false;
static BOOL RespectSilentMode = false;
- (void)start {
    if (LibretroInitial) {
        return;
    }
    LibretroInitial = true;
    char arguments[]   = "retroarch";
    char       *argv[] = {arguments,   NULL};
    int argc           = 1;
    apple_platform     = self;

    [CocoaView get].view.frame = [[UIScreen mainScreen] bounds];

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
          command_event(CMD_EVENT_AUDIO_START, NULL);
    });

    extern void manic_input_set_deinit(void);
    manic_input_set_deinit();
    
    rarch_main(argc, argv, NULL);

//    uico_driver_state_t *uico_st     = uico_state_get_ptr();
//    rarch_setting_t *appicon_setting = menu_setting_find_enum(MENU_ENUM_LABEL_APPICON_SETTINGS);
//    struct string_list *icons;
//    if (               appicon_setting
//            && uico_st->drv
//            && uico_st->drv->get_app_icons
//            && (icons = uico_st->drv->get_app_icons())
//            && icons->size > 1)
//    {
//       int i;
//       size_t _len    = 0;
//       char *options = NULL;
//       const char *icon_name;
//
//       appicon_setting->default_value.string = icons->elems[0].data;
//       icon_name = [@"appicon" cStringUsingEncoding:kCFStringEncodingUTF8]; /* need to ask uico_st for this */
//       for (i = 0; i < (int)icons->size; i++)
//       {
//          _len += strlen(icons->elems[i].data) + 1;
//          if (string_is_equal(icon_name, icons->elems[i].data))
//             appicon_setting->value.target.string = icons->elems[i].data;
//       }
//       options = (char*)calloc(_len, sizeof(char));
//       string_list_join_concat(options, _len, icons, "|");
//       if (appicon_setting->values)
//          free((void*)appicon_setting->values);
//       appicon_setting->values = options;
//    }
    rarch_start_draw_observer();
 }

- (void)pause {
    if (!LibretroInitial) { return; }
    command_event(CMD_EVENT_PAUSE, NULL);
    rarch_stop_draw_observer();
}

- (void)stop {
    if (!LibretroInitial) { return; }
    LibretroInitial = false;
    command_event(CMD_EVENT_CLOSE_CONTENT, NULL);
    command_event(CMD_EVENT_UNLOAD_CORE, NULL);
    rarch_stop_draw_observer();
    main_exit(NULL);
    self.gamePath = nil;
    self.corePath = nil;
}

- (void)resume {
    if (!LibretroInitial) { return; }
    rarch_start_draw_observer();
    NSError *error;
    settings_t *settings            = config_get_ptr();
    if (settings->bools.audio_respect_silent_mode)
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    else
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    settings->bools.audio_sync = false;
    command_event(CMD_EVENT_RESUME, NULL);
    if (needToLoadStatePath) {
        [self loadGame:self.gamePath corePath:self.corePath completion:nil];
        [self loadState:needToLoadStatePath];
        needToLoadStatePath = nil;
    }
}

- (BOOL)loadGame:(NSString *_Nonnull)gamePath corePath:(NSString *_Nonnull)corePath completion:(void(^ _Nullable)(NSDictionary *_Nullable))completion {
    settings_t *settings = config_get_ptr();
    settings->bools.video_font_enable = false;//禁用通知
    settings->bools.audio_respect_silent_mode = RespectSilentMode;
    content_ctx_info_t content_info;
    content_info.argc        = 0;
    content_info.argv        = NULL;
    content_info.args        = NULL;
    content_info.environ_get = NULL;
    
    task_push_load_content_with_new_core_from_menu(corePath.UTF8String,
                                                   gamePath.UTF8String,
                                                   &content_info,
                                                   CORE_TYPE_PLAIN,
                                                   NULL,
                                                   NULL);
    
    self.gamePath = gamePath;
    self.corePath = corePath;
    
    //核心信息
    core_info_t *core_info      = NULL;
    core_info_get_current_core(&core_info);

    //核心选项 开启PSP内部作弊码支持
    if (strcmp(core_info->core_name, "PPSSPP") == 0 && completion) {
        core_option_manager_t *coreopts = NULL;
        retroarch_ctl(RARCH_CTL_CORE_OPTIONS_LIST_GET, &coreopts);
        core_option_manager_set_val(coreopts, 8, 1, false); //开启ppsspp内部作弊码
        core_options_flush();//生成核心配置
        //获取PSP的游戏信息
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *savePath = [[NSString stringWithCString:runloop_state_get_ptr()->savefile_dir encoding:NSUTF8StringEncoding] stringByAppendingPathComponent:@"PSP/Cheats"];
            NSError *error = nil;
            NSArray *files = [fileManager contentsOfDirectoryAtPath:savePath error:&error];
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil);
                });
                return;
            }
            NSString *latestFileName = nil;
            NSDate *latestDate = [NSDate distantPast];
            for (NSString *fileName in files) {
                if ([[fileName pathExtension] isEqualToString:@"ini"]) {
                    NSString *fullPath = [savePath stringByAppendingPathComponent:fileName];
                    NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:&error];
                    if (error) {
                        continue;
                    }
                    
                    NSDate *creationDate = attributes[NSFileCreationDate];
                    if ([creationDate compare:latestDate] == NSOrderedDescending) {
                        latestDate = creationDate;
                        latestFileName = fileName;
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(latestFileName == nil ? nil : @{@"PSPGameCode": [latestFileName stringByDeletingPathExtension]});
            });
        });
    } else {
        if (completion) {
            completion(nil);
        }
    }
    
    return YES;
}

extern void manic_input_button_event(unsigned port, unsigned button_id, bool pressed);
extern void manic_input_analog_event(unsigned port, unsigned stick_id, float x_value, float y_value);
- (void)pressButton:(unsigned)button playerIndex:(unsigned)playerIndex {
    manic_input_button_event(playerIndex, button, true);
}

- (void)releaseButton:(unsigned)button playerIndex:(unsigned)playerIndex {
    manic_input_button_event(playerIndex, button, false);
}

- (void)moveStick:(BOOL)isLeft x:(CGFloat)x y:(CGFloat)y playerIndex:(unsigned)playerIndex {
    manic_input_analog_event(playerIndex, isLeft ? RETRO_DEVICE_INDEX_ANALOG_LEFT : RETRO_DEVICE_INDEX_ANALOG_RIGHT, x, y);
}

- (void)sendEvent:(UIEvent * _Nonnull)event {
   if (@available(iOS 13.4, tvOS 13.4, *))
   {
      if (event.type == UIEventTypeHover)
         return;
   }
   if (event.allTouches.count)
      handle_touch_event(event.allTouches.allObjects);
}

- (void)mute:(BOOL)mute {
    audio_driver_state_t *audio = audio_state_get_ptr();
    audio->mute_enable = !mute;
}

- (void)snapshot:(void(^ _Nullable)(UIImage *_Nullable image))completion {
    if (!completion) {
        return;
    }
    // 获取截图目录
    settings_t *settings = config_get_ptr();
    NSString *screenShotDir = [[NSString stringWithCString:settings->paths.directory_screenshot encoding:NSUTF8StringEncoding] stringByDeletingPathExtension];
    // 执行截图命令
    command_event(CMD_EVENT_TAKE_SCREENSHOT, NULL);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        __block BOOL cancelledByCondition = NO;
        // 等待截图完成
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        // 设置定时器间隔（0.1秒）
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
        // 设置定时器回调
        dispatch_source_set_event_handler(timer, ^{
            // 检查文件是否存在
            NSArray *files = [fileManager contentsOfDirectoryAtPath:screenShotDir error:nil];
            NSArray *sortedFiles = [[files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *fileName, NSDictionary *bindings) {
                NSString *fullPath = [screenShotDir stringByAppendingPathComponent:fileName];
                BOOL isDir = NO;
                [fileManager fileExistsAtPath:fullPath isDirectory:&isDir];
                return !isDir;
            }]] sortedArrayUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
                NSString *path1 = [screenShotDir stringByAppendingPathComponent:file1];
                NSString *path2 = [screenShotDir stringByAppendingPathComponent:file2];
                
                NSDate *date1 = [[fileManager attributesOfItemAtPath:path1 error:nil] fileCreationDate];
                NSDate *date2 = [[fileManager attributesOfItemAtPath:path2 error:nil] fileCreationDate];
                
                return [date2 compare:date1]; // 创建时间降序
            }];
            
            NSString *latestFile = sortedFiles.firstObject;
            if (latestFile)  {
                NSString *latestPath = [screenShotDir stringByAppendingPathComponent:latestFile];
                NSDate *creationDate = [[fileManager attributesOfItemAtPath:latestPath error:nil] fileCreationDate];
                if ([NSDate now].timeIntervalSince1970 - creationDate.timeIntervalSince1970 < 1.0) {
                    NSString *imageFilePath = [screenShotDir stringByAppendingPathComponent:latestFile];
                    if (@available(iOS 17.0, *)) {
                        UIImage *image = [UIImage imageWithContentsOfFile:imageFilePath];
                        if (image) {
                            dispatch_source_cancel(timer);
                            cancelledByCondition = YES;
                            // 在主线程回调
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (completion) {
                                    NSLog(@"保存图片成功!!");
                                    completion(image);
                                }
                                [fileManager removeItemAtPath:imageFilePath error:nil];
                            });
                        }
                    } else {
                        dispatch_source_cancel(timer);
                        cancelledByCondition = YES;
                        CGFloat delay = 3;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            UIImage *image = [UIImage imageWithContentsOfFile:imageFilePath];
                            if (image) {
                                // 在主线程回调
                                if (completion) {
                                    NSLog(@"保存图片成功!!");
                                    completion(image);
                                } else {
                                    completion(nil);
                                }
                                [fileManager removeItemAtPath:imageFilePath error:nil];
                            }
                        });
                    }
                }
            }
        });
        // 启动定时器
        dispatch_resume(timer);
        // 设置超时（2秒）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (cancelledByCondition) {
                return;
            }
            dispatch_source_cancel(timer);
            // 在主线程回调超时
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil);
                }
            });
        });
    });
}

- (BOOL)saveState:(void(^ _Nullable)(NSString *_Nullable path))completion {
    if (!completion) {
        return NO;
    }
    NSLog(@"开始存档");
    NSString *statePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.state", [[NSDate now] timeIntervalSince1970] * 1000]];
    if (content_save_state(statePath.UTF8String, true)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            content_wait_for_save_state_task();
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"开始结束");
                completion(statePath);
            });
        });
        return YES;
    }
    return NO;
}

- (BOOL)loadState:(NSString *_Nonnull)path {
    return content_load_state(path.UTF8String, false, false);
}

- (void)fastForward:(float)rate {
    settings_t *settings = config_get_ptr();
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    input_driver_state_t *input_st = input_state_get_ptr();
    audio_driver_state_t *audio_st = audio_state_get_ptr();
    if (rate <= 1) {
        //恢复速度
        settings->floats.fastforward_ratio = 1.0f;
        // 1. 清除快进标志
        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
        // 2. 清除非阻塞输入
        input_st->flags &= ~INP_FLAG_NONBLOCKING;
        // 3. 更新帧率限制
        command_event(CMD_EVENT_SET_FRAME_LIMIT, NULL);
        // 4. 恢复音频缓冲区大小
        audio_st->chunk_size = AUDIO_CHUNK_SIZE_BLOCKING;
        // 5. 恢复音频阻塞模式
        if (audio_st->current_audio && audio_st->context_audio_data)
            audio_st->current_audio->set_nonblock_state(audio_st->context_audio_data, false);
    } else {
        //快进
        // 1. 设置快进比例
        settings->floats.fastforward_ratio = rate;
        // 2. 设置快进标志
        runloop_st->flags |= RUNLOOP_FLAG_FASTMOTION;
        // 3. 设置非阻塞输入
        input_st->flags |= INP_FLAG_NONBLOCKING;
        // 4. 更新帧率限制
        command_event(CMD_EVENT_SET_FRAME_LIMIT, NULL);
        // 5. 设置音频缓冲区大小
        audio_st->chunk_size = AUDIO_CHUNK_SIZE_NONBLOCKING;
        // 6. 设置音频非阻塞模式
        if (audio_st->current_audio && audio_st->context_audio_data)
            audio_st->current_audio->set_nonblock_state(audio_st->context_audio_data, true);
    }
}

- (void)reload {
    [self reloadByKeepState: NO];
}

static NSString *_Nullable needToLoadStatePath = nil;
- (void)reloadByKeepState:(BOOL)keepState {
    if (keepState) {
        [self saveState:^(NSString * _Nullable path) {
            if (iterate_observer) {
                //游戏运行状态 直接加载存档
                [self loadGame:self.gamePath corePath:self.corePath completion:nil];
                [self loadState:path];
            } else {
                //暂停中 标记在恢复的时候需要加载游戏和存档
                needToLoadStatePath = path;
            }
        }];
    } else {
        [self loadGame:self.gamePath corePath:self.corePath completion:nil];
    }
}


- (void)updatePSPCheat:(NSString *_Nonnull)cheatCode cheatFilePath:(NSString *_Nonnull)cheatFilePath reloadGame:(BOOL)reloadGame {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cheatFilePath]) {
        [fileManager removeItemAtPath:cheatFilePath error:nil];
    }
    if (cheatCode && ![cheatCode isEqualToString:@""]) {
        [fileManager createDirectoryAtPath:[cheatFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:nil];
        [cheatCode writeToFile:cheatFilePath atomically:true encoding:NSUTF8StringEncoding error:nil];
    }
    if (reloadGame) {
        [self reloadByKeepState:YES];
    }
}

- (void)setPSPResolution:(unsigned)resolution reload:(BOOL)reload {
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:@"config/PPSSPP/PPSSPP.opt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        return;
    }

    // 正则匹配并替换
    NSString *pattern = @"ppsspp_internal_resolution\\s*=\\s*\"[^\"]*\"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    
    NSString *newValue = [NSString stringWithFormat:@"%dx%d", 480*resolution, 272*resolution];
    NSString *replacement = [NSString stringWithFormat:@"ppsspp_internal_resolution = \"%@\"", newValue];
    NSString *updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                                options:0
                                                                  range:NSMakeRange(0, fileContents.length)
                                                           withTemplate:replacement];

    
    
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (reload) {
        [self reloadByKeepState:YES];
    }
}

- (void)setPSPLanguage:(unsigned)language {
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:@"config/PPSSPP/PPSSPP.opt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {    
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        return;
    }

    // 正则匹配并替换
    NSString *pattern = @"ppsspp_language\\s*=\\s*\"[^\"]*\"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    NSArray<NSString *> *languages = @[@"Automatic", @"English", @"Japanese", @"French", @"Spanish", @"German", @"Italian", @"Dutch", @"Portuguese", @"Russian", @"Korean", @"Chinese Traditional", @"Chinese Simplified"];
    if (language < languages.count) {
        NSString *newValue = languages[language];
        NSString *replacement = [NSString stringWithFormat:@"ppsspp_language = \"%@\"", newValue];
        NSString *updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                                    options:0
                                                                      range:NSMakeRange(0, fileContents.length)
                                                               withTemplate:replacement];

        
        
        // 写回文件
        [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
}

- (void)updateCoreConfig:(NSString *_Nonnull)coreName key:(NSString *_Nonnull)key value:(NSString *_Nonnull)value reload:(BOOL)reload {
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        fileContents = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        // 写回文件
        [fileContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (reload) {
            [self reloadByKeepState:YES];
        }
        return;
    }
    
    NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
    if ([oldValue isEqualToString:value]) {
        return;
    }

    // 正则匹配并替换
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key] ;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
    NSString *updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                                options:0
                                                                  range:NSMakeRange(0, fileContents.length)
                                                           withTemplate:replacement];
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (reload) {
        [self reloadByKeepState:YES];
    }
}

- (void)updateLibretroConfig:(NSString *_Nonnull)key value:(NSString *_Nonnull)value {
    NSString *configFilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/Libretro/config/retroarch.cfg"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"读取文件失败: %@", error.localizedDescription);
        [NSFileManager.defaultManager createDirectoryAtPath:[configFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        fileContents = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        // 写回文件
        [fileContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        return;
    }
    
    NSString *oldValue = [self configValueForKey:key inFileContents:fileContents];
    if ([oldValue isEqualToString:value]) {
        return;
    }

    // 正则匹配并替换
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"[^\"]*\"", key] ;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return;
    }
    NSString *replacement = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
    NSString *updatedContents = [regex stringByReplacingMatchesInString:fileContents
                                                                options:0
                                                                  range:NSMakeRange(0, fileContents.length)
                                                           withTemplate:replacement];
    // 写回文件
    [updatedContents writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (NSString * _Nullable)coreConfigValue:(NSString * _Nonnull)coreName key:(NSString * _Nonnull)key {
    NSString *configPath = [NSString stringWithFormat:@"config/%@/%@.opt", coreName, coreName];
    NSString *configFilePath = [self.workspace stringByAppendingPathComponent:configPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
        core_options_flush();//生成配置
    }
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    return [self configValueForKey:key inFileContents:fileContents];
}

- (NSString * _Nullable)libretroConfigValue:(NSString * _Nonnull)key {
    NSString *configFilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/Libretro/config/retroarch.cfg"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        return nil;
    }
    return [self configValueForKey:key inFileContents:fileContents];
}

- (NSString * _Nullable)configValueForKey:(NSString * _Nonnull)key inFileContents:(NSString * _Nonnull)fileContents {
    NSError *error = nil;
    // 构建正则表达式
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"([^\"]*)\"", key];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return nil;
    }

    NSTextCheckingResult *match = [regex firstMatchInString:fileContents options:0 range:NSMakeRange(0, fileContents.length)];
    
    if (match && match.numberOfRanges > 1) {
        NSRange valueRange = [match rangeAtIndex:1];
        return [fileContents substringWithRange:valueRange];
    }
    
    return nil;
}

- (void)setShader:(NSString *_Nullable)path {
    settings_t *settings = config_get_ptr();
    if (!settings) {
        return;
    }
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        settings->bools.video_shader_enable = true;
        video_shader_toggle(settings, true);
        set_shader_preset(path.UTF8String);
    } else {
        settings->bools.video_shader_enable = false;
        video_shader_toggle(settings, true);
    }
}

void set_shader_preset(const char * _Nullable preset_path)
{
    settings_t *settings = config_get_ptr();
    video_driver_state_t *video_st = video_state_get_ptr();
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    
    if (!video_st || !video_st->current_video || !video_st->current_video->set_shader)
        return;
        
    // 获取 shader 类型
    enum rarch_shader_type type = video_shader_parse_type(preset_path);
    if (type == RARCH_SHADER_NONE)
        return;
        
    // 设置 shader
    if (video_st->current_video->set_shader(video_st->data, type, preset_path))
    {
        // 启用 shader
        configuration_set_bool(settings, settings->bools.video_shader_enable, true);
        
        // 更新运行时 shader preset 路径
        if (!string_is_empty(preset_path))
        {
            if (runloop_st->runtime_shader_preset_path != preset_path)
                strlcpy(runloop_st->runtime_shader_preset_path,
                       preset_path,
                       sizeof(runloop_st->runtime_shader_preset_path));
                       
            // 更新 shader manager
            struct video_shader *shader = menu_shader_get();
            if (shader)
            {
                if (menu_shader_manager_set_preset(shader, type, preset_path, false))
                    shader->flags &= ~SHDR_FLAG_MODIFIED;
            }
        }
        else
        {
            runloop_st->runtime_shader_preset_path[0] = '\0';
        }
    }
}

- (void)addCheatCode:(NSString *_Nonnull)code index:(unsigned)index enable:(BOOL)enable {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (runloop_st && runloop_st->current_core.retro_cheat_set) {
        runloop_st->current_core.retro_cheat_set(index, enable, code.UTF8String);
    }
}

- (void)resetCheatCode {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (runloop_st && runloop_st->current_core.retro_cheat_reset) {
        runloop_st->current_core.retro_cheat_reset();
    }
}

- (void)setRespectSilentMode:(BOOL)respect {
    RespectSilentMode = respect;
}

- (void)setDiskIndex:(unsigned)index {
    command_event(CMD_EVENT_DISK_EJECT_TOGGLE, NULL);
    command_event(CMD_EVENT_DISK_INDEX, &index);
    command_event(CMD_EVENT_DISK_EJECT_TOGGLE, NULL);
}

- (NSUInteger)getCurrentDiskIndex {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st) {
        return 0;
    }
    rarch_system_info_t *sys_info = &runloop_st->system;
    if (!sys_info) {
        return 0;
    }
    disk_control_interface_t *disk_control = &sys_info->disk_control;
    if (!disk_control) {
        return 0;
    }
    unsigned image_index = disk_control->cb.get_image_index();
    return image_index;
}

- (NSUInteger)getDiskCount {
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st) {
        return 0;
    }
    rarch_system_info_t *sys_info = &runloop_st->system;
    if (!sys_info) {
        return 0;
    }
    disk_control_interface_t *disk_control = &sys_info->disk_control;
    if (!disk_control) {
        return 0;
    }
    unsigned num_images  = disk_control->cb.get_num_images();
    return num_images;
}

@end

ui_companion_driver_t ui_companion_cocoatouch = {
   NULL, /* init */
   NULL, /* deinit */
   NULL, /* toggle */
   ui_companion_cocoatouch_event_command,
   NULL, /* notify_refresh */
   NULL, /* msg_queue_push */
   NULL, /* render_messagebox */
   NULL, /* get_main_window */
   NULL, /* log_msg */
   NULL, /* is_active */
   ui_companion_cocoatouch_get_app_icons,
   ui_companion_cocoatouch_set_app_icon,
   ui_companion_cocoatouch_get_app_icon_texture,
   NULL, /* browser_window */
   NULL, /* msg_window */
   NULL, /* window */
   NULL, /* application */
   "cocoatouch",
};

#ifndef NO_ROOT_VIEW
int main(int argc, char *argv[])
{
#if TARGET_OS_IOS
    if (jb_enable_ptrace_hack())
        RARCH_LOG("Ptrace hack complete, JIT support is enabled.\n");
    else
        RARCH_WARN("Ptrace hack NOT available; Please use an app like Jitterbug.\n");
#endif
#ifdef HAVE_SDL2
    SDL_SetMainReady();
#endif
   @autoreleasepool {
      return UIApplicationMain(argc, argv, NSStringFromClass([RApplication class]), NSStringFromClass([RetroArch_iOS class]));
   }
}
#endif


