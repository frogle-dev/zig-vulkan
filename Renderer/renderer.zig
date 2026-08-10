const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL_vulkan.h");
});

const vk = @import("Vulkan");
const delque = @import("DeletionQueue");
const win = @import("Window");

pub const RendererError = error{
    SdlLoadVulkanLibraryFailed,
    SdlGetInstanceProcAddrFailed,
    SdlGetInstanceExtensionsFailed,
};

pub const api_version = vk.API_VERSION_1_4;

const Instance = struct {
    instance: vk.Instance,
    fns: vk.InstanceWrapper,
};

pub const Renderer = struct {
    _window: *win.Window,

    _instance: Instance,

    pub fn init(window: *win.Window, comptime app_name: [:0]const u8) !@This() {
        if (!c.SDL_Vulkan_LoadLibrary(null)) { // sdl will find vulkan library, if not sdl get vk instance proc addr wil fail
            std.log.err("{s}", .{c.SDL_GetError()});
            return RendererError.SdlLoadVulkanLibraryFailed;
        }

        const get_instance_proc_addr = c.SDL_Vulkan_GetVkGetInstanceProcAddr() orelse {
            std.log.err("{s}", .{c.SDL_GetError()});
            return RendererError.SdlGetInstanceProcAddrFailed;
        };

        const pfn: vk.PfnGetInstanceProcAddr = @ptrCast(get_instance_proc_addr);
        const base_fns = vk.BaseWrapper.load(pfn);

        const instance = try createInstance(base_fns, app_name);

        return .{
            ._window = window,
            ._instance = instance,
        };
    }

    pub fn deinit(_: *@This()) void {}

    fn createInstance(base_fns: vk.BaseWrapper, comptime app_name: [:0]const u8) !Instance {
        const app_info = vk.ApplicationInfo{
            .api_version = api_version.toU32(),
            .engine_version = 1,
            .application_version = 1,
            .p_application_name = app_name,
            .p_engine_name = "Zig Vulkan Engine",
        };

        var instance_ext_count: u32 = 0;
        const extensions = c.SDL_Vulkan_GetInstanceExtensions(&instance_ext_count) orelse {
            std.log.err("{s}", .{c.SDL_GetError()});
            return RendererError.SdlGetInstanceExtensionsFailed;
        };

        const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

        const instance_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_layer_count = required_layers.len,
            .pp_enabled_layer_names = &required_layers,
            .enabled_extension_count = instance_ext_count,
            .pp_enabled_extension_names = @ptrCast(extensions),
        };

        const instance = try base_fns.createInstance(&instance_info, null);

        return .{
            .instance = instance,
            .fns = vk.InstanceWrapper.load(instance, base_fns.dispatch.vkGetInstanceProcAddr),
        };
    }
};
