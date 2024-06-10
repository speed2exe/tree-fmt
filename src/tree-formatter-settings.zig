pub const TreeFormatterSettings = struct {
    // name of the root node
    name: []const u8 = ".",

    array_elem_limit: usize = 5,
    slice_elem_limit: usize = 5,
    vector_elem_limit: usize = 5,
    hash_map_entry_limit: usize = 5,
    multi_array_list_get_limit: usize = 5,

    /// if []u8 should be printed as a string
    /// affects Arrays, Slice, Vector
    print_u8_chars: bool = true,

    /// disables printing of []u8
    /// in lists (Array, Slice, Vector)
    ignore_u8_in_lists: bool = false,

    /// determines maximum repeat count for a unique pointer
    ptr_repeat_limit: usize = 1,

    /// limits the number of children to print
    type_print_limit: usize = 1, //TODO

    /// if allowed to format multi array list (std.MultiArrayList)
    format_multi_array_list: bool = true,

    /// if allowed to format hash map (std.HashMap)
    format_hash_map_unmanaged: bool = true,
};
