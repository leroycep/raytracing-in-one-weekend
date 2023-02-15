const std = @import("std");
const Vec3d = @import("vec3.zig").Vec3d;
const c = @import("./c.zig");

const WIDTH = 400;
const ASPECT_RATIO = 16.0 / 9.0;
const HEIGHT = @floatToInt(usize, @intToFloat(f64, WIDTH) / ASPECT_RATIO);

var pixels: [WIDTH * HEIGHT]u32 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rng = std.rand.DefaultPrng.init(1337);
    const rand = rng.random();

    var f = std.mem.zeroInit(c.fenster, .{
        .title = "ray-tracing",
        .width = WIDTH,
        .height = HEIGHT,
        .buf = &pixels,
    });
    _ = c.fenster_open(&f);
    defer c.fenster_close(&f);

    const viewport_height = 2;
    const viewport_width = ASPECT_RATIO * viewport_height;
    const focal_length = 1.0;

    const origin = @Vector(3, f64){ 0, 0, 0 };
    const horizontal = @Vector(3, f64){ viewport_width, 0, 0 };
    const vertical = @Vector(3, f64){ 0, viewport_height, 0 };
    const lower_left = origin - horizontal / @splat(3, @as(f64, 2)) - vertical / @splat(3, @as(f64, 2)) - @Vector(3, f64){ 0, 0, focal_length };

    const samples_per_pixel = 100;
    const max_subcalls = 50;

    var world = World{ .allocator = allocator };
    defer world.deinit();
    try world.objects.append(world.allocator, .{
        .sphere = .{ .center = .{ -0.0, 0, -1 }, .radius = 0.5 },
        .material = Material{ .lambertian = .{ 0.7, 0.3, 0.3 } },
    });
    try world.objects.append(world.allocator, .{
        .sphere = .{ .center = .{ 0, -100.5, -1 }, .radius = 100 },
        .material = Material{ .lambertian = .{ 0.8, 0.8, 0.0 } },
    });
    try world.objects.append(world.allocator, .{
        .sphere = .{ .center = .{ -1, 0, -1 }, .radius = 0.5 },
        .material = Material{ .metal = .{ 0.8, 0.8, 0.8 } },
    });
    try world.objects.append(world.allocator, .{
        .sphere = .{ .center = .{ 1, 0, -1 }, .radius = 0.5 },
        .material = Material{ .metal = .{ 0.8, 0.6, 0.2 } },
    });

    var j: usize = HEIGHT;
    rendering: while (j > 0) : (j -= 1) {
        std.debug.print("\rScanlines remaining: {}", .{j});

        var i: usize = 0;
        while (i < WIDTH) : (i += 1) {
            var pixel_color = @Vector(3, f64){ 0, 0, 0 };

            var samples_taken: usize = 0;
            while (samples_taken < samples_per_pixel) : (samples_taken += 1) {
                const u = @splat(3, (@intToFloat(f64, i) + rand.float(f64)) / @intToFloat(f64, WIDTH));
                const v = @splat(3, (@intToFloat(f64, j) + rand.float(f64)) / @intToFloat(f64, HEIGHT));

                const ray = Ray{ .pos = origin, .dir = lower_left + u * horizontal + v * vertical - origin };

                pixel_color += rayColor(ray, world, rand, max_subcalls);
            }

            pixel_color /= @splat(3, @intToFloat(f64, samples_taken));

            // gamma correction
            pixel_color = @sqrt(pixel_color);

            pixels[(HEIGHT - j) * WIDTH + i] = (@floatToInt(u32, pixel_color[0] * 0xFF) << 16) | (@floatToInt(u32, pixel_color[1] * 0xFF) << 8) | (@floatToInt(u32, pixel_color[2] * 0xFF) << 0);
            if (c.fenster_loop(&f) != 0) {
                break :rendering;
            }
        }
    }

    std.debug.print("\nDone.\n", .{});

    while (c.fenster_loop(&f) != 0) {
        if (f.keys[27] != 0) {
            break;
        }
    }
}

