//
//  bridge.cpp
//  Durian
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

#include "Durian-Swift.h"
using namespace Durian;

struct cntnr_d {
    DurianCommon durianCommon{DurianCommon::init()};
    DurianSystem durianSystem{DurianSystem::init()};
    
    std::unique_ptr<Emulator> emulator;
    std::unique_ptr<WSInput> input;
    std::unique_ptr<iOSRenderer> renderer;
    std::unique_ptr<iOSSink> sink;
    
    std::condition_variable_any cv;
    std::mutex mutex;
    std::atomic<bool> paused, running;
    std::jthread thread;
    
    uint32_t height, width;
    
    std::filesystem::path durian_path, debugger_path, firmware_path;
    std::filesystem::path hd_packs_path, recent_games_path, saves_path;
    std::filesystem::path save_states_path, screenshots_path;
} cntnr_d;

class iOSMessageManager final : public IMessageManager
{
public:
    
    
    void DisplayMessage(string title, string message) override
    {
        printf("[%s]: %s\n", title.c_str(), message.c_str());
    }
};

void durian::print_about(void) {
    printf("Welcome to Mango\n");
    printf("Game Boy emulator based on Gambatte\n");
}

void durian::initialize_paths(void) {
    auto durianDirectoryURL{cntnr_d.durianCommon.getDurianDirectoryURL()};
    if (durianDirectoryURL.isSome()) {
        auto durian_path{std::filesystem::path{durianDirectoryURL.get()}};
        
        cntnr_d.durian_path = durian_path;
        cntnr_d.debugger_path = durian_path / "debugger";
        cntnr_d.firmware_path = durian_path / "firmware";
        cntnr_d.hd_packs_path = durian_path / "hd_packs";
        cntnr_d.recent_games_path = durian_path / "recent_games";
        cntnr_d.saves_path = durian_path / "saves";
        cntnr_d.save_states_path = durian_path / "save_states";
        cntnr_d.screenshots_path = durian_path / "screenshots";
    }
}

void durian::initialize_system(void) {
    FolderUtilities::SetHomeFolder(cntnr_d.durian_path.string());
    
    auto mm{std::make_unique<iOSMessageManager>()};
    MessageManager::SetOptions(false, true);
    MessageManager::RegisterMessageManager(mm.get());
    
    cntnr_d.emulator = std::make_unique<Emulator>();
    cntnr_d.emulator->Initialize(false);
    
    cntnr_d.input = std::make_unique<WSInput>();
    cntnr_d.renderer = std::make_unique<iOSRenderer>(cntnr_d.emulator, 144, 224);
    cntnr_d.sink = std::make_unique<iOSSink>(cntnr_d.emulator, 48000);
    
    WsConfig ws = cntnr_d.emulator->GetSettings()->GetWsConfig();
    ws.AudioMode = WsAudioMode::Speakers;
    for (auto channel : {&ws.Channel1Vol, &ws.Channel2Vol, &ws.Channel3Vol, &ws.Channel4Vol, &ws.Channel5Vol})
        *channel = 100;
    ws.ControllerHorizontal.Type = ControllerType::WsController;
    ws.ControllerVertical.Type = ControllerType::WsControllerVertical;
    cntnr_d.emulator->GetSettings()->SetWsConfig(ws);
}


void durian::destroy_system(void) {
    durian::initialize_system();
}


void durian::insert_disc(std::string path) {
    cntnr_d.emulator->LoadRom({path}, {});
    cntnr_d.emulator->RegisterInputProvider(cntnr_d.input.get());
}


bool durian::is_paused(bool change, bool set_paused) {
    if (change)
        cntnr_d.paused.store(set_paused);
    
    if (change)
        set_paused ? cntnr_d.emulator->Pause() : cntnr_d.emulator->Resume();
    
    return cntnr_d.paused.load();
}

bool durian::is_running(bool change, bool set_running) {
    if (change)
        cntnr_d.running.store(set_running);
    return cntnr_d.running.load();
}


void durian::start(void) {
    cntnr_d.thread = std::jthread([&](std::stop_token token) {
        using namespace std::chrono;
        
        const auto frameDuration = duration<double>(1.0 / 60.0);
        
        while (!token.stop_requested()) {
            {
                std::unique_lock lock(cntnr_d.mutex);
                cntnr_d.cv.wait(lock, token, []() {
                    return !cntnr_d.paused.load();
                });
                
                if (token.stop_requested())
                    break;
            }
            
            auto frameStart = steady_clock::now();
            
            std::vector<uint32_t> data{0};
            if (cntnr_d.renderer->GetFrameIfReady(data, cntnr_d.height, cntnr_d.width))
                durian::video_callback(durian::context, data.data(), 0);

            // Limit FPS
            auto frameEnd = steady_clock::now();
            auto elapsed = frameEnd - frameStart;
            if (elapsed < frameDuration)
                std::this_thread::sleep_for(frameDuration - elapsed);
        }
    });
}

void durian::stop(void) {
    cntnr_d.emulator->Stop(false, true);
    
    cntnr_d.thread.request_stop();
    if (cntnr_d.thread.joinable())
        cntnr_d.thread.join();
    
    cntnr_d.paused.store(false);
    cntnr_d.running.store(false);
}


int durian::framebuffer_height(void) {
    return cntnr_d.height;
}

int durian::framebuffer_width(void) {
    return cntnr_d.width;
}


void durian::audio_buffer_callback(durian::AudioVideoBufferCallback callback) {
    durian::audio_callback = callback;
}

void durian::video_buffer_callback(durian::AudioVideoBufferCallback callback) {
    durian::video_callback = callback;
}


void durian::press_button(uint32_t button) {
    cntnr_d.input->keys |= button;
}

void durian::release_button(uint32_t button) {
    cntnr_d.input->keys &= ~button;
}


void durian::set_context(void* context) {
    durian::context = context;
}
