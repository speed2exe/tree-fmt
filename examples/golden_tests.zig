//! Assertion based tests.
//!
//! The tests in `examples.zig` and `edge_cases.zig` only print their output, so
//! they catch crashes but not regressions in layout. The tests here render into
//! a buffer and compare against an expected string.
//!
//! Rendering is made deterministic first:
//! - ANSI color escapes are stripped
//! - pointer addresses are replaced with `@ADDR`
//!
//! Run with: `zig build test -Dtest-filter="golden"`

const std = @import("std");
const tree_fmt = @import("tree-fmt");

const TreeFormatterSettings = tree_fmt.TreeFormatterSettings;

/// Writer that captures everything the formatter prints.
const Capture = struct {
    list: *std.ArrayList(u8),
    gpa: std.mem.Allocator,

    pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
        try self.list.print(self.gpa, fmt, args);
    }

    pub fn writeAll(self: @This(), bytes: []const u8) !void {
        try self.list.appendSlice(self.gpa, bytes);
    }
};

fn isIdentChar(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

/// Removes ANSI color escapes (ESC '[' <digits/;> <letter>).
fn stripAnsi(gpa: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);

    var i: usize = 0;
    while (i < raw.len) {
        if (raw[i] == 0x1b and i + 1 < raw.len and raw[i + 1] == '[') {
            i += 2;
            while (i < raw.len and (raw[i] == ';' or std.ascii.isDigit(raw[i]))) : (i += 1) {}
            if (i < raw.len) i += 1; // final byte of the sequence
            continue;
        }
        try out.append(gpa, raw[i]);
        i += 1;
    }

    return out.toOwnedSlice(gpa);
}

/// Replaces pointer addresses (`@1a2b3c4d`) with `@ADDR`.
///
/// A `@` followed by hex digits is only treated as an address when it is not
/// part of a longer identifier, so `@Vector(4, u8)` and `@fromBackingInt(200)`
/// are left alone.
fn normalizeAddresses(gpa: std.mem.Allocator, text: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '@') {
            var end = i + 1;
            while (end < text.len and std.ascii.isHex(text[end])) : (end += 1) {}
            if (end > i + 1 and (end == text.len or !isIdentChar(text[end]))) {
                try out.appendSlice(gpa, "@ADDR");
                i = end;
                continue;
            }
        }
        try out.append(gpa, text[i]);
        i += 1;
    }

    return out.toOwnedSlice(gpa);
}

fn renderRaw(gpa: std.mem.Allocator, value: anytype, settings: TreeFormatterSettings) ![]u8 {
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(gpa);

    const f = tree_fmt.treeFormatter(gpa, Capture{ .list = &raw, .gpa = gpa });
    try f.format(value, settings);

    return stripAnsi(gpa, raw.items);
}

/// Renders `value` and returns the normalized (color and address free) tree.
fn render(gpa: std.mem.Allocator, value: anytype, settings: TreeFormatterSettings) ![]u8 {
    const stripped = try renderRaw(gpa, value, settings);
    defer gpa.free(stripped);

    return normalizeAddresses(gpa, stripped);
}

fn expectTree(expected: []const u8, value: anytype, settings: TreeFormatterSettings) !void {
    const gpa = std.testing.allocator;
    const actual = try render(gpa, value, settings);
    defer gpa.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

fn countOf(haystack: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, haystack, needle);
}

/// Asserts that exactly `shown` entries are printed and, when entries were
/// dropped, that the trailing limit message is present exactly once.
fn expectShownEntries(
    value: anytype,
    settings: TreeFormatterSettings,
    shown: usize,
    total: usize,
) !void {
    const gpa = std.testing.allocator;
    const out = try render(gpa, value, settings);
    defer gpa.free(out);

    try std.testing.expectEqual(shown, countOf(out, ".next(): "));

    const limit_message = try std.fmt.allocPrint(
        gpa,
        "... (showed first {d} out of {d} items only)",
        .{ shown, total },
    );
    defer gpa.free(limit_message);

    if (shown < total) {
        try std.testing.expectEqual(@as(usize, 1), countOf(out, limit_message));
    } else {
        try std.testing.expectEqual(@as(usize, 0), countOf(out, "... (showed first "));
    }
}

