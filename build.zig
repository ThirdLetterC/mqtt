// Used the following as cross-compilation build.zig example:
// https://git.sr.ht/~jamii/focus/tree/master/build.zig

const std = @import("std");

const common_cflags = [_][]const u8{
    "-std=c23",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-Werror",
    "-D_POSIX_C_SOURCE=200809L",
};

const debug_cflags = [_][]const u8{
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

fn cflagsFor(
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    sanitize: bool,
) []const []const u8 {
    const use_debug = optimize == .Debug and target.result.os.tag != .windows;
    if (use_debug and sanitize) return &debug_cflags;
    return &common_cflags;
}

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const sanitize = b.option(
        bool,
        "sanitize",
        "Enable ASan/UBSan/leak sanitizers for Debug builds (default: on)",
    ) orelse (optimize == .Debug);

    const windows = try addPlatformLibrary(
        b,
        "mqtt-c",
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        optimize,
        sanitize,
    );
    b.installArtifact(windows);

    const apple_silicon_mac = try addPlatformLibrary(
        b,
        "mqtt-c-apple-silicon",
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        optimize,
        sanitize,
    );
    b.installArtifact(apple_silicon_mac);

    const x86_64_mac = try addPlatformLibrary(
        b,
        "mqtt-c-mac-x64",
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        optimize,
        sanitize,
    );
    b.installArtifact(x86_64_mac);

    const x86_64_linux = try addPlatformLibrary(
        b,
        "mqtt-c-x64",
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        optimize,
        sanitize,
    );
    b.installArtifact(x86_64_linux);

    const arm64_linux = try addPlatformLibrary(
        b,
        "mqtt-c-arm64",
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        optimize,
        sanitize,
    );
    b.installArtifact(arm64_linux);

    const tests = try addTests(b, optimize, sanitize);
    b.installArtifact(tests);

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

    const tests_step = b.step("tests", "Build tests executable");
    tests_step.dependOn(&tests.step);

    const test_step = b.step("test", "Build and run tests");
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}

fn addPlatformLibrary(
    b: *std.Build,
    name: []const u8,
    target_query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    sanitize: bool,
) !*std.Build.Step.Compile {
    const module = b.createModule(.{
        .target = b.resolveTargetQuery(target_query),
        .optimize = optimize,
        .link_libc = true,
    });
    try includeCommon(b, module, optimize, sanitize);

    return b.addLibrary(.{
        .name = name,
        .root_module = module,
    });
}

fn addTests(b: *std.Build, optimize: std.builtin.OptimizeMode, sanitize: bool) !*std.Build.Step.Compile {
    const target = b.standardTargetOptions(.{});
    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    try includeCommon(b, module, optimize, sanitize);

    const resolved_target = module.resolved_target orelse @panic("target missing");
    module.addIncludePath(b.path("examples/templates"));
    module.addCSourceFiles(.{
        .files = &.{"tests.c"},
        .flags = cflagsFor(optimize, resolved_target, sanitize),
    });

    return b.addExecutable(.{
        .name = "tests",
        .root_module = module,
    });
}

fn includeCommon(
    b: *std.Build,
    module: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
    sanitize: bool,
) !void {
    module.addIncludePath(b.path("include"));

    const target = module.resolved_target orelse @panic("target missing");

    const cflags = cflagsFor(optimize, target, sanitize);

    module.addCSourceFiles(.{
        .files = &.{ "src/mqtt.c", "src/mqtt_pal.c" },
        .flags = cflags,
    });
}
