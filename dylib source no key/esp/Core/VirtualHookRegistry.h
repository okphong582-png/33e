#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace VirtualHooks {
// Callers serialize operations. Keep originals after restoration: a game
// thread can have fetched the replacement pointer immediately before OFF.
template <std::size_t Capacity = 64> class Registry {
public:
    struct Record { std::uint64_t slot=0, original=0, replacement=0; bool active=false; };
    enum class Result { Installed, Existing, Conflict, Unreadable, ReadOnly, Full };
    const Record *find(std::uint64_t slot) const {
        for (std::size_t i=0;i<count_;++i) if (records_[i].slot==slot) return &records_[i];
        return nullptr;
    }
    std::uint64_t original(std::uint64_t slot) const {
        const auto *r=find(slot); return r ? r->original : 0;
    }
    template<class Read, class Writable, class CompareExchange>
    Result install(std::uint64_t slot,std::uint64_t expected,std::uint64_t replacement,
                   Read read,Writable writable,CompareExchange exchange) {
        if (!slot || slot%8 || !expected || !replacement || expected==replacement) return Result::Conflict;
        std::uint64_t live=0;
        if (!read(slot,live)) return Result::Unreadable;
        auto *r=const_cast<Record *>(find(slot));
        if (r && (r->original!=expected || r->replacement!=replacement)) return Result::Conflict;
        if (live==replacement) {
            if (!r) return Result::Conflict; // Never adopt an unknown hook.
            r->active=true; return Result::Existing;
        }
        if (live!=expected) return Result::Conflict;
        if (!writable(slot)) return Result::ReadOnly;
        const bool added=!r;
        if (!r) {
            if (count_==Capacity) return Result::Full;
            r=&records_[count_++]; *r={slot,expected,replacement,false};
        }
        // Publish the original before exposing the callback to another thread.
        auto compare=expected;
        if (!exchange(slot,compare,replacement)) {
            if (added) { *r={}; --count_; }
            return Result::Conflict;
        }
        r->active=true; return Result::Installed;
    }
    template<class Read,class Writable,class CompareExchange>
    bool restoreAll(Read read,Writable writable,CompareExchange exchange) {
        bool complete=true;
        for (std::size_t i=0;i<count_;++i) {
            auto &r=records_[i]; if (!r.active) continue;
            std::uint64_t live=0;
            if (!read(r.slot,live)) { complete=false; continue; }
            if (live!=r.replacement) { r.active=false; continue; }
            if (!writable(r.slot)) { complete=false; continue; }
            auto expected=r.replacement;
            if (exchange(r.slot,expected,r.original) || expected!=r.replacement) r.active=false;
            else complete=false;
        }
        return complete;
    }
private:
    std::array<Record,Capacity> records_{};
    std::size_t count_=0;
};
}
