#!/bin/zsh

echo "🧠 Memory snapshot:"
vm_stat
echo ""

echo "🔍 Top memory users:"
ps -axo pid,comm,rss,%mem | sort -k3 -nr | head -15
echo ""

echo "💽 Disk activity snapshot:"
iostat -w 1 -c 2
echo ""

echo "🧼 Flushing disk writes..."
sync

echo ""
echo "✅ Done."
echo "💡 If Word is slow: likely OneDrive/AutoSave, not RAM."
