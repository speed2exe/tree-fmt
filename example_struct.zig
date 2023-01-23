const std = @import("std");
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

var i32_value: i32 = 42;

const Struct1 = struct {
    // valid in comptime
    // k: type = u16,
    // field_comptime_float: comptime_float = 3.14,
    // field_comptime_int: comptime_int = 11,
    // field_fn: fn () void = functionOne,

    field_void: void = undefined,
    field_bool: bool = true,
    field_u8: u32 = 11,
    field_float: f32 = 3.14,

    field_i32_ptr: *i32 = &i32_value,
    field_slice_u8: []const u8 = "s1 string",

    field_array_u8: [3]u8 = [_]u8{ 1, 2, 3 },
    field_array_u8_empty: [0]u8 = .{},

    field_struct2: Struct2 = .{},
    field_struct4: Struct4 = .{},

    // TODO: not working, need to fix
    // field_struct_recursive: LinkedNode,

    field_null: @TypeOf(null) = null,

    field_opt_i32_value: ?i32 = 9,
    field_opt_i32_null: ?i32 = null,

    field_error: ErrorSet1 = error.Error1,
    field_error_union_error: anyerror!u8 = error.Error2,
    field_error_union_value: ErrorSet1!u8 = 5,

    field_enum_1: EnumSet1 = .Enum1,
    field_enum_2: EnumSet2 = .Enum3,

    field_union_1: Union1 = .{ .int = 98 },
    field_union_2: Union1 = .{ .float = 3.14 },
    field_union_3: Union1 = .{ .bool = true },

    field_tagged_union_1: TaggedUnion1 = .{ .int = 98 },
    field_tagged_union_2: TaggedUnion1 = .{ .float = 3.14 },
    field_tagged_union_3: TaggedUnion1 = .{ .bool = true },

    field_fn_ptr: *const fn () void = functionOne,
    field_vector: @Vector(4, i32) = .{ 1, 2, 3, 4 },

    // TODO: support Frame and AnyFrame
    // field_anyframe: anyframe = undefined,
};

const Struct2 = struct {
    field_s3: Struct3 = .{},
    field_slice_s3: []const Struct3 = &.{ .{}, .{} },
};

const Struct3 = struct {
    field_i32: i32 = 33,
};

const Struct4 = struct {};

const ErrorSet1 = error{
    Error1,
    Error2,
};

const EnumSet1 = enum {
    Enum1,
    Enum2,
};

const EnumSet2 = enum(i32) {
    Enum3 = -999,
    Enum4 = 999,
};

const Union1 = union {
    int: i32,
    float: f32,
    bool: bool,
};

const TaggedUnion1 = union(enum) {
    int: i32,
    float: f32,
    bool: bool,
};

fn functionOne() void {}

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
    var tree_formatter = TreeFormatter.init(allocator, .{});
    var struct1: Struct1 = .{};
    try tree_formatter.formatValueWithId(w, struct1, "struct1");
}
