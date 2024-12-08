//      Copyright 2024 - Marcos Pires
//      Permission to use, copy, modify, and/or distribute this software for
//      any purpose with or without fee is hereby granted.
//
//      THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL
//      WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
//      OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
//      FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
//      DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
//      AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
//      OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

// HOW TO RUN THIS:
// Download your puzzle input from adventofcode.com/2024/day/8 to the file input.txt
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const DynamicBitSet = std.bit_set.DynamicBitSet;
const tokenizeScalar = std.mem.tokenizeScalar;

const Puzzle = @This();

input_data: []const u8,
arena: Allocator,
part1: u64 = undefined,
part2: u64 = undefined,

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 4096, 1, null);
    file.close();

    var puzzle = Puzzle{ .input_data = input_data, .arena = arena.allocator() };

    try puzzle.solve();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Part One: {d}\n", .{puzzle.part1});
    try stdout.print("Part Two: {d}\n", .{puzzle.part2});
}

const Pos = struct {
    l: i8,
    r: i8,

    pub fn dif(self: Pos, other: Pos) Pos {
        return .{
            .l = self.l - other.l,
            .r = self.r - other.r,
        };
    }

    pub fn add(self: Pos, other: Pos) Pos {
        return .{
            .l = self.l + other.l,
            .r = self.r + other.r,
        };
    }
};
const ArrayPos = std.ArrayListUnmanaged(Pos);

const AntennaLocationDict = struct {
    //each array is a list of antenna possitions associated with each possible letter/number
    arrays: []ArrayPos,
    arena: Allocator,

    const Self = @This();

    pub fn init(arena: Allocator) !Self {
        var arrays = try arena.alloc(ArrayPos, 62);
        for (0..62) |i| {
            arrays[i] = try ArrayPos.initCapacity(arena, 8);
        }
        return Self{ .arrays = arrays, .arena = arena };
    }

    pub fn add(self: *Self, idx: u8, line: i8, row: i8) !void {
        const i = AntennaLocationDict.index(idx);
        try self.arrays[i].append(self.arena, .{ .l = line, .r = row });
    }

    fn index(c: u8) usize {
        if (std.ascii.isDigit(c)) return c - '0';
        if (std.ascii.isUpper(c)) return c - 'A' + 10;
        if (std.ascii.isLower(c)) return c - 'a' + 36;
        unreachable;
    }
};

pub fn solve(puzzle: *Puzzle) !void {
    var lines_it = tokenizeScalar(u8, puzzle.input_data, '\n');

    const side_len = lines_it.peek().?.len;
    var antenna_loc = try AntennaLocationDict.init(puzzle.arena);

    var l: i8 = 0;
    //Find the position of antennas
    while (lines_it.next()) |line| : (l += 1) {
        for (line, 0..) |c, r| {
            if (c == '.') continue else try antenna_loc.add(c, l, @intCast(r));
        }
    }

    //Find the antinodes between antennas

    var antinodes = try DynamicBitSet.initEmpty(puzzle.arena, side_len * side_len);
    puzzle.part1 = try solvePart1(side_len, &antinodes, antenna_loc);

    //you can pass the same antinodes, since part1 is a subset of part2, no need to reset
    puzzle.part2 = try solvePart2(side_len, &antinodes, antenna_loc);
}

fn solvePart1(side_len: usize, antinodes: *DynamicBitSet, antenna_loc: AntennaLocationDict) !u64 {
    for (antenna_loc.arrays) |antenna_array| {
        const antenna = antenna_array.items;
        if (antenna.len < 2) continue; //There are no antennas, or just one antenna

        //This is a triangular number of pair combinations
        //No need to repeat pairs with earlier numbers
        for (antenna[0 .. antenna.len - 1], 0..) |pos_a, idx_a| {
            for (antenna[idx_a + 1 .. antenna.len]) |pos_b| {
                const an1 = antinode(pos_a, pos_b);
                if (inbounds(side_len, an1)) antinodes.set(index(side_len, an1));

                const an2 = antinode(pos_b, pos_a);
                if (inbounds(side_len, an2)) antinodes.set(index(side_len, an2));
            }
        }
    }

    return antinodes.count();
}

fn solvePart2(side_len: usize, antinodes: *DynamicBitSet, antenna_loc: AntennaLocationDict) !u64 {
    for (antenna_loc.arrays) |antenna_array| {
        const antenna = antenna_array.items;
        if (antenna.len < 2) continue; //There are no antennas, or just one antenna

        //This is a triangular number of pair combinations
        //No need to repeat pairs with earlier numbers
        for (antenna[0 .. antenna.len - 1], 0..) |pos_a, idx_a| {
            for (antenna[idx_a + 1 .. antenna.len]) |pos_b| {
                projectAntinode(pos_a, pos_b, side_len, antinodes);
                projectAntinode(pos_b, pos_a, side_len, antinodes);
            }
        }
    }

    return antinodes.count();
}

inline fn index(s: usize, p: Pos) usize {
    const pl: usize = @intCast(p.l);
    const pr: usize = @intCast(p.r);
    return s * pl + pr;
}

//part 1 antinode projection
fn antinode(a: Pos, b: Pos) Pos {
    const dif_l = b.l - a.l;
    const dif_r = b.r - a.r;
    return .{ .l = a.l + 2 * dif_l, .r = a.r + 2 * dif_r };
}

inline fn inbounds(s: usize, p: Pos) bool {
    return p.l >= 0 and p.l < s and p.r >= 0 and p.r < s;
}

//part 2 antinode projection
fn projectAntinode(a: Pos, b: Pos, s: usize, antinodes: *DynamicBitSet) void {
    const dif = b.dif(a);
    var an = a.add(dif);
    while (inbounds(s, an)) : (an = an.add(dif)) antinodes.set(index(s, an));
}

test "advent" {
    const input_data =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer _ = arena.reset(.free_all);
    var puzzle = Puzzle{ .input_data = input_data, .arena = arena.allocator() };
    try puzzle.solve();
    try std.testing.expectEqual(14, puzzle.part1);
    try std.testing.expectEqual(34, puzzle.part2);
}
