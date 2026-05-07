const heroHint = document.querySelector("#hero-hint");
const archBlocks = document.querySelectorAll(".arch-block");
const archTitle = document.querySelector("#arch-title");
const archBody = document.querySelector("#arch-body");
const archKicker = document.querySelector("#arch-kicker");
const modeButtons = document.querySelectorAll(".mode-button");
const layerButtons = document.querySelectorAll(".layer-choice");
const layerKicker = document.querySelector("#layer-kicker");
const layerTitle = document.querySelector("#layer-title");
const layerBody = document.querySelector("#layer-body");
const klayoutCanvas = document.querySelector("#klayoutCanvas");
const klayoutStatus = document.querySelector("#klayoutStatus");
const klayoutLegend = document.querySelector("#klayoutLegend");

const layerPalette = {
  met3: {
    color: "#ffb04a",
    label: "Met3: yerel sinyal omurgası",
    description: "Standart hücre bölgelerinden çıkan kısa ve orta mesafeli sinyal yollarının yoğunlaştığı üst yönlendirme katmanıdır. Serimde yerel bağlantı yoğunluğunu ve blok içi sinyal trafiğini okumayı kolaylaştırır."
  },
  met4: {
    color: "#40e2c1",
    label: "Met4: bloklar arası dağıtım",
    description: "Met3 üzerindeki yerel bağlantıları daha geniş yonga bölgelerine taşıyan ara dağıtım katmanıdır. CPU, bellek ve çevre birimleri arasında uzayan veri ve kontrol yollarının fiziksel izini görünür kılar."
  },
  met5: {
    color: "#ff6f9f",
    label: "Met5: üst dağıtım katmanı",
    description: "En üst seviyedeki uzun bağlantıların ve geniş dağıtım hatlarının temsil edildiği katmandır. Yonga ölçeğindeki yönlendirme omurgasını ve üst metal yoğunluğunu sade bir şekilde gösterir."
  }
};

const layerViewState = {
  mode: "stack",
  layer: "all",
  prepared: null,
  detail: null,
  detailLoading: false,
  detailError: "",
  zoom: 1,
  panX: 0,
  panY: 0,
  dragging: false,
  dragX: 0,
  dragY: 0,
  inspectionFrameKey: "",
  width: 960,
  height: 680,
  pixelRatio: 1
};

function observeReveals() {
  const revealVisible = () => {
    document.querySelectorAll(".reveal").forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.top < window.innerHeight * 0.94 && rect.bottom > -window.innerHeight * 0.2) {
        el.classList.add("is-visible");
      }
    });
  };

  revealVisible();
  window.addEventListener("scroll", revealVisible, { passive: true });
  window.addEventListener("resize", revealVisible);
  window.addEventListener("hashchange", () => setTimeout(revealVisible, 40));
  setTimeout(revealVisible, 80);
  setTimeout(revealVisible, 320);

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) entry.target.classList.add("is-visible");
      });
    },
    { threshold: 0.15 }
  );

  document.querySelectorAll(".reveal").forEach((el) => observer.observe(el));
}

function makeTiltZones() {
  document.querySelectorAll(".tilt-zone").forEach((zone) => {
    const target = zone.querySelector(".drag-tilt, .arch-board");
    if (!target) return;

    zone.addEventListener("pointermove", (event) => {
      if (event.target.classList.contains("drag-part")) return;
      const rect = zone.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width - 0.5;
      const y = (event.clientY - rect.top) / rect.height - 0.5;
      target.style.setProperty("--tilt-x", `${(-y * 7).toFixed(2)}deg`);
      target.style.setProperty("--tilt-y", `${(x * 7).toFixed(2)}deg`);
      if (target.classList.contains("soc-chip")) {
        target.style.transform = `rotateX(calc(58deg + var(--tilt-x, 0deg))) rotateZ(-36deg) rotateY(var(--tilt-y, 0deg))`;
      }
      if (target.classList.contains("arch-board")) {
        target.style.transform = `rotateX(calc(58deg + var(--tilt-x, 0deg))) rotateZ(-24deg) rotateY(var(--tilt-y, 0deg))`;
      }
      if (target.classList.contains("layer-stack") && target.dataset.mode !== "top") {
        target.style.transform = `rotateX(calc(62deg + var(--tilt-x, 0deg))) rotateZ(-38deg) rotateY(var(--tilt-y, 0deg))`;
      }
    });

    zone.addEventListener("pointerleave", () => {
      target.style.removeProperty("--tilt-x");
      target.style.removeProperty("--tilt-y");
      if (target.classList.contains("soc-chip")) {
        target.style.transform = "";
      }
      if (target.classList.contains("arch-board")) {
        target.style.transform = "";
      }
      if (target.classList.contains("layer-stack")) {
        target.style.transform = "";
      }
    });
  });
}

function makeDraggableParts() {
  document.querySelectorAll(".drag-part").forEach((part) => {
    let startX = 0;
    let startY = 0;
    let baseX = 0;
    let baseY = 0;

    part.addEventListener("pointerdown", (event) => {
      part.setPointerCapture(event.pointerId);
      startX = event.clientX;
      startY = event.clientY;
      baseX = Number(part.dataset.x || 0);
      baseY = Number(part.dataset.y || 0);
      part.dataset.dragging = "true";
    });

    part.addEventListener("pointermove", (event) => {
      if (part.dataset.dragging !== "true") return;
      const nextX = baseX + event.clientX - startX;
      const nextY = baseY + event.clientY - startY;
      part.dataset.x = nextX;
      part.dataset.y = nextY;
      part.style.setProperty("--drag-x", `${nextX}px`);
      part.style.setProperty("--drag-y", `${nextY}px`);
    });

    part.addEventListener("pointerup", (event) => {
      part.releasePointerCapture(event.pointerId);
      part.dataset.dragging = "false";
    });

    part.addEventListener("pointercancel", () => {
      part.dataset.dragging = "false";
    });
  });
}

