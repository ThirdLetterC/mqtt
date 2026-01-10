// Used the following as cross-compilation build.zig example:
// https://git.sr.ht/~jamii/focus/tree/master/build.zig

const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const windows = try addPlatformLibrary(
        b,
        "mqtt-c",
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        optimize,
    );
    b.installArtifact(windows);

    const apple_silicon_mac = try addPlatformLibrary(
        b,
        "mqtt-c-apple-silicon",
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        optimize,
    );
    b.installArtifact(apple_silicon_mac);

    const x86_64_mac = try addPlatformLibrary(
        b,
        "mqtt-c-mac-x64",
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        optimize,
    );
    b.installArtifact(x86_64_mac);

    const x86_64_linux = try addPlatformLibrary(
        b,
        "mqtt-c-x64",
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        optimize,
    );
    b.installArtifact(x86_64_linux);

    const arm64_linux = try addPlatformLibrary(
        b,
        "mqtt-c-arm64",
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        optimize,
    );
    b.installArtifact(arm64_linux);

    const windows_step = b.step("windows", "Build for Windows");
    windows_step.dependOn(&windows.step);

    const apple_silicon_mac_step = b.step("apple_silicon_mac", "Build for Apple Silicon Macs");
    apple_silicon_mac_step.dependOn(&apple_silicon_mac.step);

    const x86_64_mac_step = b.step("x86_64_mac", "Build for Intel Macs");
    x86_64_mac_step.dependOn(&x86_64_mac.step);

    const x86_64_linux_step = b.step("x86_64_linux", "Build for Linux");
    x86_64_linux_step.dependOn(&x86_64_linux.step);

    const arm64_linux_step = b.step("arm64_linux", "Build for ARM64 Linux");
    arm64_linux_step.dependOn(&arm64_linux.step);
}

fn addPlatformLibrary(
    b: *std.Build,
    name: []const u8,
    target_query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const module = b.createModule(.{
        .target = b.resolveTargetQuery(target_query),
        .optimize = optimize,
        .link_libc = true,
    });
    try includeCommon(b, module, optimize);

    return b.addLibrary(.{
        .name = name,
        .root_module = module,
    });
}

fn includeCommon(
    b: *std.Build,
    module: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
) !void {
    module.addIncludePath(b.path("include"));

    const target = module.resolved_target orelse @panic("target missing");

    const common_flags: []const []const u8 = &.{
        "-std=c23",
        "-Wall",
        "-Wextra",
        "-Wpedantic",
        "-Werror",
        "-D_POSIX_C_SOURCE=200809L",
    };

    const debug_flags: []const []const u8 = &.{
        "-std=c23",
        "-Wall",
        "-Wextra",
        "-Wpedantic",
        "-Werror",
        "-D_POSIX_C_SOURCE=200809L",
        "-fsanitize=address",
        "-fsanitize=undefined",
        "-fsanitize=leak",
    };

    const cflags = if (optimize == .Debug and target.result.os.tag != .windows)
        debug_flags
    else
        common_flags;

    module.addCSourceFiles(.{
        .files = &.{ "src/mqtt.c", "src/mqtt_pal.c" },
        .flags = cflags,
    });
}
