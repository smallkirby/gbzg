# gbzg: GameBoy Emulator written in Zig

Forked from [gb-emu](https://github.com/take44444/gb-emu).

![Lint](https://github.com/smallkirby/gbzg/actions/workflows/zig-fmt.yml/badge.svg)
![Test](https://github.com/smallkirby/gbzg/actions/workflows/unittest.yml/badge.svg)
![BootROM](https://github.com/smallkirby/gbzg/actions/workflows/boot.yml/badge.svg)
![cpu_instrs](https://github.com/smallkirby/gbzg/actions/workflows/cpu_instrs.yml/badge.svg)
![instr_timing](https://github.com/smallkirby/gbzg/actions/workflows/instr_timing.yml/badge.svg)
![mem_timing](https://github.com/smallkirby/gbzg/actions/workflows/mem_timing.yml/badge.svg)
![mem_timing2](https://github.com/smallkirby/gbzg/actions/workflows/mem_timing2.yml/badge.svg)
![dmg-acid2](https://github.com/smallkirby/gbzg/actions/workflows/dmg-acid2.yml/badge.svg)

| <img src="docs/boot.gif" width="400" > |
|:--:|
| *Boot [Free ROM](https://github.com/take44444/Gameboy-free_bootrom)* |

| <img src="docs/cpu_instrs.png" width="200" > | <img src="docs/instr_timing.png" width="200" > |
|:--:|:--:|
| [Blargg cpu_instrs](https://github.com/retrio/gb-test-roms/tree/master/cpu_instrs) test | [Blargg instr_timing](https://github.com/retrio/gb-test-roms/tree/master/instr_timing) test |
| <img src="docs/mem_timing.png" width="200" > | <img src="docs/mem_timing2.png" width="200" > |
| [Blargg mem_timing](https://github.com/retrio/gb-test-roms/tree/master/mem_timing) test | [Blargg mem_timing2](https://github.com/retrio/gb-test-roms/tree/master/mem_timing-2) test |
| <img src="docs/dmg-acid2.png" width="200" > |
| [dmg-acid2](https://github.com/mattcurrie/dmg-acid2) PPU test |

## Build

```sh
zig build run
```

## Renderer

For now, [Sixel](https://github.com/saitoha/libsixel) is supported as a LCD renderer.
You can install dependencies by following command.

```sh
sudo apt install libsixel-dev
```

Note that your terminal must support Sixel encoding.
Major candidate would be [WezTerm](https://wezfurlong.org/wezterm/index.html).
