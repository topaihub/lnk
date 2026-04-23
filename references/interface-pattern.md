# Interface Pattern: Adding a New Vtable Interface

## 1. Define the interface in `core/`

```zig
// core/my_service.zig
const std = @import("std");

pub const MyService = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        do_thing: *const fn (ptr: *anyopaque, arg: []const u8) anyerror!void,
    };

    pub fn doThing(self: MyService, arg: []const u8) !void {
        return self.vtable.do_thing(self.ptr, arg);
    }
};
```

## 2. Create the implementation in `infra/`

```zig
// infra/real_service.zig
const MyService = @import("../core/my_service.zig").MyService;

pub const RealService = struct {
    // internal state...

    fn doThingImpl(self: *RealService, arg: []const u8) !void {
        // real implementation
        _ = self;
        _ = arg;
    }

    // VTable wrapper
    fn vtDoThing(ptr: *anyopaque, arg: []const u8) anyerror!void {
        const self: *RealService = @ptrCast(@alignCast(ptr));
        return self.doThingImpl(arg);
    }

    const vtable = MyService.VTable{
        .do_thing = vtDoThing,
    };

    pub fn myService(self: *RealService) MyService {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }
};
```

## 3. Add to `App` in `app.zig`

Add the new interface field to the `App` struct.

## 4. Wire in `main.zig`

Instantiate the infra implementation and pass `.myService()` to `App.init()`.

## Key Rules
- Interface in `core/` — no implementation details
- Implementation in `infra/` — knows about real dependencies
- Commands only see the interface via `App`
- Only `main.zig` wires implementations to interfaces
