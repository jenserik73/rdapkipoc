PS1="\[\e[34m\]\w\[\e[33m\]\$(git branch --show-current 2>/dev/null | sed 's/.*/ (&)/')\[\e[0m\] \$ "