function bindHeroHints() {
  document.querySelectorAll(".chip-module").forEach((module) => {
    module.addEventListener("pointerenter", () => {
      heroHint.textContent = module.dataset.info;
    });
  });
}

function bindArchitectureDetails() {
  archBlocks.forEach((block) => {
    block.addEventListener("pointerenter", () => selectArchBlock(block));
    block.addEventListener("click", () => selectArchBlock(block));
  });
}

function selectArchBlock(block) {
  archBlocks.forEach((item) => item.classList.toggle("is-active", item === block));
  archKicker.textContent = "Secili blok";
  archTitle.textContent = block.dataset.title;
  archBody.textContent = block.dataset.body;
}

function bindLayerControls() {
  modeButtons.forEach((button) => {
    button.addEventListener("click", () => {
      layerViewState.mode = button.dataset.mode;
      modeButtons.forEach((item) => item.classList.toggle("is-active", item === button));
      updateLayerCopy();
    });
  });

  layerButtons.forEach((button) => {
    button.addEventListener("click", () => {
      layerViewState.layer = button.dataset.layer;
      layerButtons.forEach((item) => item.classList.toggle("is-active", item === button));
      updateLayerCopy();
    });
  });
}

async function initKLayoutViewer() {
  if (!klayoutCanvas) return;

  try {
    const data = await loadKLayoutData();
    layerViewState.prepared = prepareKLayoutData(data);
    buildLayerLegend();
    resizeKLayoutCanvas();
    bindKLayoutNavigation();
    primeDetailFromUrl();
    updateLayerCopy();
    window.addEventListener("resize", resizeKLayoutCanvas);
    requestAnimationFrame(drawKLayoutFrame);
  } catch (error) {
    klayoutStatus.textContent = "KLayout verisi okunamadı. Bu demo yerel sunucu veya GitHub Pages üzerinden açılmalıdır.";
    console.error(error);
  }
}

