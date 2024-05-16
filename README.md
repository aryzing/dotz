# dotz

Copies a file tree via hard links from a given source to a given destination. Ideal for copying dot files and other config files from a git repository.

Arguments must be absolute or relative paths, and does not handle shell expansion (e.g., `~`).

Usage: `dotz $SOURCE $DEST`.

Example: assume a "dotfiles" repo contains a file structure such as

```text
# dotfiles
# ├── .bashrc
# └── .config
#     ├── foo1
#     │   └── config1.yml
#     ├── foo2
#     │   └── config2.toml
#     └── foo3
#         └── config3.json
```

To copy this tree to the user's home directory, run

```shell
dotz /path/to/dotfiles /home/user
```

The above tree will be copied to the home directory with hard links. The config files may be edited from within the home folder, while the changes are reflected and maintained in the `dotfiles` repository.

Inspired by [GNU Stow](https://www.gnu.org/software/stow/).

Suggestions welcome.
