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
    LayerNotSupported,
    ExtensionNotSupported,
    FailedToGetInstanceProcAddr,
};

pub const api_version = vk.API_VERSION_1_4;

const vulkan_debug: bool = switch (@import("builtin").mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

const required_layers =
    if (vulkan_debug) [1][*:0]const u8{"VK_LAYER_KHRONOS_validation"} else [0][*:0]const u8{};

/// c_array must have c_array_len valid elements
fn cArrayToArrayList(gpa: std.mem.Allocator, comptime CType: type, comptime ZType: type, c_array: [*c]const CType, c_array_len: u32) !std.ArrayList(ZType) {
    var array_list = try std.ArrayList(ZType).initCapacity(gpa, c_array_len);
    array_list.items.len = c_array_len;

    var i: u32 = 0;
    while (i < c_array_len) : (i += 1) {
        array_list.items[i] = @ptrCast(c_array[i]);
    }

    return array_list;
}

const Instance = struct {
    instance: vk.Instance,
    fns: vk.InstanceWrapper,
};

pub const Renderer = struct {
    _window: *win.Window,

    _instance: Instance,

    pub fn init(gpa: std.mem.Allocator, window: *win.Window, comptime app_name: [:0]const u8) !@This() {
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

        const instance = try createInstance(gpa, base_fns, app_name);
        // createDebugMessenger(instance);

        return .{
            ._window = window,
            ._instance = instance,
        };
    }

    pub fn deinit(_: *@This()) void {}

    fn createInstance(gpa: std.mem.Allocator, base_fns: vk.BaseWrapper, comptime app_name: [:0]const u8) !Instance {
        const app_info = vk.ApplicationInfo{
            .api_version = api_version.toU32(),
            .engine_version = 1,
            .application_version = 1,
            .p_application_name = app_name,
            .p_engine_name = "Zig Vulkan Engine",
        };

        var layer_count: u32 = 0;
        _ = try base_fns.enumerateInstanceLayerProperties(&layer_count, null);
        var layer_props = try std.ArrayList(vk.LayerProperties).initCapacity(gpa, layer_count);
        defer layer_props.deinit(gpa);
        layer_props.items.len = layer_count;
        _ = try base_fns.enumerateInstanceLayerProperties(&layer_count, layer_props.items.ptr);

        for (required_layers) |required_layer| {
            var found = false;
            for (layer_props.items) |layer_prop| {
                if (std.mem.eql(u8, std.mem.sliceTo(&layer_prop.layer_name, 0), std.mem.span(required_layer))) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                std.log.err("Missing layer: {s}", .{required_layer});
                return RendererError.LayerNotSupported;
            }
        }

        std.log.debug("Found all required layers", .{});

        var sdl_ext_count: u32 = 0;
        const sdl_extensions = c.SDL_Vulkan_GetInstanceExtensions(&sdl_ext_count) orelse {
            std.log.err("{s}", .{c.SDL_GetError()});
            return RendererError.SdlGetInstanceExtensionsFailed;
        };

        var required_extensions = try cArrayToArrayList(gpa, [*c]const u8, [*:0]const u8, sdl_extensions, sdl_ext_count);
        defer required_extensions.deinit(gpa);

        if (vulkan_debug) {
            try required_extensions.append(gpa, vk.extensions.ext_debug_utils.name);
        }

        var ext_count: u32 = 0;
        _ = try base_fns.enumerateInstanceExtensionProperties(null, &ext_count, null);
        var ext_props = try std.ArrayList(vk.ExtensionProperties).initCapacity(gpa, ext_count);
        defer ext_props.deinit(gpa);
        ext_props.items.len = ext_count;
        _ = try base_fns.enumerateInstanceExtensionProperties(null, &ext_count, ext_props.items.ptr);

        for (required_extensions.items) |required_extension| {
            var found = false;
            for (ext_props.items) |ext_prop| {
                if (std.mem.eql(u8, std.mem.sliceTo(&ext_prop.extension_name, 0), std.mem.span(required_extension))) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                std.log.err("Missing extension: {s}", .{required_extension});
                return RendererError.ExtensionNotSupported;
            }
        }

        std.log.debug("Found all required extensions", .{});

        const instance_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_layer_count = required_layers.len,
            .pp_enabled_layer_names = &required_layers,
            .enabled_extension_count = @intCast(required_extensions.items.len),
            .pp_enabled_extension_names = required_extensions.items.ptr,
        };

        const instance = try base_fns.createInstance(&instance_info, null);

        return .{
            .instance = instance,
            .fns = vk.InstanceWrapper.load(instance, base_fns.dispatch.vkGetInstanceProcAddr orelse {
                return RendererError.FailedToGetInstanceProcAddr;
            }),
        };
    }
    //
    //     fn debugCallback() void {
    //
    // }
    //
    //     fn createDebugMessenger(instance: *Instance) !vk.DebugUtilsMessengerEXT {
    //         if (!enable_validation_layers)
    //             return;
    //
    //         const debug_messenger_info = vk.DebugUtilsMessengerCreateInfoEXT{
    //             // .pfn_user_callback =
    //         }
    //
    //         return
    //     }
};
