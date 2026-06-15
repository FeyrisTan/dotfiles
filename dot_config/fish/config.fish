source /usr/share/cachyos-fish-config/cachyos-config.fish

zoxide init fish | source

# SoulForge
set -gx PATH $HOME/.soulforge/bin $PATH

fnm env | source

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/gomi/.lmstudio/bin
# End of LM Studio CLI section

