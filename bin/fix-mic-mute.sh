#!/bin/bash
sleep 3
ID=$(wpctl status | grep -oP '\d+(?=\.\s+M7 Mono)')
[ -n "$ID" ] && wpctl set-mute "$ID" 0
