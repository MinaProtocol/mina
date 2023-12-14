#!/bin/bash
apt install -y tmux
chmod 700 /root/startup.sh
tmux new-session -d -s 0
tmux send-keys -t 0 'bash /root/startup.sh' C-m