async function loadKLayoutData() {
  if (window.location.protocol === "file:") {
    throw new Error("JSON data cannot be loaded from file://. Use a local HTTP server.");
  }

  const response = await fetch("layers_full.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`layers_full.json could not be loaded: ${response.status}`);
  return response.json();
}

async function loadDetailData() {
  if (layerViewState.detail || layerViewState.detailLoading) return;

  layerViewState.detailLoading = true;
  layerViewState.detailError = "";
  updateLayerCopy();

  try {
    if (window.location.protocol === "file:") {
      throw new Error("Detail JSON cannot be loaded from file://. Use a local HTTP server.");
    }

    const response = await fetch("detail_view.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`detail_view.json could not be loaded: ${response.status}`);
    const detailData = await response.json();
    layerViewState.detail = prepareDetailData(detailData);
  } catch (error) {
    layerViewState.detailError = "Detay verisi yüklenemedi; yakın görünümde yalnız üst metal verisi gösterilir.";
    console.error(error);
  } finally {
    layerViewState.detailLoading = false;
    buildLayerLegend();
    updateLayerCopy();
  }
}

function prepareDetailData(data) {
  const dbu = data.meta.dbu_um;
  const bbox = data.meta.bbox.map((value) => value * dbu);
  const [left, bottom, right, top] = bbox;
  const layerByName = {};
  data.layers.forEach((layer) => {
    layerByName[layer.name] = layer;
  });

  return {
    dbu,
    bbox,
    centerX: (left + right) / 2,
    centerY: (bottom + top) / 2,
    width: right - left,
    height: top - bottom,
    layers: data.layers,
    layerByName,
    masters: data.masters,
    instances: data.instances,
    routeBoxCount: data.layers.reduce((sum, layer) => sum + layer.boxes.length / 4, 0)
  };
}

function prepareKLayoutData(data) {
  const [x0, y0, x1, y1] = data.meta.bbox_um;
  const centerX = (x0 + x1) / 2;
  const centerY = (y0 + y1) / 2;
  const dieWidthUm = x1 - x0;
  const dieDepthUm = y1 - y0;
  const scale = 620 / Math.max(dieWidthUm, dieDepthUm);
  const minZ = Math.min(...data.layers.map((layer) => layer.z_um));

  const layers = data.layers.map((layer, index) => {
    const palette = layerPalette[layer.name] || { color: layer.color, label: layer.name };
    const baseY = 34 + (layer.z_um - minZ) * 118 + index * 8;
    const polygons = layer.polygons
      .map((polygon) => ({
        area: polygon.area_um2,
        points: polygon.points.map(([x, y]) => ({
          x: (x - centerX) * scale,
          z: (y - centerY) * scale
        }))
      }))
      .filter((polygon) => polygon.points.length >= 3);

    return {
      name: layer.name,
      label: palette.label,
      description: palette.description,
      color: palette.color,
      layerNumber: layer.layer,
      datatype: layer.datatype,
      zUm: layer.z_um,
      heightUm: layer.height_um,
      polygonCount: layer.polygon_count,
      polygons,
      baseY
    };
  });

  return {
    designName: "SoC serim modeli",
    dieWidthUm,
    dieDepthUm,
    die: {
      width: dieWidthUm * scale,
      depth: dieDepthUm * scale,
      bottomY: -34
    },
    layers,
    totalPolygons: layers.reduce((sum, layer) => sum + layer.polygonCount, 0)
  };
}

function buildLayerLegend() {
  const prepared = layerViewState.prepared;
  if (!prepared || !klayoutLegend) return;
  klayoutLegend.replaceChildren();

  const detailLegend = layerViewState.detail
    ? layerViewState.detail.layers.filter((layer) => ["diff", "poly", "li1", "met1", "met2", "met3", "met4", "met5"].includes(layer.name))
    : null;
  const legendItems = detailLegend || prepared.layers;

  legendItems.forEach((layer) => {
    const item = document.createElement("span");
    const dot = document.createElement("i");
    dot.style.background = layer.color;
    dot.style.boxShadow = `0 0 18px ${rgba(layer.color, 0.5)}`;
    const count = layer.polygonCount || layer.boxes.length / 4;
    item.append(dot, document.createTextNode(`${layer.label || layer.name} (${formatNumber(count)})`));
    klayoutLegend.append(item);
  });
}

function updateLayerCopy() {
  const prepared = layerViewState.prepared;
  if (!prepared) return;

  if (layerViewState.layer === "all") {
    layerKicker.textContent = "KLayout 2.5D";
    layerTitle.textContent = "Tüm üst yönlendirme katmanları";
    layerBody.textContent = `${formatNumber(prepared.totalPolygons)} üst metal poligonu birlikte gösteriliyor. Bu birleşik görünüm, yerel sinyal omurgasını, bloklar arası dağıtımı ve üst seviye bağlantı yoğunluğunu tek serim üzerinde okumayı sağlar. Yakınlaştırınca hücre içi poly/diff, li1, met1/met2 ve via detayları açılır.`;
  } else {
    const layer = prepared.layers.find((item) => item.name === layerViewState.layer);
    if (!layer) return;
    layerKicker.textContent = `${layer.name.toUpperCase()} | layer ${layer.layerNumber}/${layer.datatype}`;
    layerTitle.textContent = layer.label;
    layerBody.textContent = `${layer.description} Bu kesitte ${formatNumber(layer.polygonCount)} poligon bulunuyor; z=${layer.zUm.toFixed(2)} µm, kalınlık=${layer.heightUm.toFixed(2)} µm. Seçili katman doygun renkte kalırken diğer katmanlar bağlam için düşük opaklıkta gösterilir.`;
  }

  if (klayoutStatus) {
    const modeLabel = layerViewState.mode === "explode" ? "ayrıştırılmış" : layerViewState.mode === "top" ? "üst görünüm" : "yığın";
    const activeLayer = prepared.layers.find((item) => item.name === layerViewState.layer);
    const layerLabel = layerViewState.layer === "all" ? "tüm üst yönlendirme" : activeLayer?.label || layerViewState.layer;
    const detailLabel = layerViewState.detail
      ? `${formatNumber(layerViewState.detail.routeBoxCount)} yönlendirme/via kutusu + ${formatNumber(layerViewState.detail.instances.length)} hücre örneği`
      : layerViewState.detailLoading
        ? "detay verisi yükleniyor"
        : layerViewState.detailError || "tekerlek ile yakınlaştır: detay verisini yükle";
    klayoutStatus.textContent = `${prepared.designName} | zoom ${layerViewState.zoom.toFixed(1)}x | ${modeLabel} | ${layerLabel} | ${detailLabel}`;
  }
}

function bindKLayoutNavigation() {
  if (!klayoutCanvas || klayoutCanvas.dataset.navigationBound === "true") return;
  klayoutCanvas.dataset.navigationBound = "true";

  klayoutCanvas.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const rect = klayoutCanvas.getBoundingClientRect();
      const pointerX = event.clientX - rect.left;
      const pointerY = event.clientY - rect.top;
      const before = screenToInspectionWorld(pointerX, pointerY);
      const factor = Math.exp(-event.deltaY * 0.0012);
      layerViewState.zoom = clamp(layerViewState.zoom * factor, 1, 48);

      if (layerViewState.zoom <= 1.02) {
        layerViewState.zoom = 1;
        layerViewState.panX = 0;
        layerViewState.panY = 0;
      } else {
        const after = inspectionWorldToScreen(before.x, before.y);
        layerViewState.panX += pointerX - after.x;
        layerViewState.panY += pointerY - after.y;
        loadDetailData();
      }

      updateLayerCopy();
    },
    { passive: false }
  );

  klayoutCanvas.addEventListener("pointerdown", (event) => {
    layerViewState.dragging = true;
    layerViewState.dragX = event.clientX;
    layerViewState.dragY = event.clientY;
    klayoutCanvas.setPointerCapture(event.pointerId);
  });

  klayoutCanvas.addEventListener("pointermove", (event) => {
    if (!layerViewState.dragging || layerViewState.zoom <= 1) return;
    layerViewState.panX += event.clientX - layerViewState.dragX;
    layerViewState.panY += event.clientY - layerViewState.dragY;
    layerViewState.dragX = event.clientX;
    layerViewState.dragY = event.clientY;
  });

  klayoutCanvas.addEventListener("pointerup", (event) => {
    layerViewState.dragging = false;
    klayoutCanvas.releasePointerCapture(event.pointerId);
  });

  klayoutCanvas.addEventListener("pointercancel", () => {
    layerViewState.dragging = false;
  });

  klayoutCanvas.addEventListener("dblclick", () => {
    layerViewState.zoom = 1;
    layerViewState.panX = 0;
    layerViewState.panY = 0;
    updateLayerCopy();
  });
}

function primeDetailFromUrl() {
  const params = new URLSearchParams(window.location.search);
  if (!params.has("detail")) return;
  const requestedZoom = Number(params.get("detail"));
  layerViewState.zoom = Number.isFinite(requestedZoom) && requestedZoom > 1 ? clamp(requestedZoom, 1, 48) : 12;
  loadDetailData();
}

function resizeKLayoutCanvas() {
  if (!klayoutCanvas) return;
  const rect = klayoutCanvas.getBoundingClientRect();
  const pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  const width = Math.max(320, Math.round(rect.width));
  const height = Math.max(420, Math.round(rect.height));

  layerViewState.width = width;
  layerViewState.height = height;
  layerViewState.pixelRatio = pixelRatio;

  if (klayoutCanvas.width !== Math.round(width * pixelRatio) || klayoutCanvas.height !== Math.round(height * pixelRatio)) {
    klayoutCanvas.width = Math.round(width * pixelRatio);
    klayoutCanvas.height = Math.round(height * pixelRatio);
  }
}

