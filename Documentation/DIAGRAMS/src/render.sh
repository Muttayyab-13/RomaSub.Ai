#!/usr/bin/env bash
# Render the RomaSub.Ai UML diagrams from PlantUML sources to PNG.
#
# Requirements: Java 8+ and plantuml.jar (https://plantuml.com/download).
# No Graphviz needed — we use PlantUML's bundled Smetana layout engine.
#
# Usage:
#   PLANTUML_JAR=/path/to/plantuml.jar ./render.sh
#
# Output PNGs are written to ./out, then the 7 core diagrams are copied to
# ../ (the DIAGRAMS folder) and the sequence diagram to "../System Sequence PNG/".
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
JAR="${PLANTUML_JAR:-$HERE/plantuml.jar}"

if [[ ! -f "$JAR" ]]; then
  echo "plantuml.jar not found. Set PLANTUML_JAR=/path/to/plantuml.jar" >&2
  exit 1
fi

mkdir -p "$HERE/out"
java -jar "$JAR" -Playout=smetana -tpng -o "out" "$HERE"/*.puml

# Place core diagrams next to the rest of the DIAGRAMS set, suffixed "_v2"
# so the revised versions sit alongside the original PNGs without overwriting.
for name in UseCase Activity DFD Architecture Package Deployment StateTransition; do
  cp "$HERE/out/$name.png" "$HERE/../${name}_v2.png"
done
# The new system-sequence diagram lives with the other sequence diagrams.
cp "$HERE/out/ExportCaptionedVideo.png" "$HERE/../System Sequence PNG/ExportCaptionedVideo_v2.png"

echo "Rendered and placed all diagrams."
