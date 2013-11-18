# czhttpd
Simple http server written in 99% pure zsh<br>

---

**Disclaimer**: This is *not* intended for serious use.

The primary goal of this project was to write a web server using pure zsh - the exception being `cat`, `expr`, and `file` which make no sense to re-implement. As such, czhttpd is not portable between shells (POSIX, what?) and, of course, has terrible performance and scalability since it uses a process pool to handle multiple connections and well, it's a shell script. I also shouldn't even have to mention the (lack of) security...

---  
<br>
**So why write it?** Because it's fun, and I have found use for czhttpd in quickly serving files on a local network and testing web pages.

### Features:
- Basic support for HTTP/1.1
    - Including: HEAD, GET, POST
- Dynamic directory listing
- UTF-8 support
- Multiple concurrent connections
- Basic CGI/1.1 support
    - phpMyAdmin appears fully functional, and partially Wordpress (requires configuring for an alternative port)

### Dependencies:
- `file`
- `cat`
- `expr`

### Usage:
```
czhttpd [OPTIONS] <file or dir>
- Configuration Options
    -c :    Configuration file (default: ~/.config/czhttpd/czhttpd.conf)

- Connection Options
    -m :    Max number of connections to accept (default: 12)
    -p :    Port to bind to (default: 8080)
    -t :    Connection timeout in seconds (default: 5)

- File Options
    -a :    Display hidden files in directories
    -i :    Specify index file (default: index.html)
    -x :    Comma delimited list of file extensions to treat as CGI scripts

- Output Options
    -l :    Enable logging to existing file (default: /dev/null)
    -v :    Enable verbose output to stdout
    -h :    Print help message

If no file or directory is given, czhttpd defaults to serving the current directory
```

### Configuration:
czhttpd supports an optional configuration file as a matter of convenience. The provided sample config lists the variables that can be overriden.

By default, czhttpd searches for czhttpd.conf in `~/.config/czhttpd`. An alternative config file can be specified with the commandline option `-c`.

### Examples:
Start czhttpd on port 8000 with logging enabled
`./czhttpd -p 8000 -l ~/.config/czhttpd/czhttpd.log`

Run with CGI enabled for php, python, and perl
`./czhttpd -x php,py,pl`

Serve an instance of phpMyAdmin installed in ~/ with logging sent to stdout
`./czhttpd -v -x php -i index.php ~/phpmyadmin`

