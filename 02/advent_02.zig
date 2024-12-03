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
// Download your puzzle input from adventofcode.com/2024/day/2 to the file input.txt
// You can also use input.txt.example by removing the .example extension
// or changing this global variable here:
const filename = "input.txt";
const INT_BUF_SIZE = 10;

const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    var input_lines = std.mem.tokenizeScalar(u8, input_data, '\n');

    var part1: u64 = 0;
    var part2: u64 = 0;
    var int_buffer: [INT_BUF_SIZE]i8 = .{0} ** INT_BUF_SIZE;

    while (input_lines.next()) |line| {
        // const fb = std.heap.FixedBufferAllocator.init(&int_buffer);
        // var array = std.ArrayList(u8).initCapacity(fb.allocator(), num: usize);
        const num_list = try tokenizeLine(line, &int_buffer);
        part1 += isSafePt1(num_list);
        part2 += isSafePt2(num_list);
    }

    std.debug.print("Part One: {d}\n", .{part1});
    std.debug.print("Part Two: {d}\n", .{part2});
}

fn tokenizeLine(line: []const u8, buf: []i8) ![]const i8 {
    var tokens = std.mem.tokenizeScalar(u8, line, ' ');
    var i: usize = 0;

    while (try nextInt(&tokens)) |num| : (i += 1) {
        buf[i] = num;
    }

    return buf[0..i];
}

const TokenIterator = std.mem.TokenIterator(u8, .scalar);

fn nextInt(tokens: *TokenIterator) !?i8 {
    if (tokens.next()) |token| {
        return try std.fmt.parseInt(i8, token, 10);
    } else return null;
}

fn isSafePt1(line: []const i8) u1 {
    var prev: i8 = line[0];
    const second: i8 = line[1];

    const polarity = std.math.sign(second - prev);
    if (polarity == 0) return 0;

    for (line[1..]) |last| {
        const abs_dif = @abs(last - prev);
        if (abs_dif < 1 or abs_dif > 3) break;
        if (std.math.sign(last - prev) != polarity) break;
        prev = last;
    } else {
        return 1;
    }

    return 0;
}

fn isSafePt2(line: []const i8) u1 {
    if (isSafePt1(line) == 0) {
        for (0..line.len) |i| {
            if (isSafeExceptIndex(line, i) == 1) return 1;
        }
        return 0;
    } else return 1;
}

fn isSafeExceptIndex(line: []const i8, index: usize) u1 {
    if (index == 0) return isSafePt1(line[1..]);
    var buffer: [INT_BUF_SIZE]i8 = .{0} ** INT_BUF_SIZE;
    std.mem.copyForwards(i8, buffer[0..], line[0..index]);
    std.mem.copyForwards(i8, buffer[index..], line[index + 1 ..]);
    return isSafePt1(buffer[0 .. line.len - 1]);
}

//This function is kept for posteriority
//This was an attempt at an O(n) solution for part two
//Curiosly I've browsed some solutions and I haven't found someone who implemented an O(n) solution
//I wonder why, probably because the naïve solution is much simpler, it works, and it isn't heavy.
fn isSafePt2Retired(line: []const i8) u1 {
    const first = line[0];
    const second = line[1];
    const third = line[2];

    if (!valid_dif(second, first)) {
        return if (isSafePt1(line[1..]) == 1) 1 else isSafeExceptIndex(line, 1);
    }

    const polarity1 = std.math.sign(second - first);
    const polarity2 = std.math.sign(third - second);
    //some comments here are old code that tried to follow a certain solution
    // const polarity3 = std.math.sign(third - first);

    if (polarity1 == 0) return isSafePt1(line[1..]);
    if (polarity2 == 0) return isSafeExceptIndex(line, 1);
    if (polarity1 != polarity2) {
        // const fourth = line[3];
        // if (std.math.sign(fourth - second) == polarity1) return isSafeExceptIndex(line, 2);
        // if (std.math.sign(fourth - second) == polarity2) return isSafePt1(line[1..]);
        // if (polarity3 != 0 and std.math.sign(fourth - third) == polarity3) return isSafeExceptIndex(line, 1);
        // return 0;
        if (isSafePt1(line[1..]) == 0)
            if (isSafeExceptIndex(line, 1) == 0)
                if (isSafeExceptIndex(line, 2) == 0) return 0 else return 1
            else
                return 1
        else
            return 1;
    }

    var prev = second;
    for (line[2..], 2..) |last, i| {
        const polarity = std.math.sign(last - prev);
        if (polarity != polarity1 or !valid_dif(last, prev)) return isSafeExceptIndex(line, i);
        prev = last;
    }

    return 1;
}

inline fn valid_dif(b: i8, a: i8) bool {
    return @abs(b - a) < 1 or @abs(b - a) > 3;
}
