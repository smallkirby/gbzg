# gbzg: GameBoy Emulator written in Zig

Forked from [gb-emu](https://github.com/take44444/gb-emu).

![Lint](https://github.com/smallkirby/gbzg/actions/workflows/zig-fmt.yml/badge.svg)
![Test](https://github.com/smallkirby/gbzg/actions/workflows/test.yml/badge.svg)

## Development

TBD

## Rendrer

For now, [Sixel](https://github.com/saitoha/libsixel) is supported as a LCD renderer.
You can install dependencies by following command.

```sh
sudo apt install libsixel-dev
```

Note that your terminal must support Sixel encoding.
Major candidate would be [WezTerm](https://wezfurlong.org/wezterm/index.html).
