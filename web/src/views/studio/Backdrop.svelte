<script lang="ts">
  import '../../styles/studio.css';
  import { fleet, shot, studio } from '../../stores';
  import { gameTexture } from '../../lib/glass';
  import {
    fontsFor,
    footLine,
    drawBackground,
    drawImages,
    drawShadow,
    drawTexts,
    boxRect,
    edgeOf,
    frameFor,
    groundAt,
    groundLine,
    keepCar,
    picturesLoaded,
    placeLine,
    preview,
    reflectFade,
    reflectStart,
    type Look,
    type Point,
    type Rect,
  } from '../../lib/look';

  let { area }: { area: Rect } = $props();
  let canvas: HTMLCanvasElement;

  const VERTEX = `attribute vec2 a_position; attribute vec2 a_texcoord; varying vec2 uv;
    void main() { gl_Position = vec4(a_position, 0.0, 1.0); uv = a_texcoord; }`;
  const FRAGMENT = `precision mediump float;
    varying vec2 uv;
    uniform sampler2D external_texture;
    uniform sampler2D u_bg;
    uniform sampler2D u_shadow;
    uniform sampler2D u_back;
    uniform sampler2D u_ground;
    uniform sampler2D u_front;
    uniform float u_mask;
    uniform float u_top;
    uniform float u_span;
    uniform float u_fade;
    uniform float u_reflect;
    uniform vec4 u_frame;
    uniform vec4 u_canvas;
    uniform vec2 u_edge;
    uniform vec2 u_key;
    uniform vec4 u_fix;
    uniform float u_rblur;
    uniform vec2 u_cell;
    uniform vec2 u_px;
    uniform float u_aspect;
    uniform sampler2D u_keep;
    float cover(vec3 c) { float g = (c.g - max(c.r, c.b)) * 255.0; return 1.0 - clamp((g - u_key.x) / (u_key.y - u_key.x), 0.0, 1.0); }
    vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
    vec3 fix(vec3 l) {
      float lift = 1.0 + u_fix.x / 100.0;
      l *= vec3(lift * (1.0 + u_fix.w / 250.0), lift, lift * (1.0 - u_fix.w / 250.0));
      float y = dot(l, vec3(0.2126, 0.7152, 0.0722));
      l = y + (l - y) * (1.0 + u_fix.z / 50.0);
      return max(vec3(0.0), 0.18 + (l - 0.18) * (1.0 + u_fix.y / 100.0));
    }
    float inside(vec2 p) { return step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0) * texture2D(u_keep, p).r; }
    vec3 despill(vec3 c) { return vec3(c.r, min(c.g, max(c.r, c.b)), c.b); }
    void main() {
      if (u_mask > 0.5) {
        vec2 q = u_cell * 0.25;
        float m = max(max(cover(texture2D(external_texture, uv + vec2(-q.x, -q.y)).rgb), cover(texture2D(external_texture, uv + vec2(q.x, -q.y)).rgb)),
          max(cover(texture2D(external_texture, uv + vec2(-q.x, q.y)).rgb), cover(texture2D(external_texture, uv + vec2(q.x, q.y)).rgb)));
        gl_FragColor = vec4(m, m, m, 1.0);
        return;
      }
      vec2 f = (uv - u_canvas.xy) / (u_canvas.zw - u_canvas.xy);
      if (f.x < 0.0 || f.x > 1.0 || f.y < 0.0 || f.y > 1.0) { gl_FragColor = vec4(0.031, 0.035, 0.047, 1.0); return; }
      vec2 g = u_frame.xy + f * (u_frame.zw - u_frame.xy);
      vec3 game = texture2D(external_texture, g).rgb;
      float a = cover(game) * inside(g);
      if (a > 0.0) {
        vec2 d = u_px * 2.0;
        vec2 slope = vec2(
          cover(texture2D(external_texture, g + vec2(d.x, 0.0)).rgb) - cover(texture2D(external_texture, g - vec2(d.x, 0.0)).rgb),
          cover(texture2D(external_texture, g + vec2(0.0, d.y)).rgb) - cover(texture2D(external_texture, g - vec2(0.0, d.y)).rgb));
        float steep = length(slope);
        if (steep > 0.15) {
          vec3 inner = texture2D(external_texture, g + slope / steep * u_px * 3.0).rgb;
          if (cover(inner) > cover(game)) game = mix(game, inner, 0.85);
        }
        a = smoothstep(0.15, 0.85, a);
      }
      vec2 p = vec2(f.x, 1.0 - f.y);
      vec3 colour = texture2D(u_bg, p).rgb;
      colour = mix(colour, vec3(0.0), texture2D(u_shadow, p).a);
      vec4 back = texture2D(u_back, p);
      colour = lin(mix(colour, back.rgb, back.a));
      float floor = u_top - texture2D(u_ground, vec2(g.x, 0.5)).r * u_span;
      if (u_reflect > 0.0 && g.y < floor && floor - g.y < u_fade) {
        float t = (floor - g.y) / u_fade;
        vec2 c = vec2(g.x, 2.0 * floor - g.y);
        float r = (floor - g.y) * 0.12 * u_rblur;
        vec3 sum = vec3(0.0);
        float hit = 0.0;
        for (int i = 0; i < 5; i++) {
          float w = r / u_aspect;
          vec2 o = i == 0 ? vec2(0.0) : i == 1 ? vec2(w, 0.0) : i == 2 ? vec2(-w, 0.0) : i == 3 ? vec2(0.0, r) : vec2(0.0, -r);
          vec3 m = texture2D(external_texture, c + o).rgb;
          float k = cover(m) * inside(c + o);
          sum += lin(despill(m)) * k;
          hit += k;
        }
        if (hit > 0.0) colour = mix(colour, sum / hit, hit / 5.0 * u_reflect * pow(1.0 - t, 1.6));
      }
      colour = mix(colour, lin(despill(game)), a);
      vec4 front = texture2D(u_front, p);
      colour = pow(fix(mix(colour, lin(front.rgb), front.a)), vec3(1.0 / 2.2));
      if (f.x < u_edge.x || f.x > 1.0 - u_edge.x || f.y < u_edge.y || f.y > 1.0 - u_edge.y) colour = mix(colour, vec3(1.0), 0.22);
      gl_FragColor = vec4(colour, 1.0);
    }`;

  const MASK_W = 256;
  const REPAINT_MS = 120;
  const SHADOW_EVERY = 4;
  const GROUND_W = 512;
  const UNITS = { bg: 1, shadow: 2, back: 3, ground: 4, front: 5, keep: 7 };

  function setup(gl: WebGLRenderingContext) {
    gl.activeTexture(gl.TEXTURE0);
    gameTexture(gl);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    const shader = (type: number, source: string) => {
      const compiled = gl.createShader(type)!;
      gl.shaderSource(compiled, source);
      gl.compileShader(compiled);
      return compiled;
    };
    const program = gl.createProgram()!;
    gl.attachShader(program, shader(gl.VERTEX_SHADER, VERTEX));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, FRAGMENT));
    gl.linkProgram(program);
    gl.useProgram(program);
    const quad = (name: string, data: number[]) => {
      gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
      const at = gl.getAttribLocation(program, name);
      gl.vertexAttribPointer(at, 2, gl.FLOAT, false, 0, 0);
      gl.enableVertexAttribArray(at);
    };
    quad('a_position', [-1, -1, 1, -1, -1, 1, 1, 1]);
    quad('a_texcoord', [0, 0, 1, 0, 0, 1, 1, 1]);
    const uniform = (name: string) => gl.getUniformLocation(program, name);
    gl.uniform1i(uniform('external_texture'), 0);
    for (const [name, unit] of Object.entries(UNITS)) {
      gl.uniform1i(uniform(`u_${name}`), unit);
      gl.activeTexture(gl.TEXTURE0 + unit);
      gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
    }
    gl.activeTexture(gl.TEXTURE0 + UNITS.keep);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.activeTexture(gl.TEXTURE6);
    const target = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, target);
    gl.activeTexture(gl.TEXTURE0);

    return {
      mask: uniform('u_mask'),
      top: uniform('u_top'),
      span: uniform('u_span'),
      fade: uniform('u_fade'),
      reflect: uniform('u_reflect'),
      rblur: uniform('u_rblur'),
      px: uniform('u_px'),
      cell: uniform('u_cell'),
      aspect: uniform('u_aspect'),
      frame: uniform('u_frame'),
      canvas: uniform('u_canvas'),
      edge: uniform('u_edge'),
      key: uniform('u_key'),
      fix: uniform('u_fix'),
      target,
      fbo: gl.createFramebuffer(),
    };
  }

  const lookKey = (look: Look) =>
    JSON.stringify([
      look.bg,
      look.bgColourA,
      look.bgColourB,
      look.bgImage,
      look.bgAngle,
      look.horizon,
      look.vignette,
      look.texts,
      look.images,
      studio.model,
      fleet.nameOf(studio.model),
      picturesLoaded(),
      fontsLoaded,
    ]);

  let fontsLoaded = 0;
  if (typeof document !== 'undefined') document.fonts.addEventListener('loadingdone', () => fontsLoaded++);

  $effect(() => {
    const gl = canvas.getContext('webgl', { antialias: false, depth: false, stencil: false, alpha: false });
    if (!gl) return;
    const uniforms = setup(gl);
    const make = () => {
      const surface = document.createElement('canvas');
      return { canvas: surface, ctx: surface.getContext('2d')! };
    };
    const bg = make();
    const back = make();
    const front = make();
    const shade = make();
    const checker = make();
    const groundRow = new Uint8Array(GROUND_W);
    const silhouette = make();
    let maskH = 0;
    let pixels = new Uint8Array(0);
    let fresh = new Uint8Array(0);
    let grid = new Uint8Array(0);
    let bottoms = new Int32Array(MASK_W);
    let ground: Point[] = [];
    let paintedAspect = 0;
    let paintedAt = 0;
    let car: Rect | null = null;
    let painted = '';
    let paintedW = 0;
    let shadowKey = '';
    let frame = 0;
    let tick = 0;
    let usual = 0;
    let usualModel = '';
    let odd = 0;
    let outlineData: ImageData | null = null;
    let shown: Rect | null = null;
    let fitScale = 0;

    preview.on = true;

    const toGame = (x: number, y: number) => {
      const shownFrame = preview.frame;
      const gameFrame = preview.game;
      if (!shownFrame || !gameFrame) return { x, y };

      return {
        x: gameFrame.x + ((x - shownFrame.x) / shownFrame.w) * gameFrame.w,
        y: gameFrame.y + ((y - shownFrame.y) / shownFrame.h) * gameFrame.h,
      };
    };
    preview.carAt = (screenX, screenY) => {
      if (!maskH) return false;
      const { x, y } = toGame(screenX, screenY);
      const mx = Math.floor((x / innerWidth) * MASK_W);
      const my = Math.floor((y / innerHeight) * maskH);
      if (mx < 0 || my < 0 || mx >= MASK_W || my >= maskH) return false;
      return pixels[(maskH - 1 - my) * MASK_W + mx] > 128;
    };

    const upload = (unit: number, source: HTMLCanvasElement) => {
      gl.activeTexture(gl.TEXTURE0 + unit);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, source);
      gl.activeTexture(gl.TEXTURE0);
    };

    function findCar(w: number, h: number, outline: boolean): Rect | null | 'skip' {
      gl!.bindFramebuffer(gl!.FRAMEBUFFER, uniforms.fbo);
      gl!.viewport(0, 0, MASK_W, maskH);
      gl!.uniform1f(uniforms.mask, 1);
      gl!.uniform2f(uniforms.cell, 1 / MASK_W, 1 / maskH);
      gl!.drawArrays(gl!.TRIANGLE_STRIP, 0, 4);
      gl!.readPixels(0, 0, MASK_W, maskH, gl!.RGBA, gl!.UNSIGNED_BYTE, fresh);
      gl!.bindFramebuffer(gl!.FRAMEBUFFER, null);
      gl!.uniform1f(uniforms.mask, 0);
      gl!.viewport(0, 0, w, h);
      const n = MASK_W * maskH;
      const only = preview.only;
      for (let i = 0; i < n; i++) grid[i] = fresh[i * 4] > 128 ? 1 : 0;
      const keep = keepCar(grid, MASK_W, maskH, [only[0], 1 - only[3], only[2], 1 - only[1]]);
      let count = 0;
      for (let i = 0; i < n; i++) if (grid[i] && keep[i]) count++;
      const cells = Math.max(1, (only[2] - only[0]) * (only[3] - only[1]) * n);
      const fill = count / cells;
      if (usualModel !== studio.model) {
        usualModel = studio.model;
        usual = 0;
      }
      if (usual && Math.abs(fill - usual) > usual * 0.2 + 30 / cells && odd < 4) {
        odd++;
        return 'skip';
      }
      odd = 0;
      if (count) usual = fill;
      for (let i = 0; i < n; i++) {
        pixels[i] = grid[i] && keep[i] ? 255 : 0;
        keep[i] *= 255;
      }
      gl!.activeTexture(gl!.TEXTURE0 + UNITS.keep);
      gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.LUMINANCE, MASK_W, maskH, 0, gl!.LUMINANCE, gl!.UNSIGNED_BYTE, keep);
      gl!.activeTexture(gl!.TEXTURE0);
      let x0 = MASK_W;
      let x1 = -1;
      let y0 = maskH;
      let y1 = -1;
      bottoms.fill(-1);
      for (let row = 0; row < maskH; row++) {
        const y = maskH - 1 - row;
        for (let x = 0; x < MASK_W; x++) {
          if (pixels[row * MASK_W + x]) {
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
            if (y > bottoms[x]) bottoms[x] = y;
          }
        }
      }
      if (x1 < 0) return null;
      if (outline) {
        if (!outlineData || outlineData.height !== maskH) outlineData = silhouette.ctx.createImageData(MASK_W, maskH);
        const image = outlineData;
        for (let row = 0; row < maskH; row++) {
          const y = maskH - 1 - row;
          for (let x = 0; x < MASK_W; x++) image.data[(y * MASK_W + x) * 4 + 3] = pixels[row * MASK_W + x];
        }
        silhouette.ctx.putImageData(image, 0, 0);
      }
      const scaleX = w / MASK_W;
      const scaleY = h / maskH;
      const foot = preview.foot;
      ground = foot
        ? footLine(foot.map(([x, y]) => ({ x: x * w, y: y * h })))
        : placeLine(groundLine(bottoms), scaleX, scaleY, scaleX / 2, scaleY);
      return { x: x0 * scaleX, y: y0 * scaleY, w: (x1 - x0 + 1) * scaleX, h: (y1 - y0 + 1) * scaleY };
    }

    function paintFrame(look: Look, target: Rect) {
      const w = Math.max(2, Math.min(1600, Math.round(target.w)));
      const h = Math.max(2, Math.round((w * target.h) / target.w));
      for (const layer of [bg, back, front]) {
        layer.canvas.width = w;
        layer.canvas.height = h;
      }
      const whole = { x: 0, y: 0, w, h };
      bg.ctx.fillStyle = '#08090c';
      bg.ctx.fillRect(0, 0, w, h);
      if (look.bg === 'none') {
        const cell = Math.max(8, Math.round(h / 24));
        if (checker.canvas.width !== cell * 2) {
          checker.canvas.width = checker.canvas.height = cell * 2;
          checker.ctx.fillStyle = '#121318';
          checker.ctx.fillRect(0, 0, cell * 2, cell * 2);
          checker.ctx.fillStyle = '#1a1b22';
          checker.ctx.fillRect(cell, 0, cell, cell);
          checker.ctx.fillRect(0, cell, cell, cell);
        }
        bg.ctx.fillStyle = bg.ctx.createPattern(checker.canvas, 'repeat')!;
        bg.ctx.fillRect(0, 0, w, h);
      }
      drawBackground(bg.ctx, whole, look);
      const name = fleet.nameOf(studio.model);
      const model = studio.model;
      const pictures = drawImages(back.ctx, whole, look, true);
      drawImages(front.ctx, whole, look, false);
      preview.boxes = [...pictures, ...drawTexts(back.ctx, whole, look, true, name, model)];
      drawTexts(front.ctx, whole, look, false, name, model);
      upload(UNITS.bg, bg.canvas);
      upload(UNITS.back, back.canvas);
      upload(UNITS.front, front.canvas);
      paintedW = target.w;
      paintedAspect = target.w / target.h;
      paintedAt = performance.now();
    }

    function paintShadow(look: Look, gameFrame: Rect, carBox: Rect) {
      const key = JSON.stringify([
        look.shadow,
        look.shadowSoft,
        look.shadowWide,
        look.shadowStyle,
        ground,
        Math.round(gameFrame.x),
        Math.round(gameFrame.y),
        Math.round(gameFrame.w),
      ]);
      if (key === shadowKey) return;
      shadowKey = key;
      const scale = Math.min(1, 480 / gameFrame.w);
      const w = Math.max(2, Math.round(gameFrame.w * scale));
      const h = Math.max(2, Math.round(gameFrame.h * scale));
      shade.canvas.width = w;
      shade.canvas.height = h;
      if (look.shadow > 0) {
        const line = placeLine(ground, scale, scale, -gameFrame.x * scale, -gameFrame.y * scale);
        const placed = {
          x: (carBox.x - gameFrame.x) * scale,
          y: (carBox.y - gameFrame.y) * scale,
          w: carBox.w * scale,
          h: carBox.h * scale,
        };
        const at = { x: -gameFrame.x * scale, y: -gameFrame.y * scale, w: innerWidth * scale, h: innerHeight * scale };
        drawShadow(shade.ctx, line, placed, look, { src: silhouette.canvas, at });
      }
      upload(UNITS.shadow, shade.canvas);
    }

    const draw = () => {
      if (shot.shooting) {
        frame = requestAnimationFrame(draw);
        return;
      }
      const w = innerWidth;
      const h = innerHeight;

      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
        maskH = Math.max(1, Math.round((MASK_W * h) / w));
        pixels = new Uint8Array(MASK_W * maskH);
        fresh = new Uint8Array(MASK_W * maskH * 4);
        grid = new Uint8Array(MASK_W * maskH);
        usual = 0;
        silhouette.canvas.width = MASK_W;
        silhouette.canvas.height = maskH;
        gl.activeTexture(gl.TEXTURE6);
        gl.bindTexture(gl.TEXTURE_2D, uniforms.target);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, MASK_W, maskH, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
        gl.bindFramebuffer(gl.FRAMEBUFFER, uniforms.fbo);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, uniforms.target, 0);
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.activeTexture(gl.TEXTURE0);
        gl.viewport(0, 0, w, h);
      }
      const look = studio.settings;
      const key = edgeOf(look);
      gl.uniform2f(uniforms.key, key.lo, key.hi);
      gl.uniform4f(uniforms.fix, look.bright || 0, look.contrast || 0, look.saturation || 0, look.warm || 0);
      let looked = false;
      const shadowNow = tick++ % SHADOW_EVERY === 0;
      const found = findCar(w, h, shadowNow);

      if (found === 'skip') {
        frame = requestAnimationFrame(draw);
        return;
      }

      if (found) {
        looked = true;
        car = (preview.hasBox && boxRect(preview.only, w, h)) || found;
      }

      if (car) {
        const gameFrame = frameFor(car, look);
        let shownW: number;
        let shownH: number;

        if (look.frame === 'fit') {
          const most = Math.min((area.w * 0.94) / gameFrame.w, (area.h * 0.94) / gameFrame.h);
          const want = Math.min(most, (Math.min(area.w, area.h * 1.6) * 0.8) / Math.hypot(gameFrame.w, gameFrame.h));
          fitScale = Math.min(most, fitScale ? fitScale + (want - fitScale) * 0.15 : want);
          shownW = gameFrame.w * fitScale;
          shownH = gameFrame.h * fitScale;
        } else {
          const aspect = gameFrame.w / gameFrame.h;
          shownW = Math.min(area.w * 0.94, area.h * 0.94 * aspect);
          shownH = shownW / aspect;
        }
        shown = { x: area.x + (area.w - shownW) / 2, y: area.y + (area.h - shownH) / 2, w: shownW, h: shownH };
        preview.frame = shown;
        preview.game = gameFrame;
        const drawn = lookKey(look);
        if (drawn !== painted && drawn.indexOf('"weight"') > -1) fontsFor(look);
        const isWider = Math.abs(shown.w - paintedW) > paintedW * 0.12;
        const isReshaped = Math.abs(shown.w / shown.h - paintedAspect) > paintedAspect * 0.01;
        const resized = isWider || isReshaped;
        if (drawn !== painted || (resized && performance.now() - paintedAt > REPAINT_MS)) {
          painted = drawn;
          paintFrame(look, shown);
        }
        if (looked) {
          if (shadowNow) paintShadow(look, gameFrame, car);
          for (let i = 0; i < GROUND_W; i++) {
            const y = ground.length ? groundAt(ground, ((i + 0.5) / GROUND_W) * w) : car.y + car.h;
            groundRow[i] = Math.max(0, Math.min(255, Math.round(((y - car.y) / Math.max(1, car.h * 1.5)) * 255)));
          }
          gl.activeTexture(gl.TEXTURE0 + UNITS.ground);
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, GROUND_W, 1, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, groundRow);
          gl.activeTexture(gl.TEXTURE0);
        }
        gl.uniform1f(uniforms.top, 1 - car.y / h);
        gl.uniform1f(uniforms.span, (car.h * 1.5) / h);
        gl.uniform1f(uniforms.fade, reflectFade(car, look) / h);
        gl.uniform1f(uniforms.reflect, reflectStart(look));
        gl.uniform1f(uniforms.rblur, (look.reflectBlur ?? 60) / 100);
        gl.uniform1f(uniforms.aspect, w / h);
        gl.uniform2f(uniforms.px, 1 / w, 1 / h);
        gl.uniform4f(
          uniforms.frame,
          gameFrame.x / w,
          1 - (gameFrame.y + gameFrame.h) / h,
          (gameFrame.x + gameFrame.w) / w,
          1 - gameFrame.y / h,
        );
        gl.uniform4f(
          uniforms.canvas,
          shown.x / w,
          1 - (shown.y + shown.h) / h,
          (shown.x + shown.w) / w,
          1 - shown.y / h,
        );
        gl.uniform2f(uniforms.edge, 1 / Math.max(1, shown.w), 1 / Math.max(1, shown.h));
      } else {
        gl.uniform4f(uniforms.canvas, 2, 2, 3, 3);
      }
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(frame);
      preview.on = false;
      preview.frame = null;
      preview.game = null;
      preview.boxes = [];
      preview.carAt = () => false;
      gl.getExtension('WEBGL_lose_context')?.loseContext();
    };
  });
</script>

<canvas bind:this={canvas} class="backdrop"></canvas>
