const std = @import("std");

pub const Vec3d = Vec3(f64);

pub fn Vec3(comptime T: type) type {
    return struct {
        pub fn length(v: [3]T) T {
            return @sqrt(lengthSquared(v));
        }

        pub fn lengthSquared(v: @Vector(3, T)) T {
            return @reduce(.Add, v * v);
        }

        pub fn dot(u: @Vector(3, T), v: @Vector(3, T)) T {
            return @reduce(.Add, u * v);
        }

        pub fn cross(u: @Vector(3, T), v: @Vector(3, T)) @Vector(3, T) {
            return .{
                u[1] * v[2] - u[2] * v[1],
                u[2] * v[0] - u[0] * v[2],
                u[0] * v[1] - u[1] * v[0],
            };
        }

        pub fn unitVector(v: @Vector(3, T)) @Vector(3, T) {
            return v / @splat(3, length(v));
        }

        pub fn reflect(v: @Vector(3, T), n: @Vector(3, T)) @Vector(3, T) {
            return v - @splat(3, 2 * dot(v, n)) * n;
        }

        pub fn nearZero(v: @Vector(3, T)) bool {
            const s = 1e-8;
            return @reduce(.And, @fabs(v) < @splat(3, @as(T, s)));
        }
    };
}
