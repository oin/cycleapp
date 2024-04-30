# cycleapp

A small macOS (10.9+) utility to cycle between different apps.

## Usage

`cycleapp` is meant to be used as part of a keyboard shortcut, defined in apps like HammerSpoon, BetterTouchTool, or Keyboard Maestro.
It allows you to quickly switch between a set of applications, in a round-robin fashion, and offers a few configuration options and nice features.

```
cycleapp [-reEsafv] com.application1.bundle-identifier [com.application2.bundle-identifier ...]
```

Pass it a space-separated list of application bundle identifiers[^1], and upon each invocation, it will activate the next app in the list, launching it if not running, and optionally hiding the previous one.
Once the end of the list is reached, it will do one of the following:

 - Switch back to the first application on the list (default behavior).
 - Return to the application that was active before activating the first app on the list (`-E`).
 - Hide all the apps on the list (`-e`, implies `-E`).

If the program is invoked twice in quick succession (within 100ms), it will hide all the apps on the list, regardless of the `-e` flag.

The following options are available:

 - `-r`: Only cycle between running applications, don't launch anything.
 - `-e`: Hide all applications in the list when at the end (implies `-E`).
 - `-E`: Return to the previous application before the cycle began when at the end.
 - `-s`: Hide the current application of the list when switching to the next one.
 - `-a`: Bring all the windows to front.
 - `-f`: Use a more forceful application activation method.
 - `-v`: Verbose mode (without arguments, show the bundle identifiers for all the running applications).

[^1]: To create the list more easily, you can open all the desired applications, then use the command `cycleapp -v`, and write down the bundle identifiers you are interested in.

## Example

The following command cycles between Notes, Calendar, and Mail, hiding the previous app when switching to the next one, and returning to the previous app when at the end of the list:

```
cycleapp -sE com.apple.Notes com.apple.iCal com.apple.mail
```

The following command cycles between Finder, Safari, and Terminal, hiding all the apps when at the end:

```
cycleapp -e com.apple.finder com.apple.Safari com.apple.Terminal
```

## How to build

```
make
```

## How to install

Download the [latest release](https://github.com/oin/cycleapp/releases), or `make RELEASE=1`, and copy the `cycleapp` binary to a directory in your `$PATH`.
