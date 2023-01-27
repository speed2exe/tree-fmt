# Zig Tree Formattar
- Tree-like formatter for Zig Programming Language
- This library pretty prints out Zig Values for your debugging needs.
- This library is in continuous development, if you face any issue with formatting, kindly open an issue.

![Screenshot](./images/screenshot.png)

## Objective
- Provide a tree-like visual representation of a Zig value

## Usage
- Use `git submodule` or copy the `src` folder into your project directly. This
  project will be packaged properly once the official package manager is released.
- Below shows a simple example of how to use this library.

```zig
const std = @import("std");

// add imports here
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

pub fn main() !void {
    // initialize your allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("leaked memory!");
        }
    }

    // initialize TreeFormatter
    var tree_formatter = TreeFormatter.init(allocator, .{});

    // initialize a writer (std.io.Writer)
    var w = std.io.getStdOut().writer();

    // initialize your value
    var sentinel_array: [*:0]const u8 = "hello world";

    // call the method with writer and value
    try tree_formatter.formatValueWithId(w, sentinel_array, "sentinel_array");
}
```

- Example output:
```
sentinel_array: [*:0]const u8 @20a71e "hello world"
├─[0]: u8 => 104
├─[1]: u8 => 101
├─[2]: u8 => 108
├─[3]: u8 => 108
├─[4]: u8 => 111
├─[5]: u8 => 32
├─[6]: u8 => 119
├─[7]: u8 => 111
├─[8]: u8 => 114
├─[9]: u8 => 108
└─... (showed first 10 out of 11 items only)
```

- You can find other examples in the root directory. To run the examples, use
  `zig run examples_<example_name>.zig`

## Example
- `std.ArrayList(u8)`
```
.: array_list.ArrayListAligned(u8,null)
├─.items: []u8 @7efcc912f000
│ ├─[0]: u8 => 0
│ ├─[1]: u8 => 1
│ ├─[2]: u8 => 2
│ ├─[3]: u8 => 3
│ ├─[4]: u8 => 4
│ └─... (showed first 5 out of 100 items only)
├─.capacity: usize => 105
└─.allocator: mem.Allocator
  ├─.ptr: *anyopaque @7fffadc5b3d8
  └─.vtable: *const mem.Allocator.VTable @202a38
    └─.*: mem.Allocator.VTable
      ├─.alloc: *const fn(*anyopaque, usize, u8, usize) ?[*]u8 @238e00
      ├─.resize: *const fn(*anyopaque, []u8, u8, usize, usize) bool @2393c0
      └─.free: *const fn(*anyopaque, []u8, u8, usize) void @23a2d0
```

- `std.AutoHashMap(u8, u8)`
```
map: hash_map.HashMap(u8,u8,hash_map.AutoContext(u8),80)
├─.unmanaged: hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80)
│ ├─.metadata: ?[*]hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80).Metadata
│ │ └─.?: [*]hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80).Metadata @7f5ea0bc7018
│ ├─.size: u32 => 100
│ └─.available: u32 => 2
├─.allocator: mem.Allocator
│ ├─.ptr: *anyopaque @7ffe61d91c30
│ └─.vtable: *const mem.Allocator.VTable @2033e0
│   └─.*: mem.Allocator.VTable
│     ├─.alloc: *const fn(*anyopaque, usize, u8, usize) ?[*]u8 @239470
│     ├─.resize: *const fn(*anyopaque, []u8, u8, usize, usize) bool @239a30
│     └─.free: *const fn(*anyopaque, []u8, u8, usize) void @23a940
└─.ctx: hash_map.AutoContext(u8) => .{}
```

