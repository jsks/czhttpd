czhttpd: simple linux http server written in 99% pure zsh

This is *not* intended for serious use. It has terrible security and was never designed to be portable. Just a toy that I've been playing with to see what I can do with zsh.

Requirements:
- `file`

TODO:
- Logging
- Better support for multiple connections
    - Recycle closed connections
- Timeout to close connection
- Better handling of child processes && exiting
