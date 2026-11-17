// Turn a dark-ink-on-white signature into white strokes on transparency.
// Usage: node scripts/process-sign.mjs <src image> [out=public/sign.png]
import sharp from "sharp";

const src = process.argv[2];
const out = process.argv[3] ?? "public/sign.png";
if (!src) {
  console.error("usage: node scripts/process-sign.mjs <src> [out]");
  process.exit(1);
}

// Ink → alpha: grayscale, invert (ink becomes bright), then steepen so the
// off-white paper drops to 0 and only the strokes keep alpha.
const { data: alpha, info } = await sharp(src)
  .grayscale()
  .negate()
  .linear(1.7, -70)
  .raw()
  .toBuffer({ resolveWithObject: true });

const white = sharp({
  create: { width: info.width, height: info.height, channels: 3, background: { r: 255, g: 255, b: 255 } },
});

const composed = await white
  .joinChannel(alpha, { raw: { width: info.width, height: info.height, channels: 1 } })
  .png()
  .toBuffer();

// Trim the transparent margin so it sits tight in the layout.
await sharp(composed).trim().png().toFile(out);
console.log("wrote", out);
