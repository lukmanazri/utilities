# Installation

## Mac

```
brew install tmux
```

## Kali Linux

```
sudo apt install tmux 
```
## TPM Plugin 
https://github.com/tmux-plugins/tpm


Install `tpm` plugins:

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## Tmux-Logging Plugin
https://github.com/tmux-plugins/tmux-logging

Install `tmux-logging` plugins:

```
git clone https://github.com/tmux-plugins/tmux-logging ~/.tmux/plugins/tmux-logging
```
## Reload tmux config

Then, Press prefix (CTRL + A) + I (capital i, as in Install) to fetch the plugin

`PREFIX` + `I`

Inside **active** tmux session:

```
source ~/.tmux.conf
```

