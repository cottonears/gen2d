const std = @import("std");
const la = @import("la.zig");
const math = std.math;
const mem = std.mem;

const print_debug = false;
const vec2f = @Vector(2, f32);
const frame_lines = [_]la.Line{
    la.Line{
        .point = [_]f32{ 0, 0 },
        .direction = [_]f32{ 1, 0 },
        .normal = [_]f32{ 0, 1 },
        .ref_dist = undefined,
    },
    la.Line{
        .point = [_]f32{ 1, 0 },
        .direction = [_]f32{ 0, 1 },
        .normal = [_]f32{ -1, 0 },
        .ref_dist = undefined,
    },
    la.Line{
        .point = [_]f32{ 1, 1 },
        .direction = [_]f32{ -1, 0 },
        .normal = [_]f32{ 0, -1 },
        .ref_dist = undefined,
    },
    la.Line{
        .point = [_]f32{ 0, 1 },
        .direction = [_]f32{ 0, -1 },
        .normal = [_]f32{ 1, 0 },
        .ref_dist = undefined,
    },
};
// TODO: it is nice to have the ref_dist together with the line details,
// but it doesn't belong in the same struct. Is there a nicer way we can
// glue these two things together? Maybe with an annonymous struct, or just
// by using a Hashmap (where the point + dir vectors are the keys)?

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
            .ref_dist = math.fabs(fl.getDisplacement(a)),
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
        var hand_line = la.getConnectingLine(a, lines[i].point).?; // from centre to last point
        if (print_debug) std.debug.print("{}. hand = ({d:.3},{d:.3})<{d:.3}.{d:.3}>; intersects:\n", .{ i, hand_line.point[0], hand_line.point[1], hand_line.direction[0], hand_line.direction[1] });
        var closest_distance: f32 = std.math.floatMax(f32); // TODO: use closest distance squared instead
        var closest_intersection: vec2f = undefined;
        var next_line_index: usize = undefined;
        for (0..lines.len) |j| {
            if (lines[j].ref_dist > closest_distance) break; // cannot be closer
            if (j == last_index or j == i) continue;
            const intersect = la.getIntersection(lines[i], lines[j]);
            const left_of_hand = hand_line.getDisplacement(intersect) > 0.0;
            const dist_from_a = la.norm2(intersect - a);
            if (print_debug) std.debug.print("{}.{} intersect = ({d:.3},{d:.3}), d_a = {d:.3}, left = {}\n", .{ i, j, intersect[0], intersect[1], dist_from_a, left_of_hand });
            if (left_of_hand and dist_from_a < closest_distance) {
                closest_intersection = intersect;
                closest_distance = dist_from_a;
                next_line_index = j;
            }
        }

        if (closest_distance < std.math.floatMax(f32)) {
            try cell_verts.append(closest_intersection);
            last_index = i;
            i = next_line_index;
        } else unreachable; // failed to find the next vertex along line i
    }
    try cell_verts.append(cell_verts.items[0]); // join last -> first
    return cell_verts.toOwnedSlice();
}
