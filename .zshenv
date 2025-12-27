# bin paths
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.config/rofi/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.local/share/zinit/polaris/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# XDG Base directory specification
export XDG_CONFIG_HOME="$HOME/.config"     # Config files
export XDG_CACHE_HOME="$HOME/.cache"       # Cache files
export XDG_DATA_HOME="$HOME/.local/share"  # Application data
export XDG_STATE_HOME="$HOME/.local/state" # Logs and state files

# Editor preferences
export EDITOR="nvim"
export VISUAL="nvim"

# gpg config
export GPG_TTY=$(tty)