// -- types shared by the tests ------------------------------------------------
// These are declared at file scope so that `@typeName` output is stable.

const Small = struct {
    a: u8 = 1,
    b: ?u8 = null,
    c: [2]i32 = .{ 1, -1 },
};

const Rect = struct { w: u16, h: u16 };

const Shape = union(enum) {
    circle: f32,
    rect: Rect,
};

const Refs = struct {
    first: *const i32,
    second: *const i32,
    third: *const i32,
};

const Person = struct { id: u64, age: u8 };

const EmptyStruct = struct {};

const Empty = struct {
    zero_array: [0]u8 = .{},
    empty_struct: EmptyStruct = .{},
    empty_slice: []const i32 = &.{},
    zero_vector: @Vector(0, i32) = .{},
};

const Color = enum(u8) { red = 3, green = 7 };

const Signed = enum(i32) { neg = -999, pos = 999 };

const NonExhaustive = enum(u8) { a = 1, _ };

const Packed = packed struct(u8) { lo: u4, hi: u4 };

const Misaligned = struct { byte: u8, word: u32 align(1) };

const OpaquePtrs = struct {
    opaque_ptr: *anyopaque,
    many: [*]const u8,
};

const MyErrors = error{ Boom, Bang };

// -- helpers -----------------------------------------------------------------

test "golden: helpers strip ansi and normalize addresses" {
    const gpa = std.testing.allocator;

    const raw = "\x1b[33m.\x1b[m: \x1b[36mu8\x1b[m \x1b[90m=>\x1b[m 1\n";
    const stripped = try stripAnsi(gpa, raw);
    defer gpa.free(stripped);
    try std.testing.expectEqualStrings(".: u8 => 1\n", stripped);

    // addresses of every length are replaced
    const addresses = try normalizeAddresses(gpa, "p: *u8 @1, q: *u8 @104ebf4f4\n");
    defer gpa.free(addresses);
    try std.testing.expectEqualStrings("p: *u8 @ADDR, q: *u8 @ADDR\n", addresses);

    // builtin names that start with a hex letter are left untouched
    const builtins = try normalizeAddresses(gpa, "@Vector(4, u8) @fromBackingInt(200) @TypeOf(null) @field\n");
    defer gpa.free(builtins);
    try std.testing.expectEqualStrings("@Vector(4, u8) @fromBackingInt(200) @TypeOf(null) @field\n", builtins);
}

// -- structs and unions ------------------------------------------------------

test "golden: struct with default and named root" {
    try expectTree(
        \\.: golden_tests.Small
        \\├─.a: u8 => 1
        \\├─.b: ?u8 => null
        \\└─.c: [2]i32
        \\  ├─[0]: i32 => 1
        \\  └─[1]: i32 => -1
        \\
    , Small{}, .{});

    try expectTree(
        \\small: golden_tests.Small
        \\├─.a: u8 => 1
        \\├─.b: ?u8
        \\│ └─.?: u8 => 7
        \\└─.c: [2]i32
        \\  ├─[0]: i32 => 1
        \\  └─[1]: i32 => -1
        \\
    , Small{ .b = 7 }, .{ .name = "small" });
}

test "golden: tagged union prints only the active field" {
    try expectTree(
        \\.: golden_tests.Shape
        \\└─.rect: golden_tests.Rect
        \\  ├─.w: u16 => 3
        \\  └─.h: u16 => 4
        \\
    , Shape{ .rect = .{ .w = 3, .h = 4 } }, .{});

    try expectTree(
        \\.: golden_tests.Shape
        \\└─.circle: f32 => 1.5
        \\
    , Shape{ .circle = 1.5 }, .{});
}

test "golden: enum values including negative backing ints" {
    try expectTree(".: golden_tests.Color => .green (7)\n", Color.green, .{});
    try expectTree(".: golden_tests.Signed => .neg (-999)\n", Signed.neg, .{});

    // enum values without a name fall back to the tag repr
    const unnamed: NonExhaustive = @fromBackingInt(200);
    try expectTree(".: golden_tests.NonExhaustive => @fromBackingInt(200) (200)\n", unnamed, .{});
}

