#!/bin/bash

# ─── User-Specific Setup ────────────────────────────────────────────
USER_HOME=$(eval echo "~$USER")

# ─── Define Watch Groups and Commands ───────────────────────────────
# Each group is a "command|dir1 dir2 dir3"
WATCH_GROUPS=(
  "pkill -SIGUSR2 waybar|$USER_HOME/.config/waybar"
)

# ─── Build Full List of Dirs to Watch ───────────────────────────────
ALL_WATCH_DIRS=()

for group in "${WATCH_GROUPS[@]}"; do
  IFS='|' read -r _cmd dirs <<<"$group"
  for dir in $dirs; do
    [[ -d "$dir" ]] && [[ ! " ${ALL_WATCH_DIRS[*]} " =~ " $dir " ]] && ALL_WATCH_DIRS+=("$dir")
  done
done

# ─── Sanity Check ───────────────────────────────────────────────────
if ! command -v inotifywait &>/dev/null; then
  echo "❌ inotifywait not found. Please install inotify-tools."
  exit 1
fi

if [ ${#ALL_WATCH_DIRS[@]} -eq 0 ]; then
  echo "❌ No valid directories to watch. Exiting."
  exit 1
fi

echo "📡 Watching for changes in:"
for dir in "${ALL_WATCH_DIRS[@]}"; do
  echo "   • $dir"
done

# ─── Watch Loop ─────────────────────────────────────────────────────
inotifywait -m -r -e modify,create,delete "${ALL_WATCH_DIRS[@]}" |
  while read -r directory event filename; do
    full_path="${directory%/}/$filename"
    echo "🔔 Change detected: [$event] $full_path"

    for group in "${WATCH_GROUPS[@]}"; do
      IFS='|' read -r cmd dirs <<<"$group"
      for dir in $dirs; do
        if [[ "$full_path" == "$dir"* ]]; then
          echo "↪️ Running: $cmd"
          eval "$cmd"
          break 2 # Only run one command per event
        fi
      done
    done
  done
