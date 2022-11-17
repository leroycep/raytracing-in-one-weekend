const std = @import("std");
const Vec3d = @import("vec3.zig").Vec3d;

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const aspect_ratio = 16.0 / 9.0;
    const width = 400;
    const height = @floatToInt(usize, @intToFloat(f64, width) / aspect_ratio);

    const viewport_height = 2;
    const viewport_width = aspect_ratio * viewport_height;
    const focal_length = 1.0;

    const origin = @Vector(3, f64){ 0, 0, 0 };
    const horizontal = @Vector(3, f64){ viewport_width, 0, 0 };
    const vertical = @Vector(3, f64){ 0, viewport_height, 0 };
    const lower_left = origin - horizontal / @splat(3, @as(f64, 2)) - vertical / @splat(3, @as(f64, 2)) - @Vector(3, f64){ 0, 0, focal_length };

    try stdout.print("P3\n{} {}\n255\n", .{ width, height });

    var j: usize = height;
    while (j > 0) : (j -= 1) {
        std.debug.print("\rScanlines remaining: {}", .{j});

        var i: usize = 0;
        while (i < width) : (i += 1) {
            const u = @splat(3, @intToFloat(f64, i) / @intToFloat(f64, width));
            const v = @splat(3, @intToFloat(f64, j) / @intToFloat(f64, height));

            const ray = Ray{ .pos = origin, .dir = lower_left + u * horizontal + v * vertical - origin };

            const pixel_color = rayColor(ray);
            try writeColor(stdout, pixel_color);
        }
    }

    try bw.flush(); // don't forget to flush!
    std.debug.print("\nDone.\n", .{});
}

pub fn rayColor(ray: Ray) [3]f64 {
    if (hitSphere(ray, .{ 0, 0, -1 }, 0.5)) {
        return .{ 1, 0, 0 };
    }
    const unit_direction = Vec3d.unitVector(ray.dir);
    const t = 0.5 * (unit_direction[1] + 1.0);
    return @splat(3, 1.0 - t) * @Vector(3, f64){ 1, 1, 1 } + @splat(3, t) * @Vector(3, f64){ 0.5, 0.7, 1 };
}

pub fn hitSphere(ray: Ray, center: @Vector(3, f64), radius: f64) bool {
    const oc = ray.pos - center;
    const a = Vec3d.dot(ray.dir, ray.dir);
    const b = 2.0 * Vec3d.dot(oc, ray.dir);
    const c = Vec3d.dot(oc, oc) - radius * radius;
    const discriminant = b * b - 4 * a * c;
    return discriminant > 0;
}

pub const Ray = struct {
    pos: [3]f64,
    dir: [3]f64,
};

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
