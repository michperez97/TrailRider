import fs from "node:fs/promises";
import https from "node:https";
import path from "node:path";

const projectId = "trailrider";
const userId = "cstvf3n3spSOpzWI60w54uKBOxK2";
const credentialPath =
  "/Users/michelperezmachado/Library/Application Support/google-vscode-extension/auth/application_default_credentials.json";
const outputPath = path.resolve("TrailRider/Exports/ride-tracks.html");
const trailMapDataPath = path.resolve("TrailRider/TrailRider/Models/TrailMapData.swift");

function postForm(url, data) {
  return request(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(data).toString(),
  });
}

function postJson(url, token, data) {
  return request(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
}

function request(url, options) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        let parsed;
        try {
          parsed = JSON.parse(body);
        } catch {
          parsed = body;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          return;
        }
        resolve(parsed);
      });
    });
    req.on("error", reject);
    req.end(options.body);
  });
}

function numberValue(value) {
  if (!value) return 0;
  if (value.doubleValue !== undefined) return Number(value.doubleValue);
  if (value.integerValue !== undefined) return Number(value.integerValue);
  return 0;
}

function stringValue(value) {
  return value?.stringValue ?? "";
}

function timestampValue(value) {
  return value?.timestampValue ?? "";
}

function routePointFromMap(value) {
  const fields = value?.mapValue?.fields ?? {};
  const latitude = numberValue(fields.latitude);
  const longitude = numberValue(fields.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude === 0 && longitude === 0) return null;
  return [
    latitude,
    longitude,
    numberValue(fields.altitude),
    numberValue(fields.timestamp),
    fields.heartRate ? numberValue(fields.heartRate) : null,
  ];
}

function routePointFromGeoPoint(value) {
  const point = value?.geoPointValue;
  if (!point) return null;
  if (point.latitude === 0 && point.longitude === 0) return null;
  return [point.latitude, point.longitude, null, null, null];
}

function routePoints(fields) {
  const detailed = fields.routePoints?.arrayValue?.values ?? [];
  if (detailed.length > 0) {
    return detailed.map(routePointFromMap).filter(Boolean);
  }

  const polyline = fields.routePolyline?.arrayValue?.values ?? [];
  return polyline.map(routePointFromGeoPoint).filter(Boolean);
}

function safeJsonForHtml(value) {
  return JSON.stringify(value).replaceAll("<", "\\u003c");
}

function formatMiles(value) {
  return Number(value || 0).toFixed(2);
}

