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
// Download your puzzle input from adventofcode.com/2024/day/4 to the file input.txt
// You can also use input.txt.example by removing the .example extension
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Slice2D = []const []const u8;
const tokenizeScalar = std.mem.tokenizeScalar;
const splitScalar = std.mem.splitScalar;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    var lines_it = std.mem.tokenizeScalar(u8, input_data, '\n');
    var map_array = try ArrayList([]const u8).initCapacity(arena.allocator(), 140); //array of slices
    while (lines_it.next()) |line| try map_array.append(line);
    const map: Slice2D = try map_array.toOwnedSlice();

    const part1 = try doPart1(map);
    const part2 = try doPart2(map);

    std.debug.print("Part One: {d}\n", .{part1});
    std.debug.print("Part Two: {d}\n", .{part2});
}

const ROW_PLUS: [3]isize = .{ -1, 0, 1 };
const LINE_PLUS: [2]isize = .{ -1, 1 };

fn doPart1(map: Slice2D) !u64 {
    var result: u64 = 0;

    for (map, 0..) |line, l| {
        var r: usize = 0;
        var split_it = splitScalar(u8, line, 'X');

        const first = split_it.first();
        if (split_it.peek() == null) continue; //because there's no X in this line!!
        r += first.len;
        result += increment(isSuffixLeft(first));
        for (ROW_PLUS) |rp| {
            for (LINE_PLUS) |lp| {
                result += increment(isSuffixGeneric(map, l, r, lp, rp));
            }
        }

        while (split_it.next()) |slice| {
            if (split_it.peek() == null) {
                result += increment(isSuffixRight(slice));
                break;
            }
            r += slice.len + 1;
            result += increment(isSuffixRight(slice));
            result += increment(isSuffixLeft(slice));
            for (ROW_PLUS) |rp| {
                for (LINE_PLUS) |lp| {
                    result += increment(isSuffixGeneric(map, l, r, lp, rp));
                }
            }
        }
    }

    return result;
}

fn doPart2(map: Slice2D) !u64 {
    var result: u64 = 0;

    for (map[1 .. map.len - 1], 1..) |line, l| {
        var r: usize = 0;
        var split_it = splitScalar(u8, line, 'A');

        const first = split_it.first();
        if (first.len > 0 and split_it.peek() != null) {
            r += first.len;
            result += increment(isXmas(map, l, r));
        }

        while (split_it.next()) |slice| {
            //don't calculate when there's no more A's in the line, or when it's the last A of the line
            r += slice.len + 1;
            if (r >= map.len - 1) break;
            result += increment(isXmas(map, l, r));
        }
    }

    return result;
}

inline fn increment(b: bool) u1 {
    return if (b) 1 else 0;
}

inline fn isSuffixLeft(slice: []const u8) bool {
    return endsWith(u8, slice, "SAM");
}

inline fn isSuffixRight(slice: []const u8) bool {
    return startsWith(u8, slice, "MAS");
}

const SUFFIX = "MAS";

inline fn isSuffixGeneric(map: Slice2D, l: usize, r: usize, l_plus: isize, r_plus: isize) bool {
    const line: isize = @intCast(l);
    const row: isize = @intCast(r);
    if (l_plus > 0 and line > map.len - 4) return false;
    if (l_plus < 0 and line < 3) return false;
    if (r_plus > 0 and row > map.len - 4) return false;
    if (r_plus < 0 and row < 3) return false;

    for (SUFFIX, 1..) |c, index| {
        const i: isize = @intCast(index);
        if (map[@intCast(line + l_plus * i)][@intCast(row + r_plus * i)] != c) return false;
    } else {
        return true;
    }
}

fn isXmas(map: Slice2D, line: usize, row: usize) bool {
    //sorry but my linter put this in a single line :-(
    const up_left = map[line - 1][row - 1];
    const up_right = map[line - 1][row + 1];
    const down_left = map[line + 1][row - 1];
    const down_right = map[line + 1][row + 1];

    return ((up_left == 'M' and down_right == 'S') or (up_left == 'S' and down_right == 'M')) and ((up_right == 'M' and down_left == 'S') or (up_right == 'S' and down_left == 'M'));
}

test "part1&part2" {
    const input_data =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer _ = arena.reset(.free_all);
    var lines_it = std.mem.tokenizeScalar(u8, input_data, '\n');
    var map_array = try ArrayList([]const u8).initCapacity(arena.allocator(), 140); //array of slices
    while (lines_it.next()) |line| try map_array.append(line);
    const map: Slice2D = try map_array.toOwnedSlice();

    try std.testing.expectEqual(18, doPart1(map));
    try std.testing.expectEqual(9, doPart2(map));
}
