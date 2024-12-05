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
// Download your puzzle input from adventofcode.com/2024/day/5 to the file input.txt
// You can also use input.txt.example by removing the .example extension
// or changing this global variable here
const filename = "input.txt";

const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
const ArrayList = std.ArrayList;
const IntegerBitSet = std.bit_set.IntegerBitSet;
const splitScalar = std.mem.splitScalar;
const parseUnsigned = std.fmt.parseUnsigned;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.reset(.free_all);

    var file = try std.fs.cwd().openFile(filename, .{});
    const input_data = try file.readToEndAllocOptions(arena.allocator(), 65536, 24576, 1, null);
    file.close();

    try solve(input_data);
}

fn solve(input_data: []const u8) !void {
    //Set of pages that should appear after a given page in key/array index
    var pages_after_dict: [100]IntegerBitSet(100) = undefined;
    for (0..100) |i| pages_after_dict[i] = IntegerBitSet(100).initEmpty();

    var split_it = splitScalar(u8, input_data, '\n');

    //parse conditions
    while (split_it.next()) |line| {
        if (line.len == 0) break; //We found the blank line
        var split_line = splitScalar(u8, line, '|');
        const before = try parseUnsigned(u8, split_line.first(), 10);
        const after = try parseUnsigned(u8, split_line.next().?, 10);
        pages_after_dict[before].set(after);
    }

    //parse manuals
    var part1: u64 = 0;

    //There is a more memory efficient way to organize this
    //But this is Advent of Code
    //Have a little fun.
    var num_buffer: [32]u8 = .{0} ** 32;
    var reject_slice_buffer: [200 * @sizeOf([]u8)]u8 = undefined;
    var reject_buffer: [200 * 32]u8 = undefined;
    var fixed_num_alloc = FixedBufferAllocator.init(&num_buffer);
    var fixed_reject_slice_buffer = FixedBufferAllocator.init(&reject_slice_buffer);
    var fixed_reject_buffer = FixedBufferAllocator.init(&reject_buffer);
    var rejects = try ArrayList([]u8).initCapacity(fixed_reject_slice_buffer.allocator(), 200);

    while (split_it.next()) |line| {
        if (line.len == 0) continue;
        var split_line = splitScalar(u8, line, ',');
        var pages_seen = IntegerBitSet(100).initEmpty();
        var pages_printed = try ArrayList(u8).initCapacity(fixed_num_alloc.allocator(), 32);
        defer fixed_num_alloc.reset();

        while (split_line.next()) |page_txt| {
            const page = try parseUnsigned(u8, page_txt, 10);
            pages_printed.appendAssumeCapacity(page);

            //Pages that should be after
            const after_pages = pages_after_dict[page];
            const conflicts = pages_seen.intersectWith(after_pages);
            if (conflicts.count() > 0) {
                while (split_line.next()) |page_txt2| {
                    pages_printed.appendAssumeCapacity(try parseUnsigned(u8, page_txt2, 10));
                }
                var reject_pages = try ArrayList(u8).initCapacity(fixed_reject_buffer.allocator(), pages_printed.items.len);
                reject_pages.appendSliceAssumeCapacity(pages_printed.items);
                rejects.appendAssumeCapacity(try reject_pages.toOwnedSlice());
                break;
            }

            pages_seen.set(page);
        } else {
            const pages = try pages_printed.toOwnedSlice();
            part1 += pages[pages.len >> 1];
        }
    }

    std.debug.print("Part One: {d}\n", .{part1});

    var part2: u64 = 0;

    for (rejects.items) |reject| {
        var reverse_index: [100]u8 = .{0xAA} ** 100;
        var pages_seen = IntegerBitSet(100).initEmpty();

        var index: u8 = 0;

        while (index < reject.len) : (index += 1) {
            const page = reject[index];
            reverse_index[page] = index;
            pages_seen.set(page);
            const after_pages = pages_after_dict[page];
            const conflicts = pages_seen.intersectWith(after_pages);

            //If we find a conflict we swap with the earliest conflict
            //and start over after the swap point
            if (conflicts.count() > 0) {
                var min_index: u8 = 0xAA;
                var it = conflicts.iterator(.{});
                while (it.next()) |conflict_page| {
                    if (reverse_index[conflict_page] < min_index) min_index = reverse_index[conflict_page];
                }

                //Swap the earliest page in the conflict set
                const conflict_page = reject[min_index];
                reject[min_index] = page;
                reject[index] = conflict_page;
                //Don't forget to update the reverse_index and pages_seen
                reverse_index[page] = min_index;
                reverse_index[conflict_page] = index;
                for (min_index + 1..index + 1) |i| {
                    pages_seen.unset(reject[i]);
                }

                index = min_index;
            }
        } else {
            part2 += reject[reject.len >> 1];
        }
    }

    std.debug.print("Part Two: {d}\n", .{part2});
}
