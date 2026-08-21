//
//  SpecialCoreOption.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

enum SpecialCoreOption: String {
    //psp
    case ppsspp_enable_wlan
    case ppsspp_enable_builtin_pro_ad_hoc_server
    case ppsspp_change_pro_ad_hoc_server_address
    case ppsspp_pro_ad_hoc_server_address01
    case ppsspp_pro_ad_hoc_server_address02
    case ppsspp_pro_ad_hoc_server_address03
    case ppsspp_pro_ad_hoc_server_address04
    case ppsspp_pro_ad_hoc_server_address05
    case ppsspp_pro_ad_hoc_server_address06
    case ppsspp_pro_ad_hoc_server_address07
    case ppsspp_pro_ad_hoc_server_address08
    case ppsspp_pro_ad_hoc_server_address09
    case ppsspp_pro_ad_hoc_server_address10
    case ppsspp_pro_ad_hoc_server_address11
    case ppsspp_pro_ad_hoc_server_address12
    case ppsspp_port_offset
    case ppsspp_language
    case ppsspp_backend
    case ppsspp_texture_replacement
    case ppsspp_cpu_core
    case ppsspp_internal_resolution
    case ppsspp_cheats
    //nes fds
    case nestopia_palette
    case nestopia_aspect
    //isPicodriveCore
    case picodrive_input1
    case picodrive_input2
    //snes
    case bsnes_ppu_no_vram_blocking
    case snes9x_block_invalid_vram_access
    //ClownMDEmuCore
    case clownmdemu_tv_standard
    //ss
    case yabause_addon_cartridge
    case beetle_saturn_region
    case beetle_saturn_cart
    case beetle_saturn_horizontal_overscan
    //ds
    case melonds_firmware_language
    case melonds_console_mode
    case melonds_mic_input
    case melonds_jit_enable
    case melonds_mic_input_active
    case melonds_number_of_screen_layouts
    case melonds_screen_layout1
    case melonds_show_cursor
    case desmume_internal_resolution
    case desmume_firmware_language
    case desmume_mic_mode
    case desmume_pointer_type
    case desmume_pointer_device_l
    case desmume_pointer_device_r
    //gba gbc gb
    case vbam_gbHardware
    case vbam_usebios
    //gbc
    case gambatte_gbc_color_correction
    //gb
    case gambatte_gb_colorization
    case gambatte_gb_internal_palette
    case mgba_gb_colors
    case vbam_palettes
    //n64
    case mupen64plus_cpucore = "mupen64plus-cpucore"
    case mupen64plus_rdp_plugin = "mupen64plus-rdp-plugin"
    case mupen64plus_pak1 = "mupen64plus-pak1"
    case mupen64plus_parallel_rdp_upscaling = "mupen64plus-parallel-rdp-upscaling"
    case mupen64plus_43screensize = "mupen64plus-43screensize"
    //vb
    case vb_color_mode
    //pm
    case pokemini_palette
    //ps1
    case beetle_psx_hw_internal_resolution
    case beetle_psx_hw_override_bios
    case beetle_psx_hw_renderer
    case beetle_psx_hw_cpu_dynarec
    case beetle_psx_hw_dither_mode
    case beetle_psx_hw_msaa
    case beetle_psx_hw_mdec_yuv
    case beetle_psx_hw_aspect_ratio
    case beetle_psx_hw_enable_memcard1
    case beetle_psx_hw_pgxp_mode
    case beetle_psx_hw_pgxp_nclip
    case beetle_psx_hw_pgxp_texture
    case beetle_psx_hw_gte_overclock
    //dc
    case reicast_internal_resolution
    case reicast_language
    case reicast_renderer
    //arcade
    case mame_cheats_enable
    //isAzahar3DS
    case citra_use_cpu_jit
    case citra_use_default_aes_key
    case citra_required_online_lle_modules
    case citra_layout_option
    case citra_touch_touchscreen
    case citra_input_type
    //a2600
    case stella_crop_hoverscan
    //a5200
    case atari800_system
    //jaguar
    case virtualjaguar_alt_inputs
    case virtualjaguar_bios
    case virtualjaguar_doom_res_hack
    case virtualjaguar_p1_retropad_analog_lu
    case virtualjaguar_p1_retropad_analog_ld
    case virtualjaguar_p1_retropad_analog_ll
    case virtualjaguar_p1_retropad_analog_lr
    case virtualjaguar_p1_retropad_analog_ru
    case virtualjaguar_p2_retropad_analog_lu
    case irtualjaguar_p2_retropad_analog_ld
    case virtualjaguar_p2_retropad_analog_ll
    case virtualjaguar_p2_retropad_analog_lr
    case virtualjaguar_p2_retropad_analog_ru
    //doom
    case prboom_resolution = "prboom-resolution"
    case prboom_rumble = "prboom-rumble"
    //dos
    case dosbox_pure_cpu_core
    //symbian
    case eka2l1_cpu_backend
    case screen_buffer_sync
    case eka2l1_device_index
    //dolphin
    case dolphin_cpu_clock_rate
    case dolphin_cpu_core
    case dolphin_osd_enabled
    case dolphin_fast_disc_speed
    case dolphin_gpu_texture_decoding
    case dolphin_shader_compilation_mode
    case dolphin_log_level
    case dolphin_log_boot
    case dolphin_log_core
    case dolphin_log_video
    case dolphin_log_common
    case dolphin_vi_skip
    case dolphin_skip_gc_bios
    case dolphin_cheats_enabled
    case dolphin_cheats_import
    
    
    
