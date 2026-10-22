export type Rect = { x: number; y: number; w: number; h: number };
export type Text = {
  t: string;
  x: number;
  y: number;
  size: number;
  colour: string;
  weight: number;
  caps: boolean;
  spacing: number;
  alpha: number;
  back: boolean;
  on?: boolean;
};
export type Img = { src: string; x: number; y: number; size: number; alpha: number; back: boolean; on?: boolean };
export type Shape = 'fit' | '16:9' | '3:2' | '4:3' | '1:1' | '4:5' | 'custom';
export type Look = {
  bg: 'none' | 'solid' | 'linear' | 'radial' | 'studio' | 'image';
  bgImage: string;
  bgColourA: string;
  bgColourB: string;
  bgAngle: number;
  horizon: number;
  vignette: number;
  frame: Shape;
  frameW: number;
  frameH: number;
  carSize: number;
  carY: number;
  carDX: number;
  carDY: number;
  shadow: number;
  shadowSoft: number;
  shadowWide: number;
  shadowStyle: 'soft' | 'contact' | 'cast';
  reflectBlur: number;
  reflectReach: number;
  reflect: number;
  texts: Text[];
  images: Img[];
  edge: number;
  bright: number;
  contrast: number;
  saturation: number;
  warm: number;
};

export function plain(look: Look) {
  if (look.bg !== 'none' || look.shadow !== 0 || look.reflect !== 0 || look.edge) return false;

  const hasText = look.texts.some((text) => text.on !== false && text.t.trim());
  const hasImage = look.images.some((image) => image.on !== false && image.src);

  return !hasText && !hasImage;
}

export type Correction = Pick<Look, 'bright' | 'contrast' | 'saturation' | 'warm'>;

export const corrected = (look: Correction) => !!(look.bright || look.contrast || look.saturation || look.warm);

export function correct(colour: [number, number, number], look: Correction) {
  let [r, g, b] = colour;

  const lift = 1 + look.bright / 100;
  r *= lift * (1 + look.warm / 250);
  g *= lift;
  b *= lift * (1 - look.warm / 250);

  const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  const saturation = 1 + look.saturation / 50;
  r = luma + (r - luma) * saturation;
  g = luma + (g - luma) * saturation;
  b = luma + (b - luma) * saturation;

  const contrast = 1 + look.contrast / 100;
  colour[0] = Math.max(0, 0.18 + (r - 0.18) * contrast);
  colour[1] = Math.max(0, 0.18 + (g - 0.18) * contrast);
  colour[2] = Math.max(0, 0.18 + (b - 0.18) * contrast);

  return colour;
}

export function edgeOf(look: Look) {
  const amount = (look.edge || 0) / 100;
  return { lo: 24 - 18 * amount, hi: 80 - 40 * amount };
}

const loads = new Map<string, Promise<HTMLImageElement | null>>();
const ready = new Map<string, HTMLImageElement>();
let loadedCount = 0;

export const picturesLoaded = () => loadedCount;

export function pictureUrl(src: string) {
  return /^https?:\/\//i.test(src) ? src : `../../images/${encodeURIComponent(src)}`;
}

function load(src: string) {
  let job = loads.get(src);

  if (!job) {
    job = new Promise((resolve) => {
      const image = new Image();
      image.crossOrigin = 'anonymous';
      image.onload = () => {
        ready.set(src, image);
        loadedCount++;
        resolve(image);
      };
      image.onerror = () => resolve(null);
      image.src = pictureUrl(src);
    });
    loads.set(src, job);
  }

  return job;
}

export function picture(src: string) {
  if (!src) return null;

  const image = ready.get(src);
  if (!image) load(src);

  return image || null;
}

export async function picturesFor(look: Look) {
  const shown = look.images.filter((image) => image.on !== false).map((image) => image.src);
  const srcs = [...shown, look.bg === 'image' ? look.bgImage : ''].filter(Boolean);

  await Promise.all(srcs.map(load));
}

export const SHAPE_NAMES: Record<string, string> = {
  fit: 'Fits the car',
  '16:9': 'Wide',
  '3:2': 'Photo',
  '4:3': 'Classic',
  '1:1': 'Square',
  '4:5': 'Tall',
  custom: 'Your own',
};

export const sizeText = (look: Look, width: number) => (look.frame === 'custom' ? `${look.frameW} × ${look.frameH} px` : `${width} px`);

const USUAL = 3;

