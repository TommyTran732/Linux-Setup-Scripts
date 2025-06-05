# Linux Setup Scripts

![ShellCheck](https://github.com/Metropolis-nexus/Linux-Setup-Scripts/actions/workflows/shellcheck.yml/badge.svg)

Generic Linux setup scripts. Edit them to your liking before running them.

## Notes on `io_uring`
`io_uring` is disabled. On Proxmox, use `aio=native` for drives. You will need to manually edit the config for cdrom. Alternatively, if you do not want to deal with this, comment out the io_uring line in `/etc/sysctl.d/99-server.conf`
