const std = @import("std");
const la = @import("la.zig");
const testing = std.testing;
const time = std.time;
const rng_seed: u64 = 1000;
const tolerance: f32 = 0.0001;

test "gen random points" {
    const pts = try la.genRandomPoints(testing.allocator, 1000, rng_seed);
    var found_left = false;
    var found_right = false;
    var found_high = false;
    var found_low = false;
    defer testing.allocator.free(pts);
    for (pts) |p| {
        // all points should be in bounds
        const in_bounds = (0 <= p[0] and p[0] <= 1) and (0 <= p[1] and p[1] <= 1);
        try testing.expect(in_bounds);
        found_left = found_left or p[0] < 0.333;
        found_right = found_right or p[0] > 0.667;
        found_low = found_low or p[1] < 0.333;
        found_high = found_high or p[1] > 0.667;
    }
    // extremely unlikely that points won't be found near each boundary
    try testing.expect(found_left);
    try testing.expect(found_right);
    try testing.expect(found_low);
    try testing.expect(found_high);
}

test "midline" {
    const pts: [2]la.vec2f = [_]la.vec2f{ [_]f32{ 1.0, 1.0 }, [_]f32{ 2.0, 1.0 } };
    const expected_one: f32 = 1.0;
    const expected_zero: f32 = 0.0;
    const expected_dist: f32 = 0.5;
    const l = la.getEquidistantLine(pts[0], pts[1]).?;
    const normal_diff: f32 = la.norm2([_]f32{ -1.0, 0.0 } - l.normal);
    const midpoint_diff: f32 = la.norm2([_]f32{ 1.5, 1.0 } - l.point);

    try testing.expectApproxEqRel(-expected_one, l.direction[1], tolerance);
    try testing.expectApproxEqRel(expected_zero, l.direction[0], tolerance);
    try testing.expectApproxEqRel(expected_zero, normal_diff, tolerance);
    try testing.expectApproxEqRel(expected_zero, midpoint_diff, tolerance);
    try testing.expectApproxEqRel(expected_dist, l.ref_dist, tolerance);
}

test "displacement 1" {
    const dir: la.vec2f = [_]f32{ 1.0, 0.0 };
    const norm: la.vec2f = [_]f32{ 0.0, 1.0 };
    const point: la.vec2f = [_]f32{ 0.0, 0.0 };
    const l = la.Line{ .point = point, .direction = dir, .normal = norm };
    const p1: la.vec2f = [_]f32{ 0.0, 2.0 };
    const p2: la.vec2f = [_]f32{ 5.0, 2.0 };
    const disp_1 = l.getDisplacement(p1);
    const disp_2 = l.getDisplacement(p2);
    const expected_disp: f32 = 2.0;
    try testing.expectApproxEqRel(expected_disp, disp_1, tolerance);
    try testing.expectApproxEqRel(expected_disp, disp_2, tolerance);
}

test "displacement 2" {
    const dir: la.vec2f = [_]f32{ -2.0 / @sqrt(5.0), 1.0 / @sqrt(5.0) };
    const norm: la.vec2f = [_]f32{ 1.0 / @sqrt(5.0), 2.0 / @sqrt(5.0) };
    const point: la.vec2f = [_]f32{ 0.0, -1.0 };
    const l = la.Line{ .point = point, .direction = dir, .normal = norm };
    const p1: la.vec2f = [_]f32{ 1.0, 1.0 };
    const p2: la.vec2f = [_]f32{ -3.0, 3.0 };
    const disp_1 = l.getDisplacement(p1);
    const disp_2 = l.getDisplacement(p2);
    const expected_dist: f32 = @sqrt(5.0);
    try testing.expectApproxEqAbs(expected_dist, disp_1, tolerance);
    try testing.expectApproxEqAbs(expected_dist, disp_2, tolerance);
}

test "intersection" {
    const line_a = la.getConnectingLine([_]f32{ -2.0, 1.0 }, [_]f32{ 10.0, 1.0 }).?;
    const line_b = la.getConnectingLine([_]f32{ -1.0, 0.0 }, [_]f32{ 3.0, 4.0 }).?;
    const expected_int: la.vec2f = [_]f32{ 0.0, 1.0 };
    const actual_int = la.getIntersection(line_a, line_b);
    try testing.expectApproxEqAbs(expected_int[0], actual_int[0], tolerance);
    try testing.expectApproxEqAbs(expected_int[1], actual_int[1], tolerance);
}

test "intersection perf." {
    // kind of silly to test performance in a test - better to do it in a program that can be run with performance optimisations enabled
    const num_iters = 10_000_000;
    const num_pts = 10;
    const pts = try la.genRandomPoints(testing.allocator, num_pts, rng_seed);
    defer testing.allocator.free(pts);
    var lines: [num_pts]la.Line = undefined;
    for (0..num_pts) |i| {
        const j = (i + 1) % num_pts; // wraps to 0
        lines[i] = la.getEquidistantLine(pts[i], pts[j]).?;
    }
    const t0 = time.milliTimestamp();
    for (0..num_iters) |i| {
        const ln1 = lines[i % num_pts];
        const ln2 = lines[(i + 1) % num_pts];
        _ = la.getIntersection(ln1, ln2);
    }
    const t1 = time.milliTimestamp();
    std.debug.print("\n {} intersections (method 1) took {} ms\n", .{ num_iters, t1 - t0 });
}
