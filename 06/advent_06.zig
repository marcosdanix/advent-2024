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
// You can also use input.txt.example by removing the .example extension
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const Slice2D = [][]u8;
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

fn solve(ctx: *Context) !void {
    var map_guard_l: u64 = undefined;
    var map_guard_r: u64 = undefined;
    var l: u64 = 0;

    var lines_it = std.mem.tokenizeScalar(u8, ctx.input_data, '\n');
    var map_array = try ArrayList([]u8).initCapacity(ctx.arena, 130); //array of slices
    while (lines_it.next()) |line_const| : (l += 1) {
        const line: []u8 = @constCast(line_const);
        try map_array.append(line);
        if (std.mem.indexOfScalar(u8, line, '^')) |r| {
            map_guard_l = l;
            map_guard_r = r;
            line[r] = '.'; //the guard doesn't have to be in map, only his position needs to be tracked.
            break;
        }
    }

    //By necessity guard_l/r are variables, but I want to be clear that the initial position is constant
    const initial_guard_l = map_guard_l;
    const initial_guard_r = map_guard_r;

    //Just add lines to the map_array, no need to check for guard positions
    while (lines_it.next()) |line| try map_array.append(@constCast(line));

    //Yes, I know it's better to have a single array instead of an array of slices
    //But it's much simpler this way, I'm not making a 90's video game here.
    const map: Slice2D = try map_array.toOwnedSlice();
    //For Part 2 I'll need to know which positions had been visited to test for loopiness
    //However it's easier if I use a single array here
    const map_len = map.len;
    var patrol_set = try DynamicBitSet.initEmpty(ctx.arena, map_len * map_len);
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
            if (map[gl][gr] == '.') {
                map[gl][gr] = 'X'; //This tile has been explored
                result += 1;
                patrol_set.set(map_len * gl + gr);
            } else if (map[gl][gr] == '#') { //go back and then start a new run
                gl = @intCast(@as(i64, @intCast(gl)) - line_plus);
                gr = @intCast(@as(i64, @intCast(gr)) - row_plus);
                break;
            } //else if '%', just ignore and continue the loop
            const ngl: i64 = @as(i64, @intCast(gl)) + line_plus;
            const ngr: i64 = @as(i64, @intCast(gr)) + row_plus;
            //we find that we left the map
            if (ngl < 0 or ngl == map.len or ngr < 0 or ngr == map[gl].len) {
                try printMap(map); //print the map for fun
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
        const obstacle_l = position / map_len;
        const obstacle_r = position % map_len;

        map[obstacle_l][obstacle_r] = '#';

        dir_index = 0;
        gl = initial_guard_l;
        gr = initial_guard_r;

        //Let's see if the obstacle we placed induces a loop in the map
        const is_loop: bool = outer: while (true) : (dir_index +%= 1) {
            const line_plus = directions[dir_index][0]; //line_plus
            const row_plus = directions[dir_index][1]; //row_plus

            //Each position in a run
            while (true) {
                if (map[gl][gr] == '.' or map[gl][gr] == 'O') {
                    //We have explored this tile and stored the direction we were facing
                    //Because if we return here in the same direction, then we know we have looped.
                    //We use the 5 LSB of the byte to store a direction mask and if it was a successful obstacle
                    //0 0 0 1         - 1 1 1 1
                    //      ^obstacle   ^previous walked directions
                    map[gl][gr] = if (map[gl][gr] == '.') @as(u8, 1) << dir_index else 0x10 | @as(u8, 1) << dir_index;
                } else if (map[gl][gr] <= 0x1F) { //contains the defined mask
                    //If the bit corresponding the current direction is set...
                    if (map[gl][gr] & @as(u8, 1) << dir_index > 0) {
                        break :outer true; //... We have found the loop!
                    }
                    map[gl][gr] |= @as(u8, 1) << dir_index;
                } else if (map[gl][gr] == '#') { //go back and then start a new run
                    gl = @intCast(@as(i64, @intCast(gl)) - line_plus);
                    gr = @intCast(@as(i64, @intCast(gr)) - row_plus);
                    break;
                } else unreachable; //for my sanity

                const ngl: i64 = @as(i64, @intCast(gl)) + line_plus;
                const ngr: i64 = @as(i64, @intCast(gr)) + row_plus;
                //we find that we left the map, then it doesn't obviously loop
                if (ngl < 0 or ngl == map.len or ngr < 0 or ngr == map[gl].len) {
                    break :outer false;
                }
                gl = @intCast(ngl);
                gr = @intCast(ngr);
            }
        };

        if (is_loop) {
            result += 1;
            map[obstacle_l][obstacle_r] = 'O';
        } else {
            map[obstacle_l][obstacle_r] = '.';
        }
    }

    ctx.part2 = result;

    initializeMap(map);
    try printMap(map);
}

fn initializeMap(map: Slice2D) void {
    for (0..map.len) |l| {
        for (0..map.len) |r| {
            switch (map[l][r]) {
                '#', '.', 'O' => |c| map[l][r] = c,
                'X' => map[l][r] = '.',
                0x01...0x0F => map[l][r] = '.',
                0x11...0x1F => map[l][r] = 'O',
                else => unreachable,
            }
        }
    }
}

fn printMap(map: Slice2D) !void {
    const stdout = std.io.getStdOut().writer();
    for (map) |line| {
        try stdout.writeAll(line);
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
