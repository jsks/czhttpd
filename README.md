# czhttpd
Simple http server written in 99.9% pure zsh<br>

---

**Disclaimer**: This is *not* intended for serious use.

The primary goal of this project was to write a web server using pure zsh. As such, czhttpd is not portable between shells (POSIX, what?) and, of course, has terrible performance and scalability since it spawns a separate child process to handle each incoming connection. It's also a shell script. On top of that, I shouldn't even have to mention the (lack of) security...

---  
<br>
**So why write it?** Because it's fun, and I have found use for czhttpd in quickly serving files on a local network and testing web pages.

### Features:
*Tested on Linux and OS X. {Free,Net,Open}BSD should work; however, they are completely untested.*

- Basic support for HTTP/1.1
    - Including: HEAD, GET, POST
- Dynamic directory listing
- UTF-8 support
- Multiple concurrent connections
- Primitive caching of root directory listing and compressed files
- Module support for:
    - Gzip compression
    - Basic CGI/1.1 support
        - phpMyAdmin appears fully functional, and partially Wordpress (requires configuring for an alternative port)

### Optional Dependencies:
- Fallback mime-type support:
    - `file`
- Directory caching:
    - Linux: `inotify-tools`
    - OSX/FreeBSD: `wait_on`

### Usage:
```
czhttpd [OPTIONS] <file or dir>
- Options
    -c :    Configuration file (default: ~/.config/czhttpd/conf/main.conf)
    -p :    Port to bind to (default: 8080)
    -h :    Print useless help message
    -v :    Redirect logging to stdout

If no file or directory is given, czhttpd defaults to serving the current directory
```

### Configuration:
The provided sample `main.conf` lists the variables that can be changed. Any additional files or modules can be sourced using the standard shell command, `source`. Currently, there are only two modules, `cgi.sh` and `compress.sh`. Their description and use should be listed in the respective `cgi.conf` and `compress.conf` config files.

By default, czhttpd searches for `main.conf` in `~/.config/czhttpd/conf/`. An alternative config file can be specified with the commandline option `-c`.

### TODO:
- [ ] Recursive caching (is there a better option than `wait_on`?)

---

I am not much of a programmer especially with zsh so if you have any suggestions or added features please feel free to contribute!
