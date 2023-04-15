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

A recent build of zig is required (zig version
`0.11.0-dev.2613+b42562be7` was working at the time of writing). Once
zig 0.11.0 is released, development will follow stable releases.

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
