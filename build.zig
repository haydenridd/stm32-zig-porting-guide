const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = std.zig.CrossTarget.CpuModel{ .explicit = &std.Target.arm.cpu.cortex_m7 },
        .cpu_features_add = std.Target.arm.featureSet(&[_]std.Target.arm.Feature{std.Target.arm.Feature.fp_armv8d16sp}),
    });

    // b.verbose = true;
    const optimize = b.standardOptimizeOption(.{});
    const blinky_exe = b.addExecutable(.{
        .name = "blinky.elf",
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .linkage = .static,
        .single_threaded = true,
    });

    // Manually including libraries bundled with arm-none-eabi-gcc
    const arm_gcc_path = b.option([]const u8, "armgcc", "Path to arm-none-eabi-gcc compiler") orelse unreachable;
    const alloc = a: {
        var v = std.heap.GeneralPurposeAllocator(.{}){};
        break :a v.allocator();
    };

    blinky_exe.addLibraryPath(.{ .path = std.fmt.allocPrint(alloc, "{s}/arm-none-eabi/lib/thumb/v7e-m+fp/hard", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addLibraryPath(.{ .path = std.fmt.allocPrint(alloc, "{s}/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addSystemIncludePath(.{ .path = std.fmt.allocPrint(alloc, "{s}/arm-none-eabi/include", .{arm_gcc_path}) catch unreachable });
    blinky_exe.linkSystemLibrary("c_nano");
    blinky_exe.linkSystemLibrary("m");

    // Manually include C runtime objects bundled with arm-none-eabi-gcc
    blinky_exe.addObjectFile(.{ .path = std.fmt.allocPrint(alloc, "{s}/arm-none-eabi/lib/thumb/v7e-m+fp/hard/crt0.o", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addObjectFile(.{ .path = std.fmt.allocPrint(alloc, "{s}/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crti.o", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addObjectFile(.{ .path = std.fmt.allocPrint(alloc, "{s}/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtbegin.o", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addObjectFile(.{ .path = std.fmt.allocPrint(alloc, "{s}/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtend.o", .{arm_gcc_path}) catch unreachable });
    blinky_exe.addObjectFile(.{ .path = std.fmt.allocPrint(alloc, "{s}/lib/gcc/arm-none-eabi/10.3.1/thumb/v7e-m+fp/hard/crtn.o", .{arm_gcc_path}) catch unreachable });

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
        .flags = &.{ "-std=c11", "-DUSE_HAL_DRIVER", "-DSTM32F750xx" },
    });

    blinky_exe.link_gc_sections = true;
    blinky_exe.link_data_sections = true;
    blinky_exe.link_function_sections = true;
    blinky_exe.setLinkerScriptPath(.{ .path = "./STM32F750N8Hx_FLASH.ld" });

    b.installArtifact(blinky_exe);
    // blinky_exe.setVerboseLink(true);
}
