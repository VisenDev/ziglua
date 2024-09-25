const std = @import("std");

const String = std.ArrayList(u8);
const Database = std.StringHashMap(String);

pub const DefineEntry = struct {
    type: type,
    name: []const u8,
};

pub fn define(
    alloc: std.mem.Allocator,
    absolute_output_path: []const u8,
    comptime to_define: []const DefineEntry,
) !void {
    var database = Database.init(alloc);
    defer database.deinit();

    inline for (to_define) |def| {
        std.debug.print("defining: {any}\n", .{def.type});
        try addClass(alloc, &database, def.name, def.type);
        std.debug.print("finished defining: {any}\n", .{def.type});
    }

    var file = try std.fs.createFileAbsolute(absolute_output_path, .{});
    defer file.close();

    try file.seekTo(0);
    try file.writeAll(file_header);

    var iter = database.valueIterator();
    while (iter.next()) |val| {
        try file.writeAll(val.items);
        try file.writeAll("\n");
    }

    try file.setEndPos(try file.getPos());

    iter = database.valueIterator();
    while (iter.next()) |val| {
        val.deinit();
    }
}

const file_header: []const u8 =
    \\---@meta
    \\
    \\--- This is an autogenerated file,
    \\--- Do not modify
    \\
    \\
;

fn addEnum(alloc: std.mem.Allocator, database: *Database, name: []const u8, comptime T: type) !void {
    if (database.contains(name) == false) {
        try database.put(name, try String.initCapacity(alloc, 32));

        var text = database.getPtr(name).?;

        try text.appendSlice("---@alias ");
        try text.appendSlice(name);
        try text.appendSlice("\n");

        inline for (@typeInfo(T).Enum.fields) |field| {
            try text.appendSlice("---|\' \"");
            try text.appendSlice(field.name);
            try text.appendSlice("\" \'\n");
        }
    }
}

fn addClass(alloc: std.mem.Allocator, database: *Database, name: []const u8, comptime T: type) !void {
    if (database.contains(name) == false) {
        try database.put(name, String.init(alloc));

        const text = database.getPtr(name).?;

        std.debug.print("defining: {s}\n", .{name});
        try addClassName(text, name);
        try addClassFields(alloc, database, text, @typeInfo(T).Struct.fields);
        std.debug.print("finished defining: {s}\n", .{name});
    }
}

fn addClassName(text: *String, name: []const u8) !void {
    try text.appendSlice("---@class ");
    try text.appendSlice(name);
    try text.appendSlice("\n");
}

fn addClassField(alloc: std.mem.Allocator, database: *Database, text: *String, comptime field: std.builtin.Type.StructField) !void {
    std.debug.print(" - adding field: {s}\n", .{field.name});
    try text.appendSlice("---@field ");
    try text.appendSlice(field.name);
    try text.appendSlice(" ");
    try addType(alloc, database, text, field.type);
    try text.appendSlice("\n");
}

fn addClassFields(
    alloc: std.mem.Allocator,
    database: *Database,
    text: *String,
    comptime fields: []const std.builtin.Type.StructField,
) !void {
    if (fields.len > 0) {
        try addClassField(alloc, database, text, fields[0]);
        try addClassFields(alloc, database, text, fields[1..fields.len]);
    } else {
        return;
    }
}

fn addType(alloc: std.mem.Allocator, database: *Database, text: *String, comptime T: type) !void {
    switch (@typeInfo(T)) {
        .Struct => {
            const name = (comptime std.fs.path.extension(@typeName(T)))[1..];
            try text.appendSlice(name);
            try addClass(alloc, database, name, T);
        },
        .Pointer => |info| {
            if (info.child == u8 and info.size == .Slice) {
                try text.appendSlice("string");
            } else switch (info.size) {
                .One => {
                    try text.appendSlice("lightuserdata");
                },
                .C, .Many, .Slice => {
                    try addType(alloc, database, text, info.child);
                    try text.appendSlice("[]");
                },
            }
        },
        .Array => |info| {
            try addType(alloc, database, text, info.child);
            try text.appendSlice("[]");
        },

        .Vector => |info| {
            try addType(alloc, database, text, info.child);
            try text.appendSlice("[]");
        },
        .Optional => |info| {
            try addType(alloc, database, text, info.child);
            try text.appendSlice("?");
        },
        .Enum => {
            const name = (comptime std.fs.path.extension(@typeName(T)))[1..];
            try addEnum(alloc, database, name, T);
            try text.appendSlice(name);
        },
        .Int => {
            try text.appendSlice("integer");
        },
        .Float => {
            try text.appendSlice("number");
        },
        .Bool => {
            try text.appendSlice("boolean");
        },
        else => {
            @compileLog(T);
            @compileError("Type not supported");
        },
    }
}
