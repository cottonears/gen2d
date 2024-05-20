const std = @import("std");
const svg = @import("svg.zig");
const math = std.math;
const mem = std.mem;
const rand = std.rand;

pub const vec2f = @Vector(2, f32);

pub const Line = struct {
    direction: vec2f, // points in the direction of the line
    normal: vec2f, // orthogonal to the line
    point: vec2f, // a point on the line

    pub fn init(point: vec2f, dir: vec2f) Line {
        const norm_squared = @reduce(.Add, dir * dir);
        const norm_coeff = if (norm_squared == 1.0) 1.0 else 1.0 / @sqrt(norm_squared);
        return Line{
            .direction = [_]f32{ norm_coeff * dir[0], norm_coeff * dir[1] },
            .normal = [_]f32{ -norm_coeff * dir[1], norm_coeff * dir[0] },
            .point = point,
        };
    }

    /// Gets a point's displacement from this line.
    /// This will be positive if the point lies on the same side as the normal.
    pub fn getDisplacement(self: *const Line, p: vec2f) f32 {
        return innerProduct(self.normal, p - self.point);
    }
};

pub fn euclideanNorm2(v: vec2f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1]);
}

pub fn innerProduct(a: vec2f, b: vec2f) f32 {
    return @reduce(.Add, a * b);
}

/// Returns a line that connects the provided points.
/// The returned line's direction points towards b; null is returned if the points are equal.
pub fn getConnectingLine(a: vec2f, b: vec2f) ?Line {
    return if (@reduce(.And, a == b)) null else Line.init(a, b - a);
}

/// Returns a line that is equidistant from the provided points.
/// The returned line's normal will point towards a; null is returned if the points are equal.
pub fn getEquidistantLine(a: vec2f, b: vec2f) ?Line {
    if (@reduce(.And, a == b)) return null;
    const d = a - b;
    const mid = [_]f32{ b[0] + 0.5 * d[0], b[1] + 0.5 * d[1] };
    return Line.init(mid, [_]f32{ d[1], -d[0] });
}

/// Uses basic algebra to find the intersection of two lines (equivalent to the determinant method, but faster)
pub fn getIntersection(a: Line, b: Line) vec2f {
    const i: u1 = if (@abs(a.direction[1]) > @abs(a.direction[0])) 1 else 0;
    const j: u1 = i +% 1; // TODO: test performance vs. more conventional way (i.e., make i & j u8s and use an if-else expression)
    const rji = a.direction[j] / a.direction[i];
    const denom = (b.direction[j] - rji * b.direction[i]);
    const beta = (a.point[j] - b.point[j] + rji * (b.point[i] - a.point[i])) / denom;
    return [_]f32{ b.point[0] + beta * b.direction[0], b.point[1] + beta * b.direction[1] };
}

/// Generates random points in [0, x] x [0, 1]; caller owns returned slice.
pub fn genRandomPoints(allocator: mem.Allocator, n: usize, seed: u64, x: f32, y: f32) ![]vec2f {
    var rng = rand.DefaultPrng.init(seed);
    var vec_array = try allocator.alloc(vec2f, n);
    errdefer allocator.dealloc(vec_array);
    for (0..n) |i| {
        const r_x = x * rng.random().float(f32);
        const r_y = y * rng.random().float(f32);
        vec_array[i] = [_]f32{ r_x, r_y };
    }
    return vec_array;
}

//
// LA tests
//
const testing = std.testing;
const time = std.time;
const rng_seed: u64 = 1000;
const tolerance: f32 = 0.0001;

test "gen random points" {
    const pts = try genRandomPoints(testing.allocator, 1000, rng_seed, 1000, 1000);
    defer testing.allocator.free(pts);
    var canvas = svg.Canvas.init(testing.allocator, 1000.0, 1000.0);
    defer canvas.deinit();

    for (pts) |p| {
        // all points should be in bounds
        const in_bounds = (0 <= p[0] and p[0] <= 1000) and (0 <= p[1] and p[1] <= 1000);
        try testing.expect(in_bounds);
        try canvas.addCircle(testing.allocator, p, 5.0);
    }

    try canvas.writeHtml(testing.allocator, "test_random.html");
}

