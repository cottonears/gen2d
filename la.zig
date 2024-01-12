const std = @import("std");
const math = std.math;
const mem = std.mem;
const rand = std.rand;

pub const vec2f = @Vector(2, f32);

pub const Line = struct {
    direction: vec2f, // points in the direction of the line
    normal: vec2f, // orthogonal to the line
    point: vec2f, // a point on the line
    ref_dist: f32 = undefined, // distance from point to reference - TODO: remove!

    pub fn init(point: vec2f, dir: vec2f) Line {
        return Line{
            .direction = dir,
            .normal = [_]f32{ -dir[1], dir[0] },
            .point = point,
        };
    }

    pub fn compRefDist(_: void, l1: Line, l2: Line) bool {
        return l1.ref_dist < l2.ref_dist;
    }

    /// Gets a point's displacement from this line.
    /// This will be positive if the point lies on the same side as the normal.
    pub fn getDisplacement(self: *const Line, p: vec2f) f32 {
        // TODO: try doing this with @reduce(.Add, norm * diff) and compare performance
        const diff = p - self.point;
        return self.normal[0] * diff[0] + self.normal[1] * diff[1];
    }
};

pub fn norm2(v: vec2f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1]);
}

pub fn normSquared2(v: vec2f) f32 {
    return v[0] * v[0] + v[1] * v[1];
}

/// Returns a line that connects the provided points.
/// The returned line's direction points towards b; null is returned if the points are equal.
pub fn getConnectingLine(a: vec2f, b: vec2f) ?Line {
    if (@reduce(.And, a == b)) return null;
    const d = b - a;
    const dist = norm2(d);
    const dir = [_]f32{ d[0] / dist, d[1] / dist };
    return Line.init(a, dir);
}

/// Returns a line that is equidistant from the provided points.
/// The returned line's normal will point towards a; null is returned if the points are equal.
pub fn getEquidistantLine(a: vec2f, b: vec2f) ?Line {
    if (@reduce(.And, a == b)) return null;
    const d = a - b;
    const dist = norm2(d);
    const nc = 1.0 / dist; // normalisation coefficient
    const mid = [_]f32{ b[0] + 0.5 * d[0], b[1] + 0.5 * d[1] };
    const dir = [_]f32{ -nc * d[1], nc * d[0] };
    const norm = [_]f32{ nc * d[0], nc * d[1] };
    return Line{ .direction = dir, .normal = norm, .point = mid, .ref_dist = 0.5 * dist };
}

/// Uses basic algebra to find the intersection of two lines (equivalent to the determinant method, but fasters)
pub fn getIntersection(a: Line, b: Line) vec2f {
    const i: u1 = if (@abs(a.direction[1]) > @abs(a.direction[0])) 1 else 0;
    const j: u1 = i +% 1; // TODO: test performance vs. more conventional way (i.e., make i & j u8s and use an if-else expression)
    const rji = a.direction[j] / a.direction[i];
    const denom = (b.direction[j] - rji * b.direction[i]);
    const beta = (a.point[j] - b.point[j] + rji * (b.point[i] - a.point[i])) / denom;
    return [_]f32{ b.point[0] + beta * b.direction[0], b.point[1] + beta * b.direction[1] };
}

/// Generates random points in [0, 1] x [0, 1]; caller owns returned slice.
pub fn genRandomPoints(allocator: mem.Allocator, n: usize, seed: u64) ![]vec2f {
    var rng = rand.DefaultPrng.init(seed);
    var vec_array = try allocator.alloc(vec2f, n);
    errdefer allocator.dealloc(vec_array);
    for (0..n) |i| {
        const r_x = rng.random().float(f32);
        const r_y = rng.random().float(f32);
        vec_array[i] = [_]f32{ r_x, r_y };
    }
    return vec_array;
}

// this (more conventional?) way of computing intersections uses matrices + inverses
// fn getIntersection1(a: vec2f, r: vec2f, b: vec2f, s: vec2f) vec2f {
//     const A = [_]f32{ a[0], r[0], a[1], r[1] };
//     const Ai = inv2(A[0], A[1], A[2], A[3]).?;
//     const B = [_]f32{ b[0], s[0], b[1], s[1] };
//     const Bi = inv2(B[0], B[1], B[2], B[3]).?;

//     var C = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
//     C[0] = Ai[0] * B[0] + Ai[1] * B[2];
//     C[1] = Ai[0] * B[1] + Ai[1] * B[3];
//     C[2] = Ai[2] * B[0] + Ai[3] * B[2];
//     C[3] = Ai[2] * B[1] + Ai[3] * B[3];
//     //const alpha = C[2] + beta * C[3];

//     var D = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
//     D[0] = Bi[0] * A[0] + Bi[1] * A[2];
//     D[1] = Bi[0] * A[1] + Bi[1] * A[3];
//     D[2] = Bi[2] * A[0] + Bi[3] * A[2];
//     D[3] = Bi[2] * A[1] + Bi[3] * A[3];
//     const beta = (D[2] + C[2] * D[3]) / (1 - C[3] * D[3]);
//     //const alpha = C[2] + beta * C[3];
//     return [_]f32{ b[0] + beta * s[0], b[1] + beta * s[1] };
// }

// // this way uses basic algebra (should be equivalent)
// fn getIntersection2(a: vec2f, r: vec2f, b: vec2f, s: vec2f) vec2f {
//     const i: u1 = if (@abs(r[0]) > @abs(r[1])) 0 else 1;
//     const j: u1 = i +% 1; //if (i > 0) 0 else 1; // i +% 1; //
//     const rji = r[j] / r[i];
//     const beta = (a[j] - b[j] + rji * (b[i] - a[i])) / (s[j] - rji * s[i]);
//     return [_]f32{ b[0] + beta * s[0], b[1] + beta * s[1] };
// }
// fn det2(a: f32, b: f32, c: f32, d: f32) f32 {
//     return a * d - b * c;
// }

// fn inv2(a: f32, b: f32, c: f32, d: f32) ?[4]f32 {
//     const det = det2(a, b, c, d);
//     if (det == 0) return null;
//     const s = 1.0 / det;
//     return [_]f32{ s * d, s * -b, s * -c, s * a };
// }
