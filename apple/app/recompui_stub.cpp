#include "recompui_launcher.h"

#include <cstring>

namespace pkmnstadium::recompui {

bool run(const char* rom_path, char* out_rom, std::size_t out_len) {
    if (out_rom != nullptr && out_len > 0) {
        const char* source = rom_path == nullptr ? "" : rom_path;
        std::strncpy(out_rom, source, out_len - 1);
        out_rom[out_len - 1] = '\0';
    }
    return true;
}

PortAssignment port_assignment(int port) {
    return port == 0
        ? PortAssignment{true, DeviceKind::Gamepad, -1}
        : PortAssignment{};
}

bool startup_fullscreen() { return true; }
std::string startup_graphics_api() { return "auto"; }
int startup_ds_option() { return 1; }
int startup_msaa() { return 0; }
std::string startup_audio_device() { return {}; }

} // namespace pkmnstadium::recompui