export function fitScale(frame: Rect, maxWidth: number) {
  return Math.min(1, maxWidth / frame.w, Math.sqrt((maxWidth * maxWidth) / 2.8 / (frame.w * frame.h)));
}

export function frameFor(car: Rect, look: Look): Rect {
  const size = Math.max(0.3, Math.min(1.5, look.carSize / 100));

  if (look.frame === 'fit') {
    const w = car.w / Math.min(1, size);
    const pad = (w - car.w) / 2;
    return { x: car.x - pad, y: car.y - pad, w, h: car.h + pad * 2 };
  }

  const [aspectW, aspectH] =
    look.frame === 'custom' ? [look.frameW || 800, look.frameH || 450] : (look.frame || '16:9').split(':').map(Number);
  const aspect = aspectW / aspectH;

  let w = car.w / (size * Math.sqrt(Math.min(1, car.w / Math.max(1, car.h) / USUAL)));
  if (car.h > (w / aspect) * size) w = (car.h / size) * aspect;

  const h = w / aspect;
  const room = h - car.h;
  const edge = Math.min(room / 2, h * 0.05);
  const y = car.y - edge - (room - edge * 2) * (Math.max(0, Math.min(100, look.carY)) / 100);

  return {
    x: car.x + car.w / 2 - w / 2 - ((look.carDX || 0) / 100) * w,
    y: y - ((look.carDY || 0) / 100) * h,
    w,
    h,
  };
}

function shade(hex: string, by: number) {
  const packed = parseInt(hex.replace('#', ''), 16) || 0;
  const channel = (value: number) => Math.round(by < 0 ? value * (1 + by) : value + (255 - value) * by);
  return `rgb(${channel((packed >> 16) & 255)},${channel((packed >> 8) & 255)},${channel(packed & 255)})`;
}

export function drawBackground(ctx: CanvasRenderingContext2D, frame: Rect, look: Look) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(frame.x, frame.y, frame.w, frame.h);
  ctx.clip();

  if (look.bg === 'solid') {
    ctx.fillStyle = look.bgColourA;
  } else if (look.bg === 'linear') {
    const angle = (look.bgAngle * Math.PI) / 180;
    const dx = Math.sin(angle);
    const dy = -Math.cos(angle);
    const half = Math.abs((frame.w / 2) * dx) + Math.abs((frame.h / 2) * dy);
    const cx = frame.x + frame.w / 2;
    const cy = frame.y + frame.h / 2;
    const gradient = ctx.createLinearGradient(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half);
    gradient.addColorStop(0, look.bgColourA);
    gradient.addColorStop(1, look.bgColourB);
    ctx.fillStyle = gradient;
  } else if (look.bg === 'radial') {
    const cx = frame.x + frame.w / 2;
    const cy = frame.y + frame.h * 0.48;
    const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.hypot(frame.w, frame.h) * 0.55);
    gradient.addColorStop(0, look.bgColourA);
    gradient.addColorStop(1, look.bgColourB);
    ctx.fillStyle = gradient;
  } else if (look.bg === 'studio') {
    const line = look.horizon / 100;
    const gradient = ctx.createLinearGradient(0, frame.y, 0, frame.y + frame.h);
    gradient.addColorStop(0, shade(look.bgColourA, -0.16));
    gradient.addColorStop(Math.max(0, line - 0.06), look.bgColourA);
    gradient.addColorStop(Math.min(1, line + 0.04), look.bgColourB);
    gradient.addColorStop(1, shade(look.bgColourB, -0.28));
    ctx.fillStyle = gradient;
  }

  if (look.bg === 'image') ctx.fillStyle = look.bgColourA;
  if (look.bg !== 'none') ctx.fillRect(frame.x, frame.y, frame.w, frame.h);

  const image = look.bg === 'image' ? picture(look.bgImage) : null;

  if (image) {
    const cover = Math.max(frame.w / image.naturalWidth, frame.h / image.naturalHeight);
    const w = image.naturalWidth * cover;
    const h = image.naturalHeight * cover;
    ctx.drawImage(image, frame.x + (frame.w - w) / 2, frame.y + (frame.h - h) / 2, w, h);
  }

  if (look.vignette > 0 && look.bg !== 'none') {
    const cx = frame.x + frame.w / 2;
    const cy = frame.y + frame.h / 2;
    ctx.translate(cx, cy);
    ctx.scale(frame.w / 2, frame.h / 2);
    const gradient = ctx.createRadialGradient(0, 0, 0.35, 0, 0, 1.45);
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(1, `rgba(0,0,0,${(look.vignette / 100) * 0.85})`);
    ctx.fillStyle = gradient;
    ctx.fillRect(-1, -1, 2, 2);
  }

  ctx.restore();
}

