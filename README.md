# czhttpd
Simple http server written in 99.9% pure zsh<br>

---

**Disclaimer**: This is *not* intended for serious use.

The primary goal of this project was to write a web server using pure zsh. There is only a single optional dependency, `file`, used as a matter of convenience by czhttpd to determine the mimetype for files without an extension. As such, czhttpd is not portable between shells (POSIX, what?) and, of course, has terrible performance and scalability since it spawns a separate child process to handle each incoming connection. It's also a shell script. On top of that, I shouldn't even have to mention the (lack of) security...

---  
<br>
**So why write it?** Because it's fun, and I have found use for czhttpd in quickly serving files on a local network and testing web pages.

### Features:
- Basic support for HTTP/1.1
    - Including: HEAD, GET, POST
- Dynamic directory listing
- UTF-8 support
- Multiple concurrent connections
- Gzip compression
- Basic CGI/1.1 support
    - phpMyAdmin appears fully functional, and partially Wordpress (requires configuring for an alternative port)

### Optional Dependency:
- `file`

### Usage:
```
czhttpd [OPTIONS] <file or dir>
- Configuration Options
    -C :    Configuration file (default: ~/.config/czhttpd/czhttpd.conf)

- Connection Options
    -c :    Disable http keep-alive and force 'connection: close' for all 
            HTTP/1.1 response headers
    -m :    Max number of connections to accept (default: 12)
    -p :    Port to bind to (default: 8080)
    -t :    Connection timeout in seconds (default: 30)

- File Options
    -a :    Display hidden files in directories
    -i :    Specify index file (default: index.html)
    -s :    Allow czhttpd to follow symlinks
    -x :    Comma delimited list of file extensions to treat as CGI scripts
    -z :    Enable gzip compression for text/{html,js,css}. An optional comma delimited list of file
            mimetypes can be specified for additional files types to compress.

- Output Options
    -l :    Enable logging to existing file (default: /dev/null)
    -v :    Enable verbose output to stdout
    -h :    Print help message

If no file or directory is given, czhttpd defaults to serving the current directory
```

### Configuration:
czhttpd supports an optional configuration file as a matter of convenience. The provided sample main.conf lists the variables that can be overriden. Any additional files can be sourced in the primary configuration file.

By default, czhttpd searches for main.conf in `~/.config/czhttpd`. An alternative config file can be specified with the commandline option `-C`.

### Examples:
- Start czhttpd on port 8000 with logging, compression, and hidden files enabled<br>
```
./czhttpd -p 8000 -a -l -z ~/.config/czhttpd/czhttpd.log
```

- Run with CGI enabled for php, python, and perl<br>
```
./czhttpd -x php,py,pl
```

- Serve an instance of phpMyAdmin installed in ~/ with logging sent to stdout<br>
```
./czhttpd -v -x php -i index.php ~/phpmyadmin
```

---

I am not much of a programmer especially with zsh so if you have any suggestions or added features please feel free to contribute!