test "golden: empty containers print an empty node" {
    try expectTree(
        \\.: golden_tests.Empty
        \\├─.zero_array: [0]u8 "" => .{}
        \\├─.empty_struct: golden_tests.EmptyStruct => .{}
        \\├─.empty_slice: []const i32 @ADDR => .{}
        \\└─.zero_vector: @Vector(0, i32) => .{}
        \\
    , Empty{}, .{});
}

test "golden: scalar leaves" {
    try expectTree(
        \\.: struct { comptime u128 = 1, comptime f16 = 0.5, comptime i64 = -1234, comptime u0 = 0, comptime void = {}, comptime @TypeOf(null) = null }
        \\├─.0: u128 => 1
        \\├─.1: f16 => 0.5
        \\├─.2: i64 => -1234
        \\├─.3: u0 => 0
        \\├─.4: void => void
        \\└─.5: @TypeOf(null) => null
        \\
    , .{ @as(u128, 1), @as(f16, 0.5), @as(i64, -1234), @as(u0, 0), {}, null }, .{});
}

// -- optionals and errors ----------------------------------------------------

test "golden: optional and error union payloads" {
    try expectTree(
        \\.: ??u8
        \\└─.?: ?u8 => null
        \\
    , @as(??u8, @as(?u8, null)), .{});

    try expectTree(".: anyerror!u8 => error.Boom\n", @as(anyerror!u8, error.Boom), .{});
    try expectTree(".: anyerror!u8: u8 => 5\n", @as(anyerror!u8, 5), .{});
}

// -- lists and limits --------------------------------------------------------

test "golden: array values and zero limit" {
    try expectTree(
        \\.: [3]u8
        \\├─[0]: u8 => 1
        \\├─[1]: u8 => 2
        \\└─[2]: u8 => 3
        \\
    , [_]u8{ 1, 2, 3 }, .{ .print_u8_chars = false });

    // a zero limit hides every element and keeps only the limit message
    try expectTree(
        \\.: [3]u8
        \\└─... (showed first 0 out of 3 items only)
        \\
    , [_]u8{ 1, 2, 3 }, .{ .print_u8_chars = false, .array_elem_limit = 0 });
}

test "golden: slice limit truncates and reports totals" {
    try expectTree(
        \\.: []const i32 @ADDR
        \\├─[0]: i32 => 7
        \\├─[1]: i32 => 8
        \\└─... (showed first 2 out of 3 items only)
        \\
    , @as([]const i32, &.{ 7, 8, 9 }), .{ .slice_elem_limit = 2 });
}

test "golden: u8 char printing modes" {
    // slice: address + string, then the bytes
    try expectTree(
        \\.: []const u8 @ADDR "hi"
        \\├─[0]: u8 => 104
        \\└─[1]: u8 => 105
        \\
    , @as([]const u8, "hi"), .{});

    // print_u8_chars = false drops the string form
    try expectTree(
        \\.: []const u8 @ADDR
        \\├─[0]: u8 => 104
        \\└─[1]: u8 => 105
        \\
    , @as([]const u8, "hi"), .{ .print_u8_chars = false });

    // vectors print their bytes too (regression: `{s}` is not valid for vectors)
    try expectTree(
        \\.: @Vector(4, u8) "abcd"
        \\├─[0]: u8 => 97
        \\├─[1]: u8 => 98
        \\├─[2]: u8 => 99
        \\└─[3]: u8 => 100
        \\
    , @as(@Vector(4, u8), "abcd".*), .{});

    // ignore_u8_in_lists drops the elements, keeping only the string
    try expectTree(".: @Vector(4, u8) \"abcd\"\n", @as(@Vector(4, u8), "abcd".*), .{
        .ignore_u8_in_lists = true,
    });
}

test "golden: vector limit truncates and reports totals" {
    try expectTree(
        \\.: @Vector(4, i32)
        \\├─[0]: i32 => 1
        \\├─[1]: i32 => 2
        \\└─... (showed first 2 out of 4 items only)
        \\
    , @as(@Vector(4, i32), .{ 1, 2, 3, 4 }), .{ .vector_elem_limit = 2 });
}

// -- pointers ----------------------------------------------------------------

