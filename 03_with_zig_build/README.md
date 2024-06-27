# Writing a `build.zig` for Zig's Build System

Surely we can do better than a Makefile though, right? This is [insert year it is currently]!

## Migrating To Zig's Build System

Zig also includes its own build-system. Documentation is on the... light... side for now, but there are enough examples out there (like this one!) to get something working. I won't go into the nitty gritty of how precisely Zig's build system works, but will provide some guidance on how our Makefile from [02_drop_in_compiler](../02_drop_in_compiler) translates to [build.zig](./build.zig). 

Some specific callouts:

``` zig
const target = b.resolveTargetQuery(.{
    .cpu_arch = .thumb,
    .os_tag = .freestanding,
    .abi = .eabihf,
    .cpu_model = std.zig.CrossTarget.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m7 },
    .cpu_features_add = std.Target.arm.featureSet(&[_]std.Target.arm.Feature{std.Target.arm.Feature.fp_armv8d16sp}),
});
```

This does the equivalent of our `-mcpu`, `-mfpu`, `-mfloat-abi` and `-mthumb` flags from earlier. This describes our target, which is an arm processor using the thumb instruction set, it has no OS, it uses the "embedded application binary interface" with an "hf" at the end to signify hardware floating point, it is a Cortex M7 processor, and finally we manually add the feature that actually enables the hardware floating point instructions. That last one was the only one that was difficult to figure out, as while there are "features" named `vfp4d16sp`, and `vfp3d16sp`, there is NOT one named `vfp5d16sp`. The equivalent feature in this case is `fp_armv8d16sp`, because this is the same instruction set, and so LLVM only contains this feature (see [here](https://github.com/llvm/llvm-project/issues/95053) for more info). An important note is *you must correctly setup your floating point configuration in this section* rather than using the `-mfpu` and `-mfloat-abi` flags from earlier. See my post on ziggit [here](https://ziggit.dev/t/clang-default-cpu-features-overriding-gcc-style-compile-flags/4683) for a full explanation why. For anyone who's ever written a toolchain file in CMake, this declarative way of defining a target architecture (complete with code-completion!) is pretty refreshing.

``` zig
blinky_exe.link_gc_sections = true;
blinky_exe.link_data_sections = true;
blinky_exe.link_function_sections = true;
```

This allows us to remove manually specified `-ffunction-sections` and `-fdata-sections` compile flags as well as `Wl,--gc-sections` linker flag. Zig does this for us now that we've asked it to.  

Finally, I use Zig to try to find `arm-none-eabi-gcc` either via a user supplied path (supply with `-Darmgcc=...`) or in the system's `PATH` variable:
``` Zig
// Try to find arm-none-eabi-gcc program at a user specified path, or PATH variable if none provided
const arm_gcc_pgm = if (b.option([]const u8, "armgcc", "Path to arm-none-eabi-gcc compiler")) |arm_gcc_path|
    b.findProgram(&.{"arm-none-eabi-gcc"}, &.{arm_gcc_path}) catch {
        std.log.err("Couldn't find arm-none-eabi-gcc at provided path: {s}\n", .{arm_gcc_path});
        unreachable;
    }
else
    b.findProgram(&.{"arm-none-eabi-gcc"}, &.{}) catch {
        std.log.err("Couldn't find arm-none-eabi-gcc in PATH, try manually providing the path to this executable with -Darmgcc=[path]\n", .{});
        unreachable;
    };
```

I use the same tricks from [02_drop_in_compiler](../02_drop_in_compiler) to find and populate the pre-compiled Newlib libc that comes bundled with `arm-none-eabi-gcc`. You should now be able to build blink by calling `zig build`!