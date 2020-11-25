<!DOCTYPE html>
<html>

<head>
  <!--  Include leaflet libs -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.0.3/dist/leaflet.css">
  <script src="https://unpkg.com/leaflet@1.0.3/dist/leaflet-src.js" crossorigin=""></script>
  <!--  Include targomo leaflet full build -->
  <script src="https://releases.targomo.com/leaflet/latest-full.min.js"></script>
  <!-- D3 libs for colors and interpolation  -->
  <script src="https://d3js.org/d3-color.v1.min.js"></script>
  <script src="https://d3js.org/d3-interpolate.v1.min.js"></script>
  <script src="https://d3js.org/d3-scale-chromatic.v1.min.js"></script>
  <!--  Include micro progress bar  -->
  <script src="https://targomo.com/developers/scripts/mipb.min.js"></script>
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
  <style>
    html,
    body {
      width: 100%;
      height: 100%;
      margin: 0;
    }

    #map {
      width: 80%;
      height: 100%;
      float: left;
    }
    #report {
      height: 100%;
    }
  </style>
</head>

<body>
  <!--  where the map will live  -->
  <div id="map"></div>
  <div id="report"></div>

  <script>
    async function initMap() {
      const client = new tgm.TargomoClient('westcentraleurope', 'myKey');

      // set the progress bar
      const pBar = new mipb({ fg: "#FF8319", style: { zIndex: 500 } });
      pBar.show();

      // map center and reachability source
      sourcePoint = { id: "point 1", lat: 52.53311053689, lng: 13.364520827508 };

      const maxTime = 1800;

      // add the map and set the initial center to berlin
      const map = L.map('map', {
        scrollWheelZoom: false
      }).setView([sourcePoint.lat, sourcePoint.lng], 11);
      const attributionText = `<a href='https://targomo.com/developers/resources/attribution/' target='_blank'>&copy; Targomo</a>`
      map.attributionControl.addAttribution(attributionText);

      // create the filter start marker
      const sourceMarker = L.marker((sourcePoint), { zIndexOffset: 1000 }).addTo(map);

      // add a basemap
      const tilesUrl = 'https://a.tile.openstreetmap.de/{z}/{x}/{y}.png';
      const tileLayer = L.tileLayer(tilesUrl, {
        tileSize: 512, zoomOffset: -1,
        minZoom: 1, crossOrigin: true
      }).addTo(map);

      const dataurl = 'resources/points.geojson';

      // get stores dataset
      const stores = await fetch(dataurl).then(async (data) => {
        return JSON.parse(await data.text());
      });
      // create the markers with a default-color
      const featureStyles = { };
      stores.features.forEach((f) => {
        featureStyles[f.id] = L.circleMarker(
            L.latLng(f.geometry.coordinates[1], f.geometry.coordinates[0]),
            geojsonMarkerOptions());
      });

      // create formatted 'targets' for analysis
      const targets = stores.features.map((store) => {
        return {
          id: store.properties['@id'],
          lat: store.geometry.coordinates[1],
          lng: store.geometry.coordinates[0]
        }
      });

      // you need to define some options for the reachability service
      const options = {
        travelType: 'car',
        maxEdgeWeight: maxTime,
        edgeWeight: 'time'
      };

      async function calcReachability(sourcePoint) {
          // calculate reachability of stores
          const reachability = await client.reachability.locations([sourcePoint], targets, options);

          // assign reachablility to original GeoJSON
          stores.features.forEach((store) => {
            const match = reachability.find((location) => {
              return location.id === store.properties['@id']
            });
            store.properties.travelTime = match ? match.travelTime : -1;
            marker = featureStyles[store.id];
            marker.setStyle({ fillColor: calcColor(store.properties.travelTime) });
          });
          sum = stores.features.map(x => x.properties.travelTime).reduce((s, x) => s + x);
          $("#report").html(`Total travel-time: ${ sum }`);
      };
      await calcReachability(sourcePoint);

      pBar.hide();

      // set style based on travelTime
      function geojsonMarkerOptions() {
        return {
          radius: 10,
          fillColor: '#666',
          color: "#000",
          weight: 0.5,
          opacity: 1,
          fillOpacity: 1
        }
      };
      function calcColor(travelTime) {
        var scaleVal = 1 - (travelTime / maxTime);
        var rgb = d3.rgb(d3.interpolateRdYlGn(scaleVal));
        return travelTime > -1 ? rgb : '#000';
      };

      // create map layer from stores data
      const storesLayer = L.geoJSON(stores, {
        pointToLayer: (feature, latlng) => {
          marker = featureStyles[feature.id];

          if (feature.properties && feature.properties['@id']) {
            marker.bindTooltip((layer) => {
                time = layer.feature.properties.travelTime > -1 ?
                            Math.round((layer.feature.properties.travelTime / 60.0) * 10) / 10 :
                            'not reachable'
                const popupContent = `<strong>${layer.feature.properties['@id']}</strong>
                                      <br><strong>Time:</strong> ${time}`;
                return popupContent;
            });
            marker.on('click', e => {
                sourcePoint = {
                    id: feature.id,
                    lat: feature.geometry.coordinates[1],
                    lng: feature.geometry.coordinates[0]
                };
                calcReachability(sourcePoint);
            });
          }

          return marker;
        }
      }).addTo(map);
    }

    initMap()

  </script>
</body>

</html>