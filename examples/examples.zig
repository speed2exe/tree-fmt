const std = @import("std");
const utils = @import("./utils.zig");
const formatter = utils.formatter;

test {
    std.testing.refAllDeclsRecursive(@import("./struct_with_all_types.zig"));
}

test "runtime and comptime slice" {
    const ct_slice1 = @typeInfo(struct { f1: u16, f2: u8, f3: u8, f4: u8 }).Struct.fields;
    const ct_slice2 = @typeInfo(struct { f1: u16, f2: u8, f3: u8, f4: u8, f5: u8 }).Struct.fields;
    const ct_slice3 = @typeInfo(struct { f1: u16, f2: u8, f3: u8, f4: u8, f5: u8, f6: u8 }).Struct.fields;
    const ct_slice4 = @typeInfo(struct {}).Struct.fields;
    try formatter.format(ct_slice1, .{ .name = "ct_slice1" });
    try formatter.format(ct_slice2, .{ .name = "ct_slice2" });
    try formatter.format(ct_slice3, .{ .name = "ct_slice3" });
    try formatter.format(ct_slice4, .{ .name = "ct_slice4" });

    // runtime slice
    const arr1 = [_]u8{ 49, 50, 51, 52, 53, 54 };
    const arr2 = [_]u8{ 49, 50, 51, 52, 53 };
    const arr3 = [_]u8{ 49, 50, 51, 52 };
    const arr4 = [_]u8{};
    try formatter.format(arr1, .{ .name = "rt_slice1" });
    try formatter.format(arr2, .{ .name = "rt_slice2" });
    try formatter.format(arr3, .{ .name = "rt_slice3" });
    try formatter.format(arr4, .{ .name = "rt_slice4" });
}

test "tagged union" {
    const MyUnion = union(enum) {
        a: u8,
        b: u16,
        c: u32,
    };
    const my_union: MyUnion = .{ .b = 123 };
    try formatter.format(my_union, .{ .name = "my_union" });
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

test "array 123" {
    var array: [128]u8 = undefined;
    for (&array, 0..) |*e, i| {
        e.* = @intCast(i);
    }
    try formatter.format(array, .{
        .name = "array",
        .array_elem_limit = 5,
        .print_u8_chars = false,
    });
    try formatter.format(@typeInfo(@TypeOf(array)), .{
        .name = "array type info",
    });

    const comp_array = [_]u8{ 1, 2, 3, 4, 5, 6 };
    try formatter.format(comp_array, .{
        .name = "comptime array",
    });
    try formatter.format(@typeInfo(@TypeOf(comp_array)), .{
        .name = "array type info",
    });
}

test "map" {
    var map = std.AutoHashMap(u8, u8).init(std.testing.allocator);
    defer map.deinit();

    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        try map.put(i, i * 2);
    }

    try formatter.format(map, .{ .name = "map" });
    try formatter.format(@typeInfo(@TypeOf(map)), .{ .name = "map typeInfo" });
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
    try formatter.format(@typeInfo(@TypeOf(array_list)), .{
        .name = "arraylist type info",
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
    try formatter.format(@typeInfo(anyerror!MyStruct), .{ .name = "err union type info" });
}

test "sentinel ptr" {
    const sentinel_array: [*:0]const u8 = "hello world";
    try formatter.format(sentinel_array, .{ .name = "sentinel_array" });
    try formatter.format(@typeInfo([*:0]const u8), .{ .name = "sentinel ptr type info" });
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
    try formatter.format(@typeInfo(?*LinkedNode), .{
        .name = "optional ptr type info",
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

    try formatter.format(@typeInfo(std.MultiArrayList(Person)), .{
        .name = "multi_array_list type info",
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
    try formatter.format(@typeInfo(@TypeOf(ast.tokens)), .{ .name = "ast type info" });
}

test "std" {
    try formatter.format(@typeInfo(std), .{
        .name = "std type info",
        .slice_elem_limit = 1000,
        .ignore_u8_in_lists = true,
    });
    try formatter.format(@typeInfo(std.net), .{
        .name = "std type info",
        .slice_elem_limit = 1000,
        .ignore_u8_in_lists = true,
    });
    try formatter.format(@typeInfo(std.net.Stream), .{
        .name = "std type info",
        .slice_elem_limit = 1000,
        .ignore_u8_in_lists = true,
    });
}
