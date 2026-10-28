# Nordschleife geographic data

Route: © OpenStreetMap contributors, ODbL 1.0.
https://www.openstreetmap.org/copyright
https://opendatacommons.org/licenses/odbl/1-0/

osm-ways.json contains the 53 connected original clockwise ways (T13 start).
Downloaded 2026-10-28 using six small OSM API 0.6 map extracts after Overpass
was unavailable. circuit.json contains the derived database; that database is
also offered under ODbL 1.0. GPL licensing of the independent game code does
not replace the database licence. Both files are distributed in the game export.
All original way/node IDs and the input digest are preserved for reproduction.

Elevations: Terrain Tiles (Mapzen), accessed 2026-10-28 from
https://registry.opendata.aws/terrain-tiles/ . N50E006 / N50E007 Skadi HGT.
https://github.com/tilezen/joerd/blob/master/docs/attribution.md
Europe terrain data produced using Copernicus data and information funded by
the European Union - EU-DEM layers; SRTM data courtesy of the U.S. Geological
Survey / NASA / NGA. Source dataset terms remain applicable to elevation data.
Elevation has been bilinearly sampled and smoothed over approximately 45 m;
this is terrain data, not a laser scan of the racing surface. No satellite image,
commercial game mesh, official logo, advertising texture or proprietary map
artwork is included. Objects/materials in the game are original or the existing
Kenney CC0 assets. Authored sub-DEM crest/banking detail is described in NORDSCHLEIFE.md.

Reproduction: tools/prepare_nordschleife.py consumes ordered.json (=osm-ways.json)
and the two HGT source tiles. Source URLs:
https://s3.amazonaws.com/elevation-tiles-prod/skadi/N50/N50E006.hgt.gz
https://s3.amazonaws.com/elevation-tiles-prod/skadi/N50/N50E007.hgt.gz
