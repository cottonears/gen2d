const std = @import("std");

pub const vec2f = @Vector(2, f32);

// quite a bit nicer to use than RGB
pub const RandomHslPalette = struct {
    h_min: u9 = 0,
    h_max: u9 = 360,
    s_min: u7 = 0,
    s_max: u7 = 100,
    l_min: u7 = 0,
    l_max: u7 = 100,
    rng: std.rand.DefaultPrng,

    pub fn init(seed: usize, h_min: ?u9, h_max: ?u9, s_min: ?u7, s_max: ?u7, l_min: ?u7, l_max: ?u7) !RandomHslPalette {
        return RandomHslPalette{
            .rng = std.rand.DefaultPrng.init(seed),
        };
    }

    pub fn getRandomHslTriple(buffer: []u8) ![]u8 {
        // TODO: update to generate random integers
        const h = h_min + (h_max - h_min) * self.rng.random().float(f32);
        const s = s_min + (s_max - s_min) * self.rng.random().float(f32);
        const l = l_min + (l_max - l_min) * self.rng.random().float(f32);
        return try std.fmt.bufPrint(buffer, "hsl({d:.0},{d:.0}%,{d:.0}%)", .{ h, s, l });
    }
};

test "default palette" {
    // get the default palette and generate some colours!
}

test "test errors" {
    // check meaningful errors are returned when
}