    func isOptimizationCoreConfig(key: String,
                                  game: Game) -> Bool {
        guard let config = SpecialCoreOption(rawValue: key) else { return false }
        return Self.getOptimizationCoreOptions(game: game).contains(config)
    }
    
    ///Some core configurations already have convenient setup entries in the frontend.
    ///Get the list of these optimized core settings.
    ///PS. User cannot see these options in the core settings.
    static func getOptimizationCoreOptions(game: Game) -> Set<Self> {
        if game.gameType == .psp {
            return [
                .ppsspp_enable_wlan,
                .ppsspp_enable_builtin_pro_ad_hoc_server,
                .ppsspp_change_pro_ad_hoc_server_address,
                .ppsspp_pro_ad_hoc_server_address01,
                .ppsspp_pro_ad_hoc_server_address02,
                .ppsspp_pro_ad_hoc_server_address03,
                .ppsspp_pro_ad_hoc_server_address04,
                .ppsspp_pro_ad_hoc_server_address05,
                .ppsspp_pro_ad_hoc_server_address06,
                .ppsspp_pro_ad_hoc_server_address07,
                .ppsspp_pro_ad_hoc_server_address08,
                .ppsspp_pro_ad_hoc_server_address09,
                .ppsspp_pro_ad_hoc_server_address10,
                .ppsspp_pro_ad_hoc_server_address11,
                .ppsspp_pro_ad_hoc_server_address12,
                .ppsspp_port_offset,
                .ppsspp_language,
                .ppsspp_backend,
                .ppsspp_texture_replacement,
                .ppsspp_cpu_core,
                .ppsspp_internal_resolution
            ]
        } else if game.gameType == .nes || game.gameType == .fds {
            return [.nestopia_palette]
        } else if game.gameType == .snes {
            if game.defaultCore == 0 {
                return [.bsnes_ppu_no_vram_blocking]
            } else if game.defaultCore == 1 {
                return [.snes9x_block_invalid_vram_access]
            }
        } else if game.isClownMDEmuCore {
            return [.clownmdemu_tv_standard]
        } else if game.gameType == .ss {
            if game.defaultCore == 0 {
                return [.beetle_saturn_region]
            }
        } else if game.gameType == .ds {
            if game.defaultCore == 0 {
                return [
                    .melonds_firmware_language,
                    .melonds_console_mode,
                    .melonds_mic_input,
                    .melonds_jit_enable
                ]
            } else if game.defaultCore == 1 {
                return [
                    .desmume_internal_resolution,
                    .desmume_firmware_language,
                    .desmume_mic_mode,
                ]
            }
        } else if game.gameType == .gba {
            if game.defaultCore == 1 {
                return [.vbam_gbHardware]
            }
        } else if game.gameType == .gbc {
            if game.defaultCore == 2 {
                return [.vbam_gbHardware]
            }
        } else if game.gameType == .gb {
            if game.defaultCore == 0 {
                return [
                    .gambatte_gb_colorization,
                    .gambatte_gb_internal_palette
                ]
            } else if game.defaultCore == 1 {
                return [.mgba_gb_colors]
            } else if game.defaultCore == 2 {
                return [
                    .vbam_gbHardware,
                    .vbam_palettes
                ]
            }
            
        } else if game.gameType == .n64 {
            return [
                .mupen64plus_cpucore,
                .mupen64plus_rdp_plugin,
                .mupen64plus_pak1,
                .mupen64plus_parallel_rdp_upscaling,
                .mupen64plus_43screensize
            ]
        } else if game.gameType == .vb {
            return [.vb_color_mode]
        } else if game.gameType == .pm {
            return [.pokemini_palette]
        } else if game.gameType == .ps1 {
            if game.defaultCore == 0 {
                return [
                    .beetle_psx_hw_internal_resolution,
                    .beetle_psx_hw_override_bios,
                    .beetle_psx_hw_renderer,
                    .beetle_psx_hw_cpu_dynarec,
                ]
            }
        } else if game.gameType == .dc {
            return [
                .reicast_internal_resolution,
                .reicast_language
            ]
        } else if game.isAzahar3DS {
            return [
                .citra_use_cpu_jit,
                .citra_use_default_aes_key,
                .citra_required_online_lle_modules
            ]
        } else if game.gameType == .doom {
            return [.prboom_resolution]
        } else if game.gameType == .dos {
            return [.dosbox_pure_cpu_core]
        } else if game.gameType == .symbian {
            return [.eka2l1_cpu_backend,
                    .eka2l1_device_index]
        } else if game.isDolphinCore {
            var options: Set<Self> = [.dolphin_cheats_enabled, .dolphin_cheats_import]
            if game.gameType == .ngc {
                options.insert(.dolphin_skip_gc_bios)
            }
            return options
        }
        return []
    }
    
