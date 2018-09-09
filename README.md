# czhttpd
Simple http server written in 99.9% pure zsh

```
$ ./czhttpd -h
Usage: czhttpd [OPTIONS] <file or dir>

czhttpd - cloud's zsh http server

Options
    -c :    Config file location (default: ~/.config/czhttpd/main.conf)
    -h :    Print this help message
    -p :    Port to bind to (default: 8080)
    -v :    Redirect log messages to stdout

If no file or directory is given, czhttpd defaults to serving
the current directory.
```

#### Dependencies
`>=zsh-5.6`. If available, `file` is also used for fallback mime-type support.


#### Features
- Basic support for `HTTP/1.1` (methods limited to `HEAD`, `GET`, `POST`)
- Dynamic directory listing with primitive caching
- UTF-8 support
- Multiple concurrent connections
- Live config reload
- Module support for:
    - Gzip compression
    - Basic CGI/1.1 support
        - phpMyAdmin appears fully functional, and partially Wordpress (requires configuring for an alternative port)
    - Basic url rewrite

#### Configuration
The provided sample `main.conf` lists the variables that can be changed. Any additional files or modules can be sourced using the standard shell command, `source`. Similarly, the configuration variables for each module can be found in the respective config files.

By default, czhttpd searches for `main.conf` in `~/.config/czhttpd/conf/`. An alternative configuration file can be specified with the commandline option `-c`.

##### Live Reload
czhttpd will automatically reload its configuration file and gracefully handle any changes and current open connections when the `HUP` signal is sent to the parent czhttpd pid. Ex:

```
kill -HUP <czhttpd pid>
```

#### TODO
- [ ] How we handle modules (including the whole srv->handler->send chain) really needs to be rethought
- [X] Finish up `debug.sh`
- [ ] IP matching should be reintroduced as a new module 
- [ ] Error messages from http_client

---

**Disclaimer**: This is *not* intended for serious use.

czhttpd is not portable between shells (POSIX, what?) and, of course, has terrible performance and scalability since it spawns a separate child process to handle each incoming connection. It's also a shell script. On top of that, I shouldn't even have to mention the (lack of) security...
