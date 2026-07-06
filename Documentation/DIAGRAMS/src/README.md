# DIAGRAMS — PlantUML sources

Editable source for the RomaSub.Ai UML diagrams. These `.puml` files render to the
`_v2` PNGs in the parent `DIAGRAMS/` folder — the revised versions sit **alongside**
the original draw.io PNGs (which are left untouched). Unlike the originals, these are
version-controlled text, so future changes are a source edit + re-render.

## What's here

| Source | Renders to | Notes |
| --- | --- | --- |
| `UseCase.puml` | `../UseCase_v2.png` | Adds **Export Captioned Video (MP4)** use case |
| `Activity.puml` | `../Activity_v2.png` | Adds captioned-video export branch (hardsub/softsub → FFmpeg) |
| `DFD.puml` | `../DFD_v2.png` | Adds process **7.0 Video Export (FFmpeg)**, media store, `.mp4` output |
| `Architecture.puml` | `../Architecture_v2.png` | Adds **Video Export Service**; FFmpeg now audio-extract **+ video-render** |
| `Package.puml` | `../Package_v2.png` | Adds **VideoExportService** + FFmpeg to the service layer |
| `Deployment.puml` | `../Deployment_v2.png` | FFmpeg node now renders video; MP4 returns to client |
| `StateTransition.puml` | `../StateTransition_v2.png` | Splits export into `ExportingText` and `RenderingVideo` |
| `ExportCaptionedVideo.puml` | `../System Sequence PNG/ExportCaptionedVideo_v2.png` | New sequence for `GET /subtitles/{id}/export-video?mode=` |

## Render

```bash
# Download plantuml.jar once from https://plantuml.com/download
PLANTUML_JAR=/path/to/plantuml.jar ./render.sh
```

No Graphviz required — rendering uses PlantUML's bundled Smetana layout
(`-Playout=smetana`). Green-highlighted nodes mark the captioned-video (video
download) feature added in this revision.
