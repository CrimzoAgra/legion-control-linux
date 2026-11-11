# Troubleshooting

## "Legion Control isn't installed yet"

The root part isn't installed. Run:

```sh
sudo bash ~/.local/share/legion-control/install.sh
```

## "Can't reach the keyboard lighting"

Run the root installer again (the command above), then reopen the app. It gives your user access to the lighting
controller.

## "fwupd isn't installed"

Run the root installer again; it installs fwupd.

## A BIOS update is on Lenovo's site but not in the app

Lenovo doesn't publish every Legion BIOS for Linux. That update needs Windows or Lenovo's own updater.

Back to the [README](../README.md)
