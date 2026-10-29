// Formatting helpers: file-name labels, word lists, dates and times.

// "Tara Fernandes" -> "tara_fernandes.profile", for the file-name labels around the desktop.
export const fileName = (name, ext) =>
  `${name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')}.${ext}`;

// "Tara Fernandes" -> "Tara F"
export function shortName(name) {
  const parts = name.trim().split(/\s+/);
  return parts.length > 1 ? `${parts[0]} ${parts.at(-1)[0]}` : parts[0];
}

// ["AI", "Health", "Gaming"] -> "AI, Health and Gaming"
export const joinWords = (list) =>
  list.length < 2 ? list.join('') : `${list.slice(0, -1).join(', ')} and ${list.at(-1)}`;

// The same background colour for the same person everywhere.
const TONES = ['pink', 'blue', 'desk'];
export const toneFor = (id = '') => TONES[[...id].reduce((n, c) => n + c.charCodeAt(0), 0) % TONES.length];

const timeFormat = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
const secondsFormat = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit', second: '2-digit' });
const dayFormat = new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', month: 'short' });

export const clockTime = (d, withSeconds = false) => (withSeconds ? secondsFormat : timeFormat).format(new Date(d));
export const menuDate = (d) => dayFormat.format(d);

const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();

// "Today", "Tomorrow", "Yesterday" or "Fri 30 Oct"
export function dayName(date, now = new Date()) {
  const d = new Date(date);
  const days = Math.round((startOfDay(d) - startOfDay(now)) / 86_400_000);
  return { 0: 'Today', 1: 'Tomorrow', [-1]: 'Yesterday' }[days] ?? dayFormat.format(d);
}

// "Today · 9:30 AM–11:00 AM", with both days when it runs past midnight.
export function timeRange(start, end, now) {
  const s = new Date(start);
  const e = new Date(end);
  return startOfDay(s) === startOfDay(e)
    ? `${dayName(s, now)} · ${clockTime(s)}–${clockTime(e)}`
    : `${dayName(s, now)} ${clockTime(s)} – ${dayName(e, now)} ${clockTime(e)}`;
}

// "in 25 min", "in 2 h 5 min", "3 days ago"
export function relativeTime(date, now = new Date()) {
  const mins = Math.round((new Date(date) - now) / 60_000);
  const abs = Math.abs(mins);
  if (abs < 1) return 'now';
  const text = abs < 60 ? `${abs} min`
    : abs < 48 * 60 ? `${Math.floor(abs / 60)} h${abs % 60 ? ` ${abs % 60} min` : ''}`
    : `${Math.round(abs / 1440)} days`;
  return mins > 0 ? `in ${text}` : `${text} ago`;
}

// <input type="datetime-local"> works in local time with no zone: "2026-10-28T09:30".
export function toLocalInput(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export const fromLocalInput = (value) => (value ? new Date(value).toISOString() : '');