test "golden: repeated pointers are truncated by the repeat limit" {
    var x: i32 = 42;
    const refs = Refs{ .first = &x, .second = &x, .third = &x };

    try expectTree(
        \\.: golden_tests.Refs
        \\├─.first: *const i32 @ADDR
        \\│ └─.*: i32 => 42
        \\├─.second: *const i32 @ADDR ...(Repeat Limit Reached)
        \\└─.third: *const i32 @ADDR ...(Repeat Limit Reached)
        \\
    , refs, .{});

    // a repeat limit of 0 behaves like 1: the pointer is expanded once
    try expectTree(
        \\.: golden_tests.Refs
        \\├─.first: *const i32 @ADDR
        \\│ └─.*: i32 => 42
        \\├─.second: *const i32 @ADDR ...(Repeat Limit Reached)
        \\└─.third: *const i32 @ADDR ...(Repeat Limit Reached)
        \\
    , refs, .{ .ptr_repeat_limit = 0 });

    try expectTree(
        \\.: golden_tests.Refs
        \\├─.first: *const i32 @ADDR
        \\│ └─.*: i32 => 42
        \\├─.second: *const i32 @ADDR (Repeated)
        \\│ └─.*: i32 => 42
        \\└─.third: *const i32 @ADDR (Repeated)
        \\  └─.*: i32 => 42
        \\
    , refs, .{ .ptr_repeat_limit = 5 });
}

test "golden: null C pointer prints a zero address" {
    const gpa = std.testing.allocator;
    const null_c_ptr: [*c]const u8 = null;
    // uses the un-normalized render so the zero address stays visible
    const out = try renderRaw(gpa, null_c_ptr, .{});
    defer gpa.free(out);
    try std.testing.expectEqualStrings(".: [*c]const u8 @0\n", out);
}

// -- memory layouts ----------------------------------------------------------

test "golden: packed and misaligned structs" {
    try expectTree(
        \\.: golden_tests.Packed
        \\├─.lo: u4 => 1
        \\└─.hi: u4 => 15
        \\
    , Packed{ .lo = 1, .hi = 15 }, .{});

    // fields are printed by value even when they are not naturally aligned
    try expectTree(
        \\.: golden_tests.Misaligned
        \\├─.byte: u8 => 1
        \\└─.word: u32 => 4294967295
        \\
    , Misaligned{ .byte = 1, .word = 0xffffffff }, .{});
}

test "golden: zero sized element types" {
    try expectTree(
        \\.: [2]golden_tests.EmptyStruct
        \\├─[0]: golden_tests.EmptyStruct => .{}
        \\└─[1]: golden_tests.EmptyStruct => .{}
        \\
    , [2]EmptyStruct{ .{}, .{} }, .{});

    try expectTree(
        \\.: [0]golden_tests.EmptyStruct => .{}
        \\
    , [0]EmptyStruct{}, .{});
}

test "golden: pointers with no printable pointee" {
    var value: u32 = 7;
    const bytes = [_]u8{ 1, 2, 3 };
    const ptrs = OpaquePtrs{ .opaque_ptr = @ptrCast(&value), .many = &bytes };

    // `*anyopaque` and a sentinel-less `[*]` print the address only
    try expectTree(
        \\.: golden_tests.OpaquePtrs
        \\├─.opaque_ptr: *anyopaque @ADDR
        \\└─.many: [*]const u8 @ADDR
        \\
    , ptrs, .{});
}

test "golden: error values keep their error set name" {
    // the set name is printed in declaration order independent (sorted) form
    try expectTree(".: error{Bang,Boom} => error.Bang\n", @as(MyErrors, error.Bang), .{});
    try expectTree(".: anyerror => error.OutOfMemory\n", @as(anyerror, error.OutOfMemory), .{});

    // an `ok` payload of an error union is inlined after the type name, an
    // `err` payload becomes the value of the node
    try expectTree(".: anyerror!void: void => void\n", @as(anyerror!void, {}), .{});
    try expectTree(".: anyerror!void => error.Boom\n", @as(anyerror!void, error.Boom), .{});
}

// -- hash maps ---------------------------------------------------------------

