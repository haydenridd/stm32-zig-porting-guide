# Advanced Project Structure

Now that we've been through the nitty gritty of what porting involves in projects 1 - 3, it's time to start turning this into
something that looks a little more like *actual* firmware, rather than just a toy project.

## Goals

For our "advanced" project example, let's shoot for the following goals:
- Re-organizing our STM32CubeMX generated code so that it's self-contained and not dirtying up our root directory
- Make use of Zig's package manager + the package [gatz](https://github.com/haydenridd/gcc-arm-to-zig) to make linking in Newlib easier
- Add actual Zig code to our project!
- Exploring how to call some vendor HAL code from Zig

## Re-Organization

Our application from #3 can be interpreted as a dependency graph of sorts, drawn crudely as so:
```
[application code (just in main.c for now)] ----depends on----> [stm32 HAL code] ----depends on----> [arm-none-eabi-gcc's Newlib libc]
```

Currently, the entirety of our "application code" consists of:
``` C
while (1)
{

HAL_GPIO_WritePin(LED_BLINK_GPIO_Port, LED_BLINK_Pin, GPIO_PIN_RESET);
HAL_Delay(1000);
HAL_GPIO_WritePin(LED_BLINK_GPIO_Port, LED_BLINK_Pin, GPIO_PIN_SET);
HAL_Delay(1000);
/* USER CODE END WHILE */

/* USER CODE BEGIN 3 */
}
```

"Everything else", startup files, linker script, driver code, etc. can be considered part of the "HAL Code". So let's move that to it's own directory `stm32_hal`:
```
stm32_hal/
- Core/
- Drivers/
- .mxproject
- blink_example.ioc
- startup_stm32f750xx.s
- STM32F750N8Hx_FLASH.ld
```

But how do we make this its own self-contained build unit? Enter Zig's package manager. By adding the file `build.zig.zon`:
``` zon
.{
    .name = "stm32_hal",
    .version = "0.0.0",
    .dependencies = .{},
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "Core",
        "Drivers",
        "startup_stm32f750xx.s",
        "STM32F750N8Hx_FLASH.ld",
    },
}
```
We've now created a "package". We also want to link in Newlib using a utility that is *also* a Zig package. We can add that on the command line with:
```
zig fetch --save git+https://github.com/haydenridd/gcc-arm-to-zig
```

Our `build.zig.zon` now looks like:
``` zon
.{
    .name = "stm32_hal",
    .version = "0.0.0",
    .dependencies = .{
        .gatz = .{
            .url = "git+https://github.com/haydenridd/gcc-arm-to-zig#ff5d2dfb03149981237a16d5e93b8c39224f318a",
            .hash = "122079adf4c3bf1082b907ea8438096c50c193fa3224ea590dd0c7d3eff1d405c3de",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "Core",
        "Drivers",
        "startup_stm32f750xx.s",
        "STM32F750N8Hx_FLASH.ld",
    },
}
```

Onto how this package should be built in `build.zig`! For a self-contained "build unit", you may be tempted to reach for a static library.
Normally, that would be a good instinct, however our STM32 HAL contains lots of "atypical" code that doesn't gel well with static libraries.
They make extensive use of "weak" symbols for interrupt handlers, and compiling weak and strong symbols together into a static library can result in unexpected behavior. I won't go into detail here about this, but here's some posts that describe the issue, including one by myself:
- https://ziggit.dev/t/c-sources-only-module-behavior/4774/10?u=haydenridd
- https://stackoverflow.com/questions/13089166/how-to-make-gcc-link-strong-symbol-in-static-library-to-overwrite-weak-symbol

So what should we use? Well, there's something in Zig's build system similar in function to CMake's [object library](https://cmake.org/cmake/help/latest/command/add_library.html#object-libraries) that should serve our purpose nicely. It sidesteps the issues with static libraries, but still lets us organize source files, dependencies, linker scripts, and system libraries into a nice consumable bundle. See [build.zig](stm32_hal/build.zig) for the relevant commands.

The last piece of the puzzle is linking Newlib to this HAL code. The `gatz` project exposes a namespace `newlib` for just this purpose. It's as simple as adding:
``` zig
pub const newlib = @import("gatz").newlib;
```
To the top of our `build.zig` file. And then in our `build.zig`:
``` Zig
// Pull in Newlib with a utility
newlib.addTo(b, target, stm32_hal) catch |err| switch (err) {
    newlib.Error.CompilerNotFound => {
        std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
        unreachable;
    },
    newlib.Error.IncompatibleCpu => {
        std.log.err("Cpu: {s} isn't supported by gatz!\n", .{target.result.cpu.model.name});
        unreachable;
    },
};
```

