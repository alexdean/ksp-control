# KSP Control

Software to relay commands from a hardware control panel to Kerbal Space Program.

KSP must have the [telemachus](https://github.com/KSP-Telemachus/Telemachus/) and
[mechjeb](https://kerbal.curseforge.com/projects/mechjeb/files) mods.

Telemachus adds an HTTP server to the KSP game. The server accepts commands
allowing us to operate an in-game spacecraft via HTTP. ksp-control receives
serial command data from a hardware control panel and translates these commands
into telemacus commands.

## Arduino

The Arduino sketch is written for a custom hardware device I built. You can
probably figure it out if you care to. The important part is that it writes
command data to the serial port in a protocol that the dispatcher program can
understand. (More on that below.)

## Dispatcher

Dispatcher is a ruby program which receives commands from the arduino and
relays them along to a locally-running telemachus server.

## Protocol

Each message sent by the arduino is a variable-length string of characters
terminated by a newline.

  * Characters 0 and 1 are the throttle setting, from '00' to '99'.
    * '--' is sent when the main engines are not active.
  * Character 2 is the autopilot mode.
    * This is '-' for 'autopilot disabled', and '0' through '8' for other
      autopilot modes supported by MechJeb.
  * All remaining characters are a bitmask (MSB first) represented as a base 10
    integer. The exact length depends on which bits are set.

Examples:

  * `59-0\n`: Throttle 59%, autopilot disabled, no bits set.
  * `8720\n`: Throttle 87%, autopilot mode 2, no bits set.
  * `---1\n`: Throttle disabled, autopilot disabled, bit 1 (staging) is set.

### Autopilot

The autopilot mode character is mapped to a telemachus command string by
`ControlState.parse`. Telemachus will then translate these strings into MechJeb
autopilot modes.

### Bitmask

  * `ControlState.bitmask_attrs` defines which bits represent which aspects of
game state.
    * examples: bit 0 is 'stage', bit 1 is 'sas', etc.
  * The `flags` variable in `ksp-control.ino` is constructed following that
    specification. Input data from physical controls is encoded into `flags`, which
    becomes the final characters of the serial message.

### Diffing Behavior

Arduino should send a new command string relatively often (every 200ms or less)
to make the controls feel immediate to the user.

To keep from over-burdening Telemachus (and the game in general) by repeatedly
re-setting identical settings every 200ms, Dispatcher remembers the previous command
string it processed, performs a diff between current state and previous state,
and sends only the changed values.

If the same command string is reported by Arduino repeatedly, Dispatcher will
not send any new commands.