- `std.MultiArrayList...` (see `example_multi_array_list.zig`)
```
multi_array_list: multi_array_list.MultiArrayList(example_multi_array_list.Person)
├─.slice(): multi_array_list.MultiArrayList(example_multi_array_list.Person).Slice
│ ├─.items
│ │ ├─(.id): []u64 @7f410ae8a000
│ │ │ ├─[0]: u64 => 0
│ │ │ ├─[1]: u64 => 1
│ │ │ ├─[2]: u64 => 2
│ │ │ ├─[3]: u64 => 3
│ │ │ ├─[4]: u64 => 4
│ │ │ └─... (showed first 5 out of 7 items only)
│ ├─(.age): []u8 @7f410ae8a080
│ │ ├─[0]: u8 => 0
│ │ ├─[1]: u8 => 1
│ │ ├─[2]: u8 => 2
│ │ ├─[3]: u8 => 3
│ │ ├─[4]: u8 => 4
│ │ └─... (showed first 5 out of 7 items only)
│ └─(.car): []example_multi_array_list.Car @7f410ae8a040
│   ├─[0]: example_multi_array_list.Car
│   │ └─.license_plate_no: u64 => 555
│   ├─[1]: example_multi_array_list.Car
│   │ └─.license_plate_no: u64 => 555
│   ├─[2]: example_multi_array_list.Car
│   │ └─.license_plate_no: u64 => 555
│   ├─[3]: example_multi_array_list.Car
│   │ └─.license_plate_no: u64 => 555
│   ├─[4]: example_multi_array_list.Car
│   │ └─.license_plate_no: u64 => 555
│   └─... (showed first 5 out of 7 items only)
├─.get
│ ├─(0): example_multi_array_list.Person
│ │ ├─.id: u64 => 0
│ │ ├─.age: u8 => 0
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ ├─(1): example_multi_array_list.Person
│ │ ├─.id: u64 => 1
│ │ ├─.age: u8 => 1
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ ├─(2): example_multi_array_list.Person
│ │ ├─.id: u64 => 2
│ │ ├─.age: u8 => 2
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ ├─(3): example_multi_array_list.Person
│ │ ├─.id: u64 => 3
│ │ ├─.age: u8 => 3
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ ├─(4): example_multi_array_list.Person
│ │ ├─.id: u64 => 4
│ │ ├─.age: u8 => 4
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ ├─(5): example_multi_array_list.Person
│ │ ├─.id: u64 => 5
│ │ ├─.age: u8 => 5
│ │ └─.car: example_multi_array_list.Car
│ │   └─.license_plate_no: u64 => 555
│ └─... (showed first 5 out of 7 items only)
├─.bytes: [*]align(8) u8 @7f410ae8a000
├─.len: usize => 7
└─.capacity: usize => 8
```

- `multi_array_list.MultiArrayList(zig.Ast.TokenList__struct_4206).Slice`
```
ast: multi_array_list.MultiArrayList(zig.Ast.TokenList__struct_4206).Slice
├─.toMultiArrayList(): multi_array_list.MultiArrayList(zig.Ast.TokenList__struct_4206)
│ ├─.slice(): multi_array_list.MultiArrayList(zig.Ast.TokenList__struct_4206).Slice
│ │ └─.items
│ │   ├─(.tag): []zig.tokenizer.Token.Tag @7f95660d8098
│ │   │ ├─[0]: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.keyword_const (86)
│ │   │ ├─[1]: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.identifier (2)
│ │   │ ├─[2]: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.equal (12)
│ │   │ ├─[3]: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.builtin (7)
│ │   │ ├─[4]: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.l_paren (16)
│ │   │ └─... (showed first 5 out of 31 items only)
│ │   └─(.start): []u32 @7f95660d8000
│ │     ├─[0]: u32 => 1
│ │     ├─[1]: u32 => 7
│ │     ├─[2]: u32 => 11
│ │     ├─[3]: u32 => 13
│ │     ├─[4]: u32 => 20
│ │     └─... (showed first 5 out of 31 items only)
│ ├─.get
│ │ ├─(0): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.keyword_const (86)
│ │ │ └─.start: u32 => 1
│ │ ├─(1): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.identifier (2)
│ │ │ └─.start: u32 => 7
│ │ ├─(2): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.equal (12)
│ │ │ └─.start: u32 => 11
│ │ ├─(3): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.builtin (7)
│ │ │ └─.start: u32 => 13
│ │ ├─(4): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.l_paren (16)
│ │ │ └─.start: u32 => 20
│ │ ├─(5): zig.Ast.TokenList__struct_4206
│ │ │ ├─.tag: zig.tokenizer.Token.Tag => zig.tokenizer.Token.Tag.string_literal (3)
│ │ │ └─.start: u32 => 21
│ │ └─... (showed first 5 out of 31 items only)
│ ├─.bytes: [*]align(4) u8 @7f95660d8000
│ ├─.len: usize => 31
│ └─.capacity: usize => 38
├─.ptrs: [2][*]u8
│ ├─[0]: [*]u8 @7f95660d8098
│ └─[1]: [*]u8 @7f95660d8000
├─.len: usize => 31
└─.capacity: usize => 38
```
