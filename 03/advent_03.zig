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
// Download your puzzle input from adventofcode.com/2024/day/3 to the file input.txt
// or changing this global variable here:
const filename = "input.txt";

const std = @import("std");
const indexOf = std.mem.indexOf;
const indexOfAny = std.mem.indexOfAny;
const startsWith = std.mem.startsWith;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    const part1 = try doPart1(input_data);
    const part2 = try doPart2(input_data);

    std.debug.print("Part One: {d}\n", .{part1});
    std.debug.print("Part Two: {d}\n", .{part2});
}

fn doPart1(input_data: []const u8) !u64 {
    var index: usize = 0;
    var result: u64 = 0;

    while (indexOf(u8, input_data[index..], "mul(")) |i| {
        index += i + 4; //len of "mem("
        const num1 = try getNumber(&index, input_data, ',') orelse continue;
        const num2 = try getNumber(&index, input_data, ')') orelse continue;
        result += num1 * num2;
    }

    return result;
}

const search_pattern: [2]u8 = .{ 'd', 'm' };

fn doPart2(input_data: []const u8) !u64 {
    var index: usize = 0;
    var result: u64 = 0;
    while (indexOfAny(u8, input_data[index..], &.{ 'd', 'm' })) |i| {
        index += i;
        //we are looking for a multiplication
        if (startsWith(u8, input_data[index..], "mul(")) {
            index += 4;
            const num1 = try getNumber(&index, input_data, ',') orelse continue;
            const num2 = try getNumber(&index, input_data, ')') orelse continue;
            result += num1 * num2;
            //but if we instead find a don't()...
        } else if (startsWith(u8, input_data[index..], "don't()")) {
            index += 7;
            //we only start multiplying after finding the next do()!
            const j = indexOf(u8, input_data[index..], "do()") orelse break;
            index += j + 4;
        } else {
            index += 1;
        }
        //no need to search for do() in this context, since it's idempotent
    }

    return result;
}

fn getNumber(index_ptr: *usize, input_data: []const u8, stop: u8) !?u64 {
    const index = index_ptr.*;
    for (input_data[index..], 0..) |char, count| {
        if (std.ascii.isDigit(char)) continue;
        if (char == stop) {
            if (count == 0) return null;
            //if (count > 3) @panic("failed 3 digit assumption"); //the input should have at most 3 digits in a row
            const num = try std.fmt.parseUnsigned(u64, input_data[index .. index + count], 10);
            index_ptr.* += count + 1;
            return num;
        }

        index_ptr.* += count;
        return null;
    } else return null;
}
