const std = @import("std");

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const width = 256;
    const height = 256;

    try stdout.print("P3\n{} {}\n255\n", .{ width, height });

    var j: usize = height;
    while (j > 0) : (j -= 1) {
        std.debug.print("\rScanlines remaining: {}", .{j});

        var i: usize = 0;
        while (i < width) : (i += 1) {
            const r = @intToFloat(f64, i) / width;
            const g = @intToFloat(f64, j) / height;
            const b = 0.25;

            try writeColor(stdout, .{ r, g, b });
        }
    }

    try bw.flush(); // don't forget to flush!
    std.debug.print("\nDone.\n", .{});
}

pub fn writeColor(writer: anytype, color: [3]f64) !void {
    try writer.print("{} {} {}\n", .{
        @floatToInt(u8, 255 * color[0]),
        @floatToInt(u8, 255 * color[1]),
        @floatToInt(u8, 255 * color[2]),
    });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
