const std = @import("std");
const umutex = @import("umutex.zig");

pub fn main() !void {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var alloc = &da.allocator;

    var mutex = try umutex.Umutex.init(alloc);
    defer alloc.destroy(mutex);

    var work = Workdata{
        .mutex = mutex,
        .data = 0,
    };

    var threads: [10]*std.os.Thread = undefined;
    for (threads) |*thread| { 
        thread.* = try std.os.spawnThread(&work, worker);
    }

    std.os.time.sleep(3 * std.os.time.ns_per_s);
    
    std.debug.warn("Using {} threads, the final value is: {}\n", threads.len, work.data);
}

const Workdata = struct {
    mutex: *umutex.Umutex,
    data: u32,
};

fn worker(work: *Workdata) void {
    _ = work.mutex.lockDelay(10 * std.os.time.millisecond);
    defer _ = work.mutex.unlock();

    work.data += 1;
}
