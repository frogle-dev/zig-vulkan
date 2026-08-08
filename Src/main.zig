const std = @import("std");

const renderer = @import("Renderer");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    // const gpa = debug_allocator.allocator();
    const gpa = switch (@import("builtin").mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.c_allocator,
    };

    var array_list = std.ArrayList(u32).empty;
    defer array_list.deinit(gpa);

    try array_list.append(gpa, 5);
    try array_list.append(gpa, 1);
}
