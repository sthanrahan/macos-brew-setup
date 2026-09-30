#!/bin/bash

echo "🧠 ===== MAC MEMORY DIAGNOSTIC ====="
echo ""

# --- Memory Overview ---
echo "📊 MEMORY OVERVIEW"
vm_stat | awk '
  /page size/ {ps=$8} 
  /Pages free/ {free=$3*ps/1024/1024} 
  /Pages active/ {active=$3*ps/1024/1024} 
  /Pages inactive/ {inactive=$3*ps/1024/1024} 
  /Pages speculative/ {spec=$3*ps/1024/1024} 
  /Pages wired/ {wired=$3*ps/1024/1024} 
  /Pages occupied by compressor/ {comp=$5*ps/1024/1024} 
  END {
    total = free + active + inactive + spec + wired;
    used = active + inactive + spec + wired;
    printf "Page size: %d bytes\n", ps;
    printf "Total RAM (approx): %.2f MB\n", total;
    printf "Used RAM:           %.2f MB\n", used;
    printf "Free RAM:           %.2f MB\n", free;
    printf "Compressed:         %.2f MB\n", comp;
  }'

echo ""

# --- Swap & Pressure ---
echo "💾 SWAP / MEMORY PRESSURE"
swapinfo=$(sysctl vm.swapusage)
echo "$swapinfo"
vm_stat | grep -E "Pages purgeable"

# Calculate simple free percentage
FREE_PCT=$(vm_stat | awk '
  /page size/ {ps=$8}
  /Pages free/ {free=$3*ps}
  /Pages active/ {act=$3*ps}
  /Pages inactive/ {inac=$3*ps}
  /Pages speculative/ {sp=$3*ps}
  /Pages wired/ {w=$3*ps}
  END {
    tot = free + act + inac + sp + w;
    if (tot > 0) printf "%d", (free / tot) * 100; else print 0;
  }')
echo "System-wide memory free percentage: $FREE_PCT%"

echo ""

# --- Top Memory Consumers ---
echo "🔥 TOP MEMORY CONSUMERS (REAL RESIDENT SIZE)"
printf "%-30s %s\n" "COMMAND" "MEMORY"
ps -axc -o comm,rss | tail +2 | awk '{
  mem[$1]+=$2
}
END {
  for (i in mem) {
    printf "%-30s %.2f MB\n", i, mem[i]/1024
  }
}' | grep -vE "^(kernel_task|launchd|WindowServer)" | sort -k2 -nr | head -15

echo ""

# --- Disk I/O ---
echo "💽 DISK I/O SNAPSHOT"
iostat -d 1 2

echo ""

# --- Quick Diagnosis ---
echo "🧭 QUICK DIAGNOSIS"

FREE_PAGES=$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')
COMPRESSED_PAGES=$(vm_stat | awk '/Pages occupied by compressor/ {gsub("\\.","",$5); print $5}')

if [[ "$FREE_PAGES" -lt 50000 ]]; then
  echo "⚠️  Low free memory"
else
  echo "✅ Free memory OK"
fi

# Aggressive threshold: > 200000 pages (~3.2GB compressed data)
if [[ "$COMPRESSED_PAGES" -gt 200000 ]]; then
  echo "⚠️  Heavy compression (RAM pressure likely)"
else
  echo "✅ Compression within normal range"
fi

# Safe Regex for Swap parsing via sed
SWAP_USED_MB=$(echo "$swapinfo" | sed -E 's/.*used = ([0-9.]+).*/\1/')
# Direct integer comparison
SWAP_INT=${SWAP_USED_MB%.*}

# Aggressive threshold: > 500 MB swap used
if [[ -n "$SWAP_INT" && "$SWAP_INT" -gt 500 ]]; then
  echo "⚠️  High swap usage ($SWAP_USED_MB MB)"
else
  echo "✅ Swap usage moderate"
fi

echo ""
echo "✅ Done."
