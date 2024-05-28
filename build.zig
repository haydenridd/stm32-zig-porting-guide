const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = std.zig.CrossTarget.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .cpu_features_add = std.Target.arm.featureSet(&[_]std.Target.arm.Feature{std.Target.arm.Feature.fp_armv8d16sp}),
    });

    const arm_gcc_version = "10.3.1";
    const project_name = "blinky";

    // b.verbose = true;
    const optimize = b.standardOptimizeOption(.{});
    const blinky_exe = b.addExecutable(.{
        .name = project_name ++ ".elf",
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .linkage = .static,
        .single_threaded = true,
    });

    // Manually including libraries bundled with arm-none-eabi-gcc
    const arm_gcc_path = b.option([]const u8, "armgcc", "Path to arm-none-eabi-gcc compiler") orelse unreachable;
    blinky_exe.addLibraryPath(.{ .path = b.fmt("{s}/arm-none-eabi/lib/thumb/v7e-m+fp/hard", .{arm_gcc_path}) });
    blinky_exe.addLibraryPath(.{ .path = b.fmt("{s}/lib/gcc/arm-none-eabi/" ++ arm_gcc_version ++ "/thumb/v7e-m+fp/hard", .{arm_gcc_path}) });
    blinky_exe.addSystemIncludePath(.{ .path = b.fmt("{s}/arm-none-eabi/include", .{arm_gcc_path}) });
    blinky_exe.linkSystemLibrary("c_nano");
    blinky_exe.linkSystemLibrary("m");

    // Allow float formating (printf, sprintf, ...)
    //blinky_exe.forceUndefinedSymbol("_printf_float"); // GCC equivalent : "-u _printf_float"

    // Manually include C runtime objects bundled with arm-none-eabi-gcc
    blinky_exe.addObjectFile(.{ .path = b.fmt("{s}/arm-none-eabi/lib/thumb/v7e-m+fp/hard/crt0.o", .{arm_gcc_path}) });
    blinky_exe.addObjectFile(.{ .path = b.fmt("{s}/lib/gcc/arm-none-eabi/" ++ arm_gcc_version ++ "/thumb/v7e-m+fp/hard/crti.o", .{arm_gcc_path}) });
    blinky_exe.addObjectFile(.{ .path = b.fmt("{s}/lib/gcc/arm-none-eabi/" ++ arm_gcc_version ++ "/thumb/v7e-m+fp/hard/crtbegin.o", .{arm_gcc_path}) });
    blinky_exe.addObjectFile(.{ .path = b.fmt("{s}/lib/gcc/arm-none-eabi/" ++ arm_gcc_version ++ "/thumb/v7e-m+fp/hard/crtend.o", .{arm_gcc_path}) });
    blinky_exe.addObjectFile(.{ .path = b.fmt("{s}/lib/gcc/arm-none-eabi/" ++ arm_gcc_version ++ "/thumb/v7e-m+fp/hard/crtn.o", .{arm_gcc_path}) });

    // Normal Include Paths
    blinky_exe.addIncludePath(b.path("Core/Inc"));
    blinky_exe.addIncludePath(b.path("Drivers/STM32F7xx_HAL_Driver/Inc"));
    blinky_exe.addIncludePath(b.path("Drivers/STM32F7xx_HAL_Driver/Inc/Legacy"));
    blinky_exe.addIncludePath(b.path("Drivers/CMSIS/Device/ST/STM32F7xx/Include"));
    blinky_exe.addIncludePath(b.path("Drivers/CMSIS/Include"));

    // Startup file
    blinky_exe.addAssemblyFile(b.path("startup_stm32f750xx.s"));

    // Source files
    blinky_exe.addCSourceFiles(.{
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
        .flags = &.{ "-Og", "-std=c11", "-DUSE_HAL_DRIVER", "-DSTM32F750xx" },
    });

    blinky_exe.link_gc_sections = true;
    blinky_exe.link_data_sections = true;
    blinky_exe.link_function_sections = true;
    blinky_exe.setLinkerScriptPath(.{ .path = "./STM32F750N8Hx_FLASH.ld" });

    // Copy the bin out of the elf
    const bin = b.addObjCopy(blinky_exe.getEmittedBin(), .{
        .format = .bin,
    });
    bin.step.dependOn(&blinky_exe.step);
    const copy_bin = b.addInstallBinFile(bin.getOutput(), project_name ++ ".bin");
    b.default_step.dependOn(&copy_bin.step);

    // Copy the bin out of the elf
    const hex = b.addObjCopy(blinky_exe.getEmittedBin(), .{
        .format = .hex,
    });
    hex.step.dependOn(&blinky_exe.step);
    const copy_hex = b.addInstallBinFile(hex.getOutput(), project_name ++ ".hex");
    b.default_step.dependOn(&copy_hex.step);

    b.installArtifact(blinky_exe);
    // blinky_exe.setVerboseLink(true);
}
