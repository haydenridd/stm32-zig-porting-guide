# General To-Do:
- Use build.zig to do the equivalent of what drop in makefile is currently doing

# Investigate To-Do:
- Zig emits to stderror for --verbose_link (this)[https://github.com/ziglang/zig/issues/19410]
- Zig doesn't have -mfpu=fpv5-sp-d16 as an option in cpu features
- Zig linker appears to use "armelf_linux_eabi" triple when freestanding is explicitly specified


# Notes
`arm-none-eabi-gcc` comes bundled with  `newlib` and `newlib-nano` variants of the C standard library, pre-compiled for each possible chip architecture. This requires manual linking in the following from `arm-none-eabi-gcc` install path:
- Pre-compiled C runtime objects for arch:
    - crti.o
    - crtbegin.o
    - crtn.o
    - crtend.o
    - crt0.o
- libc_nano.a
- libm.a
- libnosys.a
- libgcc.a
