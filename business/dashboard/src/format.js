const compactFmt = new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 });

export const pct = (x, digits = 0) => (x == null ? "–" : `${(x * 100).toFixed(digits)}%`);
export const compact = (n) => (n == null ? "–" : compactFmt.format(n));
export const full = (n) => (n == null ? "–" : Math.round(n).toLocaleString("en"));
export const usd = (n) => (n == null ? "–" : `$${compactFmt.format(n)}`);
