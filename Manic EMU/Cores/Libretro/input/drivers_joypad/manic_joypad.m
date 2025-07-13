/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2014 - Hans-Kristian Arntzen
 *  Copyright (C) 2011-2017 - Daniel De Matteis
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>

#include <boolean.h>

#include <AvailabilityMacros.h>

#include "../input_driver.h"
#include "../../tasks/tasks_internal.h"

#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>

#ifndef MAX_MANIC_CONTROLLERS
#define MAX_MANIC_CONTROLLERS 4
#endif
#ifndef MAX_MANIC_AXES
#define MAX_MANIC_AXES 6
#endif

#if TARGET_OS_IOS
#include "../../configuration.h"

/* TODO/FIXME - static globals */
static uint32_t manic_buttons[MAX_USERS];
static int16_t  manic_axes[MAX_USERS][MAX_MANIC_AXES];

static bool manic_inited;

void manic_input_set_deinit(void) {
    manic_inited = false;
}

void manic_input_button_event(unsigned port, unsigned button_id, bool pressed) {
    uint32_t *buttons        = &manic_buttons[port];
    if (pressed) {
        switch (button_id) {
            case RETRO_DEVICE_ID_JOYPAD_UP:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_UP);
                break;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
                break;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT:
                *buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_B:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_B);
                break;
            case RETRO_DEVICE_ID_JOYPAD_A:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_A);
                break;
            case RETRO_DEVICE_ID_JOYPAD_Y:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_Y);
                break;
            case RETRO_DEVICE_ID_JOYPAD_X:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_X);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L2:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R2:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L3:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_L3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R3:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_R3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_SELECT:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_START:
                *buttons |=  (1 << RETRO_DEVICE_ID_JOYPAD_START);
                break;
            case RARCH_FIRST_CUSTOM_BIND:
                *buttons |=  (1 << RARCH_FIRST_CUSTOM_BIND);
                break;
            default:
                break;
        }
    } else {
        switch (button_id) {
            case RETRO_DEVICE_ID_JOYPAD_UP:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_UP);
                break;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
                break;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_B:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_B);
                break;
            case RETRO_DEVICE_ID_JOYPAD_A:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_A);
                break;
            case RETRO_DEVICE_ID_JOYPAD_Y:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_Y);
                break;
            case RETRO_DEVICE_ID_JOYPAD_X:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_X);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L2:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R2:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R2);
                break;
            case RETRO_DEVICE_ID_JOYPAD_L3:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_R3:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R3);
                break;
            case RETRO_DEVICE_ID_JOYPAD_SELECT:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
                break;
            case RETRO_DEVICE_ID_JOYPAD_START:
                *buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
                break;
            case RARCH_FIRST_CUSTOM_BIND:
                *buttons &= ~(1 << RARCH_FIRST_CUSTOM_BIND);
                break;
            default:
                break;
        }
    }
}

void manic_input_analog_event(unsigned port, unsigned stick_id, float x_value, float y_value) {
    switch (stick_id) {
        case RETRO_DEVICE_INDEX_ANALOG_LEFT:
            manic_axes[port][0] = x_value * 32767.0f;
            manic_axes[port][1] = y_value * 32767.0f;
            break;
        case RETRO_DEVICE_INDEX_ANALOG_RIGHT:
            manic_axes[port][2] = x_value * 32767.0f;
            manic_axes[port][3] = y_value * 32767.0f;
            break;
        default:
            break;
    }
    
}


static void manic_gamecontroller_joypad_poll(void) { }

#endif

void *manic_gamecontroller_joypad_init(void *data) {
    if (manic_inited)
        return (void*)-1;
    
    manic_inited = true;
    for (unsigned i = 0; i < MAX_USERS; i++) {
        input_autoconfigure_connect("Manic Controller", [NSString stringWithFormat:@"Manic Player %d", i].UTF8String, manic_joypad.ident, i, 0, 0);
    }
    return (void*)-1;
}

static void manic_gamecontroller_joypad_destroy(void) { }

static int32_t manic_gamecontroller_joypad_button(unsigned port, uint16_t joykey) {
    if (port >= DEFAULT_MAX_PADS)
        return 0;
    /* Check hat. */
    else if (GET_HAT_DIR(joykey))
        return 0;
    else if (joykey < 32)
        return ((manic_buttons[port] & (1 << joykey)) != 0);
    return 0;
}

static void manic_gamecontroller_joypad_get_buttons(unsigned port, input_bits_t *state) {
    BITS_COPY16_PTR(state, manic_buttons[port]);
}

static int16_t manic_gamecontroller_joypad_axis(unsigned port, uint32_t joyaxis) {
    if (AXIS_NEG_GET(joyaxis) < MAX_MANIC_AXES) {
        int16_t axis = AXIS_NEG_GET(joyaxis);
        int16_t val  = manic_axes[port][axis];
        if (val < 0)
            return val;
    } else if (AXIS_POS_GET(joyaxis) < MAX_MANIC_AXES) {
        int16_t axis = AXIS_POS_GET(joyaxis);
        int16_t val  = manic_axes[port][axis];
        if (val > 0)
            return val;
    }
    return 0;
}

static int16_t manic_gamecontroller_joypad_state(rarch_joypad_info_t *joypad_info,
                                                 const struct retro_keybind *binds,
                                                 unsigned port)
{
   unsigned i;
   int16_t ret                          = 0;
   uint16_t port_idx                    = joypad_info->joy_idx;

   if (port_idx < DEFAULT_MAX_PADS)
   {
      for (i = 0; i < RARCH_FIRST_CUSTOM_BIND; i++)
      {
         /* Auto-binds are per joypad, not per user. */
         const uint64_t joykey  = (binds[i].joykey != NO_BTN)
            ? binds[i].joykey  : joypad_info->auto_binds[i].joykey;
         const uint32_t joyaxis = (binds[i].joyaxis != AXIS_NONE)
            ? binds[i].joyaxis : joypad_info->auto_binds[i].joyaxis;
         if (     (uint16_t)joykey != NO_BTN
               && !GET_HAT_DIR(i)
               && (i < 32)
               && ((manic_buttons[port_idx] & (1 << i)) != 0)
            )
            ret |= ( 1 << i);
         else if (joyaxis != AXIS_NONE &&
               ((float)abs(manic_gamecontroller_joypad_axis(port_idx, joyaxis))
                / 0x8000) > joypad_info->axis_threshold)
            ret |= (1 << i);
      }
   }

   return ret;
}

static bool manic_gamecontroller_joypad_set_rumble(unsigned pad,
                                                   enum retro_rumble_effect type, uint16_t strength) {
    return false;
}

static bool manic_gamecontroller_joypad_query_pad(unsigned pad)
{
    return pad < MAX_USERS;
}

static const char *manic_gamecontroller_joypad_name(unsigned pad)
{
    if (pad < MAX_USERS)
        return "Manic Controller";
    return NULL;
}

input_device_driver_t manic_joypad = {
    manic_gamecontroller_joypad_init,
    manic_gamecontroller_joypad_query_pad,
    manic_gamecontroller_joypad_destroy,
    manic_gamecontroller_joypad_button,
    manic_gamecontroller_joypad_state,
    manic_gamecontroller_joypad_get_buttons,
    manic_gamecontroller_joypad_axis,
    manic_gamecontroller_joypad_poll,
    manic_gamecontroller_joypad_set_rumble,
    NULL,
    NULL,
    NULL,
    manic_gamecontroller_joypad_name,
    "manic",
};
