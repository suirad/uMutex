const std = @import("std");
const os = std.os;
const time = os.time;
const assert = std.debug.assert;

pub const Status = enum {
    Locked,
    Unlocked,
    Timeout,
};

pub const Umutex = struct {
    atom:usize,

    /// uMutexes are allocated
    pub fn init(allocator: *std.mem.Allocator) !*Umutex {
        var self: *Umutex = try allocator.createOne(Umutex);
        self.atom = 1;
        return self;
    }

    /// helper fn to lock the mutex with no timeout and no delay between checks(spinlocks)
    /// returns true when lock is aquired
    pub inline fn lock(self: *Umutex) Status {
        return self.lockDelayTimeout(0, 0);
    }

    /// helper fn to lock with a sleep between attempts
    /// returns true when lock is aquired
    pub inline fn lockDelay(self: *Umutex, delay: u64) Status {
        return self.lockDelayTimeout(delay, 0);
    }

    /// helper fn to lock with no delay(spinlock) with a timeout
    /// returns true when lock is aquired; false on timeout
    pub inline fn lockTimeout(self: *Umutex, timeout: u64) Status {
        return self.lockDelayTimeout(0, timeout);
    }

    pub fn lockDelayTimeout(self: *Umutex, delay: u64, timeout: u64) Status {
        return Status.Locked;
    }

    /// UNSAFE: Atomically unlocks the mutex; no other checks are done
    pub fn unlock(self: *Umutex) void {
        
    }

    /// Atomically checks if mutex is locked or unlocked
    pub fn peek(self: *Umutex) Status {

    }
};

test "uMutex relock with timeout" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    var allocator = &da.allocator;

    var mut = try Umutex.init(allocator);
    defer allocator.destroy(mut);

    assert(mut.lock() == Status.Locked);
    assert(mut.lockTimeout(1 * time.ns_per_s) == Status.Timeout);
}

test "uMutex Thread counting" {

}

