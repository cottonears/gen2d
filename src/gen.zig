const std = @import("std");
const la = @import("la.zig");
const svg = @import("svg.zig");
const math = std.math;
const mem = std.mem;
const vec2f = la.vec2f;
const Line = la.Line;
const print_debug = false;

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

/// Gets all potential boundary lines around the point a
pub fn getVoronoiLinesForPoint(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f) ![]LineWithDist {
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

// construct a list of vertices at intersection points of the closest lines
pub fn genVoronoiCell(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f) ![]vec2f {
    const potential_boundaries = try getVoronoiLinesForPoint(allocator, a, other_pts);
    defer allocator.free(potential_boundaries);
    var cell_verts = std.ArrayList(vec2f).init(allocator);
    defer cell_verts.deinit();
    var last_index: usize = 0;
    var i: usize = 0;

    while (i > 0 or last_index == 0) {
        // TODO: try pre-compute intersections of all closeish lines to improve performance?
        var hand_line = la.getConnectingLine(a, potential_boundaries[i].line.point); // from centre to last point
        if (hand_line == null) continue;
        //if (print_debug) std.debug.print("{}. hand = ({d:.3},{d:.3})<{d:.3}.{d:.3}>; intersects:\n", .{ i, hand_line.point[0], hand_line.point[1], hand_line.direction[0], hand_line.direction[1] });
        var closest_distance: f32 = std.math.floatMax(f32); // TODO: use closest distance squared instead
        var closest_intersection: vec2f = undefined;
        var next_line_index: usize = undefined;
        for (0..potential_boundaries.len) |j| {
            if (potential_boundaries[j].dist > closest_distance) break; // cannot be closer
            if (j == last_index or j == i) continue;
            const intersect = la.getIntersection(potential_boundaries[i].line, potential_boundaries[j].line);
            const left_of_hand = hand_line.?.getDisplacement(intersect) > 0.0;
            const dist_from_a = la.euclideanNorm2(intersect - a);
            if (print_debug) std.debug.print("{}.{} intersect = ({d:.3},{d:.3}), d_a = {d:.3}, left = {}\n", .{ i, j, intersect[0], intersect[1], dist_from_a, left_of_hand });
            if (left_of_hand and dist_from_a < closest_distance) {
                closest_intersection = intersect;
                closest_distance = dist_from_a;
                next_line_index = j;
            }
        }

        try cell_verts.append(closest_intersection);
        last_index = i;
        i = next_line_index;
    }
    return cell_verts.toOwnedSlice();
}

const testing = std.testing;

test "voronoi lines 1" {
    const pts = try la.genRandomPoints(testing.allocator, 2, 0, 1000, 1000);
    defer testing.allocator.free(pts);
    for (pts, 0..) |p, i| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ i + 1, p[0], p[1] });
    }
    const cell_lines = try getVoronoiLinesForPoint(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_lines);
    std.debug.print("\ncell lines for {}:\n", .{0});
    for (cell_lines) |c| {
        std.debug.print("point = ({d:.3}, {d:.3}); dir = ({d:.3}, {d:.3})\n", .{ c.line.point[0], c.line.point[1], c.line.direction[0], c.line.direction[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "voronoi cells 1 pt" {
    const pts = [_]la.vec2f{la.vec2f{ 0.5, 0.5 }};
    std.debug.print("\nCell nuclei:\n", .{});
    for (pts) |p| std.debug.print("({d:.3}, {d:.3})\n", .{ p[0], p[1] });
    const cell_verts = try genVoronoiCell(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_verts);
    std.debug.print("\nCell vertices:\n", .{});
    for (cell_verts, 0..) |c, j| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ j, c[0], c[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "voronoi cells 5 pts" {
    const pts = try la.genRandomPoints(testing.allocator, 5, 89, 1000, 1000);
    defer testing.allocator.free(pts);
    var canvas = svg.Canvas.init(testing.allocator, 1000, 1000);
    defer canvas.deinit();

    const cell_verts = try genVoronoiCell(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_verts);
    try canvas.addPolygon(testing.allocator, cell_verts);
    for (pts) |p| try canvas.addCircle(testing.allocator, p, 5);

    try canvas.writeHtml(testing.allocator, "test_voronoi.html");
    std.debug.print("\nDone!\n", .{});
}
