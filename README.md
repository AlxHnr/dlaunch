# Dlaunch

A dmenu wrapper which allows you to search trough various sources provided
by plugins. It will learn what you use the most and presort the search
results accordingly. Dlaunch can be extended by plugins written in Scheme.
You can find some of my plugins
[here](https://github.com/AlxHnr/Dlaunch-plugins). If you want to write
your own plugins, take a look at
[this tutorial](https://github.com/AlxHnr/Dlaunch/wiki/Writing-Dlaunch-plugins),
or at the
[plugin API](https://github.com/AlxHnr/Dlaunch/wiki/The-Dlaunch-plugin-API).

![screenshot.png](https://raw.github.com/AlxHnr/Dlaunch/master/screenshots/dlaunch.png)

Here is a more customized Dlaunch, which searches trough the _home-files_
source:

![screenshot-home-files.png](https://raw.github.com/AlxHnr/Dlaunch/master/screenshots/home-files.png)

## Usage

**Note:** Dlaunch itself doesn't provide any content to search in. For this
you must install a plugin, which provides a source.

After having successfully installed Dlaunch, you can run it by executing
`dlaunch` from your shell. All command line arguments are passed directly
to dmenu. The only exception are the following arguments, which are handled
by Dlaunch directly:

### --sources=NAMES

Comma separated source names which specify in which sources Dlaunch should
search. Example:

`dlaunch --sources=home-files,user-cmd`

### --compile

Builds all plugins and exits. You don't need to call this manually, since
Dlaunch will recompile all plugins after modification automatically.

### --help

Shows a short summary about all available commands and exits.

## Configuring Dlaunch

There isn't much to configure in Dlaunch. The file
`~/.config/dmenu-args.scm` contains quoted strings, which will be passed to
dmenu. Please mind that this path may be different on your system.

Here is an example:

```scm
; Enable case insensitive search:
"-i"

; Make dmenu appear at the bottom of the screen:
"-b"

; Set a nicer font:
"-fn" "xft:DejaVu Sans Mono:pixelsize=13"

; Green colors like in the screenshot above:
"-nb" "#181818" "-nf" "#BCBCBC"
"-sb" "#4C7523" "-sf" "#DEDEDE"
```

For more informations, see the
[manpage of dmenu](http://linux.die.net/man/1/dmenu).

## Plugins

Dlaunch can be extended by
[writing plugins](https://github.com/AlxHnr/Dlaunch/wiki/Writing-Dlaunch-plugins).
A dlaunch plugin is a simple Scheme script, which will be loaded at
runtime. To install a plugin, just throw its source file into the plugin
directory. On most systems this is `~/.config/dlaunch/plugins/`.

## Requirements and installation

Dlaunch depends on:

* [CHICKEN Scheme](http://call-cc.org)
* [dmenu](http://tools.suckless.org/dmenu/)

To install Dlaunch, you must clone this repository first:

```sh
git clone --recursive https://github.com/AlxHnr/Dlaunch
```

Now you have two options: You can either install it globally or locally.

**System wide installation**

This is the simpler variant. Just build Dlaunch in its directory and
install it with these commands:

```sh
cd Dlaunch/
make
sudo make install
```

**Local installation**

You need to make sure to set the variable INSTALL\_PREFIX to your local
installation directory, which is usually `~/.local/`. Then you can build
and install it with these commands:

```sh
cd Dlaunch/
make
make install
```

Make sure, that INSTALL\_PREFIX is set before you build Dlaunch. And also
make sure, that the `bin/` subdirectory in INSTALL\_PREFIX is listed in
your PATH variable. Refer to the documentation of your OS for more
informations.

## Uninstalling Dlaunch

Uninstalling is pretty much like installing Dlaunch. If you have installed
Dlaunch system wide, simply run `sudo make uninstall` from inside Dlaunch's
source directory.

If you have installed Dlaunch locally, you must ensure that INSTALL\_PREFIX
is setup exactly like during its installation. Then run `make uninstall`
from Dlaunch's source directory.

### Wiping Dlaunch's residue from your home directory

Dlaunch and its plugins create various files in your home directory for
caching, storing settings and other things. To get rid of them, just run:

```sh
# Wipe dlaunch's cache:
rm -rf "$HOME/.cache/dlaunch/"

# Wipe dlaunch's metadata, scores, rankings, etc:
rm -rf "$HOME/.local/share/dlaunch/"

# Remove all plugins and settings:
rm -rf "$HOME/.config/dlaunch/"
```

Please mind that all these paths may differ on your System.

## License

Released under the zlib license.
