const std = @import("std");
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("leaked memory!");
        }
    }

    var w = std.io.getStdOut().writer();
    var tree_formatter = TreeFormatter.init(allocator, .{
        .array_print_limit = 5,
        .print_u8_chars = false,
    });

    var multi_array_list = std.MultiArrayList(Person){};
    defer multi_array_list.deinit(allocator);

    comptime var i: u8 = 0;
    inline while (i < 3) : (i += 1) {
        try multi_array_list.append(allocator, .{
            .id = i,
            .age = i,
        });
    }

    try tree_formatter.formatValueWithId(w, multi_array_list, "multi_array_list");
}

const Person = struct {
    id: u64,
    age: u8,
    car: Car = .{},
};

const Car = struct {
    license_plate_no: u64 = 555,
};
