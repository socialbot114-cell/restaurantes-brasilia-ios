# Restaurant photo sources and permissions

Only photos with documented redistribution permission are bundled in
`Resources/Assets.xcassets`. Restaurants without an authorized photo use the
app's native category artwork. The app does not load restaurant photos from
remote sources.

## Confirmed asset

| Restaurant | Asset | Source | Permission record |
| --- | --- | --- | --- |
| Verona Ristorante | `VeronaRistorante` (`894 × 503`, JPEG) | [Tripadvisor photo](https://dynamic-media-cdn.tripadvisor.com/media/photo-o/0a/93/30/69/fachada-interna.jpg?w=900&h=700&s=1) · [restaurant page](https://www.tripadvisor.com.br/Restaurant_Review-g303322-d25431086-Reviews-Verona_Ristorante_Brasilia-Brasilia_Federal_District.html) | User confirmed explicit authorization from the Tripadvisor team at an in-person meeting on 2026-09-24; app attribution: Tripadvisor |

## Removed assets — Duo Gourmet

The **239** Duo Gourmet covers were removed from the catalog and asset bundle
for release 1.1.1. Their source database records the restriction:
*"Conteúdo proprietário – uso interno/referência. Não redistribuir."* Attribution
alone did not grant permission to redistribute them. These records now use the
native artwork for their category and contain no restaurant photo metadata.

Catalog facts such as restaurant names, addresses, categories, ratings, and
source links remain separate from these removed image assets.

## How the metadata is produced

Catalog facts and any explicitly authorized photos come from the shared research
pipeline in `/home/richard/Documentos/db brasilia`:

```bash
python3 _tools/scrape_duogourmet.py          # catalog data
python3 _tools/download_media.py --only-missing
python3 _tools/optimize_images.py            # WebP, max 1200 px
```

Then, from this project, remove any photo metadata without documented rights
and import only assets still explicitly referenced by the catalog:

```bash
python3 tools/apply_photo_metadata.py        # removes photo_* fields without written rights
python3 tools/import_photo_assets.py         # builds Assets.xcassets/<photo_asset>.imageset
```

`apply_photo_metadata.py` preserves records marked `user-confirmed-authorized`
and strips photo metadata from every other catalog entry.

Add additional images only with a confirmed restaurant match and written
redistribution permission. Record each mapping and permission status here and
in the corresponding catalog entry (`photo_asset`, `photo_source_url`,
`photo_rights_status`, `photo_attribution`). Source attribution alone is not
permission.