test "golden: hash map entry limit shows exactly N entries" {
    const gpa = std.testing.allocator;
    var map: std.array_hash_map.Auto(u8, u8) = .empty;
    defer map.deinit(gpa);
    for ([_]u8{ 1, 2, 3 }) |k| try map.put(gpa, k, k * 10);

    // regression: `>` used to print `limit + 1` entries, so a limit of 0 still
    // printed one entry
    try expectShownEntries(map, .{ .name = "m", .hash_map_entry_limit = 0 }, 0, 3);
    try expectShownEntries(map, .{ .name = "m", .hash_map_entry_limit = 1 }, 1, 3);
    try expectShownEntries(map, .{ .name = "m", .hash_map_entry_limit = 2 }, 2, 3);
    try expectShownEntries(map, .{ .name = "m", .hash_map_entry_limit = 3 }, 3, 3);
    try expectShownEntries(map, .{ .name = "m", .hash_map_entry_limit = 10 }, 3, 3);
}

test "golden: empty hash map has no entries" {
    const gpa = std.testing.allocator;
    var map: std.array_hash_map.Auto(u8, u8) = .empty;
    defer map.deinit(gpa);

    const out = try render(gpa, map, .{ .name = "m" });
    defer gpa.free(out);

    // `.iterator()` is still printed, but without children
    try std.testing.expectEqual(@as(usize, 1), countOf(out, ".iterator()\n"));
    try std.testing.expectEqual(@as(usize, 0), countOf(out, ".next(): "));
    try std.testing.expectEqual(@as(usize, 0), countOf(out, "... (showed first "));
}

test "golden: hash map formatting can be disabled" {
    const gpa = std.testing.allocator;
    var map: std.array_hash_map.Auto(u8, u8) = .empty;
    defer map.deinit(gpa);
    try map.put(gpa, 1, 10);

    const out = try render(gpa, map, .{ .name = "m", .format_hash_map_unmanaged = false });
    defer gpa.free(out);

    try std.testing.expectEqual(@as(usize, 0), countOf(out, ".iterator()"));
    try std.testing.expectEqual(@as(usize, 0), countOf(out, ".next(): "));
    // the raw fields are still printed
    try std.testing.expectEqual(@as(usize, 1), countOf(out, ".entries: "));
}

// -- multi array list --------------------------------------------------------

test "golden: multi array list get limit" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Person) = .{};
    defer list.deinit(gpa);
    try list.append(gpa, .{ .id = 1, .age = 2 });
    try list.append(gpa, .{ .id = 3, .age = 4 });

    for ([_]usize{ 0, 1, 2, 5 }) |limit| {
        const out = try render(gpa, list, .{
            .name = "m",
            .print_u8_chars = false,
            .multi_array_list_get_limit = limit,
        });
        defer gpa.free(out);

        // every `.get()` entry prints the element type name
        const shown = @min(limit, list.len);
        try std.testing.expectEqual(shown, countOf(out, "): golden_tests.Person\n"));

        if (shown < list.len) {
            const msg = try std.fmt.allocPrint(
                gpa,
                "... (showed first {d} out of {d} items only)",
                .{ shown, list.len },
            );
            defer gpa.free(msg);
            try std.testing.expectEqual(@as(usize, 1), countOf(out, msg));
        } else {
            try std.testing.expectEqual(@as(usize, 0), countOf(out, "... (showed first "));
        }
    }
}

test "golden: empty multi array list" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Person) = .{};
    defer list.deinit(gpa);

    const out = try render(gpa, list, .{ .name = "m", .print_u8_chars = false });
    defer gpa.free(out);

    // `.get()` is printed as a childless node, and there is no limit message
    try std.testing.expectEqual(@as(usize, 1), countOf(out, ".get()\n"));
    try std.testing.expectEqual(@as(usize, 0), countOf(out, "... (showed first "));
    try std.testing.expectEqual(@as(usize, 1), countOf(out, ".len: usize => 0"));
}

test "golden: multi array list formatting can be disabled" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Person) = .{};
    defer list.deinit(gpa);
    try list.append(gpa, .{ .id = 1, .age = 2 });

    const out = try render(gpa, list, .{ .name = "m", .format_multi_array_list = false });
    defer gpa.free(out);

    try std.testing.expectEqual(@as(usize, 0), countOf(out, ".slice()"));
    try std.testing.expectEqual(@as(usize, 0), countOf(out, ".get()"));
    try std.testing.expectEqual(@as(usize, 1), countOf(out, ".bytes: "));
}
