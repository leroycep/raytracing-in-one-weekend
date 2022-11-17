const std = @import("std");

pub const Vec3d = Vec3(f64);

pub fn Vec3(comptime T: type) type {
    return struct {
        pub fn length(v: [3]T) T {
            return @sqrt(lengthSquared(v));
        }

        pub fn lengthSquared(v: [3]T) T {
            return v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
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

        pub fn unit_vector(v: @Vector(3, T)) @Vector(3, T) {
            return v / length(v);
        }
    };
}
