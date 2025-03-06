# ntfyd

Subscribe to [ntfy](https://ntfy.sh) topics on desktops and get native
notifications without a browser

## Design

`ntfyd` gets notifications using sources and forwards them to
sinks. Currently, only the HTTP source and the D-Bus sink are
supported.

#### Sources

- [x] HTTP
- [ ] Websockets

#### Sinks

- [x] D-Bus (requires `libsystemd`)
- [ ] macOS native notifications
- [ ] Windows native notifications

## Build

Zig 0.14.0 is required. `ntfyd` follows zig stable releases.

Compiling is as simple as

```
zig build
```

The resulting `ntfyd` binary can be found in the `zig-out/bin/`
directory.

## Usage

Currently, subscribing is done via command-line options. Configuration
file support is planned.

```
ntfyd [OPTIONS] [server address] [topics]...

Options:
 -u     username
 -p     password
```
