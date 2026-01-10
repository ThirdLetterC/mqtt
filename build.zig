// Used the following as cross-compilation build.zig example:
// https://git.sr.ht/~jamii/focus/tree/master/build.zig

const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const windows = b.addStaticLibrary("mqtt-c", null);
    try includeCommon(windows);
    windows.setTarget(std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });
    windows.install();

    const apple_silicon_mac = b.addStaticLibrary("mqtt-c-apple-silicon", null);
    try includeCommon(apple_silicon_mac);
    apple_silicon_mac.setTarget(std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    });
    apple_silicon_mac.install();

    const x86_64_mac = b.addStaticLibrary("mqtt-c-mac-x64", null);
    try includeCommon(x86_64_mac);
    x86_64_mac.setTarget(std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    });
    x86_64_mac.install();

    const x86_64_linux = b.addStaticLibrary("mqtt-c-x64", null);
    try includeCommon(x86_64_linux);
    x86_64_linux.setTarget(std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    });
    x86_64_linux.install();

    const arm64_linux = b.addStaticLibrary("mqtt-c-arm64", null);
    try includeCommon(arm64_linux);
    arm64_linux.setTarget(std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
    });
    arm64_linux.install();

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

fn includeCommon(lib: *std.build.LibExeObjStep) !void {
    lib.addIncludeDir("include");

    var flags = std.ArrayList([]const u8).init(std.heap.page_allocator);
    try flags.appendSlice(&.{
        "-std=c23",
        "-Wall",
        "-Wextra",
        "-Wpedantic",
        "-Werror",
        "-D_POSIX_C_SOURCE=200809L",
    });
    if (lib.root_module.optimize == .Debug) {
        try flags.appendSlice(&.{
            "-fsanitize=address",
            "-fsanitize=undefined",
            "-fsanitize=leak",
        });
    }
    const cflags = try flags.toOwnedSlice();

    lib.addCSourceFile("src/mqtt.c", cflags);
    lib.addCSourceFile("src/mqtt_pal.c", cflags);

    lib.setBuildMode(.Debug); // Can be .Debug, .ReleaseSafe, .ReleaseFast, and .ReleaseSmall
    lib.linkLibC();
}
