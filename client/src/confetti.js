import confetti from 'canvas-confetti';

const COLORS = ['#f5b8c4', '#a6d9e7', '#1a1a1a', '#fbf8f3', '#f3cfcd'];

// Confetti in the desktop's colours, drawn on `canvas` or, without one, over the page.
// Skipped for people who prefer reduced motion. Returns a function that clears it.
export function celebrate(canvas, options) {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return () => {};
  const fire = canvas ? confetti.create(canvas, { resize: true }) : confetti;
  fire({ particleCount: 140, spread: 80, origin: { y: 0.55 }, colors: COLORS, ...options });
  return () => fire.reset();
}
