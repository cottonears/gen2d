const std = @import("std");
const la = @import("la.zig");
const gen = @import("gen.zig");

const testing = std.testing;

test "voronoi lines 1" {
    const pts = try la.genRandomPoints(testing.allocator, 2, 0);
    defer testing.allocator.free(pts);
    for (pts, 0..) |p, i| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ i + 1, p[0], p[1] });
    }
    const cell_lines = try gen.getVoronoiLinesForPoint(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_lines);
    std.debug.print("\ncell lines for {}:\n", .{0});
    for (cell_lines) |c| {
        std.debug.print("point = ({d:.3}, {d:.3}); dir = ({d:.3}, {d:.3})\n", .{ c.point[0], c.point[1], c.direction[0], c.direction[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "voronoi cells 1 pt" {
    const pts = [_]la.vec2f{la.vec2f{ 0.5, 0.5 }};
    std.debug.print("\nCell nuclei:\n", .{});
    for (pts) |p| std.debug.print("({d:.3}, {d:.3})\n", .{ p[0], p[1] });
    const cell_verts = try gen.genVoronoiCell(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_verts);
    std.debug.print("\nCell vertices:\n", .{});
    for (cell_verts, 0..) |c, j| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ j, c[0], c[1] });
    }
    std.debug.print("\nDone!\n", .{});
}

test "voronoi cells 8 pts" {
    const pts = try la.genRandomPoints(testing.allocator, 8, 89);
    defer testing.allocator.free(pts);
    std.debug.print("\nCell nuclei:\n", .{});
    for (pts) |p| std.debug.print("({d:.3}, {d:.3})\n", .{ p[0], p[1] });

    // vertex 0
    const cell_verts = try gen.genVoronoiCell(testing.allocator, pts[0], pts[1..]);
    defer testing.allocator.free(cell_verts);
    std.debug.print("\nCell vertices:\n", .{});
    for (cell_verts, 0..) |c, j| {
        std.debug.print("\n{}. ({d:.3}, {d:.3})", .{ j, c[0], c[1] });
    }

    std.debug.print("\nDone!\n", .{});
}
