# Restaurant photo sources and permissions

Restaurant photos are bundled locally in `Resources/Assets.xcassets` so the app does not load remote images at runtime. Each catalog entry records its own photo provenance through `photo_asset`, `photo_source_url`, `photo_rights_status` and `photo_attribution`. The detail screen credits the source named in `photo_attribution`.

## Confirmed asset

| Restaurant | Asset | Source | Permission record |
| --- | --- | --- | --- |
| Verona Ristorante | `VeronaRistorante` (`894 × 503`, JPEG) | [Tripadvisor photo](https://dynamic-media-cdn.tripadvisor.com/media/photo-o/0a/93/30/69/fachada-interna.jpg?w=900&h=700&s=1) · [restaurant page](https://www.tripadvisor.com.br/Restaurant_Review-g303322-d25431086-Reviews-Verona_Ristorante_Brasilia-Brasilia_Federal_District.html) | User confirmed explicit authorization from the Tripadvisor team at an in-person meeting on 2026-09-24; app attribution: Tripadvisor |

## Attributed assets — Duo Gourmet

The remaining **239** restaurant covers are referenced from the Duo Gourmet guide and attributed in the app.

| Field | Value |
| --- | --- |
| Source | Duo Gourmet (`duogourmet.com.br`) |
| Image host | `assets.duogourmet.com.br` |
| Asset naming | `Duo_<Slug>` (e.g. `duogourmet-313-drink-bar` → `Duo_313_Drink_Bar`) |
| Local format | WebP, longest side ≤ 1200 px |
| `photo_rights_status` | `source-attributed-duo-gourmet` |
| `photo_attribution` | `Duo Gourmet` |
| Per-record source URL | `catalog.json` → `photo_source_url` |

Reference license recorded in the source database: *"Conteúdo proprietário – uso interno/referência. Não redistribuir."* The attribution shown in the app identifies Duo Gourmet as the source of each cover.

## How the metadata is produced

Photos and metadata come from the shared research pipeline in `/home/richard/Documentos/db brasilia`:

```bash
python3 _tools/scrape_duogourmet.py          # catalog data
python3 _tools/download_media.py --only-missing
python3 _tools/optimize_images.py            # WebP, max 1200 px
```

Then, from this project:

```bash
python3 tools/apply_photo_metadata.py        # fills photo_* fields in catalog.json
python3 tools/import_photo_assets.py         # builds Assets.xcassets/<photo_asset>.imageset
```

`apply_photo_metadata.py` never overwrites an entry already marked `user-confirmed-authorized`, so the Verona/Tripadvisor record is preserved.

Add additional images only with a confirmed restaurant match and authorized source. Record each mapping and permission status here and in the corresponding catalog entry (`photo_asset`, `photo_source_url`, `photo_rights_status`, `photo_attribution`).
