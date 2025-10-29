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

We also want to use a Zig package to make adding Newlib easier. We can add that on the command line with:
```
zig fetch --save git+https://github.com/haydenridd/gcc-arm-to-zig
```

Our `build.zig.zon` now looks like:
``` zon
.{
    .name = .stm32_zig_porting,
    .fingerprint = 0x2d8bd33af4894acb,
    .version = "0.0.0",
    .dependencies = .{
        .gatz = .{
            .url = "git+https://github.com/haydenridd/gcc-arm-to-zig#03dcd9ebcfc2f939cc4b053cb3796d9a0f91dd9e",
            .hash = "gatz-0.0.0-aAr5xGCoAAAZbkEgw4SfS63VakN8gV0M3VT48tInlsLc",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
        "README.md",
    },
}
```

We'll cover actually using this package later.

Because Zig's build system is just Zig code, we can make a function that adds our HAL code to our application module to keep this out of the way of our application code:
```Zig
fn addHalCode(b: *std.Build, module: *std.Build.Module) void {

    // Add STM32 Hal
    const headers = .{
        "stm32_hal/Core/Inc",
        "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Inc",
        "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Inc/Legacy",
        "stm32_hal/Drivers/CMSIS/Device/ST/STM32F7xx/Include",
        "stm32_hal/Drivers/CMSIS/Include",
    };
    inline for (headers) |header| {
        module.addIncludePath(b.path(header));
    }

    // Source files
    module.addCSourceFiles(.{
        .files = &.{
            "stm32_hal/Core/Src/main.c",
            "stm32_hal/Core/Src/gpio.c",
            "stm32_hal/Core/Src/stm32f7xx_it.c",
            "stm32_hal/Core/Src/stm32f7xx_hal_msp.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_cortex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_rcc.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_rcc_ex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_flash.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_flash_ex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_gpio.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_dma.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_dma_ex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_pwr.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_pwr_ex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_i2c.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_i2c_ex.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim.c",
            "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim_ex.c",
            "stm32_hal/Core/Src/system_stm32f7xx.c",
            "stm32_hal/Core/Src/sysmem.c",
            "stm32_hal/Core/Src/syscalls.c",
        },
        .flags = &.{"-std=c11"},
    });

    // Neccessary for HAL
    module.addCMacro("USE_HAL_DRIVER", "");
    module.addCMacro("STM32F750xx", "");

    // Startup file
    module.addAssemblyFile(b.path("stm32_hal/startup_stm32f750xx.s"));
}
```

Our HAL code won't change very much as it's provided by the vendor, so this keeps adding all the sources/headers from
clogging up our build.zig.

Now, we want to link in Newlib the HAL code we use makes use of functions provided by the C standard library. The
`gatz` project exposes a namespace `newlib` for just this purpose. It's as simple as adding:
``` zig
pub const newlib = @import("gatz").newlib;
```
To the top of our `build.zig` file. Then, we'll make another function for adding in Newlib:
``` Zig
/// Add newlib to a module using the gatz package
fn addNewlib(b: *std.Build, module: *std.Build.Module) void {
    newlib.addTo(b, module) catch |err| switch (err) {
        newlib.Error.CompilerNotFound => {
            std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
            unreachable;
        },
        newlib.Error.IncompatibleCpu => {
            std.log.err("Cpu: {s} isn't supported by gatz!\n", .{module.resolved_target.?.result.cpu.model.name});
            unreachable;
        },
    };
}
```

## Some Notes on Zig Packages

At this point you might be rightfully wondering how our `build.zig.zon` addition let us directly import `gatz` for use
in our build.zig (and where `gatz` even comes from). Zig's package manager is still relatively undocumented, but generally speaking:
- If you want your package to export utility functions *to be used in a build.zig file*, you must mark them `pub`
*in that package's build.zig* file. Take a look at the source code for the
[gatz](https://github.com/haydenridd/gcc-arm-to-zig) package to learn more about how to make/use packages. It
demonstrates a couple different ways you can use packages, as it supplies:
- An API that can be used in `build.zig`
- An API that can be used in application code
- A standalone executable utility

## Adding Zig Code

It's finally time to add some Zig code. At this point, we don't really have any application code yet, as that's all
squirreled away in our `stm32_hal` package. So let's fix that! Going to [main.c](stm32_hal/Core/Src/main.c), we delete
our while loop code and add this ominous looking function before the while loop:
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

And add it to our application's module in `build.zig`:
``` Zig
const blinky_mod = b.addModule(executable_name, .{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .link_libc = false,
    .single_threaded = true,
    .sanitize_c = .off, // Removes C UBSAN runtime from executable (bloats binary)
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