function drawKLayoutFrame(now) {
  requestAnimationFrame(drawKLayoutFrame);
  const prepared = layerViewState.prepared;
  if (!prepared || !klayoutCanvas) return;

  const ctx = klayoutCanvas.getContext("2d");
  const width = layerViewState.width;
  const height = layerViewState.height;
  ctx.setTransform(layerViewState.pixelRatio, 0, 0, layerViewState.pixelRatio, 0, 0);

  if (layerViewState.zoom > 1.02) {
    const key = [
      layerViewState.zoom.toFixed(3),
      layerViewState.panX.toFixed(1),
      layerViewState.panY.toFixed(1),
      layerViewState.layer,
      layerViewState.detail ? "detail" : layerViewState.detailLoading ? "loading" : "fallback"
    ].join("|");
    if (key === layerViewState.inspectionFrameKey && !layerViewState.dragging) return;
    layerViewState.inspectionFrameKey = key;
    ctx.clearRect(0, 0, width, height);
    drawInspectionFrame(ctx, prepared, width, height);
    return;
  }

  layerViewState.inspectionFrameKey = "";
  ctx.clearRect(0, 0, width, height);
  const camera = createOrbitCamera(now, width, height);
  const drawItems = [];
  pushDieSlab(drawItems, prepared, camera);

  prepared.layers.forEach((layer, index) => {
    const level = getLayerLevel(layer, index);
    pushLayerPlate(drawItems, prepared, layer, level, camera);
    pushLayerPolygons(drawItems, layer, level, camera);
  });

  drawItems.sort((a, b) => b.depth - a.depth);
  drawItems.forEach((item) => drawProjectedPolygon(ctx, item));
  drawFocusTarget(ctx, camera);
}

function drawInspectionFrame(ctx, prepared, width, height) {
  const transform = getInspectionTransform();
  const detail = layerViewState.detail;
  const bounds = getInspectionBounds();

  drawInspectionBase(ctx, prepared, transform, width, height);

  if (detail) {
    drawDetailRoutes(ctx, detail, transform, bounds);
    drawDetailCells(ctx, detail, transform, bounds);
  } else {
    drawInspectionFallback(ctx, prepared, transform);
    drawDetailLoadingBadge(ctx, width, height);
  }
}

function drawInspectionBase(ctx, prepared, transform, width, height) {
  const [left, bottom, right, top] = [0, 0, prepared.dieWidthUm, prepared.dieDepthUm];
  const p1 = inspectionWorldToScreen(left, bottom);
  const p2 = inspectionWorldToScreen(right, top);
  const x = Math.min(p1.x, p2.x);
  const y = Math.min(p1.y, p2.y);
  const w = Math.abs(p2.x - p1.x);
  const h = Math.abs(p2.y - p1.y);

  ctx.save();
  ctx.fillStyle = "rgba(5, 12, 16, 0.9)";
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = "rgba(11, 24, 30, 0.96)";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.18)";
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);

  const gridStepUm = chooseGridStep(transform.scale);
  const startX = Math.floor(left / gridStepUm) * gridStepUm;
  const startY = Math.floor(bottom / gridStepUm) * gridStepUm;
  ctx.beginPath();
  for (let gx = startX; gx <= right; gx += gridStepUm) {
    const a = inspectionWorldToScreen(gx, bottom);
    const b = inspectionWorldToScreen(gx, top);
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
  }
  for (let gy = startY; gy <= top; gy += gridStepUm) {
    const a = inspectionWorldToScreen(left, gy);
    const b = inspectionWorldToScreen(right, gy);
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
  }
  ctx.strokeStyle = "rgba(255, 255, 255, 0.055)";
  ctx.stroke();
  ctx.restore();
}

function drawInspectionFallback(ctx, prepared, transform) {
  const cameralessLayers = prepared.layers;
  cameralessLayers.forEach((layer) => {
    if (layerViewState.layer !== "all" && layerViewState.layer !== layer.name) return;
    ctx.fillStyle = rgba(layer.color, layerViewState.layer === "all" ? 0.5 : 0.78);
    layer.polygons.forEach((polygon) => {
      drawUmPolygon(ctx, polygon.points.map((point) => ({
        x: point.x / transform.overviewScale + transform.centerX,
        y: point.z / transform.overviewScale + transform.centerY
      })));
    });
  });
}

function drawDetailLoadingBadge(ctx, width, height) {
  ctx.save();
  ctx.fillStyle = "rgba(5, 8, 12, 0.72)";
  ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
  ctx.lineWidth = 1;
  roundRect(ctx, 18, height - 74, Math.min(520, width - 36), 48, 8);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = "#dff7fb";
  ctx.font = "800 13px Segoe UI, Arial";
  const text = layerViewState.detailError || "Yakın görünüm verisi yükleniyor; yerel sunucuda li1/met1/met2 ve hücre içi katmanlar açılır.";
  ctx.fillText(text, 34, height - 44);
  ctx.restore();
}

function drawDetailRoutes(ctx, detail, transform, bounds) {
  detail.layers.forEach((layer) => {
    if (layer.boxes.length === 0) return;
    if (layerViewState.zoom < layer.minZoom) return;
    if (layerViewState.layer !== "all" && layerViewState.layer !== layer.name) return;

    const isVia = layer.name.includes("via") || layer.name.includes("con");
    ctx.fillStyle = rgba(layer.color, isVia ? 0.86 : 0.62);
    drawFlatBoxes(ctx, layer.boxes, detail.dbu, transform, bounds, isVia ? 1.2 : 0.7);
  });
}

