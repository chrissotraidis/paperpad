#include "controller_slots.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <utility>
#include <vector>

namespace {

using namespace paperpad::input;

struct FakeController {
    int device_index = -1;
    ControllerInstanceId instance_id = -1;
    bool attached = true;
    uint16_t buttons = 0;
    float axis = 0.0f;
};

class FakeBackend final : public ControllerBackend {
public:
    void connect(int device_index, ControllerInstanceId instance_id) {
        visible.push_back({device_index, instance_id});
    }

    void disconnect_without_event(ControllerInstanceId instance_id) {
        visible.erase(
            std::remove_if(visible.begin(), visible.end(), [instance_id](const auto& item) {
                return item.instance_id == instance_id;
            }),
            visible.end());
        for (const auto& handle : handles) {
            if (handle->instance_id == instance_id) {
                handle->attached = false;
            }
        }
    }

    FakeController* fake_handle(const ControllerSlots& slots, std::size_t player_slot) const {
        return static_cast<FakeController*>(slots.player_handle(player_slot));
    }

    std::vector<EnumeratedController> enumerate() override {
        return visible;
    }

    ControllerHandle open(int device_index) override {
        const auto item = std::find_if(visible.begin(), visible.end(), [device_index](const auto& candidate) {
            return candidate.device_index == device_index;
        });
        if (item == visible.end()) {
            return nullptr;
        }
        handles.push_back(std::make_unique<FakeController>(FakeController{
            item->device_index, item->instance_id, true, 0, 0.0f,
        }));
        return handles.back().get();
    }

    void close(ControllerHandle handle) override {
        static_cast<FakeController*>(handle)->attached = false;
    }

    bool connected(ControllerHandle handle) const override {
        return static_cast<FakeController*>(handle)->attached;
    }

    ControllerInstanceId instance_id(ControllerHandle handle) const override {
        return static_cast<FakeController*>(handle)->instance_id;
    }

private:
    std::vector<EnumeratedController> visible;
    std::vector<std::unique_ptr<FakeController>> handles;
};

[[noreturn]] void fail(const char* message) {
    std::fprintf(stderr, "controller_slots_test: %s\n", message);
    std::exit(EXIT_FAILURE);
}

void require(bool condition, const char* message) {
    if (!condition) {
        fail(message);
    }
}

std::pair<uint16_t, float> read_player_one(
    const FakeBackend& backend,
    const ControllerSlots& slots) {
    FakeController* handle = backend.fake_handle(slots, 0);
    if (handle == nullptr || !handle->attached) {
        return {0, 0.0f};
    }
    return {handle->buttons, handle->axis};
}

void test_single_controller_reconnect_releases_input() {
    FakeBackend backend;
    ControllerSlots slots;
    backend.connect(0, 101);
    slots.reconcile(backend);
    require(slots.player_instance_id(0) == 101, "initial controller did not take player 1");

    FakeController* first = backend.fake_handle(slots, 0);
    first->buttons = 0x8000;
    first->axis = 0.75f;
    const auto held = read_player_one(backend, slots);
    require(held.first != 0 && std::abs(held.second) > 0.0f, "test input was not held");

    backend.disconnect_without_event(101);
    slots.reconcile(backend);
    require(slots.player_handle(0) == nullptr, "stale controller kept player 1");
    require(slots.connected_count() == 0, "disconnected controller remained assigned");
    const auto released = read_player_one(backend, slots);
    require(released.first == 0 && released.second == 0.0f,
        "disconnect did not release held buttons and axes");

    backend.connect(0, 202);
    slots.reconcile(backend);
    require(slots.player_instance_id(0) == 202, "sole returning controller did not reclaim player 1");
    FakeController* returning = backend.fake_handle(slots, 0);
    require(returning->buttons == 0 && returning->axis == 0.0f,
        "reconnect inherited held buttons or axes");
}

void test_two_controller_slots_are_preserved() {
    FakeBackend backend;
    ControllerSlots slots;
    backend.connect(0, 101);
    slots.reconcile(backend);
    backend.connect(1, 202);
    slots.reconcile(backend);

    require(slots.player_instance_id(0) == 101, "additional controller displaced player 1");
    require(slots.player_instance_id(1) == 202, "additional controller did not take player 2");

    backend.disconnect_without_event(202);
    slots.reconcile(backend);
    require(slots.player_instance_id(0) == 101, "player 1 moved after player 2 disconnected");
    require(slots.player_handle(1) == nullptr, "stale player 2 handle was retained");

    backend.connect(1, 303);
    slots.reconcile(backend);
    require(slots.player_instance_id(0) == 101, "returning player 2 displaced player 1");
    require(slots.player_instance_id(1) == 303, "returning additional controller missed next free slot");
}

void test_foreground_resume_reconciles_missed_removal() {
    FakeBackend backend;
    ControllerSlots slots;
    backend.connect(0, 101);
    slots.reconcile(backend);

    backend.disconnect_without_event(101);
    backend.connect(0, 202);
    const auto changes = slots.reconcile(backend);

    require(changes.size() == 2, "foreground reconcile did not release then assign");
    require(changes[0].kind == ControllerSlotChangeKind::Released
            && changes[0].player_slot == 0 && changes[0].instance_id == 101,
        "missed removal did not release stale player 1 first");
    require(changes[1].kind == ControllerSlotChangeKind::Assigned
            && changes[1].player_slot == 0 && changes[1].instance_id == 202,
        "foreground reconnect did not assign the returning controller to player 1");
}

} // namespace

int main() {
    test_single_controller_reconnect_releases_input();
    test_two_controller_slots_are_preserved();
    test_foreground_resume_reconciles_missed_removal();
    std::puts("controller_slots_test: all scenarios passed");
    return EXIT_SUCCESS;
}
