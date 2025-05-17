C="/tmp/suid_curr"
P="/tmp/suid_prev"
S=true
G=true

while getopts "ug" o; do
  case $o in
    u) G=false ;;
    g) S=false ;;
  esac
done

[ "$S" = false ] && [ "$G" = false ] && S=true && G=true

echo "Recherche fichiers SUID/SGID..."
cmd="find / -type f"
if [ "$S" = true ] && [ "$G" = true ]; then
  cmd="$cmd \( -perm -4000 -o -perm -2000 \)"
elif [ "$S" = true ]; then
  cmd="$cmd -perm -4000"
else
  cmd="$cmd -perm -2000"
fi
cmd="$cmd -printf '%p %m %T@\n'"
eval "$cmd" 2>/dev/null | sort > "$C"

echo "Fichiers trouvés:"
while read -r f p t; do
  txt=""
  [ "$S" = true ] && [[ "$p" =~ [4][0-7][0-7][0-7] ]] && txt="${txt}SUID "
  [ "$G" = true ] && [[ "$p" =~ [2][0-7][0-7][0-7] ]] && txt="${txt}SGID "
  [ -n "$txt" ] && echo "[$txt] $f (perm: $p)"
done < "$C"

if [ -f "$P" ]; then
  echo -e "\nComparaison:"
  
  echo -e "\nFichiers ajoutés:"
  comm -23 <(cut -d' ' -f1 "$C") <(cut -d' ' -f1 "$P") > /tmp/add
  if [ -s /tmp/add ]; then
    while read -r f; do
      grep -w "$f" "$C" | while read -r p m t; do
        date=$(date -d @${t%.*} "+%Y-%m-%d %H:%M")
        echo "$p (perm: $m, date: $date)"
      done
    done < /tmp/add
  else
    echo "Aucun"
  fi
  
  echo -e "\nFichiers supprimés:"
  comm -13 <(cut -d' ' -f1 "$C") <(cut -d' ' -f1 "$P") > /tmp/del
  if [ -s /tmp/del ]; then
    while read -r f; do
      grep -w "$f" "$P" | while read -r p m _; do
        echo "$p (perm: $m)"
      done
    done < /tmp/del
  else
    echo "Aucun"
  fi
  
  echo -e "\nPermissions modifiées:"
  while read -r line; do
    f=$(echo "$line" | cut -d' ' -f1)
    p=$(echo "$line" | cut -d' ' -f2)
    t=$(echo "$line" | cut -d' ' -f3)
    prev=$(grep -w "$f" "$P")
    if [ -n "$prev" ]; then
      pp=$(echo "$prev" | cut -d' ' -f2)
      if [ "$p" != "$pp" ]; then
        date=$(date -d @${t%.*} "+%Y-%m-%d %H:%M")
        echo "$f: $pp -> $p (date: $date)"
      fi
    fi
  done < "$C"
else
  echo -e "\nPas de liste précédente."
fi

cp "$C" "$P"
rm -f /tmp/add /tmp/del 2>/dev/null
echo -e "\nListe sauvegardée."