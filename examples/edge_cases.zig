//! Print only scenarios for values that are easy to get wrong.
//!
//! Every test here renders one value with `defaultFormatter()` so the output can
//! be inspected with:
//!
//! ```bash
//! zig build test -Dtest-filter="edge"
//! ```
//!
//! These tests catch crashes and compiler errors. The exact layout of these
//! values is locked down by the assertions in `golden_tests.zig`.

const std = @import("std");
const formatter = @import("tree-fmt").defaultFormatter();

// -- empty and zero sized ----------------------------------------------------

const EmptyStruct = struct {};

const Empties = struct {
    nothing: void = {},
    empty_array: [0]u8 = .{},
    empty_struct: EmptyStruct = .{},
    empty_slice: []const i32 = &.{},
    empty_vector: @Vector(0, i32) = .{},
    empty_tuple: struct {} = .{},
};

test "edge: empty and zero sized values" {
    try formatter.format(Empties{}, .{ .name = "empties" });

    // zero sized element types inside a list
    try formatter.format([3]EmptyStruct{ .{}, .{}, .{} }, .{ .name = "zero_sized_elems" });
    try formatter.format([0]EmptyStruct{}, .{ .name = "zero_sized_empty" });
}

// -- scalar leaves -----------------------------------------------------------

test "edge: integer and float widths" {
    try formatter.format(.{
        @as(u0, 0),
        @as(i7, -64),
        @as(u7, 127),
        @as(u128, 340282366920938463463374607431768211455),
        @as(i128, -170141183460469231731687303715884105728),
        @as(f16, 0.5),
        @as(f32, -1.25),
        @as(f64, 3.5),
        @as(f128, -2.5),
        true,
        @as(void, {}),
        null,
    }, .{ .name = "widths" });
}

// -- memory layouts ----------------------------------------------------------

const Packed = packed struct(u16) {
    lo: u4,
    hi: u4,
    flag: u1,
    pad: u7,
};

const ExternLayout = extern struct {
    tag: u8,
    value: u32,
};

const Misaligned = struct {
    byte: u8,
    word: u32 align(1),
};

test "edge: packed, extern and misaligned structs" {
    try formatter.format(Packed{ .lo = 1, .hi = 15, .flag = 1, .pad = 0 }, .{
        .name = "packed",
    });
    try formatter.format(ExternLayout{ .tag = 9, .value = 1234 }, .{
        .name = "extern",
    });
    try formatter.format(Misaligned{ .byte = 1, .word = 0xdeadbeef }, .{
        .name = "misaligned",
    });
}

// -- pointers ----------------------------------------------------------------

fn double(x: i32) i32 {
    return x * 2;
}

const Ptrs = struct {
    opaque_ptr: *anyopaque,
    many: [*]const u8,
    c_many: [*c]const u8,
    sentinel_many: [*:0]const u8,
    sentinel_slice: [:0]const u8,
    single: *const u32,
    misaligned_ptr: *align(1) const u32,
    fn_ptr: *const fn (i32) i32,
};

test "edge: pointer kinds" {
    var word: u32 = 0xAABBCCDD;
    var opaque_value: u32 = 7;
    const bytes = [_]u8{ 1, 2, 3, 4 };
    const ptrs = Ptrs{
        .opaque_ptr = @ptrCast(&opaque_value),
        .many = &bytes,
        .c_many = &bytes,
        .sentinel_many = "hi",
        .sentinel_slice = "hi",
        .single = &word,
        .misaligned_ptr = @ptrCast(&word),
        .fn_ptr = &double,
    };
    try formatter.format(ptrs, .{
        .name = "ptrs",
        .array_elem_limit = 2,
    });

    // a null C pointer prints the zero address instead of crashing
    const null_c_ptr: [*c]const u8 = null;
    try formatter.format(null_c_ptr, .{ .name = "null_c_ptr" });

    // optional pointers
    const no_ptr: ?*const u32 = null;
    try formatter.format(no_ptr, .{ .name = "no_ptr" });
}

test "edge: function values" {
    // a function body has no printable value, only the type name is printed
    try formatter.format(&double, .{ .name = "fn_ptr" });
    try formatter.format(@TypeOf(&double), .{ .name = "fn_ptr_type" });
}

// -- unions and enums --------------------------------------------------------

const Event = union(enum) {
    quit: void,
    key: u8,
    resize: struct { w: u16, h: u16 },
};

const Status = enum(i8) {
    failed = -1,
    ok = 0,
    unknown = 1,
    _,
};

test "edge: unions and enums" {
    try formatter.format(Event{ .quit = {} }, .{ .name = "event" });
    try formatter.format(Event{ .key = 'a' }, .{ .name = "event" });
    try formatter.format(Event{ .resize = .{ .w = 80, .h = 24 } }, .{ .name = "event" });

    try formatter.format(Status.failed, .{ .name = "status" });
    try formatter.format(Status.ok, .{ .name = "status" });
    // unnamed enum values fall back to the backing integer
    const unnamed: Status = @fromBackingInt(42);
    try formatter.format(unnamed, .{ .name = "status" });
}

