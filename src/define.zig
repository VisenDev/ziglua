const std = @import("std");

const String = std.ArrayList(u8);
const Database = std.StringHashMap(void);

pub const DefineState = struct {
    allocator: std.mem.Allocator,
    database: Database,
    definitions: std.ArrayList(String),

    pub fn init(alloc: std.mem.Allocator) DefineState {
        return DefineState{
            .allocator = alloc,
            .database = Database.init(alloc),
            .definitions = std.ArrayList(String).init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.definitions.items) |def| {
            def.deinit();
        }
        defer self.database.deinit();
        defer self.definitions.deinit();
    }
};

pub fn define(
    alloc: std.mem.Allocator,
    absolute_output_path: []const u8,
    comptime to_define: []const type,
) !void {
    var state = DefineState.init(alloc);
    defer state.deinit();

    inline for (to_define) |T| {
        _ = try addClass(&state, T);
    }

    var file = try std.fs.createFileAbsolute(absolute_output_path, .{});
    defer file.close();

    try file.seekTo(0);
    try file.writeAll(file_header);

    for (state.definitions.items) |def| {
        try file.writeAll(def.items);
        try file.writeAll("\n");
    }

    try file.setEndPos(try file.getPos());
}

const file_header: []const u8 =
    \\---@meta
    \\
    \\--- This is an autogenerated file,
    \\--- Do not modify
    \\
    \\
;

fn name(comptime T: type) []const u8 {
    return (comptime std.fs.path.extension(@typeName(T)))[1..];
}

fn addEnum(
    state: *DefineState,
    comptime T: type,
) !void {
    if (state.database.contains(@typeName(T)) == false) {
        try state.database.put(@typeName(T), {});
        try state.definitions.append(String.init(state.allocator));
        const index = state.definitions.items.len - 1;

        try state.definitions.items[index].appendSlice("---@alias ");
        try state.definitions.items[index].appendSlice(name(T));
        try state.definitions.items[index].appendSlice("\n");

        inline for (@typeInfo(T).Enum.fields) |field| {
            try state.definitions.items[index].appendSlice("---|\' \"");
            try state.definitions.items[index].appendSlice(field.name);
            try state.definitions.items[index].appendSlice("\" \'\n");
        }
    }
}

pub fn addClass(
    state: *DefineState,
    comptime T: type,
) !void {
    if (state.database.contains(@typeName(T)) == false) {
        try state.database.put(@typeName(T), {});
        try state.definitions.append(String.init(state.allocator));
        const index = state.definitions.items.len - 1;

        try state.definitions.items[index].appendSlice("---@class (exact) ");
        try state.definitions.items[index].appendSlice(name(T));
        try state.definitions.items[index].appendSlice("\n");

        inline for (@typeInfo(T).Struct.fields) |field| {
            try state.definitions.items[index].appendSlice("---@field ");
            try state.definitions.items[index].appendSlice(field.name);

            if (field.default_value != null) {
                try state.definitions.items[index].appendSlice("?");
            }
            try state.definitions.items[index].appendSlice(" ");
            try luaTypeName(state, index, field.type);
            try state.definitions.items[index].appendSlice("\n");
        }
    }
}

fn luaTypeName(
    state: *DefineState,
    index: usize,
    comptime T: type,
) !void {
    switch (@typeInfo(T)) {
        .Struct => {
            try state.definitions.items[index].appendSlice(name(T));
            try addClass(state, T);
        },
        .Pointer => |info| {
            if (info.child == u8 and info.size == .Slice) {
                try state.definitions.items[index].appendSlice("string");
            } else switch (info.size) {
                .One => {
                    try state.definitions.items[index].appendSlice("lightuserdata");
                },
                .C, .Many, .Slice => {
                    try luaTypeName(state, index, info.child);
                    try state.definitions.items[index].appendSlice("[]");
                },
            }
        },
        .Array => |info| {
            try luaTypeName(state, index, info.child);
            try state.definitions.items[index].appendSlice("[]");
        },

        .Vector => |info| {
            try luaTypeName(state, index, info.child);
            try state.definitions.items[index].appendSlice("[]");
        },
        .Optional => |info| {
            try luaTypeName(state, index, info.child);
            try state.definitions.items[index].appendSlice(" | nil");
        },
        .Enum => {
            try state.definitions.items[index].appendSlice(name(T));
            try addEnum(state, T);
        },
        .Int => {
            try state.definitions.items[index].appendSlice("integer");
        },
        .Float => {
            try state.definitions.items[index].appendSlice("number");
        },
        .Bool => {
            try state.definitions.items[index].appendSlice("boolean");
        },
        else => {
            @compileLog(T);
            @compileError("Type not supported");
        },
    }
}
