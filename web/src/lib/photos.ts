import { nui } from './nui';
import {
  correct,
  corrected,
  drawBackground,
  drawImages,
  drawShadow,
  drawTexts,
  edgeOf,
  fitScale,
  fontsFor,
  footLine,
  frameFor,
  groundAt,
  groundLine,
  keepCar,
  picturesFor,
  plain,
  reflectAt,
  reflectFade,
  reflectStart,
  type Look,
  type Point,
  type Rect,
} from './look';

export type Fix = { bright: number; contrast: number; saturation: number; warm: number };
export type Layers = { black: string; primary: string; secondary: string; fix?: Fix };

const fixOf = (look?: Look): Fix | undefined => {
  if (!look || !corrected(look)) return undefined;
  return { bright: look.bright, contrast: look.contrast, saturation: look.saturation, warm: look.warm };
};

const KEYS = ['black', 'primary', 'secondary'] as const;

function load(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('A picture could not be read.'));
    image.src = src;
  });
}

function pixels(image: HTMLImageElement, x = 0, y = 0, w = image.width, h = image.height) {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;

  const context = canvas.getContext('2d', { willReadFrequently: true })!;
  context.drawImage(image, x, y, w, h, 0, 0, w, h);

  return { canvas, context, data: context.getImageData(0, 0, w, h) };
}

function coverage(r: number, g: number, b: number, lo = 24, hi = 80) {
  const green = g - Math.max(r, b);
  return green <= lo ? 1 : green >= hi ? 0 : 1 - (green - lo) / (hi - lo);
}

let lookOf: (model: string) => { look: Look; name: string } | null = () => null;

export function useLook(fn: typeof lookOf) {
  lookOf = fn;
}

function blank(w: number, h: number) {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  return { canvas, context: canvas.getContext('2d', { willReadFrequently: true })! };
}

type Surface = { canvas: HTMLCanvasElement; context: CanvasRenderingContext2D };
type Mask = {
  alpha: Float32Array;
  width: number;
  height: number;
  grid: Uint8Array;
  gridW: number;
  gridH: number;
  cellOf: (i: number) => number;
};
type Layout = { frame: Rect; scale: number; outW: number; outH: number };
type Scene = {
  car: Rect;
  layout: Layout;
  name: string;
  model: string;
  foot?: number[][];
  width: number;
  height: number;
};

const GRID_W = 256;
const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));

function buildAlphaMask(shots: Uint8ClampedArray[], width: number, height: number, look?: Look): Mask {
  const { lo, hi } = look ? edgeOf(look) : { lo: 24, hi: 80 };
  const alpha = new Float32Array(width * height);
  const gridW = GRID_W;
  const gridH = Math.max(1, Math.round((gridW * height) / width));
  const grid = new Uint8Array(gridW * gridH);
  const cellOf = (i: number) => {
    const row = Math.min(gridH - 1, (((i / width) | 0) * gridH / height) | 0);
    const column = Math.min(gridW - 1, ((i % width) * gridW / width) | 0);
    return row * gridW + column;
  };

  for (let i = 0; i < alpha.length; i++) {
    let covered = 0;

    for (let n = 0; n < shots.length; n++) {
      const shot = shots[n];
      covered = Math.max(covered, coverage(shot[i * 4], shot[i * 4 + 1], shot[i * 4 + 2], lo, hi));
    }

    alpha[i] = covered;
    if (covered > 0.5) grid[cellOf(i)] = 1;
  }

  return { alpha, width, height, grid, gridW, gridH, cellOf };
}

function keepCarOnly(mask: Mask, box?: number[]) {
  const area = Array.isArray(box) && box.length === 4 ? box.map(Number) : [0, 0, 1, 1];
  const keep = keepCar(mask.grid, mask.gridW, mask.gridH, area);

  for (let i = 0; i < mask.alpha.length; i++) {
    if (!keep[mask.cellOf(i)]) mask.alpha[i] = 0;
  }
}

