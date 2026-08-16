#include "controller_slots.h"

#include <algorithm>

namespace paperpad::input {

namespace {

bool contains_instance(
    const std::vector<EnumeratedController>& controllers,
    ControllerInstanceId instance_id) {
    return std::any_of(controllers.begin(), controllers.end(), [instance_id](const auto& item) {
        return item.instance_id == instance_id;
    });
}

} // namespace

std::vector<ControllerSlotChange> ControllerSlots::reconcile(ControllerBackend& backend) {
    std::vector<ControllerSlotChange> changes;
    std::vector<EnumeratedController> controllers = backend.enumerate();
    controllers.erase(
        std::remove_if(controllers.begin(), controllers.end(), [](const auto& item) {
            return item.device_index < 0 || item.instance_id < 0;
        }),
        controllers.end());

    for (std::size_t slot_index = 0; slot_index < slots_.size(); ++slot_index) {
        Slot& slot = slots_[slot_index];
        if (slot.handle == nullptr) {
            slot.instance_id = -1;
            continue;
        }

        const bool valid = backend.connected(slot.handle)
            && backend.instance_id(slot.handle) == slot.instance_id
            && contains_instance(controllers, slot.instance_id);
        if (!valid) {
            const ControllerInstanceId released_instance = slot.instance_id;
            backend.close(slot.handle);
            slot = {};
            changes.push_back({
                ControllerSlotChangeKind::Released,
                static_cast<int>(slot_index),
                -1,
                released_instance,
            });
        }
    }

    for (const EnumeratedController& item : controllers) {
        const bool already_assigned = std::any_of(slots_.begin(), slots_.end(), [&item](const Slot& slot) {
            return slot.handle != nullptr && slot.instance_id == item.instance_id;
        });
        if (already_assigned) {
            continue;
        }

        const auto free_slot = std::find_if(slots_.begin(), slots_.end(), [](const Slot& slot) {
            return slot.handle == nullptr;
        });
        if (free_slot == slots_.end()) {
            break;
        }

        const int player_slot = static_cast<int>(std::distance(slots_.begin(), free_slot));
        ControllerHandle handle = backend.open(item.device_index);
        if (handle == nullptr || !backend.connected(handle)
            || backend.instance_id(handle) != item.instance_id) {
            if (handle != nullptr) {
                backend.close(handle);
            }
            changes.push_back({
                ControllerSlotChangeKind::OpenFailed,
                player_slot,
                item.device_index,
                item.instance_id,
            });
            continue;
        }

        *free_slot = {handle, item.instance_id};
        changes.push_back({
            ControllerSlotChangeKind::Assigned,
            player_slot,
            item.device_index,
            item.instance_id,
        });
    }

    return changes;
}

std::vector<ControllerSlotChange> ControllerSlots::release_instance(
    ControllerBackend& backend, ControllerInstanceId instance_id) {
    std::vector<ControllerSlotChange> changes;
    for (std::size_t slot_index = 0; slot_index < slots_.size(); ++slot_index) {
        Slot& slot = slots_[slot_index];
        if (slot.handle == nullptr || slot.instance_id != instance_id) {
            continue;
        }

        backend.close(slot.handle);
        slot = {};
        changes.push_back({
            ControllerSlotChangeKind::Released,
            static_cast<int>(slot_index),
            -1,
            instance_id,
        });
    }
    return changes;
}

void ControllerSlots::close_all(ControllerBackend& backend) {
    for (Slot& slot : slots_) {
        if (slot.handle != nullptr) {
            backend.close(slot.handle);
        }
        slot = {};
    }
}

ControllerHandle ControllerSlots::player_handle(std::size_t player_slot) const {
    return player_slot < slots_.size() ? slots_[player_slot].handle : nullptr;
}

ControllerInstanceId ControllerSlots::player_instance_id(std::size_t player_slot) const {
    return player_slot < slots_.size() ? slots_[player_slot].instance_id : -1;
}

std::size_t ControllerSlots::connected_count() const {
    return static_cast<std::size_t>(std::count_if(slots_.begin(), slots_.end(), [](const Slot& slot) {
        return slot.handle != nullptr;
    }));
}

} // namespace paperpad::input
