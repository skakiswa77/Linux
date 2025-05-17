#!/bin/bash

[ "$EUID" -ne 0 ] && echo "Besoin root" && exit 1
[ $# -ne 1 ] && echo "Usage: $0 <fichier>" && exit 1
F=$1
[ ! -f "$F" ] && echo "Fichier introuvable" && exit 1
D="/etc/sudoers.d"
[ ! -d "$D" ] && echo "Dossier $D manquant" && exit 1

while IFS=: read -r l m c _; do
  echo "Config sudo: $l"
  
  if ! id "$l" &>/dev/null; then
    echo "$l n'existe pas. Ignoré."
    continue
  fi
  
  if ! grep -q "$l" /etc/sudoers && [ ! -f "$D/$l" ]; then
    echo "$l pas sudoer. Ignoré."
    continue
  fi
  
  > "$D/$l"
  
  IFS=',' read -ra M <<< "$m"
  if [ ${#M[@]} -gt 1 ]; then
    echo "Host_Alias H_${l^^} = $m" >> "$D/$l"
    m="H_${l^^}"
  fi
  
  IFS='@' read -ra B <<< "$c"
  for b in "${B[@]}"; do
    if [[ "$b" == *","* ]]; then
      IFS=',' read -r cmd mode <<< "$b"
    else
      cmd="$b"
      mode="passwd"
    fi
    
    if [[ "$cmd" != /* ]]; then
      full=$(which "$cmd" 2>/dev/null || echo "$cmd")
      [ "$full" != "$cmd" ] && cmd="$full"
    fi
    
    if [ "$mode" = "nopasswd" ]; then
      echo "$l $m = NOPASSWD: $cmd" >> "$D/$l"
    else
      echo "$l $m = $cmd" >> "$D/$l"
    fi
  done
  
  chmod 440 "$D/$l"
  
done < "$F"
echo "Configuration terminée."
