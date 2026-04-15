# Installation

## Mac

```
brew install tmux
```

## Kali Linux

```
sudo apt install tmux 
```

https://github.com/tmux-plugins/tpm
https://github.com/tmux-plugins/tmux-logging

Install `tmux-logging` plugins:

```
git clone https://github.com/tmux-plugins/tmux-logging ~/.tmux/plugins/tmux-logging
```

Install `tpm` plugins:

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Inside **active** tmux session:

```
source ~/.tmux.conf
```

Then, Press prefix + I (capital i, as in Install) to fetch the plugin

`PREFIX` + `I`
