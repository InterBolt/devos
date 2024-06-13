# TODOS

- [ ] require that every plugin have a valid source which is either a file path or a url.
- [ ] implement a manifest.json that maps plugin names to their sources and that is mounted into the firejail sandboxes for plugin authors to use to verify whether or not a plugin running alongside it will behave predictably.
- [ ] redownload each plugin from source if our manifest no longer matches
- [ ] add support for `solos plugin <url|name>` - should add plugin to vscode workspace, init the source as the filepath, pull in the precheck script, and prepare some instructions in a GUIDE.md file.
- [ ] add support for daemon reload --foreground which will kill the current daemon and start a new one in the foreground for better debugging visibility.
