const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("memory leak detected", .{}),
        }
    }

    var w = std.io.getStdOut().writer();
    var tree_formatter = treeFormatter(allocator, w);

    var multi_array_list: std.MultiArrayList(Person) = .{};
    defer multi_array_list.deinit(allocator);

    comptime var i: u8 = 0;
    inline while (i < 7) : (i += 1) {
        try multi_array_list.append(allocator, .{
            .id = i,
            .age = i,
        });
    }

    try tree_formatter.format(multi_array_list, .{
        .name = "multi_array_list1",
        .multi_array_list_get_limit = 4,
        .print_u8_chars = false,
    });
}

const Person = struct {
    id: u64,
    age: u8,
    car: Car = .{},
};

const Car = struct {
    license_plate_no: u64 = 555,
};
