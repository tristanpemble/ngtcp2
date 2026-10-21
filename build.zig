const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const shared = b.option(bool, "shared", "Build a shared library") orelse false;
    const upstream = b.dependency("ngtcp2", .{});
    const version = std.SemanticVersion.parse(manifest.version) catch unreachable;
    const version_header = b.addConfigHeader(.{
        .include_path = "ngtcp2/version.h",
        .include_guard = "NGTCP2_VERSION_H",
    }, .{
        .NGTCP2_VERSION = manifest.version,
        .NGTCP2_VERSION_NUM = @as(i64, @intCast((version.major << 16) | (version.minor << 8) | version.patch)),
    });
    if (!shared) version_header.addValue("NGTCP2_STATICLIB", u8, 1);

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = if (shared) true else null,
    });
    module.addCMacro("BUILDING_NGTCP2", "1");
    if (target.result.os.tag != .windows) {
        module.addCMacro("HAVE_ARPA_INET_H", "1");
        module.addCMacro("HAVE_NETINET_IN_H", "1");
        module.addCMacro("HAVE_UNISTD_H", "1");
    }
    if (target.result.cpu.arch.endian() == .big) {
        module.addCMacro("WORDS_BIGENDIAN", "1");
    }
    module.addConfigHeader(version_header);
    module.addIncludePath(upstream.path("lib/includes"));
    module.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = &library_sources,
        .flags = &.{ "-std=c11", "-fvisibility=hidden", "-UNDEBUG" },
    });

    const lib = b.addLibrary(.{
        .name = "ngtcp2",
        .linkage = if (shared) .dynamic else .static,
        .version = if (shared) .{ .major = 16, .minor = 11, .patch = 0 } else null,
        .root_module = module,
    });
    lib.installHeader(upstream.path("lib/includes/ngtcp2/ngtcp2.h"), "ngtcp2/ngtcp2.h");
    lib.installConfigHeader(version_header);
    b.installArtifact(lib);

    const test_lib = if (shared) b.addLibrary(.{
        .name = "ngtcp2-test",
        .linkage = .static,
        .root_module = module,
    }) else lib;
    const tests = b.addExecutable(.{
        .name = "ngtcp2-tests",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    tests.root_module.addConfigHeader(version_header);
    tests.root_module.addCMacro("NGTCP2_STATICLIB", "1");
    tests.root_module.addIncludePath(upstream.path("lib"));
    tests.root_module.addIncludePath(upstream.path("lib/includes"));
    tests.root_module.addIncludePath(upstream.path("tests/munit"));
    tests.root_module.addCSourceFiles(.{
        .root = upstream.path("tests"),
        .files = &test_sources,
        .flags = &.{ "-std=c11", "-UNDEBUG" },
    });
    tests.root_module.linkLibrary(test_lib);
    const run_tests = b.addRunArtifact(tests);

    b.step("test", "Run upstream unit tests").dependOn(&run_tests.step);
}

const library_sources = [_][]const u8{
    "ngtcp2_pkt.c",
    "ngtcp2_conv.c",
    "ngtcp2_str.c",
    "ngtcp2_vec.c",
    "ngtcp2_buf.c",
    "ngtcp2_conn.c",
    "ngtcp2_mem.c",
    "ngtcp2_pq.c",
    "ngtcp2_map.c",
    "ngtcp2_rob.c",
    "ngtcp2_ppe.c",
    "ngtcp2_crypto.c",
    "ngtcp2_err.c",
    "ngtcp2_range.c",
    "ngtcp2_acktr.c",
    "ngtcp2_rtb.c",
    "ngtcp2_frame_chain.c",
    "ngtcp2_strm.c",
    "ngtcp2_idtr.c",
    "ngtcp2_gaptr.c",
    "ngtcp2_ringbuf.c",
    "ngtcp2_log.c",
    "ngtcp2_qlog.c",
    "ngtcp2_cid.c",
    "ngtcp2_ksl.c",
    "ngtcp2_cc.c",
    "ngtcp2_bbr.c",
    "ngtcp2_addr.c",
    "ngtcp2_path.c",
    "ngtcp2_pv.c",
    "ngtcp2_pmtud.c",
    "ngtcp2_version.c",
    "ngtcp2_rst.c",
    "ngtcp2_wf.c",
    "ngtcp2_opl.c",
    "ngtcp2_balloc.c",
    "ngtcp2_objalloc.c",
    "ngtcp2_unreachable.c",
    "ngtcp2_transport_params.c",
    "ngtcp2_settings.c",
    "ngtcp2_callbacks.c",
    "ngtcp2_dcidtr.c",
    "ngtcp2_pcg.c",
    "ngtcp2_ratelim.c",
    "ngtcp2_conn_info.c",
    "ngtcp2_fmt.c",
};

const test_sources = [_][]const u8{
    "main.c",
    "ngtcp2_pkt_test.c",
    "ngtcp2_range_test.c",
    "ngtcp2_rob_test.c",
    "ngtcp2_acktr_test.c",
    "ngtcp2_map_test.c",
    "ngtcp2_transport_params_test.c",
    "ngtcp2_rtb_test.c",
    "ngtcp2_idtr_test.c",
    "ngtcp2_conn_test.c",
    "ngtcp2_ringbuf_test.c",
    "ngtcp2_conv_test.c",
    "ngtcp2_ksl_test.c",
    "ngtcp2_gaptr_test.c",
    "ngtcp2_vec_test.c",
    "ngtcp2_strm_test.c",
    "ngtcp2_pv_test.c",
    "ngtcp2_pmtud_test.c",
    "ngtcp2_str_test.c",
    "ngtcp2_tstamp_test.c",
    "ngtcp2_cc_test.c",
    "ngtcp2_qlog_test.c",
    "ngtcp2_wf_test.c",
    "ngtcp2_settings_test.c",
    "ngtcp2_callbacks_test.c",
    "ngtcp2_ppe_test.c",
    "ngtcp2_dcidtr_test.c",
    "ngtcp2_addr_test.c",
    "ngtcp2_pcg_test.c",
    "ngtcp2_ratelim_test.c",
    "ngtcp2_conn_info_test.c",
    "ngtcp2_cid_test.c",
    "ngtcp2_log_test.c",
    "ngtcp2_fmt_test.c",
    "ngtcp2_macro_test.c",
    "ngtcp2_test_helper.c",
    "munit/munit.c",
};