// -- errors ------------------------------------------------------------------

const MyErrors = error{ Boom, Bang };

test "edge: error values and error sets" {
    const err: MyErrors = error.Bang;
    try formatter.format(err, .{ .name = "err" });

    const any_err: anyerror = error.OutOfMemory;
    try formatter.format(any_err, .{ .name = "any_err" });

    const void_payload: anyerror!void = error.Boom;
    try formatter.format(void_payload, .{ .name = "void_payload" });

    const ok_void: anyerror!void = {};
    try formatter.format(ok_void, .{ .name = "ok_void" });

    const ok_value: anyerror!u8 = 7;
    try formatter.format(ok_value, .{ .name = "ok_value" });

    // error union nested inside an optional, and vice versa
    const nested: ?anyerror!u8 = @as(anyerror!u8, error.Bang);
    try formatter.format(nested, .{ .name = "nested" });

    try formatter.format(@typeInfo(MyErrors), .{
        .name = "error set type info",
        .slice_elem_limit = 10,
    });
}

// -- nesting -----------------------------------------------------------------

const Leaf = struct { value: u8 };
const Level1 = struct { leaf: Leaf };
const Level2 = struct { one: Level1 };
const Level3 = struct { two: Level2, extra: ?*const Leaf = null };

test "edge: deep nesting" {
    try formatter.format(Level3{ .two = .{ .one = .{ .leaf = .{ .value = 42 } } } }, .{
        .name = "deep",
    });

    // nested arrays and slices of strings
    const grid = [2][3]u8{ .{ 1, 2, 3 }, .{ 4, 5, 6 } };
    try formatter.format(grid, .{
        .name = "grid",
        .print_u8_chars = false,
    });

    const words = [_][]const u8{ "alpha", "beta", "gamma" };
    try formatter.format(@as([]const []const u8, &words), .{
        .name = "words",
        .slice_elem_limit = 2,
    });
}

// -- wide structs ------------------------------------------------------------

const Wide = struct {
    f00: u8 = 0,
    f01: u16 = 1,
    f02: u32 = 2,
    f03: u64 = 3,
    f04: i8 = -4,
    f05: i16 = -5,
    f06: i32 = -6,
    f07: i64 = -7,
    f08: f32 = 8.5,
    f09: f64 = 9.5,
    f10: bool = true,
    f11: ?u8 = null,
    f12: [2]u8 = .{ 'a', 'b' },
    f13: []const u8 = "hi",
    f14: Color = .red,
    f15: union { a: u8 } = .{ .a = 0 },
};

const Color = enum { red, green };

test "edge: wide struct" {
    try formatter.format(Wide{}, .{
        .name = "wide",
        .ignore_u8_in_lists = true,
    });
}

// -- settings ----------------------------------------------------------------

const MalElem = struct { id: u64 };

test "edge: empty name and zeroed limits" {
    const value = .{ @as(u8, 1), @as(u8, 2), @as(u8, 3) };

    // an empty name falls back to the plain type name
    try formatter.format(value, .{ .name = "" });

    const gpa = std.heap.page_allocator;

    // every limit at zero hides all children but keeps the totals
    const array = [_]u8{ 1, 2, 3 };
    try formatter.format(array, .{
        .name = "array limit 0",
        .print_u8_chars = false,
        .array_elem_limit = 0,
    });

    try formatter.format(@as([]const u8, "abc"), .{
        .name = "slice limit 0",
        .print_u8_chars = false,
        .slice_elem_limit = 0,
    });

    const vector: @Vector(3, i32) = .{ 1, 2, 3 };
    try formatter.format(vector, .{
        .name = "vector limit 0",
        .vector_elem_limit = 0,
    });

    var map: std.array_hash_map.Auto(u8, u8) = .empty;
    defer map.deinit(gpa);
    try map.put(gpa, 1, 2);
    try formatter.format(map, .{
        .name = "map limit 0",
        .hash_map_entry_limit = 0,
    });

    var list: std.MultiArrayList(MalElem) = .{};
    defer list.deinit(gpa);
    try list.append(gpa, .{ .id = 1 });
    try formatter.format(list, .{
        .name = "multi array list limit 0",
        .multi_array_list_get_limit = 0,
    });

    // u8 lists can be collapsed to their string form
    const hello = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try formatter.format(hello, .{
        .name = "hello",
        .ignore_u8_in_lists = true,
    });
    try formatter.format(@as([]const u8, &hello), .{
        .name = "hello_slice",
        .ignore_u8_in_lists = true,
    });
}
