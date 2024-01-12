const std = @import("std");
const math = std.math;
const mem = std.mem;
const rand = std.rand;

pub const vec2f = @Vector(2, f32);

pub const Line = struct {
    direction: vec2f, // points in the direction of the line
    normal: vec2f, // orthogonal to the line
    point: vec2f, // a point on the line

    pub fn init(point: vec2f, dir: vec2f) Line {
        // TODO: check norm of dir and normalise if needed
        return Line{
            .direction = dir,
            .normal = [_]f32{ -dir[1], dir[0] },
            .point = point,
        };
    }

    /// Gets a point's displacement from this line.
    /// This will be positive if the point lies on the same side as the normal.
    pub fn getDisplacement(self: *const Line, p: vec2f) f32 {
        // TODO: try doing this with @reduce(.Add, norm * diff) and compare performance
        const diff = p - self.point;
        return self.normal[0] * diff[0] + self.normal[1] * diff[1];
    }
};

pub fn euclideanNorm2(v: vec2f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1]);
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
    return Line.init(mid, d);
}

/// Uses basic algebra to find the intersection of two lines (equivalent to the determinant method, but faster)
pub fn getIntersection(a: Line, b: Line) vec2f {
    const i: u1 = if (math.fabs(a.direction[1]) > math.fabs(a.direction[0])) 1 else 0;
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
