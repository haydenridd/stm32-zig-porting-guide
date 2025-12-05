const std = @import("std");
const newlib = @import("gatz").newlib;

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = std.Target.Query.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        // Note that "fp_armv8d16sp" is the same instruction set as "fpv5-sp-d16", so LLVM only has the former
        // https://github.com/llvm/llvm-project/issues/95053
        .cpu_features_add = std.Target.arm.featureSet(&[_]std.Target.arm.Feature{std.Target.arm.Feature.fp_armv8d16sp}),
    });
    const executable_name = "blinky";

    const optimize = b.standardOptimizeOption(.{});

    const blinky_mod = b.addModule(executable_name, .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .single_threaded = true,
        .sanitize_c = .off, // Removes C UBSAN runtime from executable (bloats binary)
    });

    const blinky_exe = b.addExecutable(.{
        .name = executable_name ++ ".elf",
        .root_module = blinky_mod,
        .linkage = .static,
    });

    addHalCode(b, blinky_mod);
    addNewlib(b, blinky_mod);

    // Linker Script + Link Options
    blinky_exe.setLinkerScript(b.path("stm32_hal/STM32F750N8Hx_FLASH.ld"));
    blinky_exe.link_gc_sections = true;
    blinky_exe.link_data_sections = true;
    blinky_exe.link_function_sections = true;

    // Produce .bin file from .elf
    const bin = b.addObjCopy(blinky_exe.getEmittedBin(), .{
        .format = .bin,
    });
    bin.step.dependOn(&blinky_exe.step);
    const copy_bin = b.addInstallBinFile(bin.getOutput(), executable_name ++ ".bin");
    b.default_step.dependOn(&copy_bin.step);

    // Produce .hex file from .elf
    const hex = b.addObjCopy(blinky_exe.getEmittedBin(), .{
        .format = .hex,
    });
    hex.step.dependOn(&blinky_exe.step);
    const copy_hex = b.addInstallBinFile(hex.getOutput(), executable_name ++ ".hex");
    b.default_step.dependOn(&copy_hex.step);

    b.installArtifact(blinky_exe);
}

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
