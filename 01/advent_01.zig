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
// Download your puzzle input from adventofcode.com/2024/day/1 to the file input.txt
// or changing this global variable here:
const filename = "input.txt";

const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const isDigit = std.ascii.isDigit;

pub fn main() !void {
    var arena = Arena.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var left_list = try std.ArrayList(i64).initCapacity(arena.allocator(), 10000);
    var right_list = try std.ArrayList(i64).initCapacity(arena.allocator(), 10000);

    var input_file = try std.fs.cwd().openFile(filename, .{});
    defer input_file.close();
    var buffered_reader = std.io.bufferedReader(input_file.reader());
    var input_reader = buffered_reader.reader();
    var buffer: [64]u8 = undefined;
    //Read each line of file and fill both lists
    while (try input_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        //Slice each number from the buffer
        var i: u8 = 0;

        while (!isDigit(line[i])) : (i += 1) {} //skip non digit characters
        var a: u8 = i;
        while (isDigit(line[i])) : (i += 1) {}
        var b: u8 = i;

        var id = try std.fmt.parseInt(i64, line[a..b], 10);
        try left_list.append(id);

        while (!isDigit(line[i])) : (i += 1) {} //skip non digit characters
        a = i;
        while (i < line.len and isDigit(line[i])) : (i += 1) {}
        b = i;

        id = try std.fmt.parseInt(i64, line[a..b], 10);
        try right_list.append(id);
    }

    //Part One

    const left_slice = try left_list.toOwnedSlice();
    const right_slice = try right_list.toOwnedSlice();

    std.sort.block(i64, left_slice, {}, std.sort.asc(i64));
    std.sort.block(i64, right_slice, {}, std.sort.asc(i64));

    var sum: i64 = 0;

    for (left_slice, right_slice) |left, right| {
        sum += @intCast(@abs(left - right));
    }

    std.debug.print("Part One: {d}\n", .{sum});

    //Part Two
    sum = 0;
    var l_index: usize = 0;
    var r_index: usize = 0;

    //Using two sorted lists, I can in O(n) time calculate the similarity score
    //Because backtracking is not necessary
    while (true) outer: {
        if (l_index == left_slice.len or r_index == right_slice.len) break;

        var mult: i64 = 0;

        const subject = left_slice[l_index];
        //How many times subject appears in the left_list
        const l_mult = while (left_slice[l_index] == subject) : (mult += 1) {
            increment_index(&l_index, left_slice.len) catch break mult + 1;
        } else mult;

        while (right_slice[r_index] < subject) {
            increment_index(&r_index, right_slice.len) catch break :outer;
        }
        if (right_slice[r_index] > subject) continue;

        mult = 0;
        const r_mult = while (right_slice[r_index] == subject) : (mult += 1) {
            increment_index(&r_index, right_slice.len) catch break mult + 1;
        } else mult;

        sum += subject * l_mult * r_mult;
    }

    std.debug.print("Part Two: {d}\n", .{sum});
}

fn increment_index(index: *usize, length: usize) !void {
    index.* += 1;
    if (index.* == length) return error.OutOfBounds;
}
