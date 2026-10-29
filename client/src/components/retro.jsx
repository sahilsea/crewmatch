// The retro desktop kit: windows, filter tabs, segmented buttons, meters and dialogs.
import { useEffect, useId, useRef, useState } from 'react';
import { CloseIcon, RestoreIcon } from './icons.jsx';

// A desktop window: title bar, white inset panel and an optional status strip.
// The ✕ minimises it to its title bar and brings it back; `action` puts a button there instead.
export function Window({
  title, titleAs: Title = 'h2', action, collapsible = true, front, inset = true, strip, className = '', children, ...rest
}) {
  const [collapsed, setCollapsed] = useState(false);
  const bodyId = useId();

  return (
    <section className={`window ${front ? 'front' : ''} ${collapsed ? 'collapsed' : ''} ${className}`} {...rest}>
      <header className="titlebar">
        {action ?? (collapsible && (
          <button
            type="button" className="win-btn" aria-controls={bodyId} aria-expanded={!collapsed}
            aria-label={`${collapsed ? 'Restore' : 'Minimise'} ${title}`} title={collapsed ? 'Restore' : 'Minimise'}
            onClick={() => setCollapsed((c) => !c)}
          >
            {collapsed ? <RestoreIcon /> : <CloseIcon />}
          </button>
        ))}
        <Title className="window-title">{title}</Title>
      </header>
      <div id={bodyId} className="window-body" hidden={collapsed}>
        {inset ? <div className="inset">{children}</div> : children}
        {strip && <StatusStrip>{strip}</StatusStrip>}
      </div>
    </section>
  );
}

export function StatusStrip({ children }) {
  return <p className="status-strip">{children}</p>;
}

// Filter tabs: pick one of a few, e.g. All / Live / Upcoming. `options` is [[key, text, count?]].
export function Tabs({ label, options, value, onChange }) {
  return (
    <div className="tabs" role="group" aria-label={label}>
      {options.map(([key, text, count]) => (
        <button key={key} type="button" className="tab" aria-pressed={value === key} onClick={() => onChange(key)}>
          {text}
          {count !== undefined && <span className="tab-count">{count}</span>}
        </button>
      ))}
    </div>
  );
}

// A row of square buttons sharing one frame. Give the main one className="primary".
export function Segmented({ label, children }) {
  return <div className="segmented" role="group" aria-label={label}>{children}</div>;
}

// A thin bar for a part of a whole. Screen readers get `label` ("2 of 3 match");
// leave it out when the same words are printed next to the bar.
export function Meter({ value, max, label, tone }) {
  const pct = max ? Math.round((value / max) * 100) : 0;
  return (
    <span className={`meter ${tone ?? ''}`} role={label ? 'img' : undefined} aria-label={label} aria-hidden={!label}>
      <span style={{ width: `${pct}%` }} />
    </span>
  );
}

export function Pill({ children, tone }) {
  return <span className={`pill ${tone ?? ''}`}>{children}</span>;
}

// A modal window on top of everything. Built on <dialog>, so focus stays inside
// and Escape closes it; so does a click on the backdrop. Mark the field to focus
// first with data-autofocus.
export function Dialog({ title, onClose, className = '', children }) {
  const ref = useRef(null);
  const pressedBackdrop = useRef(false);
  const titleId = useId();

  useEffect(() => {
    const dialog = ref.current;
    dialog.showModal();
    dialog.querySelector('[data-autofocus]')?.focus();
    return () => dialog.close();
  }, []);

  return (
    <dialog
      ref={ref} className="dialog" aria-labelledby={titleId}
      onCancel={(e) => { e.preventDefault(); onClose(); }}
      onPointerDown={(e) => { pressedBackdrop.current = e.target === e.currentTarget; }}
      onClick={(e) => { if (pressedBackdrop.current && e.target === e.currentTarget) onClose(); }}
    >
      <section className={`window front ${className}`}>
        <header className="titlebar">
          <button type="button" className="win-btn" aria-label="Close" title="Close" onClick={onClose}><CloseIcon /></button>
          <h2 id={titleId} className="window-title">{title}</h2>
        </header>
        {children}
      </section>
    </dialog>
  );
}