export type Point = { x: number; y: number };

export function groundLine(bottoms: ArrayLike<number>): Point[] {
  const line: Point[] = [];

  for (let x = 0; x < bottoms.length; x++) {
    const y = bottoms[x];
    if (y < 0) continue;

    while (line.length >= 2) {
      const prev = line[line.length - 2];
      const tip = line[line.length - 1];
      if ((tip.x - prev.x) * (y - prev.y) - (tip.y - prev.y) * (x - prev.x) < 0) break;
      line.pop();
    }

    line.push({ x, y });
  }

  if (line.length < 3) return line;

  let slope = 0;
  let longest = 0;

  for (let n = 1; n < line.length; n++) {
    const dx = line[n].x - line[n - 1].x;
    const dy = line[n].y - line[n - 1].y;
    const length = Math.hypot(dx, dy);

    if (length > longest) {
      longest = length;
      slope = dy / Math.max(1e-6, dx);
    }
  }

  const limit = Math.abs(slope) * 1.5 + 0.15;
  const first = line[0].x;
  const last = line[line.length - 1].x;
  const reach = (last - first) * 0.15;

  while (line.length > 2 && (line[1].y - line[0].y) / Math.max(1e-6, line[1].x - line[0].x) > limit) line.shift();

  while (line.length > 2) {
    const prev = line[line.length - 2];
    const tip = line[line.length - 1];
    if ((tip.y - prev.y) / Math.max(1e-6, tip.x - prev.x) < -limit) line.pop();
    else break;
  }

  if (line[0].x > first) {
    const end = line[0];
    const inner = line.find((point) => point.x >= end.x + reach) || line[line.length - 1];
    line.unshift({ x: first, y: end.y - ((inner.y - end.y) / Math.max(1e-6, inner.x - end.x)) * (end.x - first) });
  }

  if (line[line.length - 1].x < last) {
    const end = line[line.length - 1];
    let inner = line[0];
    for (const point of line) if (point.x <= end.x - reach) inner = point;
    line.push({ x: last, y: end.y + ((end.y - inner.y) / Math.max(1e-6, end.x - inner.x)) * (last - end.x) });
  }

  return line;
}

export function footLine(points: Point[]): Point[] {
  const sorted = [...points].sort((a, b) => a.x - b.x || b.y - a.y);
  const line: Point[] = [];

  for (const point of sorted) {
    if (line.length && point.x - line[line.length - 1].x < 1e-6) continue;

    while (line.length >= 2) {
      const prev = line[line.length - 2];
      const tip = line[line.length - 1];
      if ((tip.x - prev.x) * (point.y - prev.y) - (tip.y - prev.y) * (point.x - prev.x) < 0) break;
      line.pop();
    }

    line.push(point);
  }

  return line;
}

export function groundAt(line: Point[], x: number) {
  if (!line.length) return 0;
  if (x <= line[0].x) return line[0].y;

  for (let n = 1; n < line.length; n++) {
    const from = line[n - 1];
    const to = line[n];
    if (x <= to.x) return from.y + ((to.y - from.y) * (x - from.x)) / Math.max(1e-6, to.x - from.x);
  }

  return line[line.length - 1].y;
}

export const placeLine = (line: Point[], scaleX: number, scaleY: number, dx: number, dy: number) =>
  line.map((point) => ({ x: point.x * scaleX + dx, y: point.y * scaleY + dy }));

const scratches: HTMLCanvasElement[] = [];

function scratch(n: number, w: number, h: number) {
  const canvas = (scratches[n] ||= document.createElement('canvas'));
  canvas.width = w;
  canvas.height = h;
  return canvas;
}

