#!/bin/bash

CURRENT="/tmp/suid_sgid_files.current"
PREVIOUS="/tmp/suid_sgid_files.previous"
SHOW_SUID=true
SHOW_SGID=true

while getopts "ug" opt; do
  case $opt in
    u) SHOW_SGID=false ;;
    g) SHOW_SUID=false ;;
  esac
done

if [ "$SHOW_SUID" = false ] && [ "$SHOW_SGID" = false ]; then
  SHOW_SUID=true
  SHOW_SGID=true
fi

find_cmd="find / -type f -path /proc -prune -o"
if [ "$SHOW_SUID" = true ] && [ "$SHOW_SGID" = true ]; then
  find_cmd="$find_cmd \( -perm -4000 -o -perm -2000 \)"
elif [ "$SHOW_SUID" = true ]; then
  find_cmd="$find_cmd -perm -4000"
elif [ "$SHOW_SGID" = true ]; then
  find_cmd="$find_cmd -perm -2000"
fi
find_cmd="$find_cmd -printf '%p %m %T@\n'"

echo "Recherche des fichiers SUID/SGID..."
eval "$find_cmd" 2>/dev/null | sort > "$CURRENT"


echo "Liste des fichiers trouvés:"
while read -r line; do
  file=$(echo "$line" | cut -d' ' -f1)
  perm=$(echo "$line" | cut -d' ' -f2)
  
  type=""
  if [ "$SHOW_SUID" = true ] && [[ "$perm" =~ [4][0-7][0-7][0-7] ]]; then
    type="${type}SUID "
  fi
  if [ "$SHOW_SGID" = true ] && [[ "$perm" =~ [2][0-7][0-7][0-7] ]]; then
    type="${type}SGID "
  fi
  
  if [ -n "$type" ]; then
    echo "[$type] $file (permissions: $perm)"
  fi
done < "$CURRENT"


if [ -f "$PREVIOUS" ]; then
  echo -e "\nComparaison avec la liste précédente:"

  echo -e "\nFichiers ajoutés:"
  comm -23 <(cut -d' ' -f1 "$CURRENT") <(cut -d' ' -f1 "$PREVIOUS") > /tmp/added
  if [ -s /tmp/added ]; then
    while read -r file; do
      grep "$file" "$CURRENT" | while read -r f p t; do
        date=$(date -d @${t%.*} "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "date inconnue")
        echo "$f (permissions: $p, modifié: $date)"
      done
    done < /tmp/added
  else
    echo "Aucun"
  fi
  
  echo -e "\nFichiers supprimés:"
  comm -13 <(cut -d' ' -f1 "$CURRENT") <(cut -d' ' -f1 "$PREVIOUS") > /tmp/removed
  if [ -s /tmp/removed ]; then
    while read -r file; do
      grep "$file" "$PREVIOUS" | while read -r f p t; do
        echo "$f (permissions: $p)"
      done
    done < /tmp/removed
  else
    echo "Aucun"
  fi
  
  echo -e "\nFichiers avec permissions modifiées:"
  found_changes=false
  while read -r curr; do
    file=$(echo "$curr" | cut -d' ' -f1)
    perm=$(echo "$curr" | cut -d' ' -f2)
    time=$(echo "$curr" | cut -d' ' -f3)
    
    prev=$(grep -w "$file" "$PREVIOUS" 2>/dev/null)
    if [ -n "$prev" ]; then
      prev_perm=$(echo "$prev" | cut -d' ' -f2)
      
      if [ "$perm" != "$prev_perm" ]; then
        found_changes=true
        date=$(date -d @${time%.*} "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "date inconnue")
        echo "$file: $prev_perm -> $perm (modifié: $date)"
      fi
    fi
  done < "$CURRENT"
  
  if [ "$found_changes" = false ]; then
    echo "Aucun changement"
  fi
  

  rm -f /tmp/added /tmp/removed
else
  echo -e "\nAucune liste précédente."
fi

cp "$CURRENT" "$PREVIOUS"
echo -e "\nListe sauvegardée."
