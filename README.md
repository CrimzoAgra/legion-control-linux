<p align="center">
  <img src="data/legion-control.svg" alt="Legion Control" width="128">
</p>

# Legion Control for Linux

Legion Control is a small Lenovo Legion Space / Vantage replacement for Linux, built with
[Quickshell](https://quickshell.org). From one window you pick power modes and firmware power limits, set the keyboard
and light bar lighting, change the battery and keyboard options, and update the BIOS and firmware.

It's made for the **Legion Pro 7 16IAX10H (Gen 10)**; other recent Legions may work in part. It installs on Arch and
CachyOS.

> **Not affiliated with or endorsed by Lenovo.** Lenovo, Legion, Legion Space and Vantage are trademarks of Lenovo.
> This is an independent tool that works with Lenovo hardware.

## The Legion Control Manual

- [Welcome to Legion Control](manual/01-welcome.md)

**Getting started**

- [Installing](manual/02-installing.md)

**Using it**

- [Performance](manual/03-performance.md)
- [Lighting](manual/04-lighting.md)
- [Battery and keyboard](manual/05-battery-and-keyboard.md)
- [Updates](manual/06-updates.md)
- [Troubleshooting](manual/07-troubleshooting.md)

**For developers**

- [How Legion Control works](docs/how-it-works.md): the files, the root helper, the lighting protocol, permissions and
  credits

## License

Legion Control is released under the [GPL-3.0](LICENSE). No warranty: this changes firmware settings, use it at your
own risk. The lighting protocol comes from OpenRGB; see [credits](docs/how-it-works.md#credits).
