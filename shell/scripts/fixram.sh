#!/bin/zsh

echo "🧠 Memory snapshot:"
vm_stat

echo ""
echo "📊 Quick status:"

# Query kernel memory pressure directly
PRESSURE_LEVEL=$(memory_pressure | awk '/System-wide memory pressure status:/ {print $5}')

echo "Memory pressure level: ${PRESSURE_LEVEL:-Normal}"

if [[ "$PRESSURE_LEVEL" == "Normal" ]]; then
    echo "🟢 Healthy"
    PRESSURE=0
elif [[ "$PRESSURE_LEVEL" == "Warn" ]]; then
    echo "🟡 Warming up"
    PRESSURE=0
else
    echo "🔴 Under pressure"
    PRESSURE=1
fi

echo ""
echo "🔍 Top memory users:"
ps -axo pid,comm,rss,%mem | sort -k3 -nr | head -15

echo ""
echo "💡 System decision:"

if [[ $PRESSURE -eq 1 ]]; then
    echo "⚠️ Cleaning helper processes..."
    pkill -f "Chrome Helper (Renderer)" && echo "✔ Chrome renderers cleared"
    pkill -f "Electron Helper (Renderer)" && echo "✔ Electron renderers cleared"
else
    echo "✅ No cleanup needed (system stable)"
fi

echo ""
echo "💽 Disk activity snapshot:"
iostat -w 1 -c 2

echo ""
echo "🧼 Flushing disk writes..."
sync

echo ""
echo "✅ Done."
echo "💡 If Word is slow: likely OneDrive/AutoSave, not RAM."
