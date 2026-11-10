#!/usr/bin/env bash
# Makes a small made-up music library (short tones with tags and cover art), so screenshots in CI have something to show.
# Usage: demo-music.sh <folder>
set -u
out="$1"
mkdir -p "$out"
i=0
while IFS='|' read -r artist album title c0 c1; do
  [ -n "$artist" ] || continue
  i=$((i + 1))
  d="$out/$artist/$album"
  mkdir -p "$d"
  cov="$d/cover.png"
  if [ ! -f "$cov" ]; then
    ffmpeg -v error -f lavfi -i "gradients=s=600x600:c0=$c0:c1=$c1:x0=0:y0=0:x1=600:y1=600" -frames:v 1 -y "$cov" \
      || ffmpeg -v error -f lavfi -i "color=c=$c0:s=600x600" -frames:v 1 -y "$cov"
  fi
  ffmpeg -v error -f lavfi -i "sine=frequency=$((180 + i * 15)):duration=$((150 + i * 7))" -i "$cov" \
    -map 0:a -map 1:v -c:a flac -c:v png -disposition:v attached_pic \
    -metadata title="$title" -metadata artist="$artist" -metadata album="$album" -metadata track="$i" -metadata date=2024 \
    -y "$d/$(printf %02d "$i") $title.flac"
done <<'LIST'
Halcyon Static|Night Drive|Headlights|0xFFB36B|0x4A0B16
Halcyon Static|Night Drive|Glass Coastline|0xFFB36B|0x4A0B16
Halcyon Static|Night Drive|Overpass|0xFFB36B|0x4A0B16
Tidewell|Paper Lanterns|Paper Lanterns|0xFDE047|0x7C2D12
Tidewell|Paper Lanterns|Lantern Smoke|0xFDE047|0x7C2D12
Oslo Park|Low Orbit|Low Orbit|0xE4E4E7|0x18181B
Oslo Park|Low Orbit|Undertow|0xE4E4E7|0x18181B
Mara Vey|Greenhouse|Greenhouse|0x4ADE80|0x022C22
Mara Vey|Greenhouse|Fern Light|0x4ADE80|0x022C22
Kite District|Neon Psalms|Neon Psalms|0xFBCFE8|0x500724
Kite District|Neon Psalms|Static Choir|0xFBCFE8|0x500724
Sena Ito|Blue Hour|Blue Hour|0x7DD3FC|0x0F172A
LIST
ls -R "$out" | head -40
