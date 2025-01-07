const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_os_is_linux = target.result.os.tag == .linux;
    const enable_dbus = b.option(bool, "enable-dbus", "Enable D-Bus Notification support") orelse target_os_is_linux;

    const exe = b.addExecutable(.{
        .name = "ntfyd",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);
    exe_options.addOption(bool, "enable_dbus", enable_dbus);

    if (enable_dbus) {
        if (!target_os_is_linux) {
            @panic("D-Bus support is only available on Linux");
        }

        exe.linkLibC();
        exe.linkSystemLibrary("libsystemd");
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
