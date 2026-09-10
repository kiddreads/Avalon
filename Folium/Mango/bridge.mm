//
//  bridge.cpp
//  Mango
//
//  Created by Jarrod Norwell on 2/7/2026.
//

#include "bridge.h"
#include "mesence.h"

#include "Shared/EmuSettings.h"
#include "Shared/MessageManager.h"
#include "Utilities/FolderUtilities.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <mutex>
#include <thread>

#include <AVFAudio/AVFAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>

#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "Mango-Swift.h"
using namespace Mango;

struct cntnr_k {
    MangoCommon mangoCommon{MangoCommon::init()};
    MangoSystem mangoSystem{MangoSystem::init()};
    
    std::unique_ptr<Emulator> emulator;
    std::unique_ptr<NESInput> input;
    std::unique_ptr<iOSRenderer> renderer;
    std::unique_ptr<iOSSink> sink;
    
    std::condition_variable_any cv;
    std::mutex mutex;
    std::atomic<bool> paused, running;
    std::jthread thread;
    
    uint32_t height, width;
    
    std::filesystem::path mango_path, debugger_path, firmware_path;
    std::filesystem::path hd_packs_path, recent_games_path, saves_path;
    std::filesystem::path save_states_path, screenshots_path;
} cntnr_k;

class iOSMessageManager final : public IMessageManager
{
public:
    
    
    void DisplayMessage(string title, string message) override
    {
        printf("[%s]: %s\n", title.c_str(), message.c_str());
    }
};

void mango::print_about(void) {
    printf("Welcome to Mango\n");
    printf("Game Boy emulator based on Gambatte\n");
}

void mango::initialize_paths(void) {
    auto mangoDirectoryURL{cntnr_k.mangoCommon.getMangoDirectoryURL()};
    if (mangoDirectoryURL.isSome()) {
        auto mango_path{std::filesystem::path{mangoDirectoryURL.get()}};
        
        cntnr_k.mango_path = mango_path;
        cntnr_k.debugger_path = mango_path / "debugger";
        cntnr_k.firmware_path = mango_path / "firmware";
        cntnr_k.hd_packs_path = mango_path / "hd_packs";
        cntnr_k.recent_games_path = mango_path / "recent_games";
        cntnr_k.saves_path = mango_path / "saves";
        cntnr_k.save_states_path = mango_path / "save_states";
        cntnr_k.screenshots_path = mango_path / "screenshots";
    }
}

void mango::initialize_system(void) {
    FolderUtilities::SetHomeFolder(cntnr_k.mango_path.string());
    
    auto mm{std::make_unique<iOSMessageManager>()};
    MessageManager::SetOptions(false, true);
    MessageManager::RegisterMessageManager(mm.get());
    
    cntnr_k.emulator = std::make_unique<Emulator>();
    cntnr_k.emulator->Initialize(false);
    
    cntnr_k.input = std::make_unique<NESInput>();
    cntnr_k.renderer = std::make_unique<iOSRenderer>(cntnr_k.emulator, 240, 256);
    cntnr_k.sink = std::make_unique<iOSSink>(cntnr_k.emulator, 48000);
    
    NesConfig nes = cntnr_k.emulator->GetSettings()->GetNesConfig();
    memcpy(nes.UserPalette, nes::kNesPalette2C02, sizeof(nes::kNesPalette2C02));
    nes.IsFullColorPalette = false;
    for (int i = 0; i < sizeof(nes.ChannelVolumes) / sizeof(nes.ChannelVolumes[0]); i++)
        nes.ChannelVolumes[i] = 100;
    nes.NtscOverscan.Left = nes::kNesOverscanLeft;
    nes.PalOverscan.Left = nes::kNesOverscanLeft;
    nes.Port1.Type = ControllerType::NesController;
    cntnr_k.emulator->GetSettings()->SetNesConfig(nes);
}


void mango::destroy_system(void) {
    mango::initialize_system();
}


void mango::insert_disc(std::string path) {
    cntnr_k.emulator->LoadRom({path}, {});
    cntnr_k.emulator->RegisterInputProvider(cntnr_k.input.get());
}


bool mango::is_paused(bool change, bool set_paused) {
    if (change)
        cntnr_k.paused.store(set_paused);
    
    if (change)
        set_paused ? cntnr_k.emulator->Pause() : cntnr_k.emulator->Resume();
    
    return cntnr_k.paused.load();
}

bool mango::is_running(bool change, bool set_running) {
    if (change)
        cntnr_k.running.store(set_running);
    return cntnr_k.running.load();
}


void mango::start(void) {
    cntnr_k.thread = std::jthread([&](std::stop_token token) {
        using namespace std::chrono;
        
        const auto frameDuration = duration<double>(1.0 / 60.0);
        
        while (!token.stop_requested()) {
            {
                std::unique_lock lock(cntnr_k.mutex);
                cntnr_k.cv.wait(lock, token, []() {
                    return !cntnr_k.paused.load();
                });
                
                if (token.stop_requested())
                    break;
            }
            
            auto frameStart = steady_clock::now();
            
            std::vector<uint32_t> data{0};
            if (cntnr_k.renderer->GetFrameIfReady(data, cntnr_k.height, cntnr_k.width))
                mango::video_callback(mango::context, data.data(), 0);

            // Limit FPS
            auto frameEnd = steady_clock::now();
            auto elapsed = frameEnd - frameStart;
            if (elapsed < frameDuration)
                std::this_thread::sleep_for(frameDuration - elapsed);
        }
    });
}

void mango::stop(void) {
    cntnr_k.emulator->Stop(false, true);
    
    cntnr_k.thread.request_stop();
    if (cntnr_k.thread.joinable())
        cntnr_k.thread.join();
    
    cntnr_k.paused.store(false);
    cntnr_k.running.store(false);
}


int mango::framebuffer_height(void) {
    return cntnr_k.height;
}

int mango::framebuffer_width(void) {
    return cntnr_k.width;
}


void mango::audio_buffer_callback(mango::AudioVideoBufferCallback callback) {
    mango::audio_callback = callback;
}

void mango::video_buffer_callback(mango::AudioVideoBufferCallback callback) {
    mango::video_callback = callback;
}


void mango::press_button(uint32_t button) {
    cntnr_k.input->keys |= button;
}

void mango::release_button(uint32_t button) {
    cntnr_k.input->keys &= ~button;
}


void mango::set_context(void* context) {
    mango::context = context;
}
