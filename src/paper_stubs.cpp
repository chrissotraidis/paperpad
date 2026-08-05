#include "recomp.h"

#include <array>
#include <cstdint>

namespace {
struct TlbEntry {
    bool valid = false;
    uint32_t virtual_base = 0;
    uint32_t physical_base = 0;
    uint32_t page_size = 0x1000;
};

std::array<TlbEntry, 32> tlb_entries{};

uint32_t page_size_from_mask(uint32_t page_mask) {
    return ((page_mask | 0x1FFFu) + 1u) >> 1;
}

bool is_rdram_kseg(uint32_t address) {
    return (address >= 0x80000000u && address < 0x80800000u) ||
           (address >= 0xA0000000u && address < 0xA0800000u);
}
}

extern "C" uint8_t* recomp_translate_address(uint8_t* rdram, gpr address) {
    const uint32_t virtual_address = static_cast<uint32_t>(address);

    if (is_rdram_kseg(virtual_address)) {
        return rdram + (virtual_address & 0x7FFFFFu);
    }

    for (const TlbEntry& entry : tlb_entries) {
        if (!entry.valid) {
            continue;
        }

        const uint32_t page_offset = virtual_address - entry.virtual_base;
        if (page_offset < entry.page_size) {
            return rdram + ((entry.physical_base + page_offset) & 0x7FFFFFu);
        }
    }

    return rdram + (address - 0xFFFFFFFF80000000ull);
}

extern "C" void osMapTLB_recomp(uint8_t*, recomp_context* ctx) {
    const uint32_t index = static_cast<uint32_t>(ctx->r4) & 31u;
    const uint32_t page_mask = static_cast<uint32_t>(ctx->r5);
    const uint32_t virtual_base = static_cast<uint32_t>(ctx->r6) & ~(page_size_from_mask(page_mask) - 1u);
    const uint32_t physical_base = static_cast<uint32_t>(ctx->r7) & 0xFFFFFFu;

    tlb_entries[index] = TlbEntry{
        .valid = true,
        .virtual_base = virtual_base,
        .physical_base = physical_base,
        .page_size = page_size_from_mask(page_mask),
    };
}

extern "C" void osUnmapTLB_recomp(uint8_t*, recomp_context* ctx) {
    const uint32_t index = static_cast<uint32_t>(ctx->r4) & 31u;
    tlb_entries[index] = {};
}



// The mstan runtime's sp-task ring references PSR diagnostic counters;
// PaperPad provides neutral stubs so the runtime links standalone.
namespace pkmnstadium::dbg {
    std::atomic<uint64_t> g_frame_count{0};
    std::atomic<uint64_t> g_send_dl_count{0};
}

// mstan's RT64 interpreter carries PSR diagnostic hooks; neutral stubs keep
// PaperPad standalone.
extern "C" void pkmnstadium_gdl_walk_snapshot(uint32_t target_vaddr, uint32_t parent_vaddr, const uint8_t* head_ptr, uint64_t submit_seq) {
    (void)target_vaddr; (void)parent_vaddr; (void)head_ptr; (void)submit_seq;
}
extern "C" const char* pkmnstadium_trace_at(uint64_t idx) { (void)idx; return nullptr; }
extern "C" uint64_t pkmnstadium_trace_capacity() { return 0; }
extern "C" uint32_t pkmnstadium_trace_write_idx() { return 0; }

// AnnePad's runtime carries a PSR post-mortem hook; PaperPad keeps a neutral
// stub that logs the reason.
extern "C" void psr_post_mortem_dump(const char* reason, void* fault_info) {
    fprintf(stderr, "[post-mortem] %s\n", reason ? reason : "unknown");
    (void)fault_info;
}
