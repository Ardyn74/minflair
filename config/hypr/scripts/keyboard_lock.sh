#!/bin/bash

MODE="${1:-caps}"

# Breve pausa para asegurar que el sistema procese el evento de teclado
sleep 0.04

resolve_state() {
  local mode="$1"
  python3 -c "
import sys, json, os, subprocess

mode = '$mode'
prop = 'numLock' if mode == 'num' else 'capsLock'
map_file = f'/tmp/hypr_{mode}_kb_map.json'
last_file = f'/tmp/hypr_{mode}_last_state'

keyboards = []
try:
    out = subprocess.check_output(['hyprctl', 'devices', '-j'], timeout=1)
    data = json.loads(out)
    keyboards = [
        k for k in data.get('keyboards', [])
        if not any(ign in k.get('name', '') for ign in ['video-bus', 'power-button', 'sleep-button', 'wmi', 'radio'])
    ]
except Exception:
    pass

curr_map = {k['name']: bool(k.get(prop, False)) for k in keyboards}

prev_map = {}
if os.path.exists(map_file):
    try:
        with open(map_file) as f:
            prev_map = json.load(f)
    except Exception:
        pass

with open(map_file, 'w') as f:
    json.dump(curr_map, f)

# 1. Teclado que cambio de estado
changed = [name for name, val in curr_map.items() if name in prev_map and prev_map[name] != val]
if changed:
    state = curr_map[changed[0]]
    res = 'ON' if state else 'OFF'
    with open(last_file, 'w') as f:
        f.write(res)
    print(res)
    sys.exit(0)

# 2. Alternancia sobre ultimo estado si ningun teclado reflejo cambio en json
if os.path.exists(last_file):
    try:
        with open(last_file) as f:
            last = f.read().strip()
        res = 'OFF' if last == 'ON' else 'ON'
        with open(last_file, 'w') as f:
            f.write(res)
        print(res)
        sys.exit(0)
    except Exception:
        pass

# 3. Estado inicial por defecto
main_kb = next((k for k in keyboards if k.get('main')), (keyboards[0] if keyboards else {}))
st = main_kb.get(prop, False)
res = 'ON' if st else 'OFF'
with open(last_file, 'w') as f:
    f.write(res)
print(res)
"
}

STATE="$(resolve_state "$MODE")"

if [ "$MODE" = "num" ]; then
  if [ "$STATE" = "ON" ]; then
    qs ipc call osd showMessage "Num Lock" "ON" "lock" 2>/dev/null || true
  else
    qs ipc call osd showMessage "Num Lock" "OFF" "lock" 2>/dev/null || true
  fi
else
  if [ "$STATE" = "ON" ]; then
    qs ipc call osd showMessage "Caps Lock" "ON" "caps-lock-filled" 2>/dev/null || true
  else
    qs ipc call osd showMessage "Caps Lock" "OFF" "caps-lock" 2>/dev/null || true
  fi
fi
