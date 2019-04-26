# czhttpd

[![Build Status](https://travis-ci.org/jsks/czhttpd.svg?branch=master)](https://travis-ci.org/jsks/czhttpd)

Simple http server written in 99.9% pure zsh

```
$ ./czhttpd -h
Usage: czhttpd [OPTIONS] [file or dir]

czhttpd - cloud's zsh http server

Options
    -c :    Optional configuration file (default: ~/.config/czhttpd/main.conf)
    -h :    Print this help message
    -p :    Port to bind to (default: 8080)
    -v :    Redirect log messages to stdout

If no file or directory is given, czhttpd defaults to serving
the current directory.
```

The czhttpd script is completely standalone. The only dependency is
zsh version **5.6 or higher**. There is a [docker
image](https://hub.docker.com/r/jsks/czhttpd) available if the version
shipped by your OS is older.

```sh
$ docker pull jsks/czhttpd
$ docker run -p 8080:8080 -it jsks/czhttpd
```

### Optional Dependencies

When available:

- `file` is used for fallback mime-type support
- `ifconfig` is used on macOS/*BSD when `IP_REDIRECT` is not set

Additionally, running the full test suite requires `md5sum`/`md5` and
`vegeta`.

### Features
- Basic support for `HTTP/1.1` (methods limited to `HEAD`, `GET`,
  `POST`)
- Dynamic directory listing with primitive caching
- UTF-8 support
- Multiple concurrent connections
- Live config reload
- Module support for:
    - Gzip compression
    - Basic CGI/1.1 support
        - phpMyAdmin appears fully functional, and partially Wordpress
          (requires configuring for an alternative port)
    - Basic url rewrite

### Configuration

The provided sample `conf/main.conf` lists the variables that can be
changed. Any additional files or modules can be sourced using the
standard shell command, `source`. Similarly, the configuration
variables for each module can be found in their respective config
files.

By default, czhttpd searches for `main.conf` in
`~/.config/czhttpd/conf/`. An alternative configuration file can be
specified with the commandline option `-c`.

#### Live Reload

czhttpd will automatically reload its configuration file and
gracefully handle any changes and open connections when the `HUP`
signal is sent to the parent czhttpd pid. Ex:

```sh
$ kill -HUP <czhttpd pid>
```

---

**Disclaimer**: This is *not* intended for serious use.

czhttpd is not portable between shells (POSIX, what?) and, of course,
has terrible performance and scalability since it spawns a separate
child process to handle each incoming connection. It's also a shell
script. On top of that, I shouldn't even have to mention the (lack of)
security...