function drawDetailCells(ctx, detail, transform, bounds) {
  if (layerViewState.layer !== "all") return;
  const showOutlines = layerViewState.zoom >= 5;
  const showInside = layerViewState.zoom >= 10;
  if (!showOutlines) return;

  ctx.save();
  detail.instances.forEach((inst) => {
    if (!boxIntersects(inst[7], inst[8], inst[9], inst[10], bounds)) return;
    const sx1 = dbuPointToScreen(inst[7], inst[8], detail.dbu, transform);
    const sx2 = dbuPointToScreen(inst[9], inst[10], detail.dbu, transform);
    const x = Math.min(sx1.x, sx2.x);
    const y = Math.min(sx1.y, sx2.y);
    const w = Math.abs(sx2.x - sx1.x);
    const h = Math.abs(sx2.y - sx1.y);

    ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
    ctx.lineWidth = 0.7;
    if (w > 4 && h > 3) ctx.strokeRect(x, y, w, h);

    if (!showInside) return;
    const master = detail.masters[inst[0]];
    if (!master) return;
    drawMasterLayers(ctx, detail, transform, inst, master);
  });
  ctx.restore();
}

function drawMasterLayers(ctx, detail, transform, inst, master) {
  const order = ["diff", "tap", "poly", "licon", "li1", "mcon", "met1"];
  order.forEach((layerName) => {
    const boxes = master.layers[layerName];
    const layer = detail.layerByName[layerName];
    if (!boxes || !layer || layerViewState.zoom < layer.minZoom) return;
    const isContact = layerName.includes("con");
    ctx.fillStyle = rgba(layer.color, isContact ? 0.84 : 0.58);

    for (let index = 0; index < boxes.length; index += 4) {
      const box = transformInstanceBox(inst, boxes[index], boxes[index + 1], boxes[index + 2], boxes[index + 3]);
      const p1 = dbuPointToScreen(box[0], box[1], detail.dbu, transform);
      const p2 = dbuPointToScreen(box[2], box[3], detail.dbu, transform);
      const x = Math.min(p1.x, p2.x);
      const y = Math.min(p1.y, p2.y);
      const w = Math.max(Math.abs(p2.x - p1.x), isContact ? 1.4 : 0.7);
      const h = Math.max(Math.abs(p2.y - p1.y), isContact ? 1.4 : 0.7);
      ctx.fillRect(x, y, w, h);
    }
  });
}

function drawFlatBoxes(ctx, boxes, dbu, transform, bounds, minPixels) {
  for (let index = 0; index < boxes.length; index += 4) {
    const left = boxes[index];
    const bottom = boxes[index + 1];
    const right = boxes[index + 2];
    const top = boxes[index + 3];
    if (!boxIntersects(left, bottom, right, top, bounds)) continue;
    const p1 = dbuPointToScreen(left, bottom, dbu, transform);
    const p2 = dbuPointToScreen(right, top, dbu, transform);
    const x = Math.min(p1.x, p2.x);
    const y = Math.min(p1.y, p2.y);
    const w = Math.max(Math.abs(p2.x - p1.x), minPixels);
    const h = Math.max(Math.abs(p2.y - p1.y), minPixels);
    ctx.fillRect(x, y, w, h);
  }
}

function drawUmPolygon(ctx, points) {
  if (points.length < 3) return;
  const first = inspectionWorldToScreen(points[0].x, points[0].y);
  ctx.beginPath();
  ctx.moveTo(first.x, first.y);
  for (let index = 1; index < points.length; index += 1) {
    const next = inspectionWorldToScreen(points[index].x, points[index].y);
    ctx.lineTo(next.x, next.y);
  }
  ctx.closePath();
  ctx.fill();
}

function transformInstanceBox(inst, left, bottom, right, top) {
  const p1 = transformInstancePoint(inst, left, bottom);
  const p2 = transformInstancePoint(inst, right, bottom);
  const p3 = transformInstancePoint(inst, right, top);
  const p4 = transformInstancePoint(inst, left, top);
  return [
    Math.min(p1.x, p2.x, p3.x, p4.x),
    Math.min(p1.y, p2.y, p3.y, p4.y),
    Math.max(p1.x, p2.x, p3.x, p4.x),
    Math.max(p1.y, p2.y, p3.y, p4.y)
  ];
}

function transformInstancePoint(inst, x, y) {
  return {
    x: inst[5] + inst[1] * x + inst[3] * y,
    y: inst[6] + inst[2] * x + inst[4] * y
  };
}

function getInspectionTransform() {
  const source = layerViewState.detail || layerViewState.prepared;
  const dieWidth = source.width || source.dieWidthUm;
  const dieHeight = source.height || source.dieDepthUm;
  const centerX = source.centerX || source.dieWidthUm / 2;
  const centerY = source.centerY || source.dieDepthUm / 2;
  const baseScale = Math.min((layerViewState.width * 0.78) / dieWidth, (layerViewState.height * 0.7) / dieHeight);

  return {
    centerX,
    centerY,
    scale: baseScale * layerViewState.zoom,
    overviewScale: 620 / Math.max(layerViewState.prepared.dieWidthUm, layerViewState.prepared.dieDepthUm)
  };
}

function inspectionWorldToScreen(x, y) {
  const transform = getInspectionTransform();
  return {
    x: layerViewState.width * 0.5 + layerViewState.panX + (x - transform.centerX) * transform.scale,
    y: layerViewState.height * 0.54 + layerViewState.panY - (y - transform.centerY) * transform.scale
  };
}

function screenToInspectionWorld(x, y) {
  const transform = getInspectionTransform();
  return {
    x: transform.centerX + (x - layerViewState.width * 0.5 - layerViewState.panX) / transform.scale,
    y: transform.centerY - (y - layerViewState.height * 0.54 - layerViewState.panY) / transform.scale
  };
}

function dbuPointToScreen(x, y, dbu, transform) {
  return {
    x: layerViewState.width * 0.5 + layerViewState.panX + (x * dbu - transform.centerX) * transform.scale,
    y: layerViewState.height * 0.54 + layerViewState.panY - (y * dbu - transform.centerY) * transform.scale
  };
}