function findCarBounds(mask: Mask): Rect {
  const { alpha, width, height } = mask;
  let left = width;
  let top = height;
  let right = -1;
  let bottom = -1;

  for (let i = 0; i < alpha.length; i++) {
    if (alpha[i] > 0.1) {
      const x = i % width;
      const y = (i / width) | 0;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right < 0) throw new Error('No vehicle was found in the picture');

  return { x: left, y: top, w: right - left + 1, h: bottom - top + 1 };
}

function layoutFor(car: Rect, look: Look | undefined, maxWidth: number): Layout {
  const frame = frameFor(car, look || ({ frame: 'fit', carSize: 94 } as Look));
  const own = look?.frame === 'custom';
  let scale: number;

  if (own) scale = look.frameW / frame.w;
  else if (look?.frame === 'fit' || !look) scale = fitScale(frame, maxWidth || 640);
  else scale = Math.min(1, (maxWidth || 640) / frame.w);

  const outW = own ? look.frameW : Math.max(1, Math.round(frame.w * scale));
  const outH = own ? look.frameH : Math.max(1, Math.round(frame.h * scale));

  return { frame, scale, outW, outH };
}

function cropAround(car: Rect, width: number, height: number): Rect {
  const pad = Math.round(Math.max(car.w, car.h) * 0.03);
  const right = car.x + car.w - 1;
  const bottom = car.y + car.h - 1;
  const x = Math.max(0, car.x - pad);
  const y = Math.max(0, car.y - pad);

  return { x, y, w: Math.min(width - 1, right + pad) - x + 1, h: Math.min(height - 1, bottom + pad) - y + 1 };
}

function despillEdges(image: HTMLImageElement, mask: Mask, crop: Rect) {
  const piece = pixels(image, crop.x, crop.y, crop.w, crop.h);
  const data = piece.data.data;

  for (let i = 0; i < data.length; i += 4) {
    const limit = Math.max(data[i], data[i + 2]);
    if (data[i + 1] > limit) data[i + 1] = limit;
  }

  const source = data.slice();
  const alphaAt = (x: number, y: number) => {
    const atY = clamp(y + crop.y, 0, mask.height - 1);
    const atX = clamp(x + crop.x, 0, mask.width - 1);
    return mask.alpha[atY * mask.width + atX];
  };

  for (let y = 0; y < crop.h; y++) {
    for (let x = 0; x < crop.w; x++) {
      const i = (y * crop.w + x) * 4;
      const alpha = alphaAt(x, y);

      if (alpha <= 0) {
        data[i + 3] = 0;
        continue;
      }

      const slopeX = alphaAt(x + 2, y) - alphaAt(x - 2, y);
      const slopeY = alphaAt(x, y + 2) - alphaAt(x, y - 2);
      const steep = Math.hypot(slopeX, slopeY);

      if (steep > 0.15) {
        const innerX = clamp(Math.round(x + (slopeX / steep) * 3), 0, crop.w - 1);
        const innerY = clamp(Math.round(y + (slopeY / steep) * 3), 0, crop.h - 1);

        if (alphaAt(innerX, innerY) > alpha) {
          const j = (innerY * crop.w + innerX) * 4;
          for (let n = 0; n < 3; n++) data[i + n] = source[i + n] * 0.15 + source[j + n] * 0.85;
        }
      }

      const edge = clamp((alpha - 0.15) / 0.7, 0, 1);
      data[i + 3] = Math.round(edge * edge * (3 - 2 * edge) * 255);
    }
  }

  piece.context.putImageData(piece.data, 0, 0);

  return piece.canvas;
}

function scaleIntoFrame(piece: HTMLCanvasElement, crop: Rect, { frame, scale, outW, outH }: Layout): Surface {
  const out = blank(outW, outH);
  out.context.imageSmoothingQuality = 'high';
  out.context.drawImage(piece, (crop.x - frame.x) * scale, (crop.y - frame.y) * scale, crop.w * scale, crop.h * scale);
  return out;
}

function lowestPixels(car: Uint8ClampedArray, outW: number, outH: number) {
  const bottoms = new Int32Array(outW).fill(-1);

  for (let x = 0; x < outW; x++) {
    for (let y = outH - 1; y >= 0; y--) {
      if (car[(y * outW + x) * 4 + 3] > 128) {
        bottoms[x] = y;
        break;
      }
    }
  }

  return bottoms;
}

function mirrorCars(carPixels: Uint8ClampedArray[], line: Point[], placed: Rect, look: Look, outW: number, outH: number) {
  const fade = reflectFade(placed, look);
  const start = reflectStart(look);
  const away = new Float32Array(outW * outH).fill(-1);

  return carPixels.map((source) => {
    const flipped = blank(outW, outH);
    const image = flipped.context.createImageData(outW, outH);
    const sharp = image.data;
    const firstX = Math.max(0, Math.ceil(line[0].x));
    const lastX = Math.min(outW - 1, Math.floor(line[line.length - 1].x));

    for (let x = firstX; x <= lastX; x++) {
      const ground = groundAt(line, x);

      for (let y = Math.ceil(ground); y < Math.min(outH, ground + fade); y++) {
        const from = Math.round(2 * ground - y);
        if (from < 0) continue;

        const i = (y * outW + x) * 4;
        const j = (from * outW + x) * 4;
        sharp[i] = source[j];
        sharp[i + 1] = source[j + 1];
        sharp[i + 2] = source[j + 2];
        sharp[i + 3] = source[j + 3];
        away[y * outW + x] = (y - ground) / fade;
      }
    }

    flipped.context.putImageData(image, 0, 0);

    const soft = blank(outW, outH);
    soft.context.filter = `blur(${Math.max(1, placed.h * 0.05 * ((look.reflectBlur ?? 60) / 100))}px)`;
    soft.context.drawImage(flipped.canvas, 0, 0);

    const blurred = soft.context.getImageData(0, 0, outW, outH).data;
    const out = new Uint8ClampedArray(sharp.length);

    for (let pixel = 0; pixel < away.length; pixel++) {
      const distance = away[pixel];
      if (distance < 0) continue;

      const blend = (look.reflectBlur ?? 60) > 0 ? Math.min(1, distance * 1.6) : 0;
      const i = pixel * 4;
      for (let n = 0; n < 3; n++) out[i + n] = sharp[i + n] * (1 - blend) + blurred[i + n] * blend;
      out[i + 3] = (sharp[i + 3] * (1 - blend) + blurred[i + 3] * blend) * start * reflectAt(distance);
    }

    return out;
  });
}

function stackLayers(out: Uint8ClampedArray, base: Uint8ClampedArray, stack: Uint8ClampedArray[]) {
  for (let i = 0; i < out.length; i += 4) {
    let alpha = base[i + 3] / 255;
    let r = toLinear[base[i]] * alpha;
    let g = toLinear[base[i + 1]] * alpha;
    let b = toLinear[base[i + 2]] * alpha;

    for (const layer of stack) {
      const cover = layer[i + 3] / 255;
      if (!cover) continue;

      r = toLinear[layer[i]] * cover + r * (1 - cover);
      g = toLinear[layer[i + 1]] * cover + g * (1 - cover);
      b = toLinear[layer[i + 2]] * cover + b * (1 - cover);
      alpha = cover + alpha * (1 - cover);
    }

    if (alpha > 0) {
      out[i] = toSrgbFast(r / alpha);
      out[i + 1] = toSrgbFast(g / alpha);
      out[i + 2] = toSrgbFast(b / alpha);
      out[i + 3] = Math.round(alpha * 255);
    }
  }
}

async function composeOutput(cars: Surface[], look: Look, { car, layout, name, model, foot, width, height }: Scene) {
  await Promise.all([fontsFor(look), picturesFor(look)]);

  const { frame, scale, outW, outH } = layout;
  const whole = { x: 0, y: 0, w: outW, h: outH };
  const placed = {
    x: (car.x - frame.x) * scale,
    y: (car.y - frame.y) * scale,
    w: car.w * scale,
    h: car.h * scale,
  };
  const read = (layer: Surface) => layer.context.getImageData(0, 0, outW, outH).data;
  const carPixels = cars.map(read);
  const bottoms = lowestPixels(carPixels[0], outW, outH);
  const toFrame = ([x, y]: number[]) => ({ x: (x * width - frame.x) * scale, y: (y * height - frame.y) * scale });
  const line = Array.isArray(foot) && foot.length > 2 ? footLine(foot.map(toFrame)) : groundLine(bottoms);

  const back = blank(outW, outH);
  drawBackground(back.context, whole, look);
  drawShadow(back.context, line, placed, look, { src: cars[0].canvas, at: whole });
  drawImages(back.context, whole, look, true);
  drawTexts(back.context, whole, look, true, name, model);

  const front = blank(outW, outH);
  drawImages(front.context, whole, look, false);
  drawTexts(front.context, whole, look, false, name, model);

  const mirrors = look.reflect > 0 && line.length ? mirrorCars(carPixels, line, placed, look, outW, outH) : null;
  const backPixels = read(back);
  const frontPixels = read(front);

  return cars.map((layer, n) => {
    const stack = mirrors ? [mirrors[n], carPixels[n], frontPixels] : [carPixels[n], frontPixels];
    const out = layer.context.createImageData(outW, outH);
    stackLayers(out.data, backPixels, stack);
    layer.context.putImageData(out, 0, 0);
    return layer.canvas.toDataURL('image/webp', 0.9);
  });
}

async function cut(shots: Layers, maxWidth: number, model: string, box?: number[], foot?: number[][]): Promise<Layers> {
  const images = await Promise.all(KEYS.map((key) => load(shots[key])));
  const width = images[0].width;
  const height = images[0].height;
  const chosen = lookOf(model);
  const look = chosen?.look;

  const mask = buildAlphaMask(images.map((image) => pixels(image).data.data), width, height, look);
  keepCarOnly(mask, box);

  const car = findCarBounds(mask);
  const layout = layoutFor(car, look, maxWidth);
  const crop = cropAround(car, width, height);
  const cars = images.map((image) => scaleIntoFrame(despillEdges(image, mask, crop), crop, layout));

  const result = {} as Layers;
  result.fix = fixOf(look);

  const webps = !look || plain(look)
    ? cars.map((layer) => layer.canvas.toDataURL('image/webp', 0.9))
    : await composeOutput(cars, look, { car, layout, name: chosen?.name || model, model, foot, width, height });

  webps.forEach((webp, n) => (result[KEYS[n]] = webp));

  return result;
}

async function keep(shots: Layers, maxWidth: number, model: string): Promise<Layers> {
  const look = lookOf(model)?.look;
  const images = await Promise.all(KEYS.map((key) => load(shots[key])));
  const scale = Math.min(1, (maxWidth || 640) / images[0].width);
  const outW = Math.round(images[0].width * scale);
  const outH = Math.round(images[0].height * scale);

  const canvases = images.map((image) => {
    const canvas = document.createElement('canvas');
    canvas.width = outW;
    canvas.height = outH;

    const context = canvas.getContext('2d', { willReadFrequently: true })!;
    context.imageSmoothingQuality = 'high';
    context.drawImage(image, 0, 0, outW, outH);

    return { canvas, context, data: context.getImageData(0, 0, outW, outH) };
  });

  const [black, body, second] = canvases.map((layer) => layer.data.data);

  for (let i = 0; i < black.length; i += 4) {
    let most = 0;

    for (let n = 0; n < 3; n++) {
      most = Math.max(most, Math.abs(body[i + n] - black[i + n]), Math.abs(second[i + n] - black[i + n]));
    }

    if (most < 10) {
      for (let n = 0; n < 3; n++) body[i + n] = second[i + n] = black[i + n];
    }
  }

  const out = { fix: fixOf(look) } as Layers;

  canvases.forEach((layer, n) => {
    layer.context.putImageData(layer.data, 0, 0);
    out[KEYS[n]] = layer.canvas.toDataURL('image/webp', 0.88);
  });

  return out;
}

const toLinear = new Float32Array(256);

for (let level = 0; level < 256; level++) {
  const srgb = level / 255;
  toLinear[level] = srgb <= 0.04045 ? srgb / 12.92 : Math.pow((srgb + 0.055) / 1.055, 2.4);
}

function toSrgb(linear: number) {
  const srgb = linear <= 0.0031308 ? linear * 12.92 : 1.055 * Math.pow(linear, 1 / 2.4) - 0.055;
  return Math.max(0, Math.min(255, Math.round(srgb * 255)));
}

const SRGB = new Uint8Array(4097);

for (let step = 0; step <= 4096; step++) SRGB[step] = toSrgb(step / 4096);

const toSrgbFast = (linear: number) => SRGB[Math.max(0, Math.min(4096, Math.round(linear * 4096)))];

function rgb(hex: string) {
  const packed = parseInt(hex.replace('#', ''), 16);
  return [toLinear[(packed >> 16) & 255], toLinear[(packed >> 8) & 255], toLinear[packed & 255]];
}

type Decoded = { images: HTMLImageElement[]; data: Uint8ClampedArray[] };

const decoded = new Map<string, Decoded>();

async function layersOf(key: string, layers: Layers) {
  const known = decoded.get(key);
  if (known) return known;

  const images = await Promise.all(KEYS.map((name) => load(layers[name])));
  const found = { images, data: images.map((image) => pixels(image).data.data) };

  if (decoded.size > 40) decoded.clear();
  decoded.set(key, found);

  return found;
}

export async function paint(
  key: string,
  layers: Layers,
  primary: string,
  secondary: string,
  format: 'webp' | 'png' = 'webp',
) {
  const found = await layersOf(key, layers);
  const base = pixels(found.images[0]);
  const out = base.data.data;
  const [black, body, second] = found.data;
  const first = rgb(primary);
  const other = rgb(secondary);
  const fix = layers.fix && corrected(layers.fix) ? layers.fix : null;
  const colour: [number, number, number] = [0, 0, 0];

  for (let i = 0; i < out.length; i += 4) {
    let most = 0;

    for (let n = 0; n < 3; n++) {
      most = Math.max(most, Math.abs(body[i + n] - black[i + n]), Math.abs(second[i + n] - black[i + n]));
    }

    for (let n = 0; n < 3; n++) {
      const dark = toLinear[black[i + n]];
      if (most < 6) colour[n] = dark;
      else colour[n] = dark + first[n] * (toLinear[body[i + n]] - dark) + other[n] * (toLinear[second[i + n]] - dark);
    }

    if (fix) correct(colour, fix);
    else if (most < 6) continue;

    out[i] = toSrgb(colour[0]);
    out[i + 1] = toSrgb(colour[1]);
    out[i + 2] = toSrgb(colour[2]);
  }

  base.context.putImageData(base.data, 0, 0);

  return {
    image: base.canvas.toDataURL(`image/${format}`, 0.92),
    width: base.canvas.width,
    height: base.canvas.height,
  };
}

export function layerKb(layers: Layers) {
  return Math.max(...KEYS.map((name) => Math.round(((layers[name].length - 23) * 3) / 4 / 1024)));
}

const fetched = new Map<string, Promise<Layers | null>>();

export function layersFor(model: string, version?: number) {
  const key = `${model}:${version ?? 0}`;
  let job = fetched.get(key);

  if (!job) {
    job = nui<{ layers?: Layers }>('layers', { model, version }, 60000).then((reply) => reply?.layers || null);
    fetched.set(key, job);
    job.then((found) => found || fetched.delete(key));
  }

  return job;
}

export function listenForJobs() {
  addEventListener('message', (event) => {
    const request = event.data;
    if (!request || typeof request !== 'object' || typeof request.id !== 'number') return;

    const model = String(request.model || '');
    let job;

    if (request.action === 'cut') {
      const cutting = request.scene
        ? keep(request.shots, request.width, model)
        : cut(request.shots, request.width, model, request.box, request.foot);
      job = cutting.then((layers) => ({ layers }));
    } else if (request.action === 'paint') {
      job = paint(request.key, request.layers, request.primary, request.secondary).then(({ image }) => ({ image }));
    }

    if (!job) return;

    job
      .then((result) => nui('done', { ...result, id: request.id, ok: true }))
      .catch((error: Error) => nui('done', { id: request.id, ok: false, error: error.message }));
  });
}