function formatDuration(seconds) {
  const value = Number(seconds || 0);
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const secs = value % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }
  return `${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
}

function extractKnownRoutes(source) {
  const routes = [];
  const routePattern =
    /TrailRoute\(name: "([^"]+)", difficulty: "([^"]+)", color: \.([a-zA-Z]+), coordinates: \[([\s\S]*?)\]\)/g;
  const coordinatePattern =
    /CLLocationCoordinate2D\(latitude: ([^,]+), longitude: ([^)]+)\)/g;
  let match;
  while ((match = routePattern.exec(source)) !== null) {
    const coordinates = [];
    let coordinateMatch;
    while ((coordinateMatch = coordinatePattern.exec(match[4])) !== null) {
      coordinates.push([Number(coordinateMatch[1]), Number(coordinateMatch[2])]);
    }
    if (coordinates.length > 1) {
      routes.push({
        name: match[1],
        difficulty: match[2],
        color: match[3],
        coordinates,
      });
    }
  }
  return routes;
}

function buildHtml(rides, knownRoutes) {
  const totalMiles = rides.reduce((sum, ride) => sum + ride.distanceMiles, 0);
  const totalPoints = rides.reduce((sum, ride) => sum + ride.points.length, 0);
  const latest = rides[0]?.startTime ?? "";
  const earliest = rides.at(-1)?.startTime ?? "";
  const rideJson = safeJsonForHtml(rides);
  const knownRouteJson = safeJsonForHtml(knownRoutes);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TrailRider Ride Tracks</title>
  <link rel="icon" href="data:,">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
  <style>
    :root {
      color-scheme: dark;
      --bg: #0a0d0a;
      --panel: #111811;
      --panel-2: #182217;
      --panel-3: #202c1f;
      --text: #f3faef;
      --muted: #aab8a4;
      --line: #324333;
      --accent: #52f28f;
      --accent-2: #f3c14b;
      --danger: #ff7667;
      --known: #9eb6ff;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      overflow: hidden;
    }

    .app {
      display: grid;
      grid-template-columns: 420px minmax(0, 1fr);
      height: 100vh;
    }

    aside {
      border-right: 1px solid var(--line);
      background: var(--panel);
      overflow: auto;
      padding: 18px 18px 24px;
    }

    h1 {
      font-size: 22px;
      margin: 0 0 6px;
      letter-spacing: 0;
    }

    .subhead {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.4;
      margin-bottom: 16px;
    }

    .selected-panel,
    .stats {
      display: grid;
      gap: 8px;
      margin-bottom: 14px;
    }

    .selected-panel {
      background: linear-gradient(135deg, rgba(82, 242, 143, 0.14), rgba(243, 193, 75, 0.08));
      border: 1px solid rgba(82, 242, 143, 0.38);
      border-radius: 8px;
      padding: 12px;
    }

    .selected-title {
      font-weight: 800;
      line-height: 1.25;
      margin-bottom: 8px;
    }

    .selected-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }

    .stat {
      background: var(--panel-2);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px;
    }

    .stat strong {
      display: block;
      font-size: 18px;
    }

    .stat span {
      color: var(--muted);
      font-size: 12px;
    }

    .controls {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px;
      margin-bottom: 12px;
    }

    button {
      appearance: none;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel-2);
      color: var(--text);
      padding: 8px 10px;
      font: inherit;
      font-size: 13px;
      cursor: pointer;
    }

    button:hover { border-color: var(--accent); }
    button.primary {
      background: var(--accent);
      border-color: var(--accent);
      color: #051006;
      font-weight: 800;
    }

    .ride-list {
      display: grid;
      gap: 8px;
      margin-bottom: 16px;
    }

    .ride {
      width: 100%;
      text-align: left;
      border-color: var(--line);
      background: #151d15;
    }

    .ride.active {
      border-color: var(--accent);
      box-shadow: inset 4px 0 0 var(--accent);
    }

    .ride-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 700;
      margin-bottom: 4px;
    }

    .swatch {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      flex: 0 0 auto;
    }

    .ride-meta {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.4;
    }

    .section-heading {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin: 18px 0 8px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }

    .segment-list {
      display: grid;
      gap: 7px;
    }

    .segment {
      border: 1px solid var(--line);
      background: #121a12;
      border-radius: 8px;
      padding: 9px;
      text-align: left;
    }

    .segment:hover { border-color: var(--accent-2); }

    .segment strong {
      display: block;
      font-size: 13px;
      margin-bottom: 3px;
    }

    .segment span {
      display: block;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.35;
    }

    .map-shell {
      display: grid;
      grid-template-rows: minmax(320px, 58fr) minmax(260px, 42fr);
      min-width: 0;
      min-height: 0;
    }

    .app.focus-3d {
      display: block;
      position: fixed;
      inset: 0;
      z-index: 1000;
      height: 100vh;
      background: #070a08;
    }

    .app.focus-3d aside,
    .app.focus-3d .map-region {
      display: none;
    }

    .app.focus-3d .map-shell {
      display: block;
      height: 100vh;
    }

    .app.focus-3d .elevation-region {
      height: 100vh;
      border-top: 0;
    }

    .map-region,
    .elevation-region {
      position: relative;
      min-height: 0;
      overflow: hidden;
    }

    .elevation-region {
      border-top: 1px solid var(--line);
      background: #070a08;
    }

    #map {
      height: 100%;
      width: 100%;
      background: #0b100b;
    }

    #elevation3d {
      height: 100%;
      width: 100%;
      background: #070a08;
    }

    .elevation-hud,
    .elevation-scale {
      position: absolute;
      z-index: 10;
      border: 1px solid rgba(255,255,255,0.16);
      background: rgba(7, 10, 8, 0.78);
      backdrop-filter: blur(12px);
      border-radius: 8px;
      box-shadow: 0 18px 38px rgba(0,0,0,0.32);
    }

    .elevation-hud {
      top: 14px;
      left: 16px;
      width: min(390px, calc(100% - 32px));
      padding: 12px;
    }

    .elevation-title {
      font-weight: 900;
      margin-bottom: 4px;
    }

    .elevation-meta,
    .elevation-note {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.4;
    }

    .elevation-scale {
      right: 14px;
      bottom: 14px;
      display: grid;
      gap: 6px;
      padding: 10px;
      min-width: 150px;
      font-size: 12px;
      color: var(--muted);
    }

    .scale-row {
      display: grid;
      grid-template-columns: 18px 1fr;
      align-items: center;
      gap: 8px;
    }

    .scale-swatch {
      width: 18px;
      height: 8px;
      border-radius: 999px;
    }

    .elevation-focus-button {
      position: absolute;
      z-index: 20;
      top: 14px;
      right: 14px;
      min-width: 98px;
      border-color: rgba(82, 242, 143, 0.55);
      background: rgba(82, 242, 143, 0.16);
      font-weight: 800;
    }

    .app.focus-3d .elevation-focus-button {
      background: var(--accent);
      border-color: var(--accent);
      color: #051006;
    }

    .app.focus-3d .elevation-hud {
      top: 14px;
      left: 14px;
      width: min(430px, calc(100% - 140px));
    }

    .map-hud {
      position: absolute;
      z-index: 600;
      left: 16px;
      bottom: 20px;
      width: min(420px, calc(100% - 32px));
      border: 1px solid rgba(255,255,255,0.18);
      background: rgba(9, 13, 9, 0.84);
      backdrop-filter: blur(14px);
      border-radius: 8px;
      padding: 12px;
      box-shadow: 0 18px 40px rgba(0,0,0,0.38);
      pointer-events: none;
    }

    .hud-title {
      font-weight: 800;
      margin-bottom: 4px;
    }

    .hud-meta {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.45;
    }

    .leaflet-popup-content-wrapper,
    .leaflet-popup-tip {
      background: #172017;
      color: var(--text);
    }

    .popup-title {
      font-weight: 800;
      margin-bottom: 4px;
    }

    .start-marker,
    .finish-marker,
    .mile-marker,
    .known-label {
      display: grid;
      place-items: center;
      border-radius: 999px;
      color: #061006;
      font-weight: 900;
      border: 2px solid rgba(0,0,0,0.55);
      box-shadow: 0 8px 22px rgba(0,0,0,0.5);
    }

    .start-marker {
      width: 34px;
      height: 34px;
      background: var(--accent);
      font-size: 14px;
    }

    .finish-marker {
      width: 34px;
      height: 34px;
      background: var(--danger);
      font-size: 14px;
    }

    .mile-marker {
      min-width: 42px;
      height: 24px;
      padding: 0 7px;
      background: var(--accent-2);
      font-size: 11px;
      white-space: nowrap;
    }

    .direction-arrow {
      width: 0;
      height: 0;
      border-left: 9px solid transparent;
      border-right: 9px solid transparent;
      border-bottom: 22px solid var(--accent);
      filter: drop-shadow(0 2px 3px rgba(0,0,0,0.85));
      transform-origin: 50% 62%;
    }

    .known-label {
      width: auto;
      height: 22px;
      padding: 0 8px;
      background: rgba(158, 182, 255, 0.92);
      color: #071022;
      font-size: 11px;
      border-radius: 6px;
      white-space: nowrap;
    }

    @media (max-width: 760px) {
      body { overflow: auto; }
      .app {
        display: block;
        height: auto;
      }
      aside {
        height: 44vh;
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }
      .map-shell {
        grid-template-rows: 34vh 32vh;
      }
      .map-hud { bottom: 10px; }
      .elevation-hud {
        top: 10px;
        left: 10px;
        width: calc(100% - 20px);
        padding: 9px;
      }
      .elevation-focus-button {
        top: 10px;
        right: 10px;
        min-width: 86px;
        padding: 8px 9px;
      }
      .app.focus-3d {
        overflow: hidden;
      }
      .app.focus-3d .elevation-hud {
        width: calc(100% - 112px);
      }
      .elevation-note { display: none; }
      .elevation-scale { display: none; }
    }
  </style>
</head>
<body>
  <div class="app">
    <aside>
      <h1>TrailRider Tracks</h1>
      <div class="subhead">
        Exported from Firestore rides for mich97. Latest saved ride: ${latest ? new Date(latest).toLocaleString() : "none"}.
      </div>
      <div class="stats">
        <div class="stat"><strong>${rides.length}</strong><span>rides</span></div>
        <div class="stat"><strong>${formatMiles(totalMiles)}</strong><span>miles</span></div>
        <div class="stat"><strong>${totalPoints.toLocaleString()}</strong><span>GPS points</span></div>
        <div class="stat"><strong>${earliest ? new Date(earliest).toLocaleDateString() : "-"}</strong><span>first saved</span></div>
      </div>
      <div class="selected-panel">
        <div id="selectedTitle" class="selected-title"></div>
        <div class="selected-grid">
          <div class="stat"><strong id="selectedMiles">-</strong><span>miles</span></div>
          <div class="stat"><strong id="selectedDuration">-</strong><span>duration</span></div>
          <div class="stat"><strong id="selectedSpeed">-</strong><span>avg mph</span></div>
          <div class="stat"><strong id="selectedPoints">-</strong><span>points</span></div>
          <div class="stat"><strong id="selectedAltitude">-</strong><span>altitude range</span></div>
          <div class="stat"><strong id="selectedClimb">-</strong><span>climb</span></div>
          <div class="stat"><strong id="selectedDrop">-</strong><span>drop</span></div>
          <div class="stat"><strong id="selectedAltPoints">-</strong><span>alt samples</span></div>
        </div>
      </div>
      <div class="controls">
        <button id="focusSelected" class="primary" type="button">Focus selected</button>
        <button id="toggleHistory" type="button">Hide history</button>
        <button id="toggleKnown" type="button">Hide known trails</button>
        <button id="toggleMarkers" type="button">Hide mile markers</button>
        <button id="focus3dFromSidebar" type="button">3D only</button>
      </div>
      <div class="section-heading">Saved rides</div>
      <div id="rideList" class="ride-list"></div>
      <div class="section-heading">Selected ride sections</div>
      <div id="segmentList" class="segment-list"></div>
    </aside>
    <main class="map-shell">
      <section class="map-region">
        <div id="map"></div>
        <div class="map-hud">
          <div id="hudTitle" class="hud-title">Hover over the selected route</div>
          <div id="hudMeta" class="hud-meta">Direction arrows point forward along the ride. Yellow markers show half-mile checkpoints.</div>
        </div>
      </section>
      <section class="elevation-region">
        <div id="elevation3d"></div>
        <button id="toggle3dFocus" class="elevation-focus-button" type="button">3D only</button>
        <div class="elevation-hud">
          <div id="elevationTitle" class="elevation-title">3D elevation profile</div>
          <div id="elevationMeta" class="elevation-meta">Same route shape as the map. Yellow cones point forward.</div>
          <div id="elevationNote" class="elevation-note"></div>
        </div>
        <div class="elevation-scale">
          <div class="scale-row"><span class="scale-swatch" style="background:#ff6b48"></span><span>climbing</span></div>
          <div class="scale-row"><span class="scale-swatch" style="background:#56f094"></span><span>mostly flat</span></div>
          <div class="scale-row"><span class="scale-swatch" style="background:#62a7ff"></span><span>descending</span></div>
          <div class="scale-row"><span class="scale-swatch" style="background:#f3c14b"></span><span>direction / mile guide</span></div>
        </div>
      </section>
    </main>
  </div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script type="importmap">
    {
      "imports": {
        "three": "https://unpkg.com/three@0.165.0/build/three.module.js",
        "three/addons/": "https://unpkg.com/three@0.165.0/examples/jsm/"
      }
    }
  </script>
  <script type="module">
    import * as THREE from "three";
    import { OrbitControls } from "three/addons/controls/OrbitControls.js";

    const rides = ${rideJson};
    const knownRoutes = ${knownRouteJson};
    const colors = ["#52f28f", "#f3c14b", "#64b5ff", "#ff7f6e", "#d080ff", "#7ee0d6", "#c0d75a", "#ff9ad5"];
    const appRoot = document.querySelector(".app");
    const map = L.map("map", { preferCanvas: true }).setView([25.885, -80.28], 13);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(map);

    let selectedIndex = 0;
    let historyVisible = true;
    let knownVisible = true;
    let markersVisible = true;
    let selectedLayer = null;
    let selectedHalo = null;
    let currentElevationVisualHeight = 0;
    let selectedMarkers = L.layerGroup().addTo(map);
    let selectedArrows = L.layerGroup().addTo(map);
    const historyGroup = L.layerGroup().addTo(map);
    const knownGroup = L.layerGroup().addTo(map);
    const allBounds = [];

    function radians(value) { return value * Math.PI / 180; }
    function degrees(value) { return value * 180 / Math.PI; }
    function distanceMeters(a, b) {
      const radius = 6371000;
      const dLat = radians(b[0] - a[0]);
      const dLon = radians(b[1] - a[1]);
      const lat1 = radians(a[0]);
      const lat2 = radians(b[0]);
      const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
      return 2 * radius * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
    }
    function bearing(a, b) {
      const lat1 = radians(a[0]);
      const lat2 = radians(b[0]);
      const dLon = radians(b[1] - a[1]);
      const y = Math.sin(dLon) * Math.cos(lat2);
      const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
      return (degrees(Math.atan2(y, x)) + 360) % 360;
    }
    function compass(angle) {
      const labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
      return labels[Math.round(angle / 45) % 8];
    }
    function formatTime(seconds) {
      if (!Number.isFinite(seconds)) return "-";
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      const s = Math.floor(seconds % 60);
      if (h > 0) return \`\${h}:\${String(m).padStart(2, "0")}:\${String(s).padStart(2, "0")}\`;
      return \`\${String(m).padStart(2, "0")}:\${String(s).padStart(2, "0")}\`;
    }
    function routeLatLngs(ride) {
      return ride.points.map((point) => [point[0], point[1]]);
    }
    function routeMetrics(ride) {
      const metrics = [{ index: 0, meters: 0 }];
      let total = 0;
      for (let index = 1; index < ride.points.length; index += 1) {
        total += distanceMeters(ride.points[index - 1], ride.points[index]);
        metrics.push({ index, meters: total });
      }
      return metrics;
    }
    function feet(meters) {
      return meters * 3.28084;
    }
    function formatFeet(meters) {
      if (!Number.isFinite(meters)) return "-";
      return \`\${Math.round(feet(meters)).toLocaleString()} ft\`;
    }
    function formatFeetRange(minMeters, maxMeters) {
      if (!Number.isFinite(minMeters) || !Number.isFinite(maxMeters)) return "-";
      return \`\${Math.round(feet(minMeters)).toLocaleString()} to \${Math.round(feet(maxMeters)).toLocaleString()} ft\`;
    }
    function altitudeValue(point) {
      const value = point?.[2];
      return Number.isFinite(value) ? value : null;
    }
    function smoothedAltitudes(points) {
      const raw = points.map(altitudeValue);
      const finite = raw.filter(Number.isFinite);
      if (finite.length < 2) return raw;
      return raw.map((value, index) => {
        if (value === null) return null;
        const windowValues = [];
        for (let offset = -2; offset <= 2; offset += 1) {
          const candidate = raw[index + offset];
          if (Number.isFinite(candidate)) windowValues.push(candidate);
        }
        return windowValues.reduce((sum, item) => sum + item, 0) / windowValues.length;
      });
    }
    function elevationStats(ride) {
      const smoothed = smoothedAltitudes(ride.points);
      const samples = smoothed.filter(Number.isFinite);
      if (samples.length < 2) {
        return {
          hasAltitude: false,
          samples: samples.length,
          total: ride.points.length,
          min: null,
          max: null,
          climb: 0,
          drop: 0,
          smoothed,
        };
      }
      let climb = 0;
      let drop = 0;
      let previous = samples[0];
      for (const current of samples.slice(1)) {
        const delta = current - previous;
        if (delta > 0.3) climb += delta;
        if (delta < -0.3) drop += Math.abs(delta);
        previous = current;
      }
      const min = Math.min(...samples);
      const max = Math.max(...samples);
      return {
        hasAltitude: samples.length >= Math.max(6, ride.points.length * 0.35) && max - min > 0.4,
        samples: samples.length,
        total: ride.points.length,
        min,
        max,
        climb,
        drop,
        smoothed,
      };
    }
    function downsampleByMetric(ride, metrics, maxPoints = 720) {
      if (ride.points.length <= maxPoints) {
        return ride.points.map((point, index) => ({ point, metric: metrics[index] }));
      }
      const step = Math.ceil(ride.points.length / maxPoints);
      const sampled = [];
      for (let index = 0; index < ride.points.length; index += step) {
        sampled.push({ point: ride.points[index], metric: metrics[index] });
      }
      if (sampled.at(-1)?.point !== ride.points.at(-1)) {
        sampled.push({ point: ride.points.at(-1), metric: metrics.at(-1) });
      }
      return sampled;
    }
    function gradeColor(grade) {
      if (grade > 0.035) return 0xff6b48;
      if (grade < -0.035) return 0x62a7ff;
      return 0x56f094;
    }
    function addCylinderBetween(group, start, end, radius, color, options = {}) {
      const direction = new THREE.Vector3().subVectors(end, start);
      const length = direction.length();
      if (length <= 0.001) return;
      const geometry = new THREE.CylinderGeometry(radius, radius, length, 8, 1);
      const opacity = options.opacity ?? 1;
      const material = new THREE.MeshStandardMaterial({
        color,
        roughness: 0.48,
        metalness: 0.08,
        emissive: color,
        emissiveIntensity: options.emissiveIntensity ?? 0.16,
        transparent: opacity < 1,
        opacity,
        depthWrite: opacity >= 1,
      });
      const mesh = new THREE.Mesh(geometry, material);
      mesh.position.copy(start).add(end).multiplyScalar(0.5);
      mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
      group.add(mesh);
    }
    function clearElevationScene() {
      while (elevationGroup.children.length > 0) {
        const child = elevationGroup.children.pop();
        child.traverse?.((node) => {
          node.geometry?.dispose?.();
          if (Array.isArray(node.material)) {
            node.material.forEach((material) => {
              material.map?.dispose?.();
              material.dispose?.();
            });
          } else {
            node.material?.map?.dispose?.();
            node.material?.dispose?.();
          }
        });
      }
    }
    function labelTexture(text, { color = "#f3faef", background = "rgba(7, 10, 8, 0.86)" } = {}) {
      const canvas = document.createElement("canvas");
      canvas.width = 512;
      canvas.height = 128;
      const context = canvas.getContext("2d");
      context.clearRect(0, 0, canvas.width, canvas.height);
      context.fillStyle = background;
      context.strokeStyle = "rgba(255,255,255,0.22)";
      context.lineWidth = 4;
      context.beginPath();
      context.roundRect(12, 18, 488, 92, 18);
      context.fill();
      context.stroke();
      context.fillStyle = color;
      context.font = "800 34px ui-sans-serif, system-ui, sans-serif";
      context.textAlign = "center";
      context.textBaseline = "middle";
      context.fillText(text, 256, 64);
      const texture = new THREE.CanvasTexture(canvas);
      texture.needsUpdate = true;
      return texture;
    }
    function addLabel(group, text, position, scale = [38, 10], color = "#f3faef") {
      const sprite = new THREE.Sprite(new THREE.SpriteMaterial({
        map: labelTexture(text, { color }),
        transparent: true,
        depthTest: false,
      }));
      sprite.position.copy(position);
      sprite.scale.set(scale[0], scale[1], 1);
      group.add(sprite);
      return sprite;
    }
    function addDirectionCone(group, position, direction, color = 0xf3c14b) {
      const geometry = new THREE.ConeGeometry(2.5, 8, 18);
      const material = new THREE.MeshStandardMaterial({
        color,
        emissive: color,
        emissiveIntensity: 0.25,
        roughness: 0.36,
      });
      const cone = new THREE.Mesh(geometry, material);
      cone.position.copy(position);
      cone.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.clone().normalize());
      group.add(cone);
      return cone;
    }
    function renderElevation3d(ride, metrics) {
      clearElevationScene();
      const stats = elevationStats(ride);
      const sampled = downsampleByMetric(ride, metrics, 420);
      const totalMeters = metrics.at(-1)?.meters ?? 1;
      const centerLat = sampled.reduce((sum, item) => sum + item.point[0], 0) / sampled.length;
      const centerLng = sampled.reduce((sum, item) => sum + item.point[1], 0) / sampled.length;
      const metersPerLng = 111320 * Math.cos(radians(centerLat));
      const projected = sampled.map((item) => {
        const xMeters = (item.point[1] - centerLng) * metersPerLng;
        const zMeters = -(item.point[0] - centerLat) * 111320;
        return { ...item, xMeters, zMeters };
      });
      const minX = Math.min(...projected.map((item) => item.xMeters));
      const maxX = Math.max(...projected.map((item) => item.xMeters));
      const minZ = Math.min(...projected.map((item) => item.zMeters));
      const maxZ = Math.max(...projected.map((item) => item.zMeters));
      const horizontalSpan = Math.max(maxX - minX, maxZ - minZ, 1);
      const horizontalScale = 230 / horizontalSpan;
      const altitudeRange = stats.hasAltitude ? Math.max(stats.max - stats.min, 1) : 1;
      const verticalScale = stats.hasAltitude ? Math.min(12, Math.max(5, 56 / altitudeRange)) : 0;
      const routeBase = 4;
      const points3d = projected.map((item) => {
        const smoothed = stats.smoothed[item.metric.index];
        const y = routeBase + (stats.hasAltitude && smoothed !== null ? (smoothed - stats.min) * verticalScale : 0);
        return new THREE.Vector3(item.xMeters * horizontalScale, y, item.zMeters * horizontalScale);
      });
      const groundPoints = points3d.map((point) => new THREE.Vector3(point.x, 0.2, point.z));

      const grid = new THREE.GridHelper(280, 18, 0x2a3d2c, 0x172319);
      grid.position.y = -0.5;
      elevationGroup.add(grid);

      for (let index = 1; index < groundPoints.length; index += 1) {
        addCylinderBetween(
          elevationGroup,
          groundPoints[index - 1],
          groundPoints[index],
          0.38,
          0x324333,
          { opacity: 0.42, emissiveIntensity: 0.02 }
        );
      }

      for (let index = 1; index < points3d.length; index += 1) {
        const start = points3d[index - 1];
        const end = points3d[index];
        const prevAlt = stats.smoothed[sampled[index - 1].metric.index];
        const nextAlt = stats.smoothed[sampled[index].metric.index];
        const segmentMeters = Math.max(1, sampled[index].metric.meters - sampled[index - 1].metric.meters);
        const grade = stats.hasAltitude && prevAlt !== null && nextAlt !== null ? (nextAlt - prevAlt) / segmentMeters : 0;
        addCylinderBetween(elevationGroup, start, end, 0.95, gradeColor(grade));
      }

      if (points3d.length > 1) {
        const startMarker = new THREE.Mesh(
          new THREE.SphereGeometry(4.2, 18, 18),
          new THREE.MeshStandardMaterial({ color: 0x52f28f, emissive: 0x52f28f, emissiveIntensity: 0.25 })
        );
        startMarker.position.copy(points3d[0]);
        elevationGroup.add(startMarker);
        addLabel(elevationGroup, "START", points3d[0].clone().add(new THREE.Vector3(0, 16, 0)), [32, 8], "#52f28f");
        const finishMarker = new THREE.Mesh(
          new THREE.SphereGeometry(4.5, 18, 18),
          new THREE.MeshStandardMaterial({ color: 0xff7667, emissive: 0xff7667, emissiveIntensity: 0.25 })
        );
        finishMarker.position.copy(points3d.at(-1));
        elevationGroup.add(finishMarker);
        addLabel(elevationGroup, "FINISH", points3d.at(-1).clone().add(new THREE.Vector3(0, 16, 0)), [34, 8], "#ff7667");
      }

      const markerEveryMeters = 1609.344;
      for (let target = markerEveryMeters; target < (metrics.at(-1)?.meters ?? 0); target += markerEveryMeters) {
        const sampledIndex = sampled.findIndex((item) => item.metric.meters >= target);
        if (sampledIndex < 0) continue;
        const point = points3d[sampledIndex];
        addCylinderBetween(
          elevationGroup,
          new THREE.Vector3(point.x, 0.2, point.z),
          new THREE.Vector3(point.x, point.y + 9, point.z),
          0.16,
          0xf3c14b
        );
        addLabel(
          elevationGroup,
          \`\${Math.round(target / 1609.344)} mi\`,
          new THREE.Vector3(point.x, point.y + 16, point.z),
          [25, 6],
          "#f3c14b"
        );
      }

      const arrowEveryMeters = Math.max(402.336, totalMeters / 12);
      for (let target = arrowEveryMeters; target < totalMeters - arrowEveryMeters * 0.35; target += arrowEveryMeters) {
        const sampledIndex = sampled.findIndex((item) => item.metric.meters >= target);
        if (sampledIndex <= 0 || sampledIndex >= points3d.length - 1) continue;
        const direction = new THREE.Vector3().subVectors(points3d[sampledIndex + 1], points3d[sampledIndex - 1]);
        addDirectionCone(
          elevationGroup,
          points3d[sampledIndex].clone().add(new THREE.Vector3(0, 4.8, 0)),
          direction,
          0xf3c14b
        );
      }

      const visualHeight = stats.hasAltitude ? (stats.max - stats.min) * verticalScale : 0;
      currentElevationVisualHeight = visualHeight;
      centerElevationView();

      elevationTitle.textContent = stats.hasAltitude ? "3D route elevation" : "3D route shape";
      elevationMeta.textContent = stats.hasAltitude
        ? \`Same shape as the map · altitude \${formatFeetRange(stats.min, stats.max)} · climb +\${formatFeet(stats.climb)} · drop -\${formatFeet(stats.drop)}\`
        : "Same shape as the map. This ride is flat because it does not have enough saved altitude samples.";
      elevationNote.textContent = stats.hasAltitude
        ? \`Yellow cones show direction. Gray ground trace shows the route footprint. Mile guides are labeled. Height is exaggerated \${verticalScale.toFixed(1)}x.\`
        : \`\${stats.samples.toLocaleString()} of \${stats.total.toLocaleString()} points include usable altitude.\`;
      selectedAltitude.textContent = stats.hasAltitude ? formatFeetRange(stats.min, stats.max) : "-";
      selectedClimb.textContent = stats.hasAltitude ? \`+\${Math.round(feet(stats.climb))} ft\` : "-";
      selectedDrop.textContent = stats.hasAltitude ? \`-\${Math.round(feet(stats.drop))} ft\` : "-";
      selectedAltPoints.textContent = \`\${stats.samples.toLocaleString()}/\${stats.total.toLocaleString()}\`;
    }
    function nearestKnown(point) {
      let best = null;
      for (const route of knownRoutes) {
        for (const coord of route.coordinates) {
          const meters = distanceMeters(point, coord);
          if (!best || meters < best.meters) {
            best = { name: route.name, difficulty: route.difficulty, meters };
          }
        }
      }
      if (!best || best.meters > 80) return { name: "Unmatched / off reference map", meters: best?.meters ?? null };
      return best;
    }
    function nearestRidePoint(ride, latlng) {
      const point = [latlng.lat, latlng.lng];
      let best = { index: 0, meters: Infinity };
      ride.points.forEach((candidate, index) => {
        const meters = distanceMeters(point, candidate);
        if (meters < best.meters) best = { index, meters };
      });
      return best;
    }

    function markerHtml(className, label) {
      return \`<div class="\${className}">\${label}</div>\`;
    }
    function divIcon(className, label, size, anchor) {
      return L.divIcon({
        html: markerHtml(className, label),
        className: "",
        iconSize: size,
        iconAnchor: anchor
      });
    }

    knownRoutes.forEach((route) => {
      const color = route.color === "green" ? "#79e26d" : route.color === "blue" ? "#7aa7ff" : "#f5f5f0";
      const layer = L.polyline(route.coordinates, {
        color,
        weight: 3,
        opacity: 0.62,
        dashArray: "8 7",
        interactive: false
      }).addTo(knownGroup);
      const midpoint = route.coordinates[Math.floor(route.coordinates.length / 2)];
      L.marker(midpoint, {
        interactive: false,
        icon: divIcon("known-label", route.name, [120, 22], [60, 11])
      }).addTo(knownGroup);
      allBounds.push(layer.getBounds());
    });

    const historyLayers = rides.map((ride, index) => {
      const latLngs = routeLatLngs(ride);
      const color = colors[index % colors.length];
      const layer = L.polyline(latLngs, {
        color: index === 0 ? color : "#7b8878",
        weight: index === 0 ? 3 : 2,
        opacity: index === 0 ? 0.42 : 0.22,
        lineJoin: "round",
        interactive: false
      }).addTo(historyGroup);
      layer.bindTooltip(\`
        \${new Date(ride.startTime).toLocaleString()} · \${ride.distanceMiles.toFixed(2)} mi
      \`);
      allBounds.push(layer.getBounds());
      return { ride, layer, color };
    });

    const list = document.getElementById("rideList");
    const segmentList = document.getElementById("segmentList");
    const selectedTitle = document.getElementById("selectedTitle");
    const selectedMiles = document.getElementById("selectedMiles");
    const selectedDuration = document.getElementById("selectedDuration");
    const selectedSpeed = document.getElementById("selectedSpeed");
    const selectedPoints = document.getElementById("selectedPoints");
    const selectedAltitude = document.getElementById("selectedAltitude");
    const selectedClimb = document.getElementById("selectedClimb");
    const selectedDrop = document.getElementById("selectedDrop");
    const selectedAltPoints = document.getElementById("selectedAltPoints");
    const hudTitle = document.getElementById("hudTitle");
    const hudMeta = document.getElementById("hudMeta");
    const elevationRoot = document.getElementById("elevation3d");
    const elevationTitle = document.getElementById("elevationTitle");
    const elevationMeta = document.getElementById("elevationMeta");
    const elevationNote = document.getElementById("elevationNote");
    const toggle3dFocus = document.getElementById("toggle3dFocus");
    const focus3dFromSidebar = document.getElementById("focus3dFromSidebar");

    const elevationScene = new THREE.Scene();
    elevationScene.background = new THREE.Color("#070a08");
    const elevationCamera = new THREE.PerspectiveCamera(48, 1, 0.1, 1200);
    elevationCamera.position.set(0, 96, 190);
    const elevationRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    elevationRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    elevationRenderer.setSize(elevationRoot.clientWidth, elevationRoot.clientHeight);
    elevationRoot.appendChild(elevationRenderer.domElement);
    const elevationControls = new OrbitControls(elevationCamera, elevationRenderer.domElement);
    elevationControls.enableDamping = true;
    elevationControls.dampingFactor = 0.08;
    elevationControls.target.set(0, 22, 0);
    elevationControls.maxDistance = 520;
    elevationControls.minDistance = 40;
    const elevationGroup = new THREE.Group();
    elevationScene.add(elevationGroup);
    elevationScene.add(new THREE.AmbientLight(0xdcebd4, 1.55));
    const keyLight = new THREE.DirectionalLight(0xffffff, 1.7);
    keyLight.position.set(-60, 120, 90);
    elevationScene.add(keyLight);

    function animateElevation() {
      elevationControls.update();
      elevationRenderer.render(elevationScene, elevationCamera);
      requestAnimationFrame(animateElevation);
    }
    animateElevation();

    function resizeElevation() {
      const width = Math.max(1, elevationRoot.clientWidth);
      const height = Math.max(1, elevationRoot.clientHeight);
      elevationCamera.aspect = width / height;
      elevationCamera.updateProjectionMatrix();
      elevationRenderer.setSize(width, height);
    }
    function centerElevationView() {
      const focused = appRoot.classList.contains("focus-3d");
      const height = currentElevationVisualHeight;
      elevationCamera.position.set(
        0,
        Math.max(focused ? 170 : 86, height + (focused ? 145 : 68)),
        focused ? 460 : 190
      );
      elevationControls.target.set(0, Math.max(12, height * 0.36), 0);
      elevationControls.update();
    }
    function set3dFocus(enabled) {
      appRoot.classList.toggle("focus-3d", enabled);
      toggle3dFocus.textContent = enabled ? "Exit 3D" : "3D only";
      focus3dFromSidebar.textContent = enabled ? "Exit 3D" : "3D only";
      requestAnimationFrame(() => {
        resizeElevation();
        centerElevationView();
      });
    }
    window.addEventListener("resize", () => {
      resizeElevation();
      centerElevationView();
    });
    resizeElevation();

    function updateRideList() {
      [...list.children].forEach((button, index) => {
        button.classList.toggle("active", index === selectedIndex);
      });
    }

    function clearSelectedRoute() {
      if (selectedLayer) map.removeLayer(selectedLayer);
      if (selectedHalo) map.removeLayer(selectedHalo);
      selectedMarkers.clearLayers();
      selectedArrows.clearLayers();
    }

    function renderSelectedRoute(index, shouldFit = true) {
      selectedIndex = index;
      const ride = rides[index];
      const color = colors[index % colors.length];
      const latLngs = routeLatLngs(ride);
      const metrics = routeMetrics(ride);
      clearSelectedRoute();

      selectedHalo = L.polyline(latLngs, {
        color: "#071007",
        weight: 11,
        opacity: 0.95,
        lineJoin: "round"
      }).addTo(map);
      selectedLayer = L.polyline(latLngs, {
        color,
        weight: 6,
        opacity: 1,
        lineJoin: "round"
      }).addTo(map);
      selectedLayer.bindPopup(\`
        <div class="popup-title">\${new Date(ride.startTime).toLocaleString()}</div>
        <div>\${ride.distanceMiles.toFixed(2)} mi · \${ride.durationLabel}</div>
        <div>\${ride.points.length.toLocaleString()} points</div>
      \`);

      if (latLngs.length > 0) {
        L.marker(latLngs[0], {
          icon: divIcon("start-marker", "S", [34, 34], [17, 17])
        }).bindPopup("<strong>Start</strong>").addTo(selectedMarkers);
        L.marker(latLngs.at(-1), {
          icon: divIcon("finish-marker", "F", [34, 34], [17, 17])
        }).bindPopup("<strong>Finish</strong>").addTo(selectedMarkers);
      }

      const totalMeters = metrics.at(-1)?.meters ?? 0;
      const markerStepMeters = 804.672;
      for (let target = markerStepMeters; target < totalMeters; target += markerStepMeters) {
        const metric = metrics.find((item) => item.meters >= target);
        if (!metric) continue;
        const point = ride.points[metric.index];
        const near = nearestKnown(point);
        const miles = target / 1609.344;
        L.marker([point[0], point[1]], {
          icon: divIcon("mile-marker", \`\${miles.toFixed(2)} mi\`, [48, 24], [24, 12])
        }).bindPopup(\`
          <div class="popup-title">Section \${miles.toFixed(2)} mi</div>
          <div>Elapsed: \${formatTime(point[3])}</div>
          <div>Nearest known: \${near.name}\${near.meters ? \` (\${Math.round(near.meters)}m)\` : ""}</div>
        \`).addTo(selectedMarkers);
      }

      const arrowCount = Math.min(22, Math.max(6, Math.floor(latLngs.length / 30)));
      const arrowStep = Math.max(4, Math.floor(latLngs.length / arrowCount));
      for (let pointIndex = arrowStep; pointIndex < latLngs.length - 1; pointIndex += arrowStep) {
        const angle = bearing(ride.points[pointIndex - 1], ride.points[pointIndex + 1]);
        L.marker(latLngs[pointIndex], {
          interactive: false,
          icon: L.divIcon({
            html: \`<div class="direction-arrow" style="transform: rotate(\${angle}deg)"></div>\`,
            className: "",
            iconSize: [24, 24],
            iconAnchor: [12, 12]
          })
        }).addTo(selectedArrows);
      }

      selectedLayer.on("mousemove", (event) => {
        const nearest = nearestRidePoint(ride, event.latlng);
        const point = ride.points[nearest.index];
        const near = nearestKnown(point);
        const metric = metrics[nearest.index];
        const heading = nearest.index < ride.points.length - 1
          ? bearing(ride.points[nearest.index], ride.points[nearest.index + 1])
          : bearing(ride.points[nearest.index - 1], ride.points[nearest.index]);
        hudTitle.textContent = \`\${(metric.meters / 1609.344).toFixed(2)} mi · \${compass(heading)}\`;
        hudMeta.textContent = \`Elapsed \${formatTime(point[3])} · nearest known trail: \${near.name}\${near.meters ? \` (\${Math.round(near.meters)}m)\` : ""}\`;
      });

      selectedTitle.textContent = new Date(ride.startTime).toLocaleString();
      selectedMiles.textContent = ride.distanceMiles.toFixed(2);
      selectedDuration.textContent = ride.durationLabel;
      selectedSpeed.textContent = ride.avgSpeedMph.toFixed(1);
      selectedPoints.textContent = ride.points.length.toLocaleString();
      hudTitle.textContent = "Hover over the selected route";
      hudMeta.textContent = "Direction arrows point forward. Yellow labels mark half-mile checkpoints; the sidebar keeps quarter-mile sections.";

      renderElevation3d(ride, metrics);
      renderSegments(ride, metrics);
      updateRideList();
      if (!markersVisible) {
        map.removeLayer(selectedMarkers);
      } else if (!map.hasLayer(selectedMarkers)) {
        selectedMarkers.addTo(map);
      }
      if (shouldFit) map.fitBounds(selectedLayer.getBounds(), { padding: [48, 48] });
    }

    function renderSegments(ride, metrics) {
      segmentList.innerHTML = "";
      const totalMeters = metrics.at(-1)?.meters ?? 0;
      const step = 402.336;
      for (let start = 0; start < totalMeters; start += step) {
        const end = Math.min(start + step, totalMeters);
        const startMetric = metrics.find((item) => item.meters >= start) ?? metrics[0];
        const endMetric = metrics.find((item) => item.meters >= end) ?? metrics.at(-1);
        const startPoint = ride.points[startMetric.index];
        const endPoint = ride.points[endMetric.index];
        const heading = bearing(startPoint, endPoint);
        const near = nearestKnown(startPoint);
        const startAlt = altitudeValue(startPoint);
        const endAlt = altitudeValue(endPoint);
        const altLine = startAlt !== null && endAlt !== null
          ? \`Altitude \${formatFeet(startAlt)} to \${formatFeet(endAlt)} · \${endAlt >= startAlt ? "+" : ""}\${Math.round(feet(endAlt - startAlt))} ft\`
          : "Altitude not recorded for this section";
        const button = document.createElement("button");
        button.type = "button";
        button.className = "segment";
        button.innerHTML = \`
          <strong>\${(start / 1609.344).toFixed(2)}-\${(end / 1609.344).toFixed(2)} mi · \${compass(heading)}</strong>
          <span>\${formatTime(startPoint[3])} to \${formatTime(endPoint[3])}</span>
          <span>\${altLine}</span>
          <span>Nearest known: \${near.name}\${near.meters ? \` · \${Math.round(near.meters)}m\` : ""}</span>
        \`;
        button.addEventListener("click", () => {
          map.setView([startPoint[0], startPoint[1]], 18, { animate: true });
        });
        segmentList.appendChild(button);
      }
    }

    historyLayers.forEach((entry, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = \`ride \${index === selectedIndex ? "active" : ""}\`;
      button.innerHTML = \`
        <div class="ride-title"><span class="swatch" style="background:\${entry.color}"></span><span>\${new Date(entry.ride.startTime).toLocaleString()}</span></div>
        <div class="ride-meta">\${entry.ride.distanceMiles.toFixed(2)} mi · \${entry.ride.durationLabel} · \${entry.ride.points.length.toLocaleString()} points</div>
      \`;
      button.addEventListener("click", () => {
        renderSelectedRoute(index);
      });
      list.appendChild(button);
    });

    function fitVisible() {
      const bounds = selectedLayer ? [selectedLayer.getBounds()] : allBounds;
      if (bounds.length === 0) {
        map.setView([25.885, -80.28], 13);
        return;
      }
      map.fitBounds(bounds.reduce((acc, item) => acc.extend(item), bounds[0]), { padding: [32, 32] });
    }

    document.getElementById("focusSelected").addEventListener("click", fitVisible);
    document.getElementById("toggleHistory").addEventListener("click", (event) => {
      historyVisible = !historyVisible;
      if (historyVisible) historyGroup.addTo(map);
      else map.removeLayer(historyGroup);
      event.currentTarget.textContent = historyVisible ? "Hide history" : "Show history";
    });
    document.getElementById("toggleKnown").addEventListener("click", (event) => {
      knownVisible = !knownVisible;
      if (knownVisible) knownGroup.addTo(map);
      else map.removeLayer(knownGroup);
      event.currentTarget.textContent = knownVisible ? "Hide known trails" : "Show known trails";
    });
    document.getElementById("toggleMarkers").addEventListener("click", (event) => {
      markersVisible = !markersVisible;
      if (markersVisible) selectedMarkers.addTo(map);
      else map.removeLayer(selectedMarkers);
      event.currentTarget.textContent = markersVisible ? "Hide mile markers" : "Show mile markers";
    });
    toggle3dFocus.addEventListener("click", () => {
      set3dFocus(!appRoot.classList.contains("focus-3d"));
    });
    focus3dFromSidebar.addEventListener("click", () => {
      set3dFocus(!appRoot.classList.contains("focus-3d"));
    });
    window.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && appRoot.classList.contains("focus-3d")) {
        set3dFocus(false);
      }
    });

    renderSelectedRoute(0);
    if (new URLSearchParams(window.location.search).get("focus3d") === "1") {
      set3dFocus(true);
    }
    if (allBounds.length > 0 && !selectedLayer) {
      fitVisible();
    }
  </script>
</body>
</html>`;
}

