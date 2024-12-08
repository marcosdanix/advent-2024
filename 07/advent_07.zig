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
// Download your puzzle input from adventofcode.com/2024/day/7 to the file input.txt
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const IntegerBitSet = std.bit_set.IntegerBitSet;
const tokenizeScalar = std.mem.tokenizeScalar;
const indexOfScalar = std.mem.indexOfScalar;
const parseUnsigned = std.fmt.parseUnsigned;
const formatInt = std.fmt.formatInt;

const Context = @This();

input_data: []const u8,
part1: u64 = undefined,
part2: u64 = undefined,

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    var ctx = Context{ .input_data = input_data };

    try ctx.solve();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Part One: {d}\n", .{ctx.part1});
    try stdout.print("Part Two: {d}\n", .{ctx.part2});
}

pub fn solve(ctx: *Context) !void {
    var lines_it = tokenizeScalar(u8, ctx.input_data, '\n');
    var buffer: [20 * @sizeOf(u64)]u8 = undefined;
    ctx.part1 = 0;
    ctx.part2 = 0;

    while (lines_it.next()) |line| {
        std.debug.print("\n", .{});
        var fixed = std.heap.FixedBufferAllocator.init(&buffer);
        const colon_pos = indexOfScalar(u8, line, ':').?;
        const total = try parseUnsigned(u64, line[0..colon_pos], 10);

        var num_it = tokenizeScalar(u8, line[colon_pos + 1 ..], ' ');
        var num_list = try ArrayList(u64).initCapacity(fixed.allocator(), 20);
        defer num_list.deinit();
        while (num_it.next()) |num_txt| num_list.appendAssumeCapacity(try parseUnsigned(u64, num_txt, 10));
        const num_array = num_list.items;
        const original_len = num_array.len;

        var op_set = IntegerBitSet(32).initEmpty();

        //for each attempt at a permutation of addition and multiplication
        var op_len = (@as(u32, 1) << @intCast(original_len - 1));
        var result = for (0..op_len) |mask| {
            op_set.mask = @intCast(mask);
            std.debug.print("{d} ", .{num_array[0]});
            var running: u64 = sumOrMultiply(&op_set, 0, num_array[0], num_array[1]);

            for (1..num_array.len - 1) |i| {
                running = sumOrMultiply(&op_set, i, running, num_array[i + 1]);
            }
            std.debug.print("= {d}\n", .{running});
            if (running == total) {
                break running;
            }
        } else 0;

        if (result > 0) {
            ctx.part1 += result;
            ctx.part2 += result;
            std.debug.print("Result!\n", .{});
            continue;
        }
        //If only doing addition and multiplication failed, then we'll try to do concatenation as well
        std.debug.print("Let's concatenate!\n", .{});
        num_list.deinit();
        var fixed_concat = std.heap.FixedBufferAllocator.init(&buffer);
        var concat_set = IntegerBitSet(32).initEmpty();
        var concat_list = ArrayList(u8).init(fixed_concat.allocator());
        const concat_len = (@as(u32, 1) << @intCast(original_len - 1));

        //for every possible concatenation
        for (1..concat_len) |concat_mask| {
            concat_set.mask = @intCast(concat_mask);

            op_len = (@as(u32, 1) << @intCast(original_len - 1 - concat_set.count()));
            //for every possible sum/multiplication permutation
            result = for (0..op_len) |op_mask| {
                try concat_list.resize(0);
                try concat_list.ensureTotalCapacityPrecise(20);
                op_set.mask = @intCast(op_mask);
                num_it.reset();
                // concat_list.appendSliceAssumeCapacity(num_it.next().?);
                const first = num_it.next().?;
                std.debug.print("{s} ", .{first});
                concat_list.appendSliceAssumeCapacity(first);

                var op_i: u32 = 0;
                var concat_i: u32 = 0;

                //for every number in the line
                while (num_it.next()) |num_txt| : (concat_i += 1) {
                    if (concat_set.isSet(concat_i)) {
                        std.debug.print("|| {s} ", .{num_txt});
                        concat_list.appendSliceAssumeCapacity(num_txt);
                    } else {
                        var running = try parseUnsigned(u64, concat_list.items, 10);
                        if (op_set.isSet(op_i)) {
                            std.debug.print("* {s} ", .{num_txt});
                            running *= try parseUnsigned(u64, num_txt, 10);
                        } else {
                            std.debug.print("+ {s} ", .{num_txt});
                            running += try parseUnsigned(u64, num_txt, 10);
                        }

                        op_i += 1;
                        try concat_list.resize(0);
                        try concat_list.ensureTotalCapacityPrecise(20);
                        try formatInt(running, 10, .lower, .{}, concat_list.writer());
                    }
                }
                std.debug.print("= {s}\n", .{concat_list.items});
                const sum = try parseUnsigned(u64, concat_list.items, 10);
                if (sum == total) break sum;
            } else 0;

            if (result > 0) {
                ctx.part2 += result;
                break;
            }
        }
    }
}

inline fn sumOrMultiply(op_set: *IntegerBitSet(32), index: usize, a: u64, b: u64) u64 {
    // return if (op_set.isSet(index)) a * b else a + b;
    if (op_set.isSet(index)) {
        std.debug.print("* {d} ", .{b});
        return a * b;
    } else {
        std.debug.print("+ {d} ", .{b});
        return a + b;
    }
}

test "advent" {
    const input_data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var ctx = Context{ .input_data = input_data };
    try ctx.solve();
    try std.testing.expectEqual(3749, ctx.part1);
    try std.testing.expectEqual(11387, ctx.part2);
}