    ///Tested optimal core settings, but may be overwritten by user attempts to adjust core settings.
    static func getBestSetupCoreConfigs(game: Game) -> [String: String] {
        var result: [Self: String] = [:]
        if game.gameType == .psp {
            result = [.ppsspp_cheats: "enabled"]
        } else if game.gameType == .nes || game.gameType == .fds {
            result = [.nestopia_aspect: "uncorrected"]
        } else if game.isPicodriveCore {
            result = [
                .picodrive_input1: "6 button pad",
                .picodrive_input2: "6 button pad"
            ]
        } else if game.gameType == .ss {
            if game.defaultCore == 0 {
                result = [.yabause_addon_cartridge: "4M_ram"]
            } else if game.defaultCore == 1 {
                result = [
                    .beetle_saturn_cart: "Extended RAM (4MB)",
                    .beetle_saturn_horizontal_overscan: "20"
                ]
            }
        } else if game.gameType == .ds {
            result = [
                .melonds_mic_input_active: "always",
                .melonds_number_of_screen_layouts: "1",
                .melonds_screen_layout1: "custom",
                .melonds_show_cursor: "disabled",
                .desmume_pointer_type: "touch",
                .desmume_pointer_device_l: "emulated",
                .desmume_pointer_device_r: "emulated",
            ]
        } else if game.gameType == .gba {
            result = [.vbam_usebios: "enabled"]
        } else if game.gameType == .gbc {
            result = [
                .gambatte_gbc_color_correction: "disabled",
                .vbam_usebios: "enabled"
            ]
        } else if game.gameType == .gb {
            result = [.vbam_usebios: "enabled"]
        } else if game.gameType == .ps1, game.defaultCore == 0 {
            result = [
                .beetle_psx_hw_dither_mode: "disabled",
                .beetle_psx_hw_msaa: "8x",
                .beetle_psx_hw_mdec_yuv: "enabled",
                .beetle_psx_hw_aspect_ratio: "4:3",
                //memory card
                .beetle_psx_hw_enable_memcard1: "disabled",
                //pgxp
                .beetle_psx_hw_pgxp_mode: "memory only",
                .beetle_psx_hw_pgxp_nclip: "enabled",
                .beetle_psx_hw_pgxp_texture: "enabled",
                //hacks
                .beetle_psx_hw_gte_overclock: "enabled",
            ]
        } else if game.gameType == .dc {
            result = [.reicast_renderer: "Vulkan"]
        } else if game.gameType == .arcade, game.defaultCore == 0 {
            result = [.mame_cheats_enable: "enabled"]
        } else if game.isAzahar3DS {
            result = [
                .citra_layout_option: "custom",
                .citra_touch_touchscreen: "enabled",
                .citra_input_type: "frontend",
            ]
        } else if game.gameType == .a2600 {
            result = [.stella_crop_hoverscan: "enabled"]
        } else if game.gameType == .a5200 {
            result = [.atari800_system: "5200"]
        } else if game.gameType == .jaguar {
            result = [.virtualjaguar_alt_inputs: "enabled",
                      .virtualjaguar_bios: "enabled",
                      .virtualjaguar_doom_res_hack: "enabled",
                      .virtualjaguar_p1_retropad_analog_lu: "num_7",
                      .virtualjaguar_p1_retropad_analog_ld: "num_8",
                      .virtualjaguar_p1_retropad_analog_ll: "num_9",
                      .virtualjaguar_p1_retropad_analog_lr: "star",
                      .virtualjaguar_p1_retropad_analog_ru: "hash",
                      .virtualjaguar_p2_retropad_analog_lu: "num_7",
                      .irtualjaguar_p2_retropad_analog_ld: "num_8",
                      .virtualjaguar_p2_retropad_analog_ll: "num_9",
                      .virtualjaguar_p2_retropad_analog_lr: "star",
                      .virtualjaguar_p2_retropad_analog_ru: "hash"
            ]
        } else if game.gameType == .doom {
            result = [.prboom_rumble: "enabled"]
        } else if game.gameType == .symbian {
            result = [.screen_buffer_sync: "off"]
        } else if game.isDolphinCore {
            let enableJIT = LibretroCore.jitAvailable() && game.jit
            if enableJIT {
                result = [
                    .dolphin_cpu_clock_rate: "1.0",
                    .dolphin_osd_enabled: "disabled",
                    .dolphin_fast_disc_speed: "disabled",
                    .dolphin_gpu_texture_decoding: "disabled",
                    .dolphin_shader_compilation_mode: "0",
                    .dolphin_log_level: "1",
                    .dolphin_log_boot: "disabled",
                    .dolphin_log_core: "disabled",
                    .dolphin_log_video: "disabled",
                    .dolphin_log_common: "disabled",
                    .dolphin_vi_skip: "disabled"
                ]
            } else {
                result = [
                    .dolphin_cpu_clock_rate: "0.2",
                    .dolphin_osd_enabled: "disabled",
                    .dolphin_fast_disc_speed: "enabled",
                    .dolphin_gpu_texture_decoding: "enabled",
                    .dolphin_shader_compilation_mode: "3",
                    .dolphin_log_level: "1",
                    .dolphin_log_boot: "disabled",
                    .dolphin_log_core: "disabled",
                    .dolphin_log_video: "disabled",
                    .dolphin_log_common: "disabled",
                    .dolphin_vi_skip: "enabled"
                ]
            }
        }
        return result.mapKeysAndValues({ ($0.key.rawValue, $0.value) })
    }
    
    static func resolvedCoreConfigs(game: Game,
                                    optimizationCoreConfigs: [Self: String],
                                    safeMode: Bool) -> [String: String]? {
        let bestSetupCoreConfigs = getBestSetupCoreConfigs(game: game)
        var resolvedCoreConfigs = optimizationCoreConfigs.mapKeysAndValues({
            ($0.key.rawValue, $0.value)
        })
        resolvedCoreConfigs = bestSetupCoreConfigs + resolvedCoreConfigs
        if !safeMode,
           let storeCoreConfigs = Prefference.defalut.getPrefference(kind: .coreOptions,
                                                                     storeKey: .coreOptionsKey(gameId: game.id, defaultCore: game.defaultCore),
                                                                     bestEfforts: true)?.coreOptionsValue {
            resolvedCoreConfigs += storeCoreConfigs
        }
        return resolvedCoreConfigs
    }
    
    static func ppssppServerAddressConfig(index: String) -> Self? {
        return SpecialCoreOption(rawValue: "ppsspp_pro_ad_hoc_server_address\(index)")
    }
}