export function drawShadow(
  ctx: CanvasRenderingContext2D,
  line: Point[],
  car: Rect,
  look: Look,
  silhouette?: { src: CanvasImageSource; at: Rect },
) {
  const strength = look.shadow / 100;
  if (strength <= 0 || line.length < 2) return;

  const soft = look.shadowSoft / 100;
  const wide = look.shadowWide / 100;
  const cx = car.x + car.w / 2;
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;
  const band = car.h * 0.07;
  const spread = (draw: () => void) => {
    ctx.translate(cx, 0);
    ctx.scale(wide, 1);
    ctx.translate(-cx, 0);
    draw();
  };

  if (!silhouette) {
    ctx.save();
    ctx.fillStyle = '#000';
    ctx.globalAlpha = Math.min(1, strength * 0.42);
    ctx.filter = `blur(${Math.max(1, car.h * (0.035 + soft * 0.08))}px)`;
    spread(() => {
      ctx.beginPath();
      line.forEach((point, n) => {
        if (n) ctx.lineTo(point.x, point.y + car.h * 0.015);
        else ctx.moveTo(point.x, point.y + car.h * 0.015);
      });
      for (let n = line.length - 1; n >= 0; n--) ctx.lineTo(line[n].x, line[n].y - car.h * 0.08);
      ctx.closePath();
      ctx.fill();
    });
    ctx.restore();
    return;
  }

  const { src, at } = silhouette;
  const reach = car.h * 0.2;
  const under = scratch(0, w, h);
  const underCtx = under.getContext('2d')!;

  for (let step = 0; step <= 10; step++) underCtx.drawImage(src, at.x, at.y + (reach * step) / 10, at.w, at.h);

  underCtx.globalCompositeOperation = 'destination-in';
  underCtx.beginPath();
  line.forEach((point, n) => {
    if (n) underCtx.lineTo(point.x, point.y + car.h * 0.03);
    else underCtx.moveTo(point.x, point.y + car.h * 0.03);
  });
  for (let n = line.length - 1; n >= 0; n--) underCtx.lineTo(line[n].x, line[n].y - reach);
  underCtx.closePath();
  underCtx.fill();
  underCtx.globalCompositeOperation = 'source-in';
  underCtx.fillStyle = '#000';
  underCtx.fillRect(0, 0, w, h);

  const shades: [number, number][] = [
    [0.5, 0.05 + soft * 0.1],
    [look.shadowStyle === 'soft' ? 0.5 : 0.8, 0.008 + soft * 0.02],
  ];

  for (const [alpha, blur] of shades) {
    ctx.save();
    ctx.globalAlpha = Math.min(1, strength * alpha);
    ctx.filter = `blur(${Math.max(1, car.h * blur)}px)`;
    spread(() => ctx.drawImage(under, 0, 0));
    ctx.restore();
  }

  if (look.shadowStyle === 'soft') return;

  if (look.shadowStyle === 'cast') {
    const cast = scratch(1, w, h);
    const castCtx = cast.getContext('2d')!;
    const floor = car.y + car.h;
    castCtx.setTransform(wide, 0, -0.75, 0.2, cx * (1 - wide) + 0.75 * floor, floor * 0.8);
    castCtx.drawImage(src, at.x, at.y, at.w, at.h);
    castCtx.setTransform(1, 0, 0, 1, 0, 0);
    castCtx.globalCompositeOperation = 'source-in';
    const gradient = castCtx.createLinearGradient(0, floor, 0, floor - car.h * 0.2);
    gradient.addColorStop(0, 'rgba(0,0,0,1)');
    gradient.addColorStop(1, 'rgba(0,0,0,0.15)');
    castCtx.fillStyle = gradient;
    castCtx.fillRect(0, 0, w, h);
    ctx.save();
    ctx.globalAlpha = Math.min(1, strength * 0.6);
    ctx.filter = `blur(${Math.max(1, car.h * (0.012 + soft * 0.03))}px)`;
    ctx.drawImage(cast, 0, 0);
    ctx.restore();
  }

  const strip = scratch(2, w, h);
  const stripCtx = strip.getContext('2d')!;
  stripCtx.drawImage(src, at.x, at.y, at.w, at.h);
  stripCtx.globalCompositeOperation = 'destination-in';
  stripCtx.beginPath();
  line.forEach((point, n) => {
    if (n) stripCtx.lineTo(point.x, point.y + 2);
    else stripCtx.moveTo(point.x, point.y + 2);
  });
  for (let n = line.length - 1; n >= 0; n--) stripCtx.lineTo(line[n].x, line[n].y - band);
  stripCtx.closePath();
  stripCtx.fill();
  stripCtx.globalCompositeOperation = 'source-in';
  stripCtx.fillStyle = '#000';
  stripCtx.fillRect(0, 0, w, h);

  const passes: [number, number, number][] = [
    [0.95, 0.006 + soft * 0.012, 0.35],
    [0.55, 0.025 + soft * 0.05, 0.6],
  ];

  for (const [alpha, blur, drop] of passes) {
    ctx.save();
    ctx.globalAlpha = Math.min(1, strength * alpha);
    ctx.filter = `blur(${Math.max(1, car.h * blur)}px)`;
    ctx.translate(cx, band * drop);
    ctx.scale(wide, 1);
    ctx.translate(-cx, 0);
    ctx.drawImage(strip, 0, 0);
    ctx.restore();
  }
}

