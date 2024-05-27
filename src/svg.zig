const std = @import("std");
const colour = @import("colour.zig");
const math = std.math;
const mem = std.mem;

const vec2f = @Vector(2, f32);

// TODO: add support for:
// - custom backgrounds
// - lines
// - styles
pub const Canvas = struct {
    height: f32,
    width: f32,
    str: std.ArrayList(u8),
    //background: [3]u8,

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
    
    pub fn addCircle(self: *Canvas, allocator: mem.Allocator, centre: vec2f, radius: f32) !void {        
        const element_str = try std.fmt.allocPrint(
            allocator,
            "\n<circle cx=\"{d:.3}\" cy=\"{d:.3}\" r=\"{d:.3}\" fill=\"black\"/>",
            .{ centre[0], centre[1], radius },
        );
        defer allocator.free(element_str);
        try self.str.appendSlice(element_str);
    }

    pub fn addPolygon(self: *Canvas, allocator: mem.Allocator, points: []vec2f, fill: []u8) !void {
        var pts_list = std.ArrayList(u8).init(allocator);
        defer pts_list.deinit();
        for (points) |p| {
            var buff: [32]u8 = undefined;
            const slice = buff[0..];
            const str = try std.fmt.bufPrint(slice, "{d:.3},{d:.3} ", .{ p[0], p[1] });
            try pts_list.appendSlice(str);
        }
        
        const element_str = try std.fmt.allocPrint(
            allocator,
            "\n<polygon points=\"{s}\" style=\"fill:{s}; stroke:grey; stroke-width:2\" />",
            .{ pts_list.items[0..], fill },
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
const canvas_width: f32 = 800;
const canvas_height: f32 = 600;

test "test write html" {
    // create a canvas and paint it
    var points: [3]vec2f = [_]vec2f{
        [_]f32{ 300, 400 },
        [_]f32{ 500, 600 },
        [_]f32{ 400, 450 },
    };
    var canvas = Canvas.init(testing.allocator, canvas_width, canvas_height);
    var palette = try colour.RandomHslPalette.init(11);    
    var buff : [32]u8 = undefined;
    const fill = try palette.getRandomColour(&buff);
    defer canvas.deinit();
    try canvas.addPolygon(testing.allocator, points[0..], fill);
    try canvas.addCircle(testing.allocator, [_]f32{ 400, 500 }, 10.0);
    try canvas.writeHtml(testing.allocator, "test_svg.html");
}
