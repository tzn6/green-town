#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$(dirname "$0")"

cp -f world_scene.tscn world.tscn

if grep -q '^run/main_scene=' project.godot; then
  sed -i 's|^run/main_scene=.*|run/main_scene="res://world.tscn"|' project.godot
elif grep -q '^\[application\]' project.godot; then
  sed -i '/^\[application\]/a run/main_scene="res://world.tscn"' project.godot
else
  printf '\n[application]\nrun/main_scene="res://world.tscn"\n' >> project.godot
fi

echo "✅ Большая карта установлена. Открой проект в Godot и нажми ▶"
