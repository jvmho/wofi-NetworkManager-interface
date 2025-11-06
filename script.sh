#!/usr/bin/zsh

cache_file="/tmp/nm_wifi_cache" # Cache folder
cache_ttl=10 # Cache lifetime 
wifi_iface=$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$wifi_iface" ] && { notify-send "Wi-Fi" "Не найден Wi-Fi адаптер"; exit 1; }

if [[ -f $cache_file && $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $cache_ttl ]]; then
  wifi_list=$(<"$cache_file")
else
  wifi_list=$(nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null)
  echo "$wifi_list" > "$cache_file"
fi

networks=$(echo "$wifi_list" | awk -F: '
  {
    ssid=$1; sig=$2;
    if(sig !~ /^[0-9]+$/) sig=0;
    if(!(ssid in max) || sig>max[ssid]) max[ssid]=sig;
  }
  END {
    n=asorti(max, idx, "@val_num_desc");
    for(i=1;i<=n;i++)
      if(idx[i]!="") printf "%-70s %3s%%\n", idx[i], max[idx[i]];
  }')

[ -z "$networks" ] && {
  notify-send "Wi-Fi" "No connections was found";
  exit 1;
}

# ===== ВЫБОР СЕТИ =====
selected_line=$(printf "%s\n" "$networks" | wofi --lines=3 --dmenu --prompt "Select Wi-Fi to connect")
[ -z "$selected_line" ] && exit 0

# Извлекаем SSID
chosen_network=$(printf "%s" "$selected_line" | sed -E 's/[[:space:]]+[0-9]+%$//')
[ -z "$chosen_network" ] && {
  notify-send "Wi-Fi" "Couldn't identify the SSID";
  exit 1;
}

# ===== ПОДКЛЮЧЕНИЕ =====
known_networks=$(nmcli -t -f NAME connection show)
if echo "$known_networks" | grep -Fxq -- "$chosen_network"; then
  if nmcli connection up "$chosen_network" >/dev/null 2>&1; then
    notify-send "Wi-Fi" "Connected to $chosen_network"
    exit 0
  else
    notify-send "Wi-Fi" "Error. Couldn't connect to $chosen_network"
  fi
fi

# ===== ПАРОЛЬ =====
password=$(zenity --entry --title="Password to $chosen_network" --text="Enter the password")
[ -z "$password" ] && exit 0

if nmcli device wifi connect "$chosen_network" password "$password" >/dev/null 2>&1; then
  notify-send "Wi-Fi" "Connected to $chosen_network"
else
  notify-send "Wi-Fi" "Invalid password. Retry connection to $chosen_network"
fi

