const std = @import("std");
const Vec3d = @import("vec3.zig").Vec3d;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rng = std.rand.DefaultPrng.init(1337);
    const rand = rng.random();

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

    const samples_per_pixel = 100;
    const max_subcalls = 50;

    var world = World{ .allocator = allocator };
    defer world.deinit();
    try world.spheres.append(world.allocator, .{ .center = .{ 0, 0, -1 }, .radius = 0.5 });
    try world.spheres.append(world.allocator, .{ .center = .{ 0, -100.5, -1 }, .radius = 100 });

    try stdout.print("P3\n{} {}\n255\n", .{ width, height });

    var j: usize = height;
    while (j > 0) : (j -= 1) {
        std.debug.print("\rScanlines remaining: {}", .{j});

        var i: usize = 0;
        while (i < width) : (i += 1) {
            var pixel_color = @Vector(3, f64){ 0, 0, 0 };

            var samples_taken: usize = 0;
            while (samples_taken < samples_per_pixel) : (samples_taken += 1) {
                const u = @splat(3, (@intToFloat(f64, i) + rand.float(f64)) / @intToFloat(f64, width));
                const v = @splat(3, (@intToFloat(f64, j) + rand.float(f64)) / @intToFloat(f64, height));

                const ray = Ray{ .pos = origin, .dir = lower_left + u * horizontal + v * vertical - origin };

                pixel_color += rayColor(ray, world, rand, max_subcalls);
            }

            pixel_color /= @splat(3, @intToFloat(f64, samples_taken));

            // gamma correction
            pixel_color = @sqrt(pixel_color);

            try writeColor(stdout, pixel_color);
        }
    }

    try bw.flush(); // don't forget to flush!
    std.debug.print("\nDone.\n", .{});
}

fn randomUnitVector(rand: std.rand.Random) @Vector(3, f64) {
    return Vec3d.unitVector(randomInUnitSphere(rand));
}

fn randomInUnitSphere(rand: std.rand.Random) @Vector(3, f64) {
    while (true) {
        const p = .{
            rand.float(f64),
            rand.float(f64),
            rand.float(f64),
        };
        if (Vec3d.length(p) >= 1) {
            continue;
        }
        return p;
    }
}

pub fn rayColor(ray: Ray, world: World, rand: std.rand.Random, max_subcalls: usize) [3]f64 {
    if (max_subcalls == 0) {
        // too many calls; set color to 0
        return .{ 0, 0, 0 };
    }
    if (world.hit(ray, 0.001, std.math.inf_f64)) |hit| {
        const target = hit.point + hit.normal + randomUnitVector(rand);
        const sub_ray_color = rayColor(.{ .pos = hit.point, .dir = target - hit.point }, world, rand, max_subcalls - 1);
        return @splat(3, @as(f64, 0.5)) * sub_ray_color;
    }
    const unit_direction = Vec3d.unitVector(ray.dir);
    const t = 0.5 * (unit_direction[1] + 1.0);
    return @splat(3, 1.0 - t) * @Vector(3, f64){ 1, 1, 1 } + @splat(3, t) * @Vector(3, f64){ 0.5, 0.7, 1 };
}

pub const HitRecord = struct {
    point: @Vector(3, f64),
    normal: @Vector(3, f64),
    t: f64,
    front_face: bool,
};

pub const World = struct {
    allocator: std.mem.Allocator,
    spheres: std.ArrayListUnmanaged(Sphere) = .{},

    pub fn deinit(this: *@This()) void {
        this.spheres.deinit(this.allocator);
    }

    pub fn hit(this: @This(), ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
        var hit_record: ?HitRecord = null;
        for (this.spheres.items) |sphere| {
            if (sphere.hit(ray, t_min, t_max)) |record| {
                const prev = hit_record orelse {
                    hit_record = record;
                    continue;
                };
                if (record.t < prev.t) {
                    hit_record = record;
                }
            }
        }
        return hit_record;
    }
};

pub const Sphere = struct {
    center: @Vector(3, f64),
    radius: f64,

    pub fn hit(this: @This(), ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
        const oc = ray.pos - this.center;
        const a = Vec3d.lengthSquared(ray.dir);
        const half_b = Vec3d.dot(oc, ray.dir);
        const c = Vec3d.lengthSquared(oc) - this.radius * this.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) return null;
        const sqrt_discriminant = @sqrt(discriminant);

        var root = (-half_b - sqrt_discriminant) / a;
        if (root < t_min or t_max < root) {
            root = (-half_b + sqrt_discriminant) / a;
            if (root < t_min or t_max < root) {
                return null;
            }
        }

        const point = ray.at(root);
        return HitRecord{
            .t = root,
            .point = point,
            .normal = (point - this.center) / @splat(3, this.radius),
            .front_face = true,
        };
    }
};

pub const Ray = struct {
    pos: [3]f64,
    dir: [3]f64,

    pub fn at(this: @This(), t: f64) @Vector(3, f64) {
        return this.pos + Vec3d.unitVector(this.dir) * @splat(3, t);
    }
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