test "midline" {
    const pts: [2]vec2f = [_]vec2f{ [_]f32{ 1.0, 1.0 }, [_]f32{ 2.0, 1.0 } };

    const l = getEquidistantLine(pts[0], pts[1]).?;
    const dir_inner_prod: f32 = innerProduct([_]f32{ 0.0, 1.0 }, l.direction);
    const normal_diff: f32 = euclideanNorm2([_]f32{ -1.0, 0.0 } - l.normal);
    const midpoint_diff: f32 = euclideanNorm2([_]f32{ 1.5, 1.0 } - l.point);
    try testing.expectApproxEqRel(1.0, @abs(dir_inner_prod), tolerance);
    try testing.expectApproxEqRel(0.0, normal_diff, tolerance);
    try testing.expectApproxEqRel(0.0, midpoint_diff, tolerance);
}

test "displacement 1" {
    const dir: vec2f = [_]f32{ 1.0, 0.0 };
    const norm: vec2f = [_]f32{ 0.0, 1.0 };
    const point: vec2f = [_]f32{ 0.0, 0.0 };
    const l = Line{ .point = point, .direction = dir, .normal = norm };
    const p1: vec2f = [_]f32{ 0.0, 2.0 };
    const p2: vec2f = [_]f32{ 5.0, 2.0 };
    const disp_1 = l.getDisplacement(p1);
    const disp_2 = l.getDisplacement(p2);
    const expected_disp: f32 = 2.0;
    try testing.expectApproxEqRel(expected_disp, disp_1, tolerance);
    try testing.expectApproxEqRel(expected_disp, disp_2, tolerance);
}

test "displacement 2" {
    const dir: vec2f = [_]f32{ -2.0 / @sqrt(5.0), 1.0 / @sqrt(5.0) };
    const norm: vec2f = [_]f32{ 1.0 / @sqrt(5.0), 2.0 / @sqrt(5.0) };
    const point: vec2f = [_]f32{ 0.0, -1.0 };
    const l = Line{ .point = point, .direction = dir, .normal = norm };
    const p1: vec2f = [_]f32{ 1.0, 1.0 };
    const p2: vec2f = [_]f32{ -3.0, 3.0 };
    const disp_1 = l.getDisplacement(p1);
    const disp_2 = l.getDisplacement(p2);
    const expected_dist: f32 = @sqrt(5.0);
    try testing.expectApproxEqAbs(expected_dist, disp_1, tolerance);
    try testing.expectApproxEqAbs(expected_dist, disp_2, tolerance);
}

test "intersection" {
    const line_a = getConnectingLine([_]f32{ -2.0, 1.0 }, [_]f32{ 10.0, 1.0 }).?;
    const line_b = getConnectingLine([_]f32{ -1.0, 0.0 }, [_]f32{ 3.0, 4.0 }).?;
    const expected_int: vec2f = [_]f32{ 0.0, 1.0 };
    const actual_int = getIntersection(line_a, line_b);
    try testing.expectApproxEqAbs(expected_int[0], actual_int[0], tolerance);
    try testing.expectApproxEqAbs(expected_int[1], actual_int[1], tolerance);
}

// test "intersection perf." {
//     // kind of silly to test performance in a test - better to do it in a program that can be run with performance optimisations enabled
//     const num_iters = 10_000_000;
//     const num_pts = 10;
//     const pts = try genRandomPoints(testing.allocator, num_pts, rng_seed, 1.0, 1.0);
//     defer testing.allocator.free(pts);
//     var lines: [num_pts]Line = undefined;
//     for (0..num_pts) |i| {
//         const j = (i + 1) % num_pts; // wraps to 0
//         lines[i] = getEquidistantLine(pts[i], pts[j]).?;
//     }
//     const t0 = time.milliTimestamp();
//     for (0..num_iters) |i| {
//         const ln1 = lines[i % num_pts];
//         const ln2 = lines[(i + 1) % num_pts];
//         _ = getIntersection(ln1, ln2);
//     }
//     const t1 = time.milliTimestamp();
//     std.debug.print("\n {} intersections (method 1) took {} ms\n", .{ num_iters, t1 - t0 });
// }
