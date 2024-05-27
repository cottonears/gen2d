const std = @import("std");
const la = @import("la.zig");
const svg = @import("svg.zig");
const colour = @import("colour.zig");
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

/// gets vertices forming a 'bubble' around the indexed point
pub fn genCell(allocator: mem.Allocator, points: []vec2f, index: usize, angle_offset: f32, num_verts: u16) ![]vec2f {
    // first generate vertices along the boundary of the Voronoi cell (store in orig)
    const potential_boundaries = try getPotentialBoundaryLines(allocator, points, index);
    defer allocator.free(potential_boundaries);
    var orig_bounds = std.ArrayList(vec2f).init(allocator); // polar coords (r, theta)
    defer orig_bounds.deinit();
    const centre = points[index];
    const angle_inc = 6.2832 / @as(f32, @floatFromInt(num_verts));
    for (0..num_verts) |i| {
        const angle = angle_offset + @as(f32, @floatFromInt(i)) * angle_inc;
        const dir = [_]f32{ math.cos(angle), math.sin(angle) };
        const ray = Line.init(centre, dir);
        var closest_dist = std.math.floatMax(f32); // for this angle/direction
        for (potential_boundaries) |bound| {
            // optimisation idea: if bound is further than closest intersect, ignore it
            const intersect = la.getIntersection(ray, bound.line);
            const disp = la.innerProduct(intersect - centre, dir);
            closest_dist = if (0.0 < disp and disp < closest_dist) disp else closest_dist;
        }
        if (closest_dist != std.math.floatMax(f32)) {
            try orig_bounds.append([_]f32{closest_dist, angle});
        } else {
            // TODO: figure out why this is happening?
            std.debug.print("\ncouldn't find intersect for point {} at angle {d:.3} rad", .{ index, angle });
        }
    }
    // next apply some scaling + filtering to the original vertices
    // at the moment, just does some scaling of point distance
    var final_bounds = std.ArrayList(vec2f).init(allocator); // Cartesian coords (x, y)
    defer final_bounds.deinit();
    for(orig_bounds.items, 0..)|point, i| {        
        const scaled_r = 0.9 * point[0];
        const angle = orig_bounds.items[i][1];
        const final_vert: vec2f = [_]f32 {
            centre[0] + scaled_r * math.cos(angle),
            centre[1] + scaled_r * math.sin(angle),
        };
        try final_bounds.append(final_vert);
    }
    return final_bounds.toOwnedSlice();
}

const testing = std.testing;
const canvas_size: f32 = 1000.0;


test "boundary lines 1" {
    const pts = try la.genRandomPoints(testing.allocator, 1, 0, canvas_size, canvas_size);
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
    // TODO: draw this!
}

test "injera cells 500 pts" {
    const num_pts = 500;
    const num_verts = 50;
    const rng_seed = 9000;

    var palette = try colour.RandomHslPalette.init(rng_seed);
    try palette.setHueRange(30, 40);
    try palette.setLightnessRange(60, 80);
    try palette.setSaturationRange(30, 60);

    const pts = try la.genRandomPoints(testing.allocator, num_pts, rng_seed, canvas_size, canvas_size);
    defer testing.allocator.free(pts);
    var canvas = svg.Canvas.init(testing.allocator, canvas_size, canvas_size);
    defer canvas.deinit();
    var col_buffer:[32]u8 = undefined;

    for (0..num_pts) |i| {
        const cell_verts = try genCell(testing.allocator, pts, i, 0, num_verts);
        defer testing.allocator.free(cell_verts);
        const col = try palette.getRandomColour(&col_buffer);
        try canvas.addPolygon(testing.allocator, cell_verts, col);
        //try canvas.addCircle(testing.allocator, pts[i], 5);
    }

    try canvas.writeHtml(testing.allocator, "test_injera.html");
    std.debug.print("\nDone!\n", .{});
}