## Depending on the `stm32_hal` Package

Organizing our HAL code makes our top level `build.zig` much simpler. First, to be able to access our new `stm32_hal` package, we add the following to `build.zig.zon` in our top level project:
``` zon
.dependencies = .{
    .stm32_hal = .{
        .path = "stm32_hal",
    },
},
```
This tells Zig's package manager to fetch our package locally from the relative path "stm32_hal".
We now delete all the code including sources/headers/assembly/linker scripts, and import + depend on our package like so:
``` zig
// Add STM32 Hal
const stm32_hal = b.dependency("stm32_hal", .{ .target = target, .optimize = optimize }).artifact("stm32_hal");
blinky_exe.addObject(stm32_hal);
```

There's only one more minor annoyance with this method, due to the following issue:
https://github.com/ziglang/zig/issues/20431

Our main "blinky" executable will try to link against libc, but not be able to find it due to not having the system paths/include paths `stm32_hal` does.
`gatz` has a function for just this purpose. We don't have to add `gatz` as a dependency to our top level project, because `stm32_hal` already has it! We can import it in our build script like so:
``` Zig
const newlib = @import("stm32_hal").newlib;
```

Note that the *only* reason this is possible is because in our `stm32_hal`'s [build.zig](stm32_hal/build.zig) we included the following line:
``` Zig
pub const newlib = @import("gatz").newlib;
```

Zig packages can be a little goofy, but a short blurb that describes using "build utilities" from packages is:
- If you want your package to export utility functions *to be used in a build.zig file*, you must mark them `pub` *in that package's build.zig* file. 

