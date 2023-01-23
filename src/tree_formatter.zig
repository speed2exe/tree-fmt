pub const TreeFormatterSettings = @import("./tree_formatter_settings.zig").TreeFormatterSettings;

const std = @import("std");
const builtin = std.builtin;

const ansi_esc_code = @import("./ansi_esc_code.zig");
const Color = ansi_esc_code.Color;
const comptimeFmtInColor = ansi_esc_code.comptimeFmtInColor;
const comptimeInColor = ansi_esc_code.comptimeInColor;

const arrow = comptimeFmtInColor(Color.bright_black, "=>", .{});
const empty = " " ++ arrow ++ " {}";
const address_fmt = comptimeInColor(Color.blue, "@{x}");

pub const TreeFormatter = struct {
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
        try writer.print(comptimeInColor(Color.yellow, id), .{});
        try self.formatValueRecursive(&prefix, &counts_by_address, writer, arg);
        try writer.print("\n", .{});
    }

    fn formatValueRecursive(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
    ) anyerror!void { // TODO: handle unable to infer error set
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
                try self.formatFieldValues(prefix, counts_by_address, writer, arg, s);
            },
            .Array => |a| {
                if (a.child == u8 and self.settings.print_u8_chars) try writer.print(" {s}", .{arg});
                if (a.len == 0) {
                    try writer.writeAll(empty);
                    return;
                }

                try self.formatArrayValues(prefix, counts_by_address, writer, arg, a);
            },
            .Vector => |v| {
                if (v.child == u8 and self.settings.print_u8_chars) try writer.print(" {s}", .{arg});
                if (v.len == 0) {
                    try writer.writeAll(empty);
                    return;
                }

                try self.formatVectorValues(prefix, counts_by_address, writer, arg, v);
            },
            .Pointer => |p| {
                switch (p.size) {
                    .One => {
                        const addr: usize = @ptrToInt(arg);
                        try writer.print(" " ++ address_fmt, .{addr});

                        if (counts_by_address.getPtr(addr)) |counts_ptr| {
                            if (counts_ptr.* >= self.settings.ptr_repeat_limit) {
                                try writer.print(" ...(Repeat Limit Reached)", .{});
                                return;
                            }
                            try writer.print(" (Repeated)", .{});
                            counts_ptr.* += 1;
                        } else {
                            try counts_by_address.put(addr, 1);
                        }

                        // TODO: segment ignores unprintable values, verification is needed
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

                        try writer.print("\n{s}└─" ++ comptimeInColor(Color.yellow, ".*"), .{prefix.items});
                        const backup_len = prefix.items.len;
                        try prefix.appendSlice("  ");
                        try self.formatValueRecursive(prefix, counts_by_address, writer, arg.*);
                        prefix.shrinkRetainingCapacity(backup_len);
                    },
                    .Slice => {
                        try writer.print(" " ++ address_fmt, .{@ptrToInt(arg.ptr)});
                        if (p.child == u8 and self.settings.print_u8_chars) try writer.print(" \"{s}\"", .{arg});
                        if (arg.len == 0) return;
                        try self.formatSliceValues(prefix, counts_by_address, writer, arg);
                    },
                    .C => {
                        try writer.print(" " ++ address_fmt, .{@ptrToInt(arg)});
                        if (p.child == u8 and self.settings.print_u8_chars) try writer.print(" \"{s}\"", .{arg});
                        if (p.sentinel) |_| {
                            try self.formatSliceValues(prefix, counts_by_address, writer, std.mem.span(arg));
                        }
                    },
                    .Many => try writer.print(" " ++ address_fmt, .{@ptrToInt(arg)}),
                }
            },
            .Optional => {
                // TODO: compilation issues
                if (arg) |value| {
                    try writer.print(" \n{s}└─" ++ comptimeInColor(Color.yellow, ".?"), .{prefix.items});
                    const backup_len = prefix.items.len;
                    try prefix.appendSlice("  ");
                    try self.formatValueRecursive(prefix, counts_by_address, writer, value);
                    prefix.shrinkRetainingCapacity(backup_len);
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
                    try self.formatFieldValueAtIndex(prefix, counts_by_address, writer, arg, u, @enumToInt(arg));
                } else {
                    try self.formatFieldValues(prefix, counts_by_address, writer, arg, u);
                }
            },
            .Enum => try writer.print(" {s} {} ({d})", .{ arrow, arg, @enumToInt(arg) }),
            .Fn => try writer.print(" " ++ address_fmt, .{@ptrToInt(&arg)}),
            else => try writer.print(" {s} {any}", .{ arrow, arg }),
        }
    }

    inline fn formatArrayValues(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
        arg_type: anytype,
    ) !void {
        const backup_len = prefix.items.len;
        inline for (arg[0 .. arg_type.len - 1]) |item, i| {
            if (i == self.settings.array_print_limit - 1) {
                try writer.print("\n{s}...{d} item(s) not shown", .{ prefix.items, arg.len - self.settings.array_print_limit });
                break;
            }
            const index_colored = comptime comptimeFmtInColor(Color.yellow, "[{d}]", .{i});
            try writer.print("\n{s}├─" ++ index_colored, .{prefix.items});
            try prefix.appendSlice("│ ");
            try self.formatValueRecursive(prefix, counts_by_address, writer, item);
            prefix.shrinkRetainingCapacity(backup_len);
        }
        const index_colored = comptime comptimeFmtInColor(Color.yellow, "[{d}]", .{arg.len - 1});
        try writer.print("\n{s}└─" ++ index_colored, .{prefix.items});
        try prefix.appendSlice("  ");
        try self.formatValueRecursive(prefix, counts_by_address, writer, arg[arg_type.len - 1]);
    }

    inline fn formatVectorValues(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
        arg_type: anytype,
    ) !void {
        const index_fmt = comptime comptimeInColor(Color.yellow, "[{d}]");
        const backup_len = prefix.items.len;
        var i: usize = 0;
        while (i < arg_type.len - 1) : (i += 1) {
            if (i == self.settings.array_print_limit - 1) {
                try writer.print("\n{s}...{d} item(s) not shown", .{ prefix.items, arg_type.len - self.settings.array_print_limit });
                break;
            }
            const item = arg[i];
            try writer.print("\n{s}├─" ++ index_fmt, .{ prefix.items, i });
            try prefix.appendSlice("│ ");
            try self.formatValueRecursive(prefix, counts_by_address, writer, item);
            prefix.shrinkRetainingCapacity(backup_len);
        }
        try writer.print("\n{s}└─" ++ index_fmt, .{ prefix.items, i });
        try prefix.appendSlice("  ");
        try self.formatValueRecursive(prefix, counts_by_address, writer, arg[arg_type.len - 1]);
    }

    inline fn formatSliceValues(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
    ) !void {
        const index_fmt = comptime comptimeInColor(Color.yellow, "[{d}]");
        const backup_len = prefix.items.len;
        for (arg[0 .. arg.len - 1]) |item, i| {
            if (i == self.settings.array_print_limit - 1) {
                try writer.print("\n{s}...{d} item(s) not shown", .{ prefix.items, arg.len - self.settings.array_print_limit });
                break;
            }
            try writer.print("\n{s}├─" ++ index_fmt, .{ prefix.items, i });
            try prefix.appendSlice("│ ");
            try self.formatValueRecursive(prefix, counts_by_address, writer, item);
            prefix.shrinkRetainingCapacity(backup_len);
        }
        try writer.print("\n{s}└─" ++ index_fmt, .{ prefix.items, arg.len - 1 });
        try prefix.appendSlice("  ");
        try self.formatValueRecursive(prefix, counts_by_address, writer, arg[arg.len - 1]);
    }

    inline fn formatFieldValues(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
        comptime arg_type: anytype,
    ) !void {
        // Note:
        // This is set so that unions can be printed for all its values
        // This can be removed if we are able to determine the active union
        // field during ReleaseSafe and Debug builds,
        @setRuntimeSafety(false);

        const backup_len = prefix.items.len;
        const last_field_idx = arg_type.fields.len - 1;
        inline for (arg_type.fields[0..last_field_idx]) |field| {
            try writer.print("\n{s}├─" ++ comptimeInColor(Color.yellow, "." ++ field.name), .{prefix.items});
            try prefix.appendSlice("│ ");
            try self.formatValueRecursive(prefix, counts_by_address, writer, @field(arg, field.name));
            prefix.shrinkRetainingCapacity(backup_len);
        }
        const last_field_name = arg_type.fields[last_field_idx].name;
        try writer.print("\n{s}└─" ++ comptimeInColor(Color.yellow, "." ++ last_field_name), .{prefix.items});
        try prefix.appendSlice("  ");
        try self.formatValueRecursive(prefix, counts_by_address, writer, @field(arg, last_field_name));
        prefix.shrinkRetainingCapacity(backup_len);
    }

    inline fn formatFieldValueAtIndex(
        self: TreeFormatter,
        prefix: *std.ArrayList(u8),
        counts_by_address: *CountsByAddress,
        writer: anytype,
        arg: anytype,
        arg_type: anytype,
        idx: usize,
    ) !void {
        const backup_len = prefix.items.len;
        inline for (arg_type.fields) |field, i| {
            if (i == idx) {
                try writer.print("\n{s}└─" ++ comptimeInColor(Color.yellow, "." ++ field.name), .{prefix.items});
                try prefix.appendSlice("  ");
                try self.formatValueRecursive(prefix, counts_by_address, writer, @field(arg, field.name));
                prefix.shrinkRetainingCapacity(backup_len);
                return;
            }
        }
    }
};

inline fn isComptime(val: anytype) bool {
    return @typeInfo(@TypeOf(.{val})).Struct.fields[0].is_comptime;
}
