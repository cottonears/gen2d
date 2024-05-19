const std = @import("std");
const math = std.math;
const mem = std.mem;

pub const Canvas = struct {
    height: f32,
    width: f32,
    //background: [3]u8,
    str: std.ArrayList(u8),

    pub fn init(w: f32, h: f32, allocator: mem.Allocator) Canvas {
        return Canvas{
            .height = h,
            .width = w,
            .str = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.str.deinit();
    }

    // TODO 1: add fill
    // TODO 2: can this be generalised for inline elements
    pub fn addCircle(self: *Canvas, cx: f32, cy: f32, r: f32) !void {
        var buff: [100]u8 = undefined;
        const buff_slice = buff[0..];
        const insert_str = try std.fmt.bufPrint(
            buff_slice,
            "\n<circle cx=\"{d:.3}\" cy=\"{d:.3}\" r=\"{d:.3}\" fill=\"red\"/>",
            .{ cx, cy, r },
        );

        try self.str.appendSlice(insert_str);
    }

    // caller owns the returned memory
    pub fn getSvg(self: *const Canvas, allocator: mem.Allocator) ![]u8 {
        var buff: [96]u8 = undefined;
        const buff_slice = buff[0..];
        const svg_start = try std.fmt.bufPrint(
            buff_slice,
            "<svg width=\"{d:.3}\" height=\"{d:.3}\" xmlns=\"http://www.w3.org/2000/svg\">",
            .{ self.width, self.height },
        );
        const svg_end = "</svg>";

        var text = std.ArrayList(u8).init(allocator);
        //errdefer allocator.free(text); ???
        try text.appendSlice(svg_start);
        try text.appendSlice(self.str.items);
        try text.appendSlice(svg_end);

        return text.toOwnedSlice();
    }

    pub fn writeHtml(self: *const Canvas, filename: []const u8, allocator: mem.Allocator) !void {
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
    var canvas = Canvas.init(1000.0, 500, testing.allocator);
    defer canvas.deinit();
    try canvas.addCircle(200, 200, 10.0);
    try canvas.writeHtml("test_svg.html", testing.allocator);
}
