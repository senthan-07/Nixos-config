# ~/.config/fish/config.fish -> rice/Dotfiles/fish/config.fish
# User layer. Fish sources this BEFORE /etc/fish/config.fish (NixOS global).

# Suppress fish's built-in "Welcome to fish, the friendly interactive shell"
set -g fish_greeting ""

# /etc/fish/config.fish already defaults STARSHIP_CONFIG to
# $HOME/.config/starship.toml, but only exports it when falling back to the
# Nix store. Exporting it here keeps the prompt and any `starship prompt`
# subprocesses reading the same symlinked rice config.
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"