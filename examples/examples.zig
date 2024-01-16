const std = @import("std");
const utils = @import("./utils.zig");
const formatter = utils.formatter;

test {
    std.testing.refAllDeclsRecursive(@import("./struct_with_all_types.zig"));
}

test "anon struct 1" {
    try formatter.format(.{ 1, 2, 3 }, .{
        .name = "foo",
    });
}

test "anon struct 2" {
    const s = .{
        .a = "hello",
        .b = @as(i32, 5),
        .c = 3,
        .d = 3.14,
    };
    try formatter.format(s, .{});
}

test "array" {
    var array: [128]u8 = undefined;
    for (&array, 0..) |*e, i| {
        e.* = @intCast(i);
    }

    try formatter.format(array, .{
        .name = "array",
        .array_elem_limit = 5,
        .print_u8_chars = false,
    });
}

test "map" {
    var map = std.AutoHashMap(u8, u8).init(std.testing.allocator);
    defer map.deinit();

    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        try map.put(i, i * 2);
    }

    try formatter.format(map, .{ .name = "map1" });
}

test "array list slice" {
    var array_list = std.ArrayList(u8).init(std.testing.allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try formatter.format(array_list, .{ .name = "array" });
    try formatter.format(array_list.items[0..0], .{
        .name = "slice1",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
    try formatter.format(array_list.items[0..1], .{
        .name = "slice2",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
    try formatter.format(array_list.items[0..2], .{
        .name = "slice3",
        .array_elem_limit = 1,
        .print_u8_chars = false,
    });
}

test "array list" {
    var array_list = std.ArrayList(u8).init(std.testing.allocator);
    defer array_list.deinit();

    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        try array_list.append(i);
    }

    try formatter.format(array_list, .{
        .array_elem_limit = 5,
        .print_u8_chars = false,
    });
}

test "error union" {
    const MyStruct = struct {
        a: []const u8 = "hi",
        b: u32 = 987,
    };

    const my_struct_value = MyStruct{ .a = "hello", .b = 123 };
    const my_struct_error = error.HiYouGotError;

    try formatter.format(my_struct_error, .{ .name = "my_struct_error" });
    try formatter.format(my_struct_value, .{ .name = "my_struct_value" });
}

test "sentinel ptr" {
    const sentinel_array: [*:0]const u8 = "hello world";
    try formatter.format(sentinel_array, .{ .name = "sentinel_array" });
}

const LinkedNode = struct {
    val: i32,
    next: ?*LinkedNode = null,
};
test "recursive struct" {
    var n1 = LinkedNode{ .val = 1 };
    var n2 = LinkedNode{ .val = 2 };
    n1.next = &n2;
    n2.next = &n1;
    try formatter.format(n1, .{
        .name = "n1",
        .ptr_repeat_limit = 2,
    });
}

test "multi array list" {
    const Car = struct {
        license_plate_no: u64 = 555,
    };
    const Person = struct {
        id: u64,
        age: u8,
        car: Car = .{},
    };

    var multi_array_list: std.MultiArrayList(Person) = .{};
    defer multi_array_list.deinit(std.testing.allocator);

    comptime var i: u8 = 0;
    inline while (i < 7) : (i += 1) {
        try multi_array_list.append(std.testing.allocator, .{
            .id = i,
            .age = i,
        });
    }

    try formatter.format(multi_array_list, .{
        .name = "multi_array_list1",
        .multi_array_list_get_limit = 4,
        .print_u8_chars = false,
    });
}

test "zig program" {
    const zig_code =
        \\ const std = @import("std");
        \\
        \\ pub fn main() void {
        \\     std.debug.print("hello {s}", .{"world"});
        \\ }
    ;
    var ast = try std.zig.Ast.parse(std.testing.allocator, zig_code, .zig);
    defer ast.deinit(std.testing.allocator);
    try formatter.format(ast.tokens, .{ .name = "ast" });
}

fn begin(args: anytype) !void {
    _ = args;
    std.debug.print("begin\n", .{});
}
test "cli parsing declaration" {
    const decl = .{
        .flags = &.{
            .{
                .short = "h",
                .long = "help",
                .description = "Prints help information",
                .type = bool,
                .default_value = false,
            },
        },
        .subs = &.{
            .{},
        },
        .exec = begin,
    };
    try formatter.format(decl, .{ .name = "cli decl" });
}
