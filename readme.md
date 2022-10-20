# Ziglua

A Zig library that provides a complete yet lightweight wrapper around the [Lua C API](https://www.lua.org/manual/5.4/manual.html#4). Ziglua currently supports the latest releases of Lua 5.1, 5.2, 5.3, and 5.4.

Ziglua offers two approaches as a library:
* **embedded**: used to embed the Lua VM in a Zig program
* **module**: used to create shared Lua modules that can be loaded at runtime in other Lua-based software

Like the Lua C API, the Ziglua API "emphasizes flexibility and simplicity... common tasks may involve several API calls. This may be boring, but it gives us full control over all the details" (_Programming In Lua 4th Edition_). However, Ziglua takes advantage of Zig's features to make it easier and safer to interact with the Lua API.

* [Docs](https://github.com/natecraddock/ziglua/blob/master/docs.md)
* [Examples](https://github.com/natecraddock/ziglua/blob/master/docs.md#examples)

## Why use Ziglua?

In a nutshell, Ziglua is a simple wrapper around the C API you would get by using Zig's `@cImport()`. Ziglua aims to mirror the [Lua C API](https://www.lua.org/manual/5.4/manual.html#4) as closely as possible, while improving ergonomics using Zig's features. For example:

* Zig error unions to require failure state handling
* Null-terminated slices instead of C strings
* Type-checked enums for parameters and return values
* Compiler-enforced checking of optional pointers
* More precise types (e.g. `bool` instead of `int`)

While there are some helper functions added to complement the C API, Ziglua aims to remain low-level. This allows full access to the Lua API through a layer of Zig's improvements over C.

If you want something higher-level (but doesn't expose the full API), perhaps try [zoltan](https://github.com/ranciere/zoltan).

## Getting Started

Adding Ziglua to your project is easy. First add this repo as a git submodule, or copy the source into your repo. Then add the following to your `build.zig` file (assuming cloned/copied into a `lib/` subdirectory):

```zig
// use the path to the Ziglua build.zig file
const ziglua = @import("lib/ziglua/build.zig");

pub fn build(b: *Builder) void {
    ...
    exe.addPackage(ziglua.linkAndPackage(b, exe, .{}));
}
```

This will compile the Lua C sources and statically link with your project. Then simply import the `ziglua` package into your code! Here is a simple example that pushes and inspects an integer on the Lua stack:

```zig
const std = @import("std");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var lua = try Lua.init(allocator);
    defer lua.deinit();

    lua.pushInteger(42);
    std.debug.print("{}\n", .{lua.toInteger(1)});
}
```

See [docs.md](https://github.com/natecraddock/ziglua/blob/master/docs.md) for documentation and detailed [examples](https://github.com/natecraddock/ziglua/blob/master/docs.md#examples) of using Ziglua.

## Status

Nearly all functions, types, and constants in the C API have been wrapped in Ziglua. Only a few exceptions have been made when the function doesn't make sense in Zig (like functions using `va_list`).

All functions have been type checked, but only the standard C API has been tested fully. Ziglua should be relatively stable and safe to use now, but is still new and changing frequently.

## Acknowledgements

Thanks to the following sources:

* [zoltan](https://github.com/ranciere/zoltan) for insights into compiling Lua with Zig
* [zig-autolua](https://github.com/daurnimator/zig-autolua) for help on writing an alloc function
* [mach-glfw](https://github.com/hexops/mach-glfw) for inspiration on a clean `build.zig`

And finally [Lua](https://lua.org). Thank you to the Lua team for providing a great language!