fn randomInHemisphere(rand: std.rand.Random, normal: @Vector(3, f64)) @Vector(3, f64) {
    const in_sphere = randomInUnitSphere(rand);
    if (Vec3d.dot(in_sphere, normal) > 0.0) {
        return in_sphere;
    } else {
        return -in_sphere;
    }
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
        const material = world.objects.items(.material)[hit.object];

        const sub_ray: Ray = switch (material) {
            .lambertian => .{
                .pos = hit.point,
                .dir = blk: {
                    const dir = hit.normal + randomInHemisphere(rand, hit.normal);
                    if (Vec3d.nearZero(dir)) {
                        break :blk hit.normal;
                    }
                    break :blk dir;
                },
            },
            .metal => .{
                .pos = hit.point,
                .dir = blk: {
                    const dir = Vec3d.reflect(ray.dir, Vec3d.unitVector(hit.normal));
                    if (Vec3d.dot(dir, hit.normal) <= 0) {
                        return .{ 0, 0, 0 };
                    }
                    break :blk dir;
                },
            },
        };

        const attenuation = switch (material) {
            .lambertian, .metal => |albedo| albedo,
        };

        const sub_ray_color = rayColor(
            sub_ray,
            world,
            rand,
            max_subcalls - 1,
        );
        return @as(@Vector(3, f64), attenuation) * sub_ray_color;
        // _ = attenuation;
        // _ = sub_ray;
        // return (Vec3d.unitVector(hit.normal) + @splat(3, @as(f64, 1))) / @splat(3, @as(f64, 2));
    }
    const unit_direction = Vec3d.unitVector(ray.dir);
    const t = 0.5 * (unit_direction[1] + 1.0);
    return @splat(3, 1.0 - t) * @Vector(3, f64){ 1, 1, 1 } + @splat(3, t) * @Vector(3, f64){ 0.5, 0.7, 1 };
}

pub const World = struct {
    allocator: std.mem.Allocator,
    objects: std.MultiArrayList(Object) = .{},

    const Object = struct {
        sphere: Sphere,
        material: Material,
    };

    pub fn deinit(this: *@This()) void {
        this.objects.deinit(this.allocator);
    }

    pub const HitRecord = struct {
        point: @Vector(3, f64),
        normal: @Vector(3, f64),
        t: f64,
        object: usize,
        front_face: bool,
    };

    pub fn hit(this: @This(), ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
        var hit_record: ?HitRecord = null;
        for (this.objects.items(.sphere)) |sphere, index| {
            if (sphere.hit(ray, t_min, t_max)) |record| {
                const this_record = .{
                    .point = record.point,
                    .normal = record.normal,
                    .t = record.t,
                    .front_face = record.front_face,

                    .object = index,
                };
                if (hit_record == null or record.t < hit_record.?.t) {
                    hit_record = this_record;
                }
            }
        }
        return hit_record;
    }
};

pub const Material = union(enum(u8)) {
    lambertian: [3]f64,
    metal: [3]f64,
};

pub const Sphere = struct {
    center: @Vector(3, f64),
    radius: f64,

    pub const HitRecord = struct {
        point: @Vector(3, f64),
        normal: @Vector(3, f64),
        t: f64,
        front_face: bool,
    };

    pub fn hit(this: @This(), ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
        const oc = ray.pos - this.center;
        const a = Vec3d.lengthSquared(ray.dir);
        const half_b = Vec3d.dot(oc, ray.dir);
        const c0 = Vec3d.lengthSquared(oc) - this.radius * this.radius;
        const discriminant = half_b * half_b - a * c0;
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
        const outward_normal = Vec3d.unitVector(point - this.center);
        const is_front_face = Vec3d.dot(ray.dir, outward_normal) < 0;
        return HitRecord{
            .t = root,
            .point = point,
            .normal = if (is_front_face) outward_normal else -outward_normal,
            .front_face = is_front_face,
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
