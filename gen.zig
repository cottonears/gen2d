const std = @import("std");
const la = @import("la.zig");
const math = std.math;
const mem = std.mem;
const print_debug = false;
const vec2f = @Vector(2, f32);

const LineWithDist = struct{
    .line : Line,
    .dist : f32,
};

const frame_lines = [_]la.Line{
    la.Line{
        .point = [_]f32{ 0, 0 },
        .direction = [_]f32{ 1, 0 },
        .normal = [_]f32{ 0, 1 },
    },
    la.Line{
        .point = [_]f32{ 1, 0 },
        .direction = [_]f32{ 0, 1 },
        .normal = [_]f32{ -1, 0 },
    },
    la.Line{
        .point = [_]f32{ 1, 1 },
        .direction = [_]f32{ -1, 0 },
        .normal = [_]f32{ 0, -1 },
    },
    la.Line{
        .point = [_]f32{ 0, 1 },
        .direction = [_]f32{ 0, -1 },
        .normal = [_]f32{ 1, 0 },
    },
};

/// Gets all potential boundary lines around the point a
pub fn getVoronoiLinesForPoint(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f) ![]la.Line {
    var eqd_lines = std.ArrayList(la.Line).init(allocator);
    defer eqd_lines.deinit();
    for (other_pts) |p| {
        const el = la.getEquidistantLine(a, p);
        if (el != null) try eqd_lines.append(el.?);
    }
    for (frame_lines) |fl| {
        const fl_with_dist = la.Line{
            .direction = fl.direction,
            .normal = fl.normal,
            .point = fl.point,
            .ref_dist = @abs(fl.getDisplacement(a)),
        };
        try eqd_lines.append(fl_with_dist);
    }
    std.sort.block(la.Line, eqd_lines.items, {}, la.Line.compRefDist);
    return eqd_lines.toOwnedSlice();
}

// construct a list of vertices at intersection points of the closest lines
pub fn genVoronoiCell(allocator: mem.Allocator, a: vec2f, other_pts: []vec2f) ![]vec2f {
    var lines = try getVoronoiLinesForPoint(allocator, a, other_pts);
    defer allocator.free(lines);
    var cell_verts = std.ArrayList(vec2f).init(allocator);
    defer cell_verts.deinit();
    var last_index: usize = 0;
    var i: usize = 0;

    while (i > 0 or last_index == 0) {
        // TODO: try pre-compute intersections of all closeish lines to improve performance?
        var hand_line = la.getConnectingLine(a, lines[i].point); // from centre to last point
        if (hand_line == null) continue;
        //if (print_debug) std.debug.print("{}. hand = ({d:.3},{d:.3})<{d:.3}.{d:.3}>; intersects:\n", .{ i, hand_line.point[0], hand_line.point[1], hand_line.direction[0], hand_line.direction[1] });
        var closest_distance: f32 = std.math.floatMax(f32); // TODO: use closest distance squared instead
        var closest_intersection: vec2f = undefined;
        var next_line_index: usize = undefined;
        for (0..lines.len) |j| {
            if (lines[j].ref_dist > closest_distance) break; // cannot be closer
            if (j == last_index or j == i) continue;
            const intersect = la.getIntersection(lines[i], lines[j]);
            const left_of_hand = hand_line.?.getDisplacement(intersect) > 0.0;
            const dist_from_a = la.norm2(intersect - a);
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

pub fn genVoronoiSvg(allocator: mem.Allocator, all_pts: []vec2f) []u8 {
    var svg_body_elts = std.ArrayList([]u8).init(allocator);
    defer svg_body_elts.deinit();
    for (all_pts) |p| {
        const cell = try genVoronoiCell(allocator, p, all_pts);
    }
    // append to the string and build up the svg

}

// TODO: move the below elsewhere!
const svg_pre_body =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8" name="viewport" content="width=device-width, initial-scale=1.0"/>
    \\</head>
    \\<body>
;

const svg_post_body =
    \\</body>
    \\</html>
;

pub fn getCellSvgElements(pts: []@Vector(2, f32), fill: []u8) []u8 {
    _ = pts;
    _ = fill;
    const str = "<polygon points=\"50,0 20,50 80,50 65,80 35,80\" fill=\"#ADD8E6\"/>";
    return str;
}