const credentials = JSON.parse(await fs.readFile(credentialPath, "utf8"));
const tokenResponse = await postForm("https://oauth2.googleapis.com/token", {
  client_id: credentials.client_id,
  client_secret: credentials.client_secret,
  refresh_token: credentials.refresh_token,
  grant_type: "refresh_token",
});

if (!tokenResponse.access_token) {
  throw new Error("Could not obtain Google access token.");
}

const queryResponse = await postJson(
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
  tokenResponse.access_token,
  {
    structuredQuery: {
      from: [{ collectionId: "rides" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "userId" },
          op: "EQUAL",
          value: { stringValue: userId },
        },
      },
      limit: 100,
    },
  },
);

const rides = queryResponse
  .filter((row) => row.document)
  .map((row) => {
    const fields = row.document.fields ?? {};
    const points = routePoints(fields);
    return {
      id: row.document.name.split("/").at(-1),
      startTime: timestampValue(fields.startTime),
      endTime: timestampValue(fields.endTime),
      distanceMiles: numberValue(fields.distanceMiles),
      durationSeconds: numberValue(fields.durationSeconds),
      durationLabel: formatDuration(numberValue(fields.durationSeconds)),
      maxSpeedMph: numberValue(fields.maxSpeedMph),
      avgSpeedMph: numberValue(fields.avgSpeedMph),
      elevationGainFeet: numberValue(fields.elevationGainFeet),
      points,
    };
  })
  .filter((ride) => ride.points.length > 1)
  .sort((a, b) => b.startTime.localeCompare(a.startTime));

const knownRouteSource = await fs.readFile(trailMapDataPath, "utf8");
const knownRoutes = extractKnownRoutes(knownRouteSource);

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.writeFile(outputPath, buildHtml(rides, knownRoutes), "utf8");

console.log(`Exported ${rides.length} rides and ${knownRoutes.length} known trail routes to ${outputPath}`);
