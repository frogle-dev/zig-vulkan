const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const WindowError = error{
    SdlInitFailed,
    SdlWindowCreationFailed,
    SdlSetHintFailed,

    SdlCreateRendererFailed,
    SdlRendererSetDrawColor,
    SdlRendererClear,
    SdlRenderPresent,
};

pub const Window = struct {
    width: u32,
    height: u32,

    _sdl_window: *c.SDL_Window,
    _renderer: *c.SDL_Renderer,

    pub fn init(width: u32, height: u32, name: [:0]const u8) WindowError!@This() {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlInitFailed;
        }

        if (!c.SDL_SetHint(c.SDL_HINT_APP_ID, name)) {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlSetHintFailed;
        }

        const sdl_window = c.SDL_CreateWindow(name, @intCast(width), @intCast(height), c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlWindowCreationFailed;
        };

        const renderer = c.SDL_CreateRenderer(sdl_window, null) orelse {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlCreateRendererFailed;
        };

        return Window{
            .width = width,
            .height = height,
            ._sdl_window = sdl_window,
            ._renderer = renderer,
        };
    }

    pub fn deinit(self: *@This()) void {
        c.SDL_DestroyRenderer(self._renderer);
        c.SDL_DestroyWindow(self._sdl_window);
        c.SDL_Quit();
    }

    pub fn pollEvents(_: @This()) bool {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) {
                return false;
            }
        }

        return true;
    }

    pub fn clear(self: *@This()) WindowError!void {
        if (!c.SDL_SetRenderDrawColor(self._renderer, 100, 10, 50, 255)) {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlRendererSetDrawColor;
        }

        if (!c.SDL_RenderClear(self._renderer)) {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlRendererSetDrawColor;
        }

        if (!c.SDL_RenderPresent(self._renderer)) {
            std.debug.print("{s}\n", .{c.SDL_GetError()});
            return WindowError.SdlRendererSetDrawColor;
        }
    }
};
