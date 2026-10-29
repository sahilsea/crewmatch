import { useEffect, useState } from 'react';
import { api } from './api.js';

// The option lists never change while the app runs, so fetch them once.
let optionsCache;
export function useOptions() {
  const [options, setOptions] = useState(optionsCache);
  useEffect(() => {
    if (optionsCache) return;
    api.get('/options').then((o) => { optionsCache = o; setOptions(o); });
  }, []);
  return options;
}

// Stacking order for overlapping windows: pressing on one brings it to the front.
// `ids` go back to front. Spread win(id) onto each <Window>.
export function useWindowOrder(ids) {
  const [order, setOrder] = useState(ids);
  const raise = (id) => setOrder((o) => (o.at(-1) === id ? o : [...o.filter((x) => x !== id), id]));
  return (id) => ({ style: { zIndex: order.indexOf(id) + 1 }, onPointerDown: () => raise(id) });
}

// The current time, ticking every `ms` milliseconds.
export function useNow(ms) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), ms);
    return () => clearInterval(id);
  }, [ms]);
  return now;
}
