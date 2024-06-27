const std = @import("std");
pub const newlib = @import("gatz").newlib;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const stm32_hal = b.addObject(.{
        .name = "stm32_hal",
        .target = target,
        .optimize = optimize,
    });

    // Includes
    const headers = .{
        "Core/Inc",
        "Drivers/STM32F7xx_HAL_Driver/Inc",
        "Drivers/STM32F7xx_HAL_Driver/Inc/Legacy",
        "Drivers/CMSIS/Device/ST/STM32F7xx/Include",
        "Drivers/CMSIS/Include",
    };
    inline for (headers) |header| {
        stm32_hal.installHeadersDirectory(b.path(header), "", .{});
        stm32_hal.addIncludePath(b.path(header));
    }

    // Source files
    stm32_hal.addCSourceFiles(.{
        .files = &.{
            "Core/Src/main.c",
            "Core/Src/gpio.c",
            "Core/Src/stm32f7xx_it.c",
            "Core/Src/stm32f7xx_hal_msp.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_cortex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_rcc.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_rcc_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_flash.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_flash_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_gpio.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_dma.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_dma_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_pwr.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_pwr_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_i2c.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_i2c_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim_ex.c",
            "Core/Src/system_stm32f7xx.c",
            "Core/Src/sysmem.c",
            "Core/Src/syscalls.c",
        },
        .flags = &.{"-std=c11"},
    });

    // Neccessary for HAL
    stm32_hal.defineCMacro("USE_HAL_DRIVER", null);
    stm32_hal.defineCMacro("STM32F750xx", null);

    // Startup file
    stm32_hal.addAssemblyFile(b.path("startup_stm32f750xx.s"));

    // Linker Script
    stm32_hal.setLinkerScriptPath(b.path("STM32F750N8Hx_FLASH.ld"));

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

    // Create artifact for top level project to depend on
    b.getInstallStep().dependOn(&b.addInstallArtifact(stm32_hal, .{ .dest_dir = .{ .override = .{ .custom = "" } } }).step);
}
