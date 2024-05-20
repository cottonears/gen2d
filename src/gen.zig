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

/// gets a collection of equidistant lines
pub fn getPotentialBoundaryLines(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f) ![]LineWithDist {
    var eqd_lines = std.ArrayList(LineWithDist).init(allocator);
    defer eqd_lines.deinit();
    for (other_pts) |p| {
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

// aim is to construct a bubble around a whose points are slightly closer to a than the voronoi boundary
pub fn genInjeraCell(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f, n: u8) ![]vec2f {
    const potential_boundaries = try getPotentialBoundaryLines(allocator, a, other_pts);
    defer allocator.free(potential_boundaries);
    var cell_verts = std.ArrayList(vec2f).init(allocator);
    defer cell_verts.deinit();

    for (1..n) |i| {
        const angle = 6.2832 / @as(f32, @floatFromInt(i));
        var closest_disp = std.math.floatMax(f32);
        var closest_intercept: ?vec2f = null;
        for (potential_boundaries) |bound| {
            // optimisation idea: if bound is further than closest intersect, ignore it
            const dir = [_]f32{ math.cos(angle), math.sin(angle) };
            const ray = Line.init(a, dir);
            const intersect = la.getIntersection(ray, bound.line);
            const intersect_disp = la.innerProduct(intersect - a, dir);
            if (0.0 < intersect_disp and intersect_disp < closest_disp) {
                closest_disp = intersect_disp;
                closest_intercept = intersect;
            }
        }
        if (closest_intercept != null) {
            try cell_verts.append(closest_intercept.?);
            std.debug.print(
                "\n{any}. closest point = ({d:.3}, {d:.3}), displacement = {d:.3} ",
                .{ i, closest_intercept.?[0], closest_intercept.?[1], closest_disp },
            );
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
    const cell_lines = try getPotentialBoundaryLines(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_lines);
    std.debug.print("\ncell lines for {}:\n", .{0});
    for (cell_lines) |c| {
        std.debug.print("point = ({d:.3}, {d:.3}); dir = ({d:.3}, {d:.3})\n", .{ c.line.point[0], c.line.point[1], c.line.direction[0], c.line.direction[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "injera cells 2 pts" {
    const pts = try la.genRandomPoints(testing.allocator, 2, 0, 1000, 1000);
    defer testing.allocator.free(pts);
    var canvas = svg.Canvas.init(testing.allocator, 1000, 1000);
    defer canvas.deinit();

    const cell_verts = try genInjeraCell(testing.allocator, pts[0], pts[1..], 8);
    defer testing.allocator.free(cell_verts);
    try canvas.addPolygon(testing.allocator, cell_verts);
    for (pts) |p| try canvas.addCircle(testing.allocator, p, 5);

    try canvas.writeHtml(testing.allocator, "test_voronoi.html");
    std.debug.print("\nDone!\n", .{});
}
