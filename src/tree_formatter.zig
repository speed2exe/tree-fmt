const std = @import("std");
const builtin = std.builtin;

const TreeFormatterSettings = @import("./tree_fmt.zig").TreeFormatterSettings;

const ansi_esc_code = @import("./ansi_esc_code.zig");
const Color = ansi_esc_code.Color;
const comptimeFmtInColor = ansi_esc_code.comptimeFmtInColor;
const comptimeInColor = ansi_esc_code.comptimeInColor;

pub const TreeFormatter = struct {
    const arrow = comptimeFmtInColor(Color.bright_black, "=>", .{});
    const empty = " " ++ arrow ++ " .{}";
    const address_fmt = comptimeInColor(Color.blue, "@{x}");
    const not_shown = comptimeInColor(Color.bright_black, " (not shown)");
    const indent_blank = "  ";
    const indent_bar = "│ ";
    const ptr_repeat_reached = comptimeInColor(Color.bright_black, " ...(Repeat Limit Reached)");
    const ptr_repeat = comptimeInColor(Color.bright_black, " (Repeated)");
    const pointer_dereference = comptimeInColor(Color.yellow, ".*");
    const optional_unwrap = comptimeInColor(Color.yellow, ".?");
    const ChildPrefix = enum {
        non_last,
        last,
        fn bytes(self: ChildPrefix) []const u8 {
            return switch (self) {
                .non_last => "├─",
                .last => "└─",
            };
        }
    };

    /// type to keep count of number of times address of the same value appear
    const CountsByAddress = std.AutoHashMap(usize, usize);

    settings: TreeFormatterSettings,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, settings: TreeFormatterSettings) TreeFormatter {
        return TreeFormatter{
            .allocator = allocator,
            .settings = settings,
        };
    }

    pub fn formatValue(self: TreeFormatter, writer: anytype, arg: anytype) !void {
        return self.formatValueWithId(writer, arg, ".");
    }

    pub fn formatValueWithId(self: TreeFormatter, writer: anytype, arg: anytype, comptime id: []const u8) !void {
        var prefix = std.ArrayList(u8).init(self.allocator);
        defer prefix.deinit();
        var counts_by_address = CountsByAddress.init(self.allocator);
        defer counts_by_address.deinit();
        var instance = Instance{
            .prefix = &prefix,
            .counts_by_address = &counts_by_address,
            .settings = self.settings,
        };
        try writer.print(comptimeInColor(Color.yellow, id), .{});
        try instance.formatValueRecursive(writer, arg);
        try writer.print("\n", .{});
    }

    const Instance = struct {
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        settings: TreeFormatterSettings,

        fn formatValueRecursive(self: *Instance, writer: anytype, arg: anytype) !void {
            const arg_type = @TypeOf(arg);
            try writer.print("{s}{s}", .{
                comptimeInColor(Color.bright_black, ": "),
                comptimeInColor(Color.cyan, @typeName(arg_type)),
            });

            switch (@typeInfo(arg_type)) {
                .Struct => |s| {
                    if (s.fields.len == 0) {
                        try writer.writeAll(empty);
                        return;
                    }
                    try self.formatFieldValues(writer, arg, s);
                },
                .Array => |a| {
                    if (a.child == u8 and self.settings.print_u8_chars) try writer.print(" {s}", .{arg});
                    if (a.len == 0) {
                        try writer.writeAll(empty);
                        return;
                    }

                    try self.formatArrayValues(writer, arg);
                },
                .Vector => |v| {
                    if (v.child == u8 and self.settings.print_u8_chars) try writer.print(" {s}", .{arg});
                    if (v.len == 0) {
                        try writer.writeAll(empty);
                        return;
                    }

                    try self.formatVectorValues(writer, arg, v);
                },
                .Pointer => |p| {
                    switch (p.size) {
                        .One => {
                            const addr: usize = @ptrToInt(arg);
                            try writer.print(" " ++ address_fmt, .{addr});

                            if (self.counts_by_address.getPtr(addr)) |counts_ptr| {
                                if (counts_ptr.* >= self.settings.ptr_repeat_limit) {
                                    try writer.writeAll(ptr_repeat_reached);
                                    return;
                                }
                                try writer.writeAll(ptr_repeat);
                                counts_ptr.* += 1;
                            } else {
                                try self.counts_by_address.put(addr, 1);
                            }

                            // TODO: segment ignores unprintable values, more verification is needed
                            if (addr == 0) return;
                            if (p.child == anyopaque) return;
                            const child_type_info = @typeInfo(p.child);
                            switch (child_type_info) {
                                .Fn => return,
                                else => {},
                            }
                            if (!isComptime(arg)) {
                                switch (child_type_info) {
                                    .Opaque => return,
                                    else => {},
                                }
                            }

                            try self.writeComptimeOnNewLine(writer, .last, pointer_dereference);
                            try self.formatValueRecursiveIndented(writer, .last, arg.*);
                        },
                        .Slice => {
                            try writer.print(" " ++ address_fmt, .{@ptrToInt(arg.ptr)});
                            if (p.child == u8 and self.settings.print_u8_chars) try writer.print(" \"{s}\"", .{arg});
                            if (arg.len == 0) {
                                try writer.writeAll(empty);
                            } else {
                                try self.formatSliceValues(writer, arg);
                            }
                        },
                        .Many, .C => {
                            try writer.print(" " ++ address_fmt, .{@ptrToInt(arg)});
                            _ = p.sentinel orelse return;
                            if (p.child == u8 and self.settings.print_u8_chars) try writer.print(" \"{s}\"", .{arg});
                            try self.formatSliceValues(writer, std.mem.span(arg));
                        },
                    }
                },
                .Optional => {
                    // TODO: compilation issues
                    if (arg) |value| {
                        try self.writeComptimeOnNewLine(writer, .last, optional_unwrap);
                        try self.formatValueRecursiveIndented(writer, .last, value);
                    } else {
                        try writer.print(" {s} null", .{arrow});
                    }
                },
                .Union => |u| {
                    if (u.fields.len == 0) {
                        try writer.writeAll(empty);
                        return;
                    }
                    if (u.tag_type) |_| {
                        try self.formatFieldValueAtIndex(writer, arg, u, @enumToInt(arg));
                    } else {
                        try self.formatFieldValues(writer, arg, u);
                    }
                },
                .Enum => try writer.print(" {s} {} ({d})", .{ arrow, arg, @enumToInt(arg) }),
                .Fn => try writer.print(" " ++ address_fmt, .{@ptrToInt(&arg)}),
                else => try writer.print(" {s} {any}", .{ arrow, arg }),
            }
        }

        inline fn formatValueRecursiveIndented(self: *Instance, writer: anytype, child_prefix: ChildPrefix, arg: anytype) anyerror!void {
            const backup_len = self.prefix.items.len;
            switch (child_prefix) {
                inline .non_last => try self.prefix.appendSlice(indent_bar),
                inline .last => try self.prefix.appendSlice(indent_blank),
            }
            try self.formatValueRecursive(writer, arg);
            self.prefix.shrinkRetainingCapacity(backup_len);
        }

        inline fn writeIndexingLimitMessage(self: *Instance, writer: anytype, len: usize) !void {
            try self.printOnNewLine(
                writer,
                .last,
                "..." ++ comptimeInColor(Color.bright_black, " (showed first {d} out of {d} items only)"),
                .{ self.settings.array_print_limit, len },
            );
        }

        inline fn formatArrayValues(self: *Instance, writer: anytype, array: anytype) !void {
            if (array.len > self.settings.array_print_limit) {
                inline for (array) |item, index| {
                    if (index >= self.settings.array_print_limit) break;
                    try self.formatIndexedValueComptime(writer, .non_last, item, index);
                }
                try self.writeIndexingLimitMessage(writer, array.len);
                return;
            }

            try self.formatArrayChildValues(writer, .non_last, array[0 .. array.len - 1]);
            try self.formatIndexedValueComptime(writer, .last, array[array.len - 1], array.len - 1);
        }

        inline fn formatArrayChildValues(self: *Instance, writer: anytype, child_prefix: ChildPrefix, args: anytype) !void {
            inline for (args) |item, index| {
                try self.formatIndexedValueComptime(writer, child_prefix, item, index);
            }
        }

        inline fn formatIndexedValueComptime(self: *Instance, writer: anytype, comptime child_prefix: ChildPrefix, item: anytype, comptime index: usize) !void {
            try self.writeComptimeOnNewLine(writer, child_prefix, comptime comptimeFmtInColor(Color.yellow, "[{d}]", .{index}));
            try self.formatValueRecursiveIndented(writer, child_prefix, item);
        }

        inline fn formatVectorValues(self: *Instance, writer: anytype, vector: anytype, vector_type: anytype) !void {
            if (vector_type.len > self.settings.array_print_limit) {
                comptime var i: usize = 0;
                inline while (i < vector_type.len) : (i += 1) {
                    if (i >= self.settings.array_print_limit) break;
                    try self.formatIndexedValueComptime(writer, .non_last, vector[i], i);
                }
                try self.writeIndexingLimitMessage(writer, vector_type.len);
                return;
            }

            comptime var i: usize = 0;
            inline while (i < vector_type.len - 1) : (i += 1)
                try self.formatIndexedValueComptime(writer, .non_last, vector[i], i);
            try self.formatIndexedValueComptime(writer, .last, vector[i], i);
        }

        inline fn formatIndexedValue(self: *Instance, writer: anytype, comptime child_prefix: ChildPrefix, item: anytype, index: usize) !void {
            try self.printOnNewLine(writer, child_prefix, comptime comptimeInColor(Color.yellow, "[{d}]"), .{index});
            try self.formatValueRecursiveIndented(writer, child_prefix, item);
        }

        inline fn formatSliceValues(self: *Instance, writer: anytype, slice: anytype) !void {
            if (slice.len > self.settings.array_print_limit) {
                for (slice[0..self.settings.array_print_limit]) |item, index|
                    try self.formatIndexedValue(writer, .non_last, item, index);
                try self.writeIndexingLimitMessage(writer, slice.len);
                return;
            }

            const last_index = slice.len - 1;
            for (slice[0..last_index]) |item, index|
                try self.formatIndexedValue(writer, .non_last, item, index);
            try self.formatIndexedValue(writer, .last, slice[last_index], last_index);
        }

        inline fn formatFieldValues(self: *Instance, writer: anytype, arg: anytype, comptime arg_type: anytype) !void {
            // Note:
            // This is set so that unions can be printed for all its values
            // This can be removed if we are able to determine the active union
            // field during ReleaseSafe and Debug builds,
            @setRuntimeSafety(false);

            inline for (arg_type.fields) |field, index| {
                const child_prefix = if (index == arg_type.fields.len - 1) .last else .non_last;
                try self.writeComptimeOnNewLine(writer, child_prefix, comptimeInColor(Color.yellow, "." ++ field.name));
                try self.formatValueRecursiveIndented(writer, child_prefix, @field(arg, field.name));
            }
        }

        inline fn formatFieldValueAtIndex(self: *Instance, writer: anytype, arg: anytype, arg_type: anytype, target_index: usize) !void {
            inline for (arg_type.fields) |field, index| {
                if (index == target_index) {
                    try self.writeComptimeOnNewLine(writer, .last, comptimeInColor(Color.yellow, "." ++ field.name));
                    try self.formatValueRecursiveIndented(writer, .last, @field(arg, field.name));
                    return;
                }
            }
        }

        inline fn printOnNewLine(self: *Instance, writer: anytype, child_prefix: ChildPrefix, comptime format: []const u8, args: anytype) !void {
            try writer.print("\n{s}" ++ child_prefix.bytes(), .{self.prefix.items});
            try writer.print(format, args);
        }

        inline fn writeComptimeOnNewLine(self: *Instance, writer: anytype, child_prefix: ChildPrefix, comptime bytes: []const u8) !void {
            try writer.print("\n{s}" ++ child_prefix.bytes() ++ bytes, .{self.prefix.items});
        }
    };
};

inline fn isComptime(val: anytype) bool {
    return @typeInfo(@TypeOf(.{val})).Struct.fields[0].is_comptime;
}
