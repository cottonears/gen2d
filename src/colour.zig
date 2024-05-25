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

    pub fn init(seed: usize) !RandomHslPalette {
        return RandomHslPalette{
            .rng = std.rand.DefaultPrng.init(seed),
        };
    }

    pub fn getRandomHslTriple(self: *RandomHslPalette, buffer: []u8) ![]u8 {
        // TODO: update to generate random integers
        const h = self.h_min + self.rng.random().int(u9)%(self.h_max - self.h_min);
        const s = self.s_min + self.rng.random().int(u7)%(self.s_max - self.s_min);
        const l = self.l_min + self.rng.random().int(u7)%(self.l_max - self.l_min);
        return try std.fmt.bufPrint(buffer, "hsl({d:.0},{d:.0}%,{d:.0}%)", .{ h, s, l });
    }
};

test "default palette" {    
    var mypal = try RandomHslPalette.init(0);
    var buff: [32]u8 = undefined;  
    for (0..10)|i|{
        const hsl = try mypal.getRandomHslTriple(&buff);
        std.debug.print("{}. {s}\n", .{i, hsl});
    }
}

test "test errors" {
    // check meaningful errors are returned when
}
