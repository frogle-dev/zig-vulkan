const std = @import("std");

/// thin wrapper around std.deque
/// the type of the queue is a fn () void
/// push the deinit function of the object you want to queue deletion for
/// on deinit, the deletion queue will run that deinit function on all the items in the queue
const DeletionQueue = struct {
    const DeinitFn = *const fn (self: anytype) void;

    _queue: std.Deque(DeinitFn),

    pub const empty = std.Deque(DeinitFn).empty;

    pub fn initCapacity(gpa: std.mem.Allocator, capacity: usize) !@This() {
        const queue = try std.Deque(DeinitFn).initCapacity(gpa, capacity);

        return .{
            ._queue = queue,
        };
    }

    /// will deinit all the elements in the queue
    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        for (self._queue.buffer) |item_deinit| {
            item_deinit();
        }

        self._queue.deinit(gpa);
    }

    pub fn pushBack(self: @This(), gpa: std.mem.Allocator, item_deinit_fn: DeinitFn) !void {
        try self._queue.pushBack(gpa, item_deinit_fn);
    }
};