export const reflectFade = (car: Rect, look: Look) => car.h * (0.12 + ((look.reflectReach ?? 45) / 100) * 0.68);
export const reflectStart = (look: Look) => (look.reflect / 100) * 0.55;
export const reflectAt = (distance: number) => Math.pow(Math.max(0, 1 - distance), 1.6);

export function fill(item: Text, name: string, model: string) {
  const text = item.t.replace(/\{name\}/gi, name).replace(/\{model\}/gi, model);
  return item.caps ? text.toUpperCase() : text;
}

export type Box = { kind: 'text' | 'img'; i: number; x: number; y: number; w: number; h: number };

export function drawTexts(
  ctx: CanvasRenderingContext2D,
  frame: Rect,
  look: Look,
  back: boolean,
  name: string,
  model: string,
) {
  const boxes: Box[] = [];

  look.texts.forEach((item, i) => {
    const text = fill(item, name, model);
    if (!text.trim() || item.on === false) return;

    const size = (item.size / 100) * frame.h;
    const x = frame.x + (item.x / 100) * frame.w;
    const y = frame.y + (item.y / 100) * frame.h;

    ctx.save();
    ctx.beginPath();
    ctx.rect(frame.x, frame.y, frame.w, frame.h);
    ctx.clip();
    ctx.font = `${item.weight} ${size}px Inter`;
    ctx.letterSpacing = `${(item.spacing / 100) * size}px`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const w = ctx.measureText(text).width;
    boxes.push({
      kind: 'text',
      i,
      x: (x - w / 2 - frame.x) / frame.w,
      y: (y - size * 0.6 - frame.y) / frame.h,
      w: w / frame.w,
      h: (size * 1.2) / frame.h,
    });

    if (item.back === back) {
      ctx.globalAlpha = item.alpha / 100;
      ctx.fillStyle = item.colour;
      ctx.fillText(text, x, y);
    }

    ctx.restore();
  });

  return boxes;
}

export function drawImages(ctx: CanvasRenderingContext2D, frame: Rect, look: Look, back: boolean) {
  const boxes: Box[] = [];

  look.images.forEach((item, i) => {
    const image = item.on === false ? null : picture(item.src);
    if (!image) return;

    const w = (item.size / 100) * frame.w;
    const h = (w * image.naturalHeight) / image.naturalWidth;
    const x = frame.x + (item.x / 100) * frame.w - w / 2;
    const y = frame.y + (item.y / 100) * frame.h - h / 2;

    boxes.push({ kind: 'img', i, x: (x - frame.x) / frame.w, y: (y - frame.y) / frame.h, w: w / frame.w, h: h / frame.h });
    if (item.back !== back) return;

    ctx.save();
    ctx.beginPath();
    ctx.rect(frame.x, frame.y, frame.w, frame.h);
    ctx.clip();
    ctx.globalAlpha = item.alpha / 100;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(image, x, y, w, h);
    ctx.restore();
  });

  return boxes;
}

export async function fontsFor(look: Look) {
  const weights = new Set(look.texts.map((text) => text.weight));
  await Promise.all([...weights].map((weight) => document.fonts.load(`${weight} 40px Inter`).catch(() => null)));
}

export const PRESETS: [string, string, Partial<Look>][] = [
  ['clear', 'See-through', { bg: 'none', shadow: 0, reflect: 0, vignette: 0 }],
  [
    'white',
    'White studio',
    {
      bg: 'studio',
      bgColourA: '#f4f4f5',
      bgColourB: '#d4d4d8',
      horizon: 66,
      vignette: 18,
      shadow: 70,
      shadowSoft: 55,
      shadowWide: 100,
      reflect: 0,
    },
  ],
  [
    'dark',
    'Dark studio',
    {
      bg: 'studio',
      bgColourA: '#26272c',
      bgColourB: '#121216',
      horizon: 64,
      vignette: 45,
      shadow: 85,
      shadowSoft: 45,
      shadowWide: 100,
      reflect: 22,
    },
  ],
  [
    'show',
    'Showroom',
    {
      bg: 'radial',
      bgColourA: '#3a3d46',
      bgColourB: '#0c0d10',
      vignette: 30,
      shadow: 80,
      shadowSoft: 50,
      shadowWide: 105,
      reflect: 35,
    },
  ],
  [
    'neon',
    'Neon night',
    {
      bg: 'linear',
      bgColourA: '#2b0b3f',
      bgColourB: '#05060a',
      bgAngle: 180,
      vignette: 40,
      shadow: 75,
      shadowSoft: 40,
      shadowWide: 100,
      reflect: 40,
    },
  ],
  [
    'sunset',
    'Sunset',
    {
      bg: 'linear',
      bgColourA: '#ff8a3d',
      bgColourB: '#5b1a63',
      bgAngle: 180,
      vignette: 25,
      shadow: 60,
      shadowSoft: 60,
      shadowWide: 110,
      reflect: 0,
    },
  ],
];

