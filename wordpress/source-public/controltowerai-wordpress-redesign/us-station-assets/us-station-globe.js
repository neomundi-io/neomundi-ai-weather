/**
 * NeoMundi US Station geographic globe.
 *
 * Orthographic behavior and the vendored mobile coastline topology follow the
 * MIT-licensed cambecc/earth project by Cameron Beccario. The pink vector
 * field below is a decorative station surface, not meteorological data.
 */
(function (window, document) {
  "use strict";

  const TAU = Math.PI * 2;
  const RAD = Math.PI / 180;
  const MAX_PARTICLE_AGE = 100;
  const PARTICLE_MULTIPLIER = 7;
  const MOBILE_PARTICLE_REDUCTION = 0.42;
  const CONSTRAINED_PARTICLE_REDUCTION = 0.28;
  const FRAME_INTERVAL = 40;
  const MOBILE_FRAME_INTERVAL = 50;
  const TRAIL_FADE = "rgba(0, 0, 0, 0.97)";
  const PARTICLE_COLORS = Object.freeze([
    "rgba(174, 15, 79, 0.78)",
    "rgba(218, 18, 100, 0.82)",
    "rgba(255, 37, 123, 0.86)",
    "rgba(255, 102, 161, 0.9)",
    "rgba(255, 207, 227, 0.94)"
  ]);
  const VORTICES = Object.freeze([
    { lat: 34, lon: 145, force: 1.1, radius: 34 },
    { lat: 24, lon: -63, force: -0.82, radius: 29 },
    { lat: -42, lon: -128, force: 1.3, radius: 42 },
    { lat: 52, lon: -18, force: -0.72, radius: 25 },
    { lat: -12, lon: 72, force: 0.66, radius: 31 }
  ]);

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function wrapLongitude(value) {
    let result = value;
    while (result > 180) result -= 360;
    while (result < -180) result += 360;
    return result;
  }

  function randomGenerator(seed) {
    let value = seed >>> 0;
    return function random() {
      value = (Math.imul(value, 1664525) + 1013904223) >>> 0;
      return value / 0xffffffff;
    };
  }

  function createParticles(count) {
    const random = randomGenerator(0x5f3759df);
    return Array.from({ length: count }, () => ({
      lat: -78 + random() * 156,
      lon: -180 + random() * 360,
      age: Math.floor(random() * MAX_PARTICLE_AGE),
      speed: 0.58 + random() * 0.9
    }));
  }

  function mediaMatches(query) {
    return typeof window.matchMedia === "function" && window.matchMedia(query).matches;
  }

  function performanceProfile() {
    const mobile = mediaMatches("(max-width: 760px)") || mediaMatches("(pointer: coarse)");
    const cores = Number(window.navigator && window.navigator.hardwareConcurrency) || 8;
    const memory = Number(window.navigator && window.navigator.deviceMemory) || 8;
    const constrained = mobile && (cores <= 4 || memory <= 4);
    return {
      frameInterval: mobile ? MOBILE_FRAME_INTERVAL : FRAME_INTERVAL,
      markerFrameInterval: mobile ? 32 : 16,
      particleReduction: constrained
        ? CONSTRAINED_PARTICLE_REDUCTION
        : mobile
          ? MOBILE_PARTICLE_REDUCTION
          : 1,
      pixelRatioCap: constrained ? 1.25 : mobile ? 1.5 : 2
    };
  }

  function decodeTopology(topology, objectName) {
    const object = topology && topology.objects && topology.objects[objectName];
    if (!object || !Array.isArray(object.geometries)) return [];
    const transform = topology.transform || { scale: [1, 1], translate: [0, 0] };
    const cache = new Map();

    function arcAt(reference) {
      const reversed = reference < 0;
      const index = reversed ? ~reference : reference;
      if (!cache.has(index)) {
        const encoded = topology.arcs[index] || [];
        let x = 0;
        let y = 0;
        const decoded = encoded.map((point) => {
          x += point[0];
          y += point[1];
          return [
            x * transform.scale[0] + transform.translate[0],
            y * transform.scale[1] + transform.translate[1]
          ];
        });
        cache.set(index, decoded);
      }
      const arc = cache.get(index);
      return reversed ? [...arc].reverse() : arc;
    }

    return object.geometries.map((geometry) => {
      const line = [];
      (Array.isArray(geometry.arcs) ? geometry.arcs : []).forEach((reference, arcIndex) => {
        const arc = arcAt(reference);
        line.push(...(arcIndex ? arc.slice(1) : arc));
      });
      return line;
    }).filter((line) => line.length > 1);
  }

  class USStationGlobe {
    constructor(canvas, options) {
      if (!canvas || typeof canvas.getContext !== "function") {
        throw new Error("US Station requires a canvas interaction surface");
      }
      this.canvas = canvas;
      this.context = canvas.getContext("2d", { alpha: true });
      this.markerCanvas = document.querySelector("[data-globe-markers]");
      this.markerContext = this.markerCanvas && this.markerCanvas.getContext("2d", { alpha: true });
      this.trailCanvas = document.createElement("canvas");
      this.trailContext = this.trailCanvas.getContext("2d", { alpha: true });
      if (!this.context || !this.markerContext || !this.trailContext) {
        throw new Error("US Station could not initialize its 2D canvas contexts");
      }
      this.cities = options.cities || [];
      this.onSelect = options.onSelect || function () {};
      this.onHover = options.onHover || function () {};
      this.topologyUrl = options.topologyUrl || "./assets/us-station-earth-topo.json";
      this.rotation = new Date().getTimezoneOffset() / 4;
      this.tilt = 0;
      this.zoom = 1;
      this.zoomTarget = 1;
      this.dragging = false;
      this.dragDistance = 0;
      this.hovered = null;
      this.hoverMotion = new Map(this.cities.map((city) => [city.id, { value: 0, velocity: 0 }]));
      this.pointer = { x: -1000, y: -1000 };
      this.lastPointer = null;
      this.cityPoints = [];
      this.coastlines = [];
      this.lakes = [];
      this.visible = true;
      this.paused = false;
      this.lastFrame = performance.now();
      this.lastMarkerFrame = this.lastFrame;
      this.trailsDirty = true;
      this.reducedMotion = mediaMatches("(prefers-reduced-motion: reduce)");
      this.profile = performanceProfile();
      this.particles = [];
      this.bind();
      this.resize();
      this.animate = this.animate.bind(this);
      this.loadGeography();
      this.frame = requestAnimationFrame(this.animate);
    }

    async loadGeography() {
      try {
        const response = await fetch(this.topologyUrl, { cache: "force-cache" });
        if (!response.ok) throw new Error("Earth topology unavailable");
        const topology = await response.json();
        this.coastlines = decodeTopology(topology, "coastline_110m");
        this.lakes = decodeTopology(topology, "lakes_110m");
        this.canvas.classList.add("has-geography");
      } catch (error) {
        this.canvas.classList.add("has-geography-fallback");
      }
    }

    bind() {
      this.boundResize = () => this.resize();
      if (typeof window.ResizeObserver === "function") {
        this.resizeObserver = new window.ResizeObserver(this.boundResize);
        this.resizeObserver.observe(this.canvas.parentElement || this.canvas);
      } else {
        this.resizeObserver = null;
        window.addEventListener("resize", this.boundResize, { passive: true });
      }
      this.canvas.addEventListener("pointerdown", (event) => this.pointerDown(event));
      this.canvas.addEventListener("pointermove", (event) => this.pointerMove(event));
      this.canvas.addEventListener("pointerup", (event) => this.pointerUp(event));
      this.canvas.addEventListener("pointercancel", (event) => this.pointerUp(event));
      this.canvas.addEventListener("click", (event) => this.click(event));
      this.canvas.addEventListener("pointerleave", () => {
        if (!this.dragging) {
          this.pointer = { x: -1000, y: -1000 };
          this.setHovered(null);
        }
      });
      this.canvas.addEventListener("wheel", (event) => {
        event.preventDefault();
        this.zoomTarget = clamp(this.zoomTarget - event.deltaY * 0.001, 0.76, 1.42);
      }, { passive: false });
      this.canvas.addEventListener("keydown", (event) => this.keyDown(event));
      document.addEventListener("visibilitychange", () => {
        this.visible = !document.hidden;
        this.lastFrame = performance.now();
        this.lastMarkerFrame = this.lastFrame;
      });
    }

    resize() {
      this.profile = performanceProfile();
      const rect = this.canvas.getBoundingClientRect();
      const ratio = Math.min(this.profile.pixelRatioCap, window.devicePixelRatio || 1);
      const width = Math.max(320, Math.round(rect.width || window.innerWidth));
      const height = Math.max(320, Math.round(rect.height || window.innerHeight));
      this.canvas.width = Math.round(width * ratio);
      this.canvas.height = Math.round(height * ratio);
      this.context.setTransform(ratio, 0, 0, ratio, 0, 0);
      this.markerCanvas.width = Math.round(width * ratio);
      this.markerCanvas.height = Math.round(height * ratio);
      this.markerContext.setTransform(ratio, 0, 0, ratio, 0, 0);
      this.trailCanvas.width = this.canvas.width;
      this.trailCanvas.height = this.canvas.height;
      this.trailContext.setTransform(ratio, 0, 0, ratio, 0, 0);
      this.width = width;
      this.height = height;
      this.baseRadius = Math.min(width, height) * 0.45;
      this.center = { x: width / 2, y: height / 2 };
      const particleCount = Math.round(
        this.baseRadius * 2 * PARTICLE_MULTIPLIER * this.profile.particleReduction
      );
      this.particles = createParticles(particleCount);
      this.trailsDirty = true;
      this.draw(performance.now(), 0);
      this.drawCities(performance.now(), 16);
    }

    get radius() {
      return this.baseRadius * this.zoom;
    }

    project(lat, lon) {
      const phi = lat * RAD;
      const lambda = (lon + this.rotation) * RAD;
      const tilt = this.tilt * RAD;
      const x = Math.cos(phi) * Math.sin(lambda);
      const y0 = Math.sin(phi);
      const z0 = Math.cos(phi) * Math.cos(lambda);
      const y = y0 * Math.cos(tilt) - z0 * Math.sin(tilt);
      const z = y0 * Math.sin(tilt) + z0 * Math.cos(tilt);
      return { x: this.center.x + this.radius * x, y: this.center.y - this.radius * y, z };
    }

    pointerPosition(event) {
      const rect = this.canvas.getBoundingClientRect();
      return { x: event.clientX - rect.left, y: event.clientY - rect.top };
    }

    pointerDown(event) {
      this.dragging = true;
      this.dragDistance = 0;
      this.lastPointer = this.pointerPosition(event);
      this.pointer = this.lastPointer;
      if (typeof this.canvas.setPointerCapture === "function" && event.pointerId !== undefined) {
        this.canvas.setPointerCapture(event.pointerId);
      }
      this.canvas.classList.add("is-dragging");
    }

    pointerMove(event) {
      const position = this.pointerPosition(event);
      this.pointer = position;
      if (this.dragging && this.lastPointer) {
        const dx = position.x - this.lastPointer.x;
        const dy = position.y - this.lastPointer.y;
        const sensitivity = 72 / this.radius;
        this.rotation += dx * sensitivity;
        this.tilt = clamp(this.tilt - dy * sensitivity, -68, 68);
        this.trailsDirty = true;
        this.dragDistance += Math.abs(dx) + Math.abs(dy);
        this.lastPointer = position;
        this.setHovered(null);
      } else {
        this.pickHovered();
      }
    }

    pointerUp(event) {
      if (!this.dragging) return;
      this.dragging = false;
      this.canvas.classList.remove("is-dragging");
      if (
        typeof this.canvas.hasPointerCapture === "function" &&
        typeof this.canvas.releasePointerCapture === "function" &&
        event.pointerId !== undefined &&
        this.canvas.hasPointerCapture(event.pointerId)
      ) {
        this.canvas.releasePointerCapture(event.pointerId);
      }
      this.pickHovered();
      this.lastPointer = null;
    }

    click(event) {
      if (this.dragDistance >= 8) return;
      this.pointer = this.pointerPosition(event);
      this.pickHovered();
      if (this.hovered) {
        this.onSelect(this.hovered.city, {
          x: event.clientX,
          y: event.clientY,
          input: "pointer"
        });
      }
    }

    keyDown(event) {
      const directions = ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"];
      if (directions.includes(event.key)) event.preventDefault();
      if (event.key === "ArrowLeft") this.rotation -= 5;
      if (event.key === "ArrowRight") this.rotation += 5;
      if (event.key === "ArrowUp") this.tilt = clamp(this.tilt + 4, -68, 68);
      if (event.key === "ArrowDown") this.tilt = clamp(this.tilt - 4, -68, 68);
      if (event.key === "+" || event.key === "=") this.zoomTarget = clamp(this.zoomTarget + 0.08, 0.76, 1.42);
      if (event.key === "-") this.zoomTarget = clamp(this.zoomTarget - 0.08, 0.76, 1.42);
      if (event.key === "Enter" || event.key === " ") {
        const target = this.hovered || [...this.cityPoints].filter((point) => point.z > 0).sort((a, b) => b.z - a.z)[0];
        if (target) {
          event.preventDefault();
          const rect = this.canvas.getBoundingClientRect();
          this.onSelect(target.city, {
            x: rect.left + target.x,
            y: rect.top + target.y,
            input: "keyboard"
          });
        }
      }
    }

    setHovered(value) {
      if ((this.hovered && this.hovered.city.id) === (value && value.city.id)) return;
      this.hovered = value;
      this.canvas.classList.toggle("has-point-hover", Boolean(value));
      this.onHover(value ? value.city : null);
    }

    pickHovered() {
      let candidate = null;
      let distance = this.profile.particleReduction < 1 ? 44 : this.width < 620 ? 36 : 38;
      for (const point of this.cityPoints) {
        if (point.z <= 0) continue;
        const current = Math.hypot(point.x - this.pointer.x, point.y - this.pointer.y);
        if (current < distance) {
          candidate = point;
          distance = current;
        }
      }
      this.setHovered(candidate);
    }

    drawAtmosphere() {
      const context = this.context;
      const radius = this.radius;
      context.save();
      context.strokeStyle = "#000005";
      context.lineWidth = 4;
      context.beginPath();
      context.arc(this.center.x, this.center.y, radius - 1.5, 0, TAU);
      context.stroke();
      context.restore();
    }

    drawSphere() {
      const radius = this.radius;
      const surface = this.context.createRadialGradient(
        this.center.x,
        this.center.y - radius * 0.01,
        0,
        this.center.x,
        this.center.y - radius * 0.01,
        radius
      );
      surface.addColorStop(0, "#2d0a1a");
      surface.addColorStop(0.69, "#2d0a1a");
      surface.addColorStop(0.91, "#19050e");
      surface.addColorStop(0.96, "#000005");
      surface.addColorStop(1, "#000005");
      this.context.fillStyle = surface;
      this.context.beginPath();
      this.context.arc(this.center.x, this.center.y, radius, 0, TAU);
      this.context.fill();
    }

    drawGrid() {
      const context = this.context;
      context.save();
      context.beginPath();
      context.arc(this.center.x, this.center.y, this.radius, 0, TAU);
      context.clip();
      context.strokeStyle = "rgba(112, 38, 72, 0.72)";
      context.lineWidth = 1;
      const drawLine = (points) => {
        context.beginPath();
        let active = false;
        points.forEach((point) => {
          if (point.z <= 0) active = false;
          else {
            if (active) context.lineTo(point.x, point.y);
            else context.moveTo(point.x, point.y);
            active = true;
          }
        });
        context.stroke();
      };
      for (let lat = -80; lat <= 80; lat += 10) {
        const points = [];
        for (let lon = -180; lon <= 180; lon += 2) points.push(this.project(lat, lon));
        drawLine(points);
      }
      for (let lon = -180; lon < 180; lon += 10) {
        const points = [];
        for (let lat = -88; lat <= 88; lat += 2) points.push(this.project(lat, lon));
        drawLine(points);
      }
      context.restore();
    }

    flowAt(lat, lon, time) {
      const phi = lat * RAD;
      const lambda = lon * RAD;
      let east = 8 + Math.cos(phi * 2.4) * 5 + Math.sin(lambda * 2.8 + time * 0.00005) * 2.2;
      let north = Math.sin(lambda * 1.8 - phi * 2.2 - time * 0.000035) * 2.5;
      VORTICES.forEach((vortex) => {
        const dx = wrapLongitude(lon - vortex.lon);
        const dy = lat - vortex.lat;
        const influence = Math.exp(-(dx * dx + dy * dy) / (vortex.radius * vortex.radius));
        east += -dy * vortex.force * influence * 0.42;
        north += dx * vortex.force * influence * 0.42;
      });
      return { east, north };
    }

    respawnParticle(particle, index) {
      const random = randomGenerator((index + 1) * 2654435761 + Math.floor(performance.now()));
      particle.lat = -78 + random() * 156;
      particle.lon = -180 + random() * 360;
      particle.age = 0;
    }

    drawParticles(time, delta) {
      const context = this.trailContext;
      const step = this.reducedMotion ? 0 : Math.min(delta, 42) / 1000;
      if (this.trailsDirty) {
        context.clearRect(0, 0, this.width, this.height);
        this.trailsDirty = false;
      } else {
        context.save();
        context.globalCompositeOperation = "destination-in";
        context.fillStyle = TRAIL_FADE;
        context.fillRect(0, 0, this.width, this.height);
        context.restore();
      }
      const buckets = PARTICLE_COLORS.map(() => []);
      context.save();
      context.beginPath();
      context.arc(this.center.x, this.center.y, this.radius - 1, 0, TAU);
      context.clip();
      context.lineCap = "round";
      context.lineWidth = 1;
      this.particles.forEach((particle, index) => {
        if (particle.age > MAX_PARTICLE_AGE) this.respawnParticle(particle, index);
        const start = this.project(particle.lat, particle.lon);
        const flow = this.flowAt(particle.lat, particle.lon, time);
        const latitudeScale = Math.max(0.25, Math.cos(particle.lat * RAD));
        if (!this.reducedMotion) {
          particle.lon = wrapLongitude(particle.lon + (flow.east * step * particle.speed) / latitudeScale);
          particle.lat += flow.north * step * particle.speed;
        }
        particle.age += 1;
        if (particle.lat > 82 || particle.lat < -82) {
          this.respawnParticle(particle, index);
          return;
        }
        const end = this.project(particle.lat, particle.lon);
        if (start.z <= 0 || end.z <= 0) return;
        const strength = Math.min(1, Math.hypot(flow.east, flow.north) / 17);
        buckets[Math.min(PARTICLE_COLORS.length - 1, Math.floor(strength * PARTICLE_COLORS.length))].push({ start, end });
      });
      buckets.forEach((bucket, index) => {
        if (!bucket.length) return;
        context.strokeStyle = PARTICLE_COLORS[index];
        context.beginPath();
        bucket.forEach((segment) => {
          context.moveTo(segment.start.x, segment.start.y);
          context.lineTo(segment.end.x, segment.end.y);
        });
        context.stroke();
      });
      context.restore();
    }

    drawGeography(lines, color, width, glow) {
      const context = this.context;
      context.save();
      context.beginPath();
      context.arc(this.center.x, this.center.y, this.radius, 0, TAU);
      context.clip();
      context.strokeStyle = color;
      context.lineWidth = width;
      context.lineJoin = "round";
      context.lineCap = "round";
      context.shadowColor = color;
      context.shadowBlur = glow;
      lines.forEach((line) => {
        context.beginPath();
        let active = false;
        let previous = null;
        line.forEach((coordinate) => {
          const point = this.project(coordinate[1], coordinate[0]);
          const jump = previous && Math.hypot(point.x - previous.x, point.y - previous.y) > this.radius * 0.24;
          if (point.z <= -0.015 || jump) active = false;
          else {
            if (active) context.lineTo(point.x, point.y);
            else context.moveTo(point.x, point.y);
            active = true;
          }
          previous = point;
        });
        context.stroke();
      });
      context.restore();
    }

    drawCities(time, delta) {
      const context = this.markerContext;
      const pulse = this.reducedMotion ? 0.5 : (Math.sin(time / 720) + 1) / 2;
      context.clearRect(0, 0, this.width, this.height);
      this.cityPoints = this.cities.map((city) => ({ city, ...this.project(city.lat, city.lon) }));
      [...this.cityPoints].sort((a, b) => a.z - b.z).forEach((point) => {
        if (point.z <= 0) return;
        const hovered = this.hovered && this.hovered.city.id === point.city.id;
        const motion = this.hoverMotion.get(point.city.id) || { value: 0, velocity: 0 };
        const target = hovered ? 1 : 0;
        if (this.reducedMotion) {
          motion.value = target;
          motion.velocity = 0;
        } else {
          const step = Math.min(34, Math.max(0, delta || 16)) / 1000;
          motion.velocity += ((target - motion.value) * 260 - motion.velocity * 29) * step;
          motion.value = clamp(motion.value + motion.velocity * step, 0, 1);
          if (Math.abs(target - motion.value) < 0.0005 && Math.abs(motion.velocity) < 0.002) {
            motion.value = target;
            motion.velocity = 0;
          }
        }
        this.hoverMotion.set(point.city.id, motion);
        const reveal = motion.value;
        const depth = clamp(point.z, 0.08, 1);
        const restRing = 6.2 + pulse * 1.1;
        const core = (2.15 + reveal * 2.05) * (0.78 + depth * 0.3);
        const ring = (restRing + reveal * (10 - restRing)) * (0.84 + depth * 0.22);
        const pinkMix = Math.round(59 + reveal * 188);
        const blueMix = Math.round(140 + reveal * 110);
        context.save();
        context.globalAlpha = 0.72 + depth * 0.28;
        context.fillStyle = "rgba(0, 0, 5, 0.8)";
        context.beginPath();
        context.arc(point.x, point.y, ring + 3 + reveal * 1.5, 0, TAU);
        context.fill();
        context.shadowColor = "rgb(255, " + pinkMix + ", " + blueMix + ")";
        context.shadowBlur = 10 + pulse * 5 + reveal * 12;
        context.strokeStyle = "rgb(255, " + pinkMix + ", " + blueMix + ")";
        context.lineWidth = 1 + reveal * 0.35;
        context.beginPath();
        context.arc(point.x, point.y, ring, 0, TAU);
        context.stroke();
        context.fillStyle = "#fff8fb";
        context.beginPath();
        context.arc(point.x, point.y, core, 0, TAU);
        context.fill();
        context.restore();
      });
      if (!this.dragging) this.pickHovered();
    }

    draw(time, delta) {
      if (!this.context || !this.width) return;
      this.context.clearRect(0, 0, this.width, this.height);
      this.drawSphere();
      this.drawGrid();
      this.drawGeography(this.coastlines, "rgba(255, 236, 245, 0.94)", 1.25, 0);
      this.drawGeography(this.lakes, "rgba(255, 236, 245, 0.86)", 1.05, 0);
      this.drawParticles(time || performance.now(), delta || 0);
      this.context.drawImage(this.trailCanvas, 0, 0, this.width, this.height);
      this.drawAtmosphere();
    }

    animate(time) {
      const delta = time - this.lastFrame;
      const markerDelta = time - this.lastMarkerFrame;
      if (this.visible && !this.paused) {
        if (delta >= this.profile.frameInterval) {
          this.lastFrame = time;
          const previousZoom = this.zoom;
          this.zoom += (this.zoomTarget - this.zoom) * 0.09;
          if (Math.abs(previousZoom - this.zoom) > 0.0001) this.trailsDirty = true;
          this.draw(time, Math.min(delta, this.profile.frameInterval * 2));
        }
        if (markerDelta >= this.profile.markerFrameInterval) {
          this.lastMarkerFrame = time;
          this.drawCities(time, Math.min(markerDelta, 34));
        }
      }
      this.frame = requestAnimationFrame(this.animate);
    }

    setPaused(value) {
      this.paused = Boolean(value);
      this.lastFrame = performance.now();
      this.lastMarkerFrame = this.lastFrame;
      if (this.paused) {
        this.pointer = { x: -1000, y: -1000 };
        this.setHovered(null);
        this.hoverMotion.forEach((motion) => {
          motion.value = 0;
          motion.velocity = 0;
        });
        this.drawCities(this.lastFrame, 16);
      }
    }

    focusCity(city) {
      if (!city) return;
      this.rotation = -city.lon;
      this.tilt = clamp(city.lat * 0.15, -32, 32);
      this.trailsDirty = true;
    }

    destroy() {
      cancelAnimationFrame(this.frame);
      if (this.resizeObserver) this.resizeObserver.disconnect();
      else window.removeEventListener("resize", this.boundResize);
    }
  }

  window.USStationGlobe = USStationGlobe;
})(window, document);