function getInspectionBounds() {
  const detail = layerViewState.detail;
  if (!detail) return null;
  const topLeft = screenToInspectionWorld(0, 0);
  const bottomRight = screenToInspectionWorld(layerViewState.width, layerViewState.height);
  const dbu = detail.dbu;
  return {
    left: Math.floor(Math.min(topLeft.x, bottomRight.x) / dbu),
    right: Math.ceil(Math.max(topLeft.x, bottomRight.x) / dbu),
    bottom: Math.floor(Math.min(topLeft.y, bottomRight.y) / dbu),
    top: Math.ceil(Math.max(topLeft.y, bottomRight.y) / dbu)
  };
}

function boxIntersects(left, bottom, right, top, bounds) {
  if (!bounds) return true;
  return right >= bounds.left && left <= bounds.right && top >= bounds.bottom && bottom <= bounds.top;
}

function chooseGridStep(scale) {
  const target = 70 / scale;
  const steps = [0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50, 100, 200];
  return steps.find((step) => step >= target) || 500;
}

function createOrbitCamera(now, width, height) {
  const deg = Math.PI / 180;
  const seconds = now * 0.001;
  const mode = layerViewState.mode;
  const angle = 160 * deg + Math.sin(seconds * 0.24) * 80 * deg;
  const radius = mode === "top" ? 360 : 930;
  const eyeY = mode === "top" ? 940 : 405;
  const targetY = mode === "explode" ? 165 : 62;
  const eye = {
    x: Math.sin(angle) * radius,
    y: eyeY,
    z: Math.cos(angle) * radius
  };
  const target = { x: 0, y: targetY, z: 0 };
  const forward = normalize(subtract(target, eye));
  const right = normalize(cross(forward, { x: 0, y: 1, z: 0 }));
  const up = cross(right, forward);
  const fov = (mode === "top" ? 30 : 36) * deg;

  return {
    eye,
    forward,
    right,
    up,
    focal: (height * 0.5) / Math.tan(fov / 2),
    centerX: width * 0.5,
    centerY: height * (mode === "explode" ? 0.6 : 0.56)
  };
}

function getLayerLevel(layer, index) {
  if (layerViewState.mode === "explode") return layer.baseY + index * 92;
  if (layerViewState.mode === "top") return 30 + index * 5;
  return layer.baseY;
}

function pushDieSlab(drawItems, prepared, camera) {
  const halfWidth = prepared.die.width / 2;
  const halfDepth = prepared.die.depth / 2;
  const topY = 0;
  const bottomY = prepared.die.bottomY;
  const corners = [
    { x: -halfWidth, z: -halfDepth },
    { x: halfWidth, z: -halfDepth },
    { x: halfWidth, z: halfDepth },
    { x: -halfWidth, z: halfDepth }
  ];

  const top = projectPlane(corners, topY, camera);
  if (top) {
    drawItems.push({
      points: top.points,
      depth: top.depth + 1,
      fill: "rgba(13, 24, 31, 0.92)",
      stroke: "rgba(255, 255, 255, 0.18)",
      lineWidth: 1.2
    });
  }

  corners.forEach((corner, index) => {
    const next = corners[(index + 1) % corners.length];
    const side = projectWorldPoints(
      [
        { x: corner.x, y: topY, z: corner.z },
        { x: next.x, y: topY, z: next.z },
        { x: next.x, y: bottomY, z: next.z },
        { x: corner.x, y: bottomY, z: corner.z }
      ],
      camera
    );
    if (!side) return;
    drawItems.push({
      points: side.points,
      depth: side.depth,
      fill: "rgba(4, 10, 14, 0.82)",
      stroke: "rgba(64, 226, 193, 0.1)",
      lineWidth: 1
    });
  });
}

function pushLayerPlate(drawItems, prepared, layer, level, camera) {
  const halfWidth = prepared.die.width / 2;
  const halfDepth = prepared.die.depth / 2;
  const plate = projectPlane(
    [
      { x: -halfWidth, z: -halfDepth },
      { x: halfWidth, z: -halfDepth },
      { x: halfWidth, z: halfDepth },
      { x: -halfWidth, z: halfDepth }
    ],
    level - 2,
    camera
  );
  if (!plate) return;

  const selected = layerViewState.layer === "all" || layerViewState.layer === layer.name;
  drawItems.push({
    points: plate.points,
    depth: plate.depth - 0.5,
    fill: rgba(layer.color, selected ? 0.09 : 0.025),
    stroke: rgba(layer.color, selected ? 0.28 : 0.08),
    lineWidth: selected ? 1.2 : 0.8
  });
}

function pushLayerPolygons(drawItems, layer, level, camera) {
  const selected = layerViewState.layer === "all" || layerViewState.layer === layer.name;
  const fillAlpha = selected ? (layerViewState.layer === "all" ? 0.52 : 0.78) : 0.11;
  const strokeAlpha = selected ? 0.22 : 0.04;

  layer.polygons.forEach((polygon) => {
    const projected = projectPlane(polygon.points, level + 3, camera);
    if (!projected) return;
    drawItems.push({
      points: projected.points,
      depth: projected.depth,
      fill: rgba(layer.color, fillAlpha),
      stroke: rgba(layer.color, strokeAlpha),
      lineWidth: selected && polygon.area > 400 ? 0.9 : 0
    });
  });
}

function projectPlane(points, y, camera) {
  return projectWorldPoints(points.map((point) => ({ x: point.x, y, z: point.z })), camera);
}

function projectWorldPoints(points, camera) {
  const projected = [];
  let depth = 0;

  for (const point of points) {
    const screen = projectPoint(point, camera);
    if (!screen) return null;
    projected.push(screen);
    depth += screen.depth;
  }

  return { points: projected, depth: depth / projected.length };
}

function projectPoint(point, camera) {
  const offset = subtract(point, camera.eye);
  const depth = dot(offset, camera.forward);
  if (depth <= 1) return null;
  const viewX = dot(offset, camera.right);
  const viewY = dot(offset, camera.up);
  const scale = camera.focal / depth;
  return {
    x: camera.centerX + viewX * scale,
    y: camera.centerY - viewY * scale,
    depth
  };
}

