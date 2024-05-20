const std = @import("std");
const la = @import("la.zig");
const svg = @import("svg.zig");
const math = std.math;
const mem = std.mem;
const vec2f = la.vec2f;
const Line = la.Line;

pub const LineWithDist = struct {
    line: Line,
    dist: f32,

    pub fn compDist(_: void, l1: LineWithDist, l2: LineWithDist) bool {
        return l1.dist < l2.dist;
    }
};

/// These are the boundaries of the frame/canvas
const frame_lines = [_]Line{
    Line{
        .point = [_]f32{ 0, 0 },
        .direction = [_]f32{ 1, 0 },
        .normal = [_]f32{ 0, 1 },
    },
    Line{
        .point = [_]f32{ 1, 0 },
        .direction = [_]f32{ 0, 1 },
        .normal = [_]f32{ -1, 0 },
    },
    Line{
        .point = [_]f32{ 1, 1 },
        .direction = [_]f32{ -1, 0 },
        .normal = [_]f32{ 0, -1 },
    },
    Line{
        .point = [_]f32{ 0, 1 },
        .direction = [_]f32{ 0, -1 },
        .normal = [_]f32{ 1, 0 },
    },
};

/// gets a collection of lines containing:
/// - one line that is equidistant between the indexed point and each other point
/// - four 'frame lines' at the boundaries
pub fn getPotentialBoundaryLines(allocator: mem.Allocator, points: []vec2f, index: usize) ![]LineWithDist {
    var eqd_lines = std.ArrayList(LineWithDist).init(allocator);
    defer eqd_lines.deinit();
    const a = points[index];
    for (points) |p| {
        const el = la.getEquidistantLine(a, p);
        if (el != null) {
            const ld = LineWithDist{ .line = el.?, .dist = el.?.getDisplacement(a) };
            try eqd_lines.append(ld);
        }
    }
    for (frame_lines) |fl| {
        const fl_with_dist = LineWithDist{
            .line = fl,
            .dist = @abs(fl.getDisplacement(a)),
        };
        try eqd_lines.append(fl_with_dist);
    }
    std.sort.block(LineWithDist, eqd_lines.items, {}, LineWithDist.compDist);
    return eqd_lines.toOwnedSlice();
}

// gets vertices forming a 'bubble' around the indexed point
pub fn genInjeraCell(allocator: mem.Allocator, points: []vec2f, index: usize, n: u16) ![]vec2f {
    const potential_boundaries = try getPotentialBoundaryLines(allocator, points, index);
    defer allocator.free(potential_boundaries);
    var cell_verts = std.ArrayList(vec2f).init(allocator);
    defer cell_verts.deinit();
    const a = points[index];

    for (1..n) |i| {
        const angle = 6.2832 * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n));
        var closest_dist = std.math.floatMax(f32);
        var closest_intercept: ?vec2f = null;
        for (potential_boundaries) |bound| {
            // optimisation idea: if bound is further than closest intersect, ignore it
            const dir = [_]f32{ math.cos(angle), math.sin(angle) };
            const ray = Line.init(a, dir);
            const intersect = la.getIntersection(ray, bound.line);
            const intersect_disp = la.innerProduct(intersect - a, dir);
            if (0.0 < intersect_disp and intersect_disp < closest_dist) {
                closest_dist = intersect_disp;
                closest_intercept = intersect;
            }
        }
        if (closest_intercept != null) {
            try cell_verts.append(closest_intercept.?);
            // std.debug.print(
            //     "\nangle = {d:.3}, dist = {d:.3}, intercept = ({d:.3}{d:.3})",
            //     .{ angle, closest_dist, closest_intercept.?[0], closest_intercept.?[1] },
            // );
        }
    }

    return cell_verts.toOwnedSlice();
}

const testing = std.testing;

test "boundary lines 1" {
    const pts = try la.genRandomPoints(testing.allocator, 1, 0, 1000, 1000);
    defer testing.allocator.free(pts);
    for (pts, 0..) |p, i| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ i + 1, p[0], p[1] });
    }
    const cell_lines = try getPotentialBoundaryLines(testing.allocator, pts, 0);
    defer testing.allocator.free(cell_lines);
    std.debug.print("\ncell lines for {}:\n", .{0});
    for (cell_lines) |c| {
        std.debug.print("point = ({d:.3}, {d:.3}); dir = ({d:.3}, {d:.3})\n", .{ c.line.point[0], c.line.point[1], c.line.direction[0], c.line.direction[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "injera cells 15 pts" {
    const pts = try la.genRandomPoints(testing.allocator, 15, 0, 1000, 1000);
    defer testing.allocator.free(pts);
    var canvas = svg.Canvas.init(testing.allocator, 1000, 1000);
    defer canvas.deinit();

    for (0..15) |i| {
        const cell_verts = try genInjeraCell(testing.allocator, pts, i, 8);
        defer testing.allocator.free(cell_verts);
        try canvas.addPolygon(testing.allocator, cell_verts);
        try canvas.addCircle(testing.allocator, pts[i], 5);
    }

    try canvas.writeHtml(testing.allocator, "test_injera.html");
    std.debug.print("\nDone!\n", .{});
}
