const std = @import("std");
pub const newlib = @import("gatz").newlib;

/// Add STM32 HAL sources/etc. as well as link in newlib
///
/// Note: Assumes the path [project root]/stm32_hal for this module!
pub fn addTo(b: *std.Build, executable: *std.Build.Step.Compile) void {

    // Includes
    const headers = .{
        "stm32_hal/Core/Inc",
        "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Inc",
        "stm32_hal/Drivers/STM32F7xx_HAL_Driver/Inc/Legacy",
        "stm32_hal/Drivers/CMSIS/Device/ST/STM32F7xx/Include",
        "stm32_hal/Drivers/CMSIS/Include",
    };
    inline for (headers) |header| {
        executable.installHeadersDirectory(b.path(header), "", .{});
        executable.addIncludePath(b.path(header));
    }

    // Source files
    executable.addCSourceFiles(.{
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
    executable.defineCMacro("USE_HAL_DRIVER", null);
    executable.defineCMacro("STM32F750xx", null);

    // Startup file
    executable.addAssemblyFile(b.path("stm32_hal/startup_stm32f750xx.s"));

    // Linker Script
    executable.setLinkerScriptPath(b.path("stm32_hal/STM32F750N8Hx_FLASH.ld"));

    // Pull in Newlib with a utility
    const resolved_target_from_exe = executable.root_module.resolved_target.?;
    newlib.addTo(b, resolved_target_from_exe, executable) catch |err| switch (err) {
        newlib.Error.CompilerNotFound => {
            std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
            unreachable;
        },
        newlib.Error.IncompatibleCpu => {
            std.log.err("Cpu: {s} isn't supported by gatz!\n", .{resolved_target_from_exe.result.cpu.model.name});
            unreachable;
        },
    };
}
