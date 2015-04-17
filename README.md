# Dlaunch

A dmenu wrapper which allows you to search trough various sources provided
by plugins. It will learn what you use the most and presort the search
results accordingly. Dlaunch can be extended by plugins written in Scheme.
You can find some of my plugins
[here](https://github.com/AlxHnr/Dlaunch-plugins). If you want to write
your own plugins, take a look at
[this tutorial](https://github.com/AlxHnr/Dlaunch/wiki/Writing-Dlaunch-plugins).

![screenshot.png](https://raw.github.com/AlxHnr/Dlaunch/master/screenshots/dlaunch.png)

Here is a more customized Dlaunch, which searches trough the _home-files_
source:

![screenshot-home-files.png](https://raw.github.com/AlxHnr/Dlaunch/master/screenshots/home-files.png)

## Requirements and installation

Dlaunch depends on:

* [CHICKEN Scheme](http://call-cc.org)
* [chicken-builder](https://github.com/AlxHnr/chicken-builder)
* [dmenu](http://tools.suckless.org/dmenu/)

After cloning this repository, you must chdir into it. Now you have two
options: a system wide, or a local installation.

A system wide installation is the default. Dlaunch will be installed to
`/usr/local`, unless you set *INSTALL_PREFIX* to another path.

For a local installation you must set the variable *INSTALL_PREFIX* to your
local installation path, which is usually `~/.local/`.

Now you can build and install Dlaunch with the following commands:

```sh
make
make install # Eventually this command must be executed as root.
```

Please mind that *INSTALL_PREFIX* must be set before you build Dlaunch.

### Uninstalling Dlaunch

First you need to ensure, that *INSTALL_PREFIX* is setup exactly like
during installation. Then simply run `make uninstall` from inside Dlaunch's
source directory.

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

## Usage

**Note:** Dlaunch itself doesn't provide any content to search in. For this
you must install a plugin, which provides a source.

After successful [installation](#requirements-and-installation) you can run
it by executing `dlaunch` from your shell. All command line arguments are
passed directly to dmenu. The only exception are the following arguments,
which are handled by Dlaunch directly:

### --sources=NAMES

Comma separated source names which specify in which sources Dlaunch should
search.

Example:

`dlaunch --sources=home-files,user-cmd`

### --compile

Builds all plugins and exits. You don't need to call this manually, since
Dlaunch will recompile all plugins after modification automatically.

### --help

Shows a short summary about all available commands and exits.

## Configuring Dlaunch

There isn't much to configure in Dlaunch. The file
`~/.config/dlaunch/dmenu-args.scm` contains quoted strings, which will be
passed to dmenu. Please mind that this path may be different on your
system.

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

## License

Released under the zlib license.