Browsing the [gatz](https://github.com/haydenridd/gcc-arm-to-zig) source code is a nice way to learn about a couple different ways you can use packages, as that package supplies both an API for using in a build.zig file, as well as an API that Zig code can call.

Finally, now that we've imported our `newlib` namespace, we can add the following to add in the system paths + include paths to our main executable:
``` Zig
// This ideally won't be neccessary in the future, see:
// - https://github.com/ziglang/zig/issues/20431
newlib.addIncludeHeadersAndSystemPathsTo(b, target, blinky_exe) catch |err| switch (err) {
    newlib.Error.CompilerNotFound => {
        std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
        unreachable;
    },
    newlib.Error.IncompatibleCpu => {
        std.log.err("Cpu: {s} isn't supported by gatz!\n", .{target.result.cpu.model.name});
        unreachable;
    },
};
```

## Adding Zig Code

It's finally time to add some Zig code. At this point, we don't really have any application code yet, as that's all squirreled away in our `stm32_hal` package. So let's fix that! Going to [main.c](stm32_hal/Core/Src/main.c), we delete our while loop code and add this ominous looking function before the while loop:
``` C
/* USER CODE BEGIN 2 */
zigMain(); // Never returns!
/* USER CODE END 2 */
```

We also add an `extern` prototype for this function to let the compiler know "This symbol exists somewhere I promise":
``` C
/* USER CODE BEGIN 0 */
extern void zigMain(void);
/* USER CODE END 0 */
```

Now onto Zig land! We create `src/main.zig` with the following:
``` Zig
export fn zigMain() void {
    while (true) {
    }
}
```

And add it to our executable in `build.zig`:
``` Zig
const blinky_exe = b.addExecutable(.{
    .name = executable_name ++ ".elf",
    .target = target,
    .optimize = optimize,
    .link_libc = false,
    .linkage = .static,
    .single_threaded = true,
    .root_source_file = b.path("src/main.zig"),
});
```

Everything should now compile and... do a whole lot of nothing. But believe it or not, we've successfully called into Zig code from C code!
`export fn zigMain() void ` tells Zig "export a function symbol taking `void` and returning `void`, and make it C ABI compatible". This fulfills our earlier
promise to the compiler that there was an `extern` symbol somewhere called `zigMain` with the function signature `void zigMain(void);`.

## Calling HAL Code from Zig

Now we get into one of Zig's best features: C interoperability. We have a couple options here. The first, and usually easiest, is to use Zig's built-in functions
`@cImport` and `@cInclude`. Generally speaking, when working with ST's generated code, you get access to "everything" by importing the `main.h` file. I won't comment on whether this is good design or not, but we will use it as our entry point to accessing HAL functions. So we add to `main.zig`:
``` Zig
const stm32_hal = @cImport({
    @cDefine("STM32F750xx", {});
    @cDefine("USE_HAL_DRIVER", {});
    @cInclude("main.h");
});
```

Note that we need to define the macros `STM32F750xx` and `USE_HAL_DRIVER` for the HAL code to compile correctly. Sadly Zig's C translation code doesn't know about command line macro definitions (defs not in headers), so we have to provide these manually. We can now spruce up `zigMain()` by calling some HAL code:
``` Zig
while (true) {
    stm32_hal.HAL_GPIO_WritePin(stm32_hal.LED_BLINK_GPIO_Port, stm32_hal.LED_BLINK_Pin, stm32_hal.GPIO_PIN_RESET);
    stm32_hal.HAL_Delay(1000);
    stm32_hal.HAL_GPIO_WritePin(stm32_hal.LED_BLINK_GPIO_Port, stm32_hal.LED_BLINK_Pin, stm32_hal.GPIO_PIN_SET);
    stm32_hal.HAL_Delay(1000);
}
```
Notice that everything is namespaced under `stm32_hal`, as that is what we assigned the result of `@cImport` to. You should now have blinky again! But how does Zig do this? Well, browse your `.zig-cache/o/` directory and look for a file called `cimport.zig`. This is a file generated by Zig that is a Zig API generated from a C header file. Note that our file is ~26000 lines long!! This is because `main.h` imports a LOT of ST header files, and so Zig generated an API for *every header file included*. Note that header translation has it's limits so perusing this file you will see things like:
``` Zig
pub const __HAL_RCC_LPTIM1_CLK_SLEEP_ENABLE = @compileError("unable to translate C expr: expected ')' instead got '|='");
```
Trying to access unresolved symbols will throw a compile error.
There is nothing magic about what Zig's doing here, in fact by picking bits and pieces out of this file, we can remove the need entirely for `@cImport` and just write the neccessary Zig code ourselves:
``` Zig
const stm32_hal = struct {
    pub const GPIO_TypeDef = extern struct {
        MODER: u32 = @import("std").mem.zeroes(u32),
        OTYPER: u32 = @import("std").mem.zeroes(u32),
        OSPEEDR: u32 = @import("std").mem.zeroes(u32),
        PUPDR: u32 = @import("std").mem.zeroes(u32),
        IDR: u32 = @import("std").mem.zeroes(u32),
        ODR: u32 = @import("std").mem.zeroes(u32),
        BSRR: u32 = @import("std").mem.zeroes(u32),
        LCKR: u32 = @import("std").mem.zeroes(u32),
        AFR: [2]u32 = @import("std").mem.zeroes([2]u32),
    };
    pub const PERIPH_BASE = @as(c_ulong, 0x40000000);
    pub const AHB1PERIPH_BASE = PERIPH_BASE + @as(c_ulong, 0x00020000);
    pub const GPIOA_BASE = AHB1PERIPH_BASE + @as(c_ulong, 0x0000);
    pub const GPIOA = @import("std").zig.c_translation.cast([*c]GPIO_TypeDef, GPIOA_BASE);
    pub const GPIO_PIN_15 = @import("std").zig.c_translation.cast(u16, @as(c_uint, 0x8000));
    pub const LED_BLINK_Pin = GPIO_PIN_15;
    pub const LED_BLINK_GPIO_Port = GPIOA;
    pub const GPIO_PinState = c_uint;
    pub const GPIO_PIN_RESET: c_int = 0;
    pub const GPIO_PIN_SET: c_int = 1;
    pub extern fn HAL_GPIO_WritePin(GPIOx: [*c]GPIO_TypeDef, GPIO_Pin: u16, PinState: GPIO_PinState) void;
    pub extern fn HAL_Delay(Delay: u32) void;
};
```

This functions the exact same way, and is only ~25 lines of code instead of 26000! However, should we want to use another peripheral/pin, we would have to go hunting around again in `cimport.zig` for the appropriate functions/datastructures. 

And there we have it: a working blinky, using Zig + vendor C code, that is organized reasonably well for further development.