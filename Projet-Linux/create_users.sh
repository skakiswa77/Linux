#!/bin/bash

[ "$EUID" -ne 0 ] && echo "Besoin root" && exit 1
[ $# -ne 1 ] && echo "Usage: $0 <fichier>" && exit 1
FILE=$1
[ ! -f "$FILE" ] && echo "Fichier introuvable" && exit 1

while IFS=: read -r p n g s a pw; do
  l="${p:0:1}$n"
  l=$(echo "$l" | tr 'A-Z' 'a-z')
  i=1
  while id "$l" &>/dev/null; do
    l="${p:0:1}$n$i"
    ((i++))
  done
  echo "Création: $l ($p $n)"
  
  if [ -n "$g" ]; then
    IFS=',' read -ra G <<< "$g"
    gp=${G[0]}
    getent group "$gp" &>/dev/null || groupadd "$gp"
    gs=""
    for ((i=1; i<${#G[@]}; i++)); do
      gg=${G[$i]}
      getent group "$gg" &>/dev/null || groupadd "$gg"
      gs="$gs${gs:+,}$gg"
    done
  else
    gp="$l"
    groupadd "$gp" 2>/dev/null
  fi
  
  if [ -n "$gs" ]; then
    useradd -m -c "$p $n" -g "$gp" -G "$gs" "$l"
  else
    useradd -m -c "$p $n" -g "$gp" "$l"
  fi
  echo "$l:$pw" | chpasswd
  passwd -e "$l"
  
  if [ "$s" = "oui" ]; then
    echo "$l ALL=(ALL) ALL" > "/etc/sudoers.d/$l"
    chmod 440 "/etc/sudoers.d/$l"
  fi
  
  if [ -n "$a" ]; then
    IFS='/' read -ra A <<< "$a"
    for app in "${A[@]}"; do
      command -v "$app" &>/dev/null && echo "$app déjà là" || {
        echo "Installation $app..."
        apt-get -y install "$app" >/dev/null 2>&1
        [ $? -eq 0 ] && echo "$app: OK" || echo "$app: Erreur"
      }
    done
  fi
  
  h=$(eval echo ~$l)
  f=$((RANDOM % 6 + 5))
  for ((i=1; i<=f; i++)); do
    s=$((RANDOM % 46 + 5))
    dd if=/dev/urandom of="$h/f_$i.dat" bs=1M count=$s status=none 2>/dev/null
  done
  chown -R "$l:$gp" "$h"
  
done < "$FILE"
echo "Terminé."
