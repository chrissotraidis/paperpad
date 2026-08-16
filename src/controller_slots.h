#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace paperpad::input {

using ControllerHandle = void*;
using ControllerInstanceId = int32_t;

struct EnumeratedController {
    int device_index = -1;
    ControllerInstanceId instance_id = -1;
};

class ControllerBackend {
public:
    virtual ~ControllerBackend() = default;

    virtual std::vector<EnumeratedController> enumerate() = 0;
    virtual ControllerHandle open(int device_index) = 0;
    virtual void close(ControllerHandle handle) = 0;
    virtual bool connected(ControllerHandle handle) const = 0;
    virtual ControllerInstanceId instance_id(ControllerHandle handle) const = 0;
};

enum class ControllerSlotChangeKind {
    Assigned,
    Released,
    OpenFailed,
};

struct ControllerSlotChange {
    ControllerSlotChangeKind kind = ControllerSlotChangeKind::OpenFailed;
    int player_slot = -1;
    int device_index = -1;
    ControllerInstanceId instance_id = -1;
};

class ControllerSlots {
public:
    static constexpr std::size_t max_players = 4;

    std::vector<ControllerSlotChange> reconcile(ControllerBackend& backend);
    std::vector<ControllerSlotChange> release_instance(
        ControllerBackend& backend, ControllerInstanceId instance_id);
    void close_all(ControllerBackend& backend);

    ControllerHandle player_handle(std::size_t player_slot) const;
    ControllerInstanceId player_instance_id(std::size_t player_slot) const;
    std::size_t connected_count() const;

private:
    struct Slot {
        ControllerHandle handle = nullptr;
        ControllerInstanceId instance_id = -1;
    };

    std::array<Slot, max_players> slots_{};
};

} // namespace paperpad::input
