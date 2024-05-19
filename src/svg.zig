const std = @import("std");
const math = std.math;
const mem = std.mem;

pub const vec2f = @Vector(2, f32);

pub const Canvas = struct {
    height: f32,
    width: f32,
    //background: [3]u8,
    str: std.ArrayList(u8),

    pub fn init(allocator: mem.Allocator, width: f32, height: f32) Canvas {
        return Canvas{
            .height = height,
            .width = width,
            .str = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.str.deinit();
    }

    // TODO: add style
    pub fn addCircle(self: *Canvas, allocator: mem.Allocator, centre: vec2f, radius: f32) !void {
        const element_str = try std.fmt.allocPrint(
            allocator,
            "\n<circle cx=\"{d:.3}\" cy=\"{d:.3}\" r=\"{d:.3}\" fill=\"black\"/>",
            .{ centre[0], centre[1], radius },
        );
        defer allocator.free(element_str);
        try self.str.appendSlice(element_str);
    }

    pub fn addPolygon(self: *Canvas, allocator: mem.Allocator, points: []vec2f) !void {
        var pts_list = std.ArrayList(u8).init(allocator);
        defer pts_list.deinit();
        for (points) |p| {
            var buff: [24]u8 = undefined;
            const slice = buff[0..];
            const str = try std.fmt.bufPrint(slice, "{d:.3},{d:.3} ", .{ p[0], p[1] });
            try pts_list.appendSlice(str);
        }
        const element_str = try std.fmt.allocPrint(
            allocator,
            "\n<polygon points=\"{s}\" style=\"fill:lime;stroke:purple;stroke-width:3\" />",
            .{pts_list.items[0..]},
        );
        defer allocator.free(element_str);
        try self.str.appendSlice(element_str);
    }

    // caller owns the returned memory
    pub fn getSvg(self: *const Canvas, allocator: mem.Allocator) ![]u8 {
        const svg_start = try std.fmt.allocPrint(
            allocator,
            "<svg width=\"{d:.3}\" height=\"{d:.3}\" xmlns=\"http://www.w3.org/2000/svg\">",
            .{ self.width, self.height },
        );
        defer allocator.free(svg_start);

        var text = std.ArrayList(u8).init(allocator);
        //errdefer allocator.free(text); ???
        try text.appendSlice(svg_start);
        try text.appendSlice(self.str.items);
        try text.appendSlice("</svg>");

        return text.toOwnedSlice();
    }

    pub fn writeHtml(self: *const Canvas, allocator: mem.Allocator, filename: []const u8) !void {
        const html_start = "<!DOCTYPE html>\n<html><body>";
        const html_end = "</body></html>";
        const svg_body = try self.getSvg(allocator);
        defer testing.allocator.free(svg_body);
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        var buf_writer = std.io.bufferedWriter(file.writer());
        const writer = buf_writer.writer();
        try writer.print("{s}\n{s}\n{s}", .{ html_start, svg_body, html_end });
        try buf_writer.flush();
    }
};

//
// svg tests
//
const testing = std.testing;

test "test write html" {
    // create a canvas and paint it
    var points: [3]vec2f = [_]vec2f{
        [_]f32{ 300, 400 },
        [_]f32{ 500, 600 },
        [_]f32{ 400, 450 },
    };
    var canvas = Canvas.init(testing.allocator, 1000.0, 1000.0);
    defer canvas.deinit();
    try canvas.addPolygon(testing.allocator, points[0..]);
    try canvas.addCircle(testing.allocator, [_]f32{ 400, 500 }, 10.0);
    try canvas.writeHtml(testing.allocator, "test_svg.html");
}
