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
    atom: std.atomic.Int(usize),

    /// uMutexes are allocated
    pub fn init(allocator: *std.mem.Allocator) !*Umutex {
        var self: *Umutex = try allocator.createOne(Umutex);
        self.atom = std.atomic.Int(usize).init(1);
        return self;
    }

    /// Helper fn to lock the mutex with no timeout and no delay between checks(spinlocks)
    /// Returns true when lock is aquired
    pub inline fn lock(self: *Umutex) Status {
        return self.lockDelayTimeout(0, 0);
    }

    /// Helper fn to lock with a sleep between attempts
    /// Returns true when lock is aquired
    pub inline fn lockDelay(self: *Umutex, nanoDelay: u64) Status {
        return self.lockDelayTimeout(nanoDelay, 0);
    }

    /// Helper fn to lock with no delay(spinlock) with a timeout
    /// Returns true when lock is aquired; false on timeout
    pub inline fn lockTimeout(self: *Umutex, miliTimeout: u64) Status {
        return self.lockDelayTimeout(0, miliTimeout);
    }

    /// Mutex locking with optional sleep between checks and timeout
    pub fn lockDelayTimeout(self: *Umutex, nanoDelay: u64, miliTimeout: u64) Status {
        var startTime: u64 = 0;
        if (miliTimeout > 0){
            startTime = time.milliTimestamp();
        }
        while (self.atom.xchg(0) != 1){
            if (miliTimeout > 0 and (time.milliTimestamp() - startTime) > miliTimeout){
                return Status.Timeout;
            }
            if (nanoDelay > 0) {
                time.sleep(nanoDelay);
            }
        }
        return Status.Locked;
    }

    /// Atomically unlocks the mutex; no other checks are done
    pub fn unlock(self: *Umutex) void {
        // If this assersion fails, then umutex was unlocked earlier from somewhere else
        assert(self.atom.xchg(1) == 0);
    }

    /// Atomically checks if mutex is locked or unlocked
    pub fn peek(self: *Umutex) Status {
        if (self.atom.get() == 1){
            return Status.Unlocked;
        }
        return Status.Locked;
    }
};

test "uMutex lock, unlock, and peeking" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var allocator = &da.allocator;

    var mutex = try Umutex.init(allocator);
    defer allocator.destroy(mutex);

    assert(mutex.lock() == Status.Locked);
    assert(mutex.peek() == Status.Locked);
    mutex.unlock();
    assert(mutex.peek() == Status.Unlocked);
}

test "uMutex lock and relock with timeout" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var allocator = &da.allocator;

    var mutex = try Umutex.init(allocator);
    defer allocator.destroy(mutex);

    assert(mutex.lock() == Status.Locked);
    assert(mutex.lockTimeout(50) == Status.Timeout);
}

test "uMutex atomic counting with threads" {
    // this test is a clone of the thread test of std.mutex
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var allocator = &da.allocator;

    var mutex = try Umutex.init(allocator);
    defer allocator.destroy(mutex);
    var context = Context{
        .mutex = mutex,
        .data = 0,
    };

    const thread_count = 10;
    var threads: [thread_count]*std.os.Thread = undefined;
    for (threads) |*t| {
        t.* = try std.os.spawnThread(&context, worker);
    }
    for (threads) |t|
        t.wait();

    std.debug.assertOrPanic(context.data == thread_count * Context.incr_count);
}

const Context = struct {
    mutex: *Umutex,
    data: i128,

    const incr_count = 10000;
};

fn worker(ctx: *Context) void {
    var i: usize = 0;
    while (i != Context.incr_count) : (i += 1) {
        const held = ctx.mutex.lock();
        defer ctx.mutex.unlock();

        ctx.data += 1;
    }
}
