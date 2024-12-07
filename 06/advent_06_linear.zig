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
// Download your puzzle input from adventofcode.com/2024/day/6 to the file input.txt
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.bit_set.DynamicBitSet;

const Context = struct {
    input_data: []u8,
    arena: Allocator,
    part1: u64 = undefined,
    part2: u64 = undefined,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    var ctx = Context{ .input_data = input_data, .arena = arena.allocator() };

    try solve(&ctx);

    std.debug.print("Part One: {d}\n", .{ctx.part1});
    std.debug.print("Part Two: {d}\n", .{ctx.part2});
}

// I tried to have a struct, but the initialization syntax sucks
// So [0] is line_plus and [1] is row_plus
// const Dir = struct {
//     line_plus: i2,
//     row_plus: i2,
// };

//UP, RIGHT, DOWN, LEFT
const directions: [4][2]i2 = .{ .{ -1, 0 }, .{ 0, 1 }, .{ 1, 0 }, .{ 0, -1 } };

inline fn idx(len: u64, l: u64, r: u64) u64 {
    return l * len + r;
}

fn solve(ctx: *Context) !void {
    var map_guard_l: u64 = undefined;
    var map_guard_r: u64 = undefined;
    var l: u64 = 0;
    var len: u64 = undefined;

    var lines_it = std.mem.tokenizeScalar(u8, ctx.input_data, '\n');
    var map_array = try ArrayList(u8).initCapacity(ctx.arena, 130 * 130); //array of slices
    while (lines_it.next()) |line_const| : (l += 1) {
        const line: []u8 = @constCast(line_const);
        if (std.mem.indexOfScalar(u8, line, '^')) |r| {
            map_guard_l = l;
            map_guard_r = r;
            line[r] = '.'; //the guard doesn't have to be in map, only his position needs to be tracked.
            len = line.len;
            try map_array.appendSlice(line);
            break;
        }
        try map_array.appendSlice(line);
    }

    while (lines_it.next()) |line_const| try map_array.appendSlice(@constCast(line_const));

    std.debug.print("side: {d} total: {d}\n", .{ len, map_array.items.len });

    //By necessity guard_l/r are variables, but I want to be clear that the initial position is constant
    const initial_guard_l = map_guard_l;
    const initial_guard_r = map_guard_r;
    const side_len = len;

    //Just add lines to the map_array, no need to check for guard positions
    while (lines_it.next()) |line| try map_array.appendSlice(@constCast(line));

    const map: []u8 = try map_array.toOwnedSlice();
    //For Part 2 I'll need to know which positions had been visited to test for loopiness
    var patrol_set = try DynamicBitSet.initEmpty(ctx.arena, map.len);
    var result: u64 = 0;
    var dir_index: u2 = 0;
    var gl = initial_guard_l;
    var gr = initial_guard_r;

    //Each run in a direction
    outer: while (true) : (dir_index +%= 1) {
        const line_plus = directions[dir_index][0]; //line_plus
        const row_plus = directions[dir_index][1]; //row_plus

        //Each position in a run
        while (true) {
            if (map[idx(side_len, gl, gr)] == '.') {
                map[idx(side_len, gl, gr)] = 'X'; //This tile has been explored
                result += 1;
                patrol_set.set(idx(side_len, gl, gr));
            } else if (map[idx(side_len, gl, gr)] == '#') { //go back and then start a new run
                gl = @intCast(@as(i64, @intCast(gl)) - line_plus);
                gr = @intCast(@as(i64, @intCast(gr)) - row_plus);
                break;
            } //else if '%', just ignore and continue the loop
            const ngl: i64 = @as(i64, @intCast(gl)) + line_plus;
            const ngr: i64 = @as(i64, @intCast(gr)) + row_plus;
            //we find that we left the map
            if (ngl < 0 or ngl == side_len or ngr < 0 or ngr == side_len) {
                try printMap(map, side_len); //print the map for fun
                break :outer;
            }
            gl = @intCast(ngl);
            gr = @intCast(ngr);
        }
    }

    ctx.part1 = result;

    result = 0;

    var patrol_it = patrol_set.iterator(.{});

    while (patrol_it.next()) |position| {
        initializeMap(map);
        const obstacle_l = position / side_len;
        const obstacle_r = position % side_len;

        map[idx(side_len, obstacle_l, obstacle_r)] = '#';

        dir_index = 0;
        gl = initial_guard_l;
        gr = initial_guard_r;

        //Let's see if the obstacle we placed induces a loop in the map
        const is_loop: bool = outer: while (true) : (dir_index +%= 1) {
            const line_plus = directions[dir_index][0]; //line_plus
            const row_plus = directions[dir_index][1]; //row_plus

            //Each position in a run
            while (true) {
                if (map[idx(side_len, gl, gr)] == '.' or map[idx(side_len, gl, gr)] == 'O') {
                    //We have explored this tile and stored the direction we were facing
                    //Because if we return here in the same direction, then we know we have looped.
                    //We use the 5 LSB of the byte to store a direction mask and if it was a successful obstacle
                    //0 0 0 1         - 1 1 1 1
                    //      ^obstacle   ^previous walked directions
                    map[idx(side_len, gl, gr)] = if (map[idx(side_len, gl, gr)] == '.') @as(u8, 1) << dir_index else 0x10 | @as(u8, 1) << dir_index;
                } else if (map[idx(side_len, gl, gr)] <= 0x1F) { //contains the defined mask
                    //If the bit corresponding the current direction is set...
                    if (map[idx(side_len, gl, gr)] & @as(u8, 1) << dir_index > 0) {
                        break :outer true; //... We have found the loop!
                    }
                    map[idx(side_len, gl, gr)] |= @as(u8, 1) << dir_index;
                } else if (map[idx(side_len, gl, gr)] == '#') { //go back and then start a new run
                    gl = @intCast(@as(i64, @intCast(gl)) - line_plus);
                    gr = @intCast(@as(i64, @intCast(gr)) - row_plus);
                    break;
                } else unreachable; //for my sanity

                const ngl: i64 = @as(i64, @intCast(gl)) + line_plus;
                const ngr: i64 = @as(i64, @intCast(gr)) + row_plus;
                //we find that we left the map, then it doesn't obviously loop
                if (ngl < 0 or ngl == side_len or ngr < 0 or ngr == side_len) {
                    break :outer false;
                }
                gl = @intCast(ngl);
                gr = @intCast(ngr);
            }
        };

        if (is_loop) {
            result += 1;
            map[idx(side_len, obstacle_l, obstacle_r)] = 'O';
        } else {
            map[idx(side_len, obstacle_l, obstacle_r)] = '.';
        }
    }

    ctx.part2 = result;

    initializeMap(map);
    try printMap(map, side_len);
}

fn initializeMap(map: []u8) void {
    for (0..map.len) |i| {
        switch (map[i]) {
            '#', '.', 'O' => |c| map[i] = c,
            'X' => map[i] = '.',
            0x01...0x0F => map[i] = '.',
            0x11...0x1F => map[i] = 'O',
            else => unreachable,
        }
    }
}

fn printMap(map: []u8, side_len: usize) !void {
    const stdout = std.io.getStdOut().writer();
    var index: usize = 0;

    while (index < map.len) : (index += side_len) {
        try stdout.writeAll(map[index .. index + side_len]);
        try stdout.writeAll("\n");
    }

    try stdout.writeAll("\n");
}

test "advent" {
    const input_data =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer _ = arena.reset(.free_all);
    var array = try ArrayList(u8).initCapacity(arena.allocator(), input_data.len);
    array.appendSliceAssumeCapacity(input_data);

    var ctx = Context{ .input_data = try array.toOwnedSlice(), .arena = arena.allocator() };
    try solve(&ctx);

    try std.testing.expectEqual(41, ctx.part1);
    try std.testing.expectEqual(6, ctx.part2);
}