export const preview = {
  on: false,
  frame: null as Rect | null,
  game: null as Rect | null,
  boxes: [] as Box[],
  carAt: (_x: number, _y: number) => false,
  only: [0.4, 0.35, 0.6, 0.65],
  hasBox: false,
  foot: null as number[][] | null,
};

export function boxRect(box: number[] | undefined, w: number, h: number): Rect | null {
  if (!Array.isArray(box) || box.length !== 4) return null;

  const [x0, y0, x1, y1] = box.map(Number);
  if (x0 <= 0 && y0 <= 0 && x1 >= 1 && y1 >= 1) return null;

  const rect = { x: x0 * w, y: y0 * h, w: (x1 - x0) * w, h: (y1 - y0) * h };
  return rect.w > 8 && rect.h > 8 ? rect : null;
}

let work = { n: 0, label: new Int32Array(0), stack: new Int32Array(0), out: new Uint8Array(0) };

export function keepCar(grid: Uint8Array, w: number, h: number, box: number[]) {
  const n = w * h;
  if (work.n !== n) work = { n, label: new Int32Array(n), stack: new Int32Array(n), out: new Uint8Array(n) };

  const { label, stack, out } = work;
  const x0 = Math.floor(box[0] * w);
  const x1 = Math.ceil(box[2] * w) - 1;
  const y0 = Math.floor(box[1] * h);
  const y1 = Math.ceil(box[3] * h) - 1;
  label.fill(0);

  const touches: boolean[] = [false];
  const sizes: number[] = [0];
  let biggest = 0;
  let any = false;

  for (let start = 0; start < n; start++) {
    if (!grid[start] || label[start]) continue;

    const id = touches.length;
    let top = 0;
    let size = 0;
    let touch = false;
    stack[top++] = start;
    label[start] = id;

    while (top) {
      const i = stack[--top];
      size++;

      const x = i % w;
      const y = (i / w) | 0;
      if (x >= x0 && x <= x1 && y >= y0 && y <= y1) touch = true;

      if (x > 0 && grid[i - 1] && !label[i - 1]) {
        label[i - 1] = id;
        stack[top++] = i - 1;
      }

      if (x < w - 1 && grid[i + 1] && !label[i + 1]) {
        label[i + 1] = id;
        stack[top++] = i + 1;
      }

      if (y > 0 && grid[i - w] && !label[i - w]) {
        label[i - w] = id;
        stack[top++] = i - w;
      }

      if (y < h - 1 && grid[i + w] && !label[i + w]) {
        label[i + w] = id;
        stack[top++] = i + w;
      }
    }

    touches.push(touch);
    sizes.push(size);
    any ||= touch;
    if (size > sizes[biggest]) biggest = id;
  }

  if (!any && biggest) touches[biggest] = true;

  out.fill(0);

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (!touches[label[y * w + x]]) continue;

      for (let dy = -1; dy <= 1; dy++) {
        const ny = y + dy;
        if (ny < 0 || ny >= h) continue;

        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx;
          if (nx >= 0 && nx < w) out[ny * w + nx] = 1;
        }
      }
    }
  }

  return out;
}

if (typeof window !== 'undefined') {
  window.addEventListener('message', (event: MessageEvent) => {
    const data = event.data;

    if (data?.type === 'carbox' && Array.isArray(data.box) && data.box.length === 4) {
      preview.only = data.box.map(Number);
      preview.hasBox = true;
      preview.foot = Array.isArray(data.foot) && data.foot.length > 2 ? data.foot : null;
    }
  });
}

export const onScreen = (box: Box, frame: Rect) => ({
  x: frame.x + box.x * frame.w,
  y: frame.y + box.y * frame.h,
  w: box.w * frame.w,
  h: box.h * frame.h,
});
