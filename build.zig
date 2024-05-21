const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = std.zig.CrossTarget.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m7 },
    });

    const optimize = b.standardOptimizeOption(.{});

    const blinky_exe = b.addExecutable(.{
        .name = "blinky.elf",
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });
    // .linkage = .static, .single_threaded = true
    blinky_exe.addIncludePath(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/include" });
    blinky_exe.addIncludePath(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/include/newlib-nano" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/lib/thumb/v7e-m+fp/hard/libnosys.a" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/lib/thumb/v7e-m+fp/hard/libc_nano.a" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/lib/thumb/v7e-m+fp/hard/libm.a" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/arm-none-eabi/lib/thumb/v7e-m+fp/hard/crt0.o" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crti.o" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtbegin.o" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/libgcc.a" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtend.o" });
    blinky_exe.addObjectFile(.{ .path = "/home/hayden/gnu_arm/gcc-arm-none-eabi-10.3-2021.10/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtn.o" });

    b.installArtifact(blinky_exe);
    blinky_exe.addIncludePath(b.path("Core/Inc"));
    blinky_exe.addIncludePath(b.path("Drivers/STM32F7xx_HAL_Driver/Inc"));
    blinky_exe.addIncludePath(b.path("Drivers/STM32F7xx_HAL_Driver/Inc/Legacy"));
    blinky_exe.addIncludePath(b.path("Drivers/CMSIS/Device/ST/STM32F7xx/Include"));
    blinky_exe.addIncludePath(b.path("Drivers/CMSIS/Include"));
    blinky_exe.addAssemblyFile(b.path("startup_stm32f750xx.s"));
    blinky_exe.addCSourceFiles(.{
        .files = &.{
            "Core/Src/main.c",
            "Core/Src/gpio.c",
            "Core/Src/quadspi.c",
            "Core/Src/spi.c",
            "Core/Src/stm32f7xx_it.c",
            "Core/Src/stm32f7xx_hal_msp.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_cortex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_qspi.c",
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
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_exti.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_spi.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_spi_ex.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim.c",
            "Drivers/STM32F7xx_HAL_Driver/Src/stm32f7xx_hal_tim_ex.c",
            "Core/Src/system_stm32f7xx.c",
            "Core/Src/sysmem.c",
            "Core/Src/syscalls.c",
        },
        .flags = &.{ "-std=c11", "-DUSE_HAL_DRIVER", "-DSTM32F750xx", "-mfloat-abi=hard", "-mfpu=fpv5-sp-d16" },
    });

    blinky_exe.link_gc_sections = true;
    blinky_exe.link_data_sections = true;
    blinky_exe.link_function_sections = true;
    blinky_exe.setLinkerScriptPath(.{ .path = "./STM32F750N8Hx_FLASH.ld" });
    blinky_exe.setVerboseLink(true);
}