function drawProjectedPolygon(ctx, item) {
  if (item.points.length < 3) return;
  ctx.beginPath();
  ctx.moveTo(item.points[0].x, item.points[0].y);
  for (let index = 1; index < item.points.length; index += 1) {
    ctx.lineTo(item.points[index].x, item.points[index].y);
  }
  ctx.closePath();
  ctx.fillStyle = item.fill;
  ctx.fill();

  if (item.lineWidth > 0) {
    ctx.lineWidth = item.lineWidth;
    ctx.strokeStyle = item.stroke;
    ctx.stroke();
  }
}

function drawFocusTarget(ctx, camera) {
  const center = projectPoint({ x: 0, y: layerViewState.mode === "explode" ? 168 : 66, z: 0 }, camera);
  if (!center) return;
  ctx.save();
  ctx.strokeStyle = "rgba(248, 251, 255, 0.36)";
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.ellipse(center.x, center.y, 34, 11, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = "rgba(248, 251, 255, 0.72)";
  ctx.beginPath();
  ctx.arc(center.x, center.y, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function subtract(a, b) {
  return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z };
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

function cross(a, b) {
  return {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x
  };
}

function normalize(vector) {
  const length = Math.hypot(vector.x, vector.y, vector.z) || 1;
  return { x: vector.x / length, y: vector.y / length, z: vector.z / length };
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function roundRect(ctx, x, y, width, height, radius) {
  const r = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + width - r, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + r);
  ctx.lineTo(x + width, y + height - r);
  ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  ctx.lineTo(x + r, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function rgba(hex, alpha) {
  const value = hex.replace("#", "");
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function formatNumber(value) {
  return new Intl.NumberFormat("tr-TR").format(value);
}

function drawPowerCanvas() {
  const canvas = document.querySelector("#powerCanvas");
  const ctx = canvas.getContext("2d");
  const values = [
    { label: "Dinamik", value: 0.025, color: "#35d7f0" },
    { label: "Statik", value: 0.098, color: "#b7f35f" }
  ];
  const total = values.reduce((sum, item) => sum + item.value, 0);
  const cx = 140;
  const cy = 140;
  const radius = 88;
  let start = -Math.PI / 2;

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#effaff";
  ctx.font = "800 22px Segoe UI, Arial";
  ctx.fillText("Vivado güç dağılımı", 286, 68);
  ctx.fillStyle = "#9aabb6";
  ctx.font = "700 14px Segoe UI, Arial";
  ctx.fillText("SAIF işaretli, yüksek güven", 286, 94);

  values.forEach((item, index) => {
    const angle = (item.value / total) * Math.PI * 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, radius, start, start + angle);
    ctx.closePath();
    ctx.fillStyle = item.color;
    ctx.fill();
    start += angle;

    const y = 136 + index * 42;
    ctx.fillStyle = item.color;
    ctx.fillRect(286, y - 13, 16, 16);
    ctx.fillStyle = "#effaff";
    ctx.font = "800 14px Segoe UI, Arial";
    ctx.fillText(item.label, 312, y);
    ctx.fillStyle = "#9aabb6";
    ctx.font = "700 13px Segoe UI, Arial";
    ctx.fillText(`${item.value.toFixed(3)} W`, 312, y + 21);
  });

  ctx.beginPath();
  ctx.arc(cx, cy, 52, 0, Math.PI * 2);
  ctx.fillStyle = "#091116";
  ctx.fill();
  ctx.textAlign = "center";
  ctx.fillStyle = "#ffffff";
  ctx.font = "900 24px Segoe UI, Arial";
  ctx.fillText("0.123", cx, cy + 2);
  ctx.fillStyle = "#9aabb6";
  ctx.font = "800 12px Segoe UI, Arial";
  ctx.fillText("W toplam", cx, cy + 24);
  ctx.textAlign = "left";
}

function drawResourceCanvas() {
  const canvas = document.querySelector("#resourceCanvas");
  const ctx = canvas.getContext("2d");
  const rows = [
    { label: "LUT", desc: "Kombinasyonel mantık", used: 8218, total: 63400, pct: 12.96, color: "#35d7f0" },
    { label: "Register", desc: "Flip-flop / durum elemanı", used: 4978, total: 126800, pct: 3.93, color: "#5ee8bd" },
    { label: "BRAM", desc: "Gömülü bellek blokları", used: 14, total: 135, pct: 10.37, color: "#ffca62" },
    { label: "DSP48", desc: "Çarp-topla blokları", used: 7, total: 240, pct: 2.92, color: "#ff6b87" },
    { label: "I/O", desc: "Kart pinleri", used: 28, total: 210, pct: 13.33, color: "#8ea2ff" }
  ];
  const maxPct = 15;
  const chartX = 214;
  const chartWidth = 280;
  const rowTop = 122;
  const rowGap = 42;

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#effaff";
  ctx.font = "800 22px Segoe UI, Arial";
  ctx.fillText("Arty A7-100T kaynak bütçesi", 28, 48);
  ctx.fillStyle = "#9aabb6";
  ctx.font = "700 14px Segoe UI, Arial";
  ctx.fillText("xc7a100tcsg324-1 | Vivado power_with_saif.rpt", 28, 72);

  ctx.fillStyle = "rgba(234,245,255,0.54)";
  ctx.font = "800 11px Segoe UI, Arial";
  ctx.fillText("Kaynak", 28, 104);
  ctx.fillText("Kullanım oranı", chartX, 104);
  ctx.textAlign = "right";
  ctx.fillText("Kullanılan / toplam", canvas.width - 28, 104);
  ctx.textAlign = "left";

  rows.forEach((row, index) => {
    const y = rowTop + index * rowGap;
    const width = Math.round((row.pct / maxPct) * chartWidth);
    const countLabel = `${formatNumber(row.used)} / ${formatNumber(row.total)}`;

    ctx.strokeStyle = "rgba(255,255,255,0.07)";
    ctx.beginPath();
    ctx.moveTo(28, y + 23);
    ctx.lineTo(canvas.width - 28, y + 23);
    ctx.stroke();

    ctx.fillStyle = "#effaff";
    ctx.font = "850 14px Segoe UI, Arial";
    ctx.fillText(row.label, 28, y);
    ctx.fillStyle = "rgba(234,245,255,0.58)";
    ctx.font = "700 11px Segoe UI, Arial";
    ctx.fillText(row.desc, 28, y + 16);

    ctx.fillStyle = "#1d2a31";
    roundRect(ctx, chartX, y - 12, chartWidth, 14, 7);
    ctx.fill();

    ctx.fillStyle = row.color;
    roundRect(ctx, chartX, y - 12, width, 14, 7);
    ctx.fill();

    ctx.textAlign = "right";
    ctx.fillStyle = "#effaff";
    ctx.font = "800 14px Segoe UI, Arial";
    ctx.fillText(`${row.pct.toFixed(2)}%`, chartX + chartWidth + 58, y);
    ctx.fillStyle = "#9aabb6";
    ctx.font = "800 12px Segoe UI, Arial";
    ctx.fillText(countLabel, canvas.width - 28, y + 16);
    ctx.textAlign = "left";
  });
}

function drawBenchmarkCanvas() {
  const canvas = document.querySelector("#benchmarkCanvas");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  const rows = [
    { label: "Newton 1/x", value: 962000, unit: "iterasyon/s", color: "#4ee2ce" },
    { label: "İkili kök", value: 761666, unit: "iterasyon/s", color: "#4ee2ce" },
    { label: "Newton kök", value: 697000, unit: "iterasyon/s", color: "#4ee2ce" },
    { label: "Jacobi 2x2", value: 467500, unit: "iterasyon/s", color: "#4ee2ce" },
    { label: "CORDIC", value: 198000, unit: "hesap/s", color: "#ffb04a" },
    { label: "FIR-16", value: 134500, unit: "sample/s", color: "#ffb04a" },
    { label: "Bellek zinciri", value: 74500, unit: "zincir/s", color: "#c9a9ff" },
    { label: "MatVec 8x8", value: 38500, unit: "matvec/s", color: "#9ddc62" },
    { label: "Sıralama 32", value: 9166, unit: "sıralama/s", color: "#ff8fb8" },
    { label: "CRC32 64B", value: 9000, unit: "blok/s", color: "#8db8ff" }
  ];
  const maxValue = 1000000;
  const left = 72;
  const right = 30;
  const top = 92;
  const bottom = 128;
  const plotWidth = canvas.width - left - right;
  const plotHeight = canvas.height - top - bottom;
  const gridValues = [0, 250000, 500000, 750000, 1000000];

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#effaff";
  ctx.font = "900 24px Segoe UI, Arial";
  ctx.fillText("İş yükü hızı karşılaştırması", 28, 42);
  ctx.fillStyle = "#9aabb6";
  ctx.font = "750 14px Segoe UI, Arial";
  ctx.fillText("2 ms ölçüm penceresinden 1 saniyelik eşdeğere ölçeklenmiş değerler", 28, 66);

  gridValues.forEach((value) => {
    const y = top + plotHeight - (value / maxValue) * plotHeight;
    ctx.strokeStyle = value === 0 ? "rgba(255,255,255,0.18)" : "rgba(255,255,255,0.08)";
    ctx.beginPath();
    ctx.moveTo(left, y);
    ctx.lineTo(left + plotWidth, y);
    ctx.stroke();
    ctx.fillStyle = "rgba(234,245,255,0.48)";
    ctx.font = "800 12px Segoe UI, Arial";
    ctx.textAlign = "right";
    const tick = value === 1000000 ? "1M/s" : `${value / 1000}k`;
    ctx.fillText(tick, left - 12, y + 4);
  });

  ctx.textAlign = "center";
  rows.forEach((row, index) => {
    const slot = plotWidth / rows.length;
    const barWidth = Math.min(48, slot * 0.54);
    const x = left + index * slot + slot / 2;
    const barHeight = Math.max(8, Math.round((row.value / maxValue) * plotHeight));
    const y = top + plotHeight - barHeight;
    const valueLabel = row.value >= 100000
      ? `${Math.round(row.value / 1000)}k`
      : formatNumber(row.value);

    ctx.save();
    ctx.globalAlpha = 0.22;
    ctx.fillStyle = row.color;
    ctx.fillRect(x - barWidth / 2, top, barWidth, plotHeight);
    ctx.restore();

    ctx.fillStyle = row.color;
    ctx.fillRect(x - barWidth / 2, y, barWidth, barHeight);

    ctx.fillStyle = "#ffffff";
    ctx.font = "850 12px Segoe UI, Arial";
    ctx.fillText(valueLabel, x, y - 8);

    ctx.save();
    ctx.translate(x, top + plotHeight + 18);
    ctx.rotate(-Math.PI / 4);
    ctx.fillStyle = "rgba(234,245,255,0.75)";
    ctx.font = "800 12px Segoe UI, Arial";
    ctx.textAlign = "right";
    ctx.fillText(row.label, 0, 0);
    ctx.restore();
  });

  ctx.fillStyle = "rgba(234,245,255,0.55)";
  ctx.font = "800 11px Segoe UI, Arial";
  ctx.textAlign = "left";
  ctx.fillText("Dikey eksen: 1 saniye eşdeğeri", left, canvas.height - 18);
}

observeReveals();
makeTiltZones();
makeDraggableParts();
bindHeroHints();
bindArchitectureDetails();
bindLayerControls();
initKLayoutViewer();
drawPowerCanvas();
drawResourceCanvas();
drawBenchmarkCanvas();
