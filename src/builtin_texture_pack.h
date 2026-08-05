#pragma once

#include <filesystem>

namespace paper_mario {
    // PaperPad does not ship a built-in replacement texture pack; the game
    // runs with its original textures. Kept as a no-op interface for parity
    // with the upstream ReCut source.
    bool ensure_builtin_texture_pack(const std::filesystem::path& directory);
}
