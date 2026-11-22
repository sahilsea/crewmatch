import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { Pill, Tabs, Window } from '../components/retro.jsx';
import { Empty, ErrorNote, FieldError, Spinner } from '../components/ui.jsx';
import { EVENT_CATEGORIES, label } from '../labels.js';
import { fromLocalInput, timeRange, toLocalInput } from '../format.js';

// What each entry status means, per kind, for the counts on each row.
const STATUS_WORDS = {
  event: { joined: 'going', completed: 'checked in' },
  challenge: { joined: 'accepted', submitted: 'to review', completed: 'approved' },
};

// A new one starts at the next full hour and runs for an hour.
function blankForm() {
  const start = new Date();
  start.setHours(start.getHours() + 1, 0, 0, 0);
  return {
    kind: 'event', title: '', summary: '', details: '', category: 'workshop', location: '',
    startsAt: toLocalInput(start), endsAt: toLocalInput(start.getTime() + 3_600_000),
    points: '50', capacity: '', checkinCode: '',
  };
}

const toForm = (e) => ({
  kind: e.kind, title: e.title, summary: e.summary, details: e.details ?? '', category: e.category,
  location: e.location ?? '', startsAt: toLocalInput(e.startsAt), endsAt: toLocalInput(e.endsAt),
  points: String(e.points), capacity: e.capacity == null ? '' : String(e.capacity), checkinCode: e.checkinCode ?? '',
});

function Field({ name, hint, error, children }) {
  return (
    <label className="field">
      <span>{name}</span>
      {children}
      {hint && !error && <small className="field-hint">{hint}</small>}
      <FieldError>{error}</FieldError>
    </label>
  );
}

// Create or edit. The API checks everything and its messages show under each field.
function EventForm({ event, onSaved, onCancel }) {
  const editing = Boolean(event);
  const [form, setForm] = useState(() => (event ? toForm(event) : blankForm()));
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const errors = error?.fieldErrors ?? {};

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));
  const setKind = (kind) => setForm((f) => ({ ...f, kind, category: EVENT_CATEGORIES[kind][0] }));

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const body = {
      kind: form.kind,
      title: form.title,
      summary: form.summary,
      details: form.details,
      category: form.category,
      location: form.location,
      startsAt: fromLocalInput(form.startsAt),
      endsAt: fromLocalInput(form.endsAt),
      points: form.points === '' ? undefined : Number(form.points),
      capacity: form.capacity === '' ? null : Number(form.capacity),
      // Empty means "generate one". Challenges have no code.
      ...(form.kind === 'event' && { checkinCode: form.checkinCode.trim() || null }),
    };
    try {
      const { event: saved } = editing
        ? await api.patch(`/admin/events/${event.id}`, body)
        : await api.post('/admin/events', body);
      if (!editing) setForm(blankForm());
      onSaved(saved, editing);
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  const challenge = form.kind === 'challenge';
  return (
    <Window
      title={editing ? `Edit ${event.kind}` : `New ${form.kind}`} id="event-form" inset={false} front={editing}
      strip={editing ? `Editing: ${event.title}` : 'Times are in your local time'}
    >
      <form className="form-body compact" onSubmit={submit} noValidate>
        <fieldset className="chip-group">
          <legend>Kind</legend>
          <div className="chips">
            {Object.keys(EVENT_CATEGORIES).map((k) => (
              <button type="button" key={k} className={`chip ${form.kind === k ? 'on' : ''}`} aria-pressed={form.kind === k} onClick={() => setKind(k)}>
                {label(k)}
              </button>
            ))}
          </div>
          <FieldError>{errors.kind}</FieldError>
        </fieldset>
        <Field name="Title" error={errors.title}>
          <input value={form.title} onChange={set('title')} maxLength={80} required />
        </Field>
        <Field name={`Summary (${140 - form.summary.length} left)`} error={errors.summary}>
          <input value={form.summary} onChange={set('summary')} maxLength={140} required />
        </Field>
        <Field name="Details, optional" error={errors.details}>
          <textarea rows={3} value={form.details} onChange={set('details')} maxLength={2000} />
        </Field>
        <div className="two-col">
          <Field name="Category" error={errors.category}>
            <select className="input" value={form.category} onChange={set('category')}>
              {EVENT_CATEGORIES[form.kind].map((c) => <option key={c} value={c}>{label(c)}</option>)}
            </select>
          </Field>
          <Field name="Location" error={errors.location}>
            <input value={form.location} onChange={set('location')} maxLength={80} placeholder={challenge ? 'Anywhere or Online' : 'Lab 3, Block B'} />
          </Field>
        </div>
        <div className="two-col">
          <Field name={challenge ? 'Opens' : 'Starts'} error={errors.startsAt}>
            <input type="datetime-local" value={form.startsAt} onChange={set('startsAt')} required />
          </Field>
          <Field name={challenge ? 'Deadline' : 'Ends'} error={errors.endsAt}>
            <input type="datetime-local" value={form.endsAt} onChange={set('endsAt')} required />
          </Field>
        </div>
        <div className="two-col">
          <Field name="Points" hint="0 to 1000" error={errors.points}>
            <input type="number" min={0} max={1000} value={form.points} onChange={set('points')} required />
          </Field>
          <Field name="Max crews" hint="Empty for no limit" error={errors.capacity}>
            <input type="number" min={1} max={500} value={form.capacity} onChange={set('capacity')} />
          </Field>
        </div>
        {!challenge && (
          <Field name="Check-in code" hint="Leave empty to generate one" error={errors.checkinCode}>
            <input value={form.checkinCode} maxLength={20} onChange={(e) => setForm((f) => ({ ...f, checkinCode: e.target.value.toUpperCase() }))} />
          </Field>
        )}
        <ErrorNote error={error} />
        <div className="row">
          <button className="btn primary" disabled={busy}>{busy ? 'Saving…' : editing ? 'Save changes' : `Create ${form.kind}`}</button>
          {editing && <button type="button" className="btn" onClick={onCancel}>Cancel</button>}
        </div>
      </form>
    </Window>
  );
}

// One submitted link: approve with the event's points or an override, or reject with a reason.
function Review({ event, entry, onDone }) {
  const [points, setPoints] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function review(action, body, message) {
    setBusy(true);
    setError(null);
    try {
      const res = await api.post(`/admin/events/${event.id}/entries/${entry.crew.id}/${action}`, body);
      onDone(res.event, message);
    } catch (err) {
      setError(err);
      setBusy(false);
    }
  }

  const award = points === '' ? event.points : Number(points);
  return (
    <li className="review">
      <p className="label ink">{event.title} · worth {event.points} pts</p>
      <p className="report-headline">{entry.crew.name}</p>
      <a className="entry-link" href={entry.submissionUrl} target="_blank" rel="noreferrer">{entry.submissionUrl}</a>
      {entry.note && <p className="entry-quote">“{entry.note}”</p>}
      <div className="review-actions">
        <label className="field">
          <span>Points</span>
          <input type="number" min={0} max={1000} placeholder={String(event.points)} value={points} onChange={(e) => setPoints(e.target.value)} />
          <FieldError>{error?.fieldErrors.points}</FieldError>
        </label>
        <button
          type="button" className="btn blue sm" disabled={busy}
          onClick={() => review('approve', points === '' ? {} : { points: Number(points) }, `Approved ${entry.crew.name}: +${award} points.`)}
        >
          Approve
        </button>
      </div>
      <div className="review-actions">
        <label className="field grow">
          <span>Reason</span>
          <input value={note} maxLength={280} placeholder="Optional, the crew sees it" onChange={(e) => setNote(e.target.value)} />
          <FieldError>{error?.fieldErrors.note}</FieldError>
        </label>
        <button
          type="button" className="btn sm" disabled={busy}
          onClick={() => review('reject', note.trim() ? { note: note.trim() } : {}, `Sent the link back to ${entry.crew.name}.`)}
        >
          Reject
        </button>
      </div>
      {error && !Object.keys(error.fieldErrors).length && <ErrorNote error={error} />}
    </li>
  );
}

export default function AdminEventsPage() {
  const [events, setEvents] = useState(null);
  const [error, setError] = useState(null);
  const [kind, setKind] = useState('all');
  const [editing, setEditing] = useState(null);
  const [flash, setFlash] = useState(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let live = true;
    api.get('/admin/events')
      .then((d) => { if (live) { setEvents(d.events); setError(null); } })
      .catch((err) => { if (live) { setError(err); setEvents((list) => list ?? []); } });
    return () => { live = false; };
  }, [version]);

  const reload = () => setVersion((v) => v + 1);

  function saved(event, wasEditing) {
    setEditing(null);
    setFlash(`${wasEditing ? 'Saved' : 'Created'} ${event.title}${event.checkinCode ? ` · check-in code ${event.checkinCode}` : ''}.`);
    reload();
  }

  function reviewed(event, message) {
    setEvents((list) => list.map((e) => (e.id === event.id ? event : e)));
    setFlash(message);
  }

  async function remove(event) {
    if (!confirm(`Delete ${event.title}? Points it gave crews come off the leaderboard.`)) return;
    try {
      await api.del(`/admin/events/${event.id}`);
      if (editing?.id === event.id) setEditing(null);
      setFlash(`Deleted ${event.title}.`);
      setEvents((list) => list.filter((e) => e.id !== event.id));
    } catch (err) {
      setError(err);
    }
  }

  function edit(event) {
    setEditing(event);
    document.getElementById('event-form')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  if (!events) return <Spinner text="Loading events" />;

  const pending = events.flatMap((e) => e.entries.filter((x) => x.status === 'submitted').map((entry) => ({ event: e, entry })));
  const shown = events.filter((e) => kind === 'all' || e.kind === kind);
  const count = (k) => events.filter((e) => e.kind === k).length;

  return (
    <div className="workspace admin-events-desk">
      <div className="desk-main">
        {flash && <p className="flash window-flash" role="status">{flash}</p>}
        <ErrorNote error={error} />

        <Window title="Pending submissions" titleAs="h1" inset={false} strip={`${pending.length} waiting for review`}>
          {pending.length === 0 ? (
            <p className="inset-note">Nothing to review. Links that crews submit for challenges show up here.</p>
          ) : (
            <ul className="review-list">
              {pending.map(({ event, entry }) => <Review key={`${event.id}-${entry.crew.id}`} event={event} entry={entry} onDone={reviewed} />)}
            </ul>
          )}
        </Window>

        <Window title="Events & challenges" inset={false} strip={`${shown.length} items · show codes on screen at the venue`}>
          <div className="events-toolbar">
            <Tabs
              label="Show" value={kind} onChange={setKind}
              options={[['all', 'All', events.length], ['event', 'Events', count('event')], ['challenge', 'Challenges', count('challenge')]]}
            />
          </div>
          {shown.length === 0 ? (
            <Empty title="Nothing yet"><p>Create the first one with the form.</p></Empty>
          ) : (
            <ul className="admin-events">
              {shown.map((e) => {
                const words = STATUS_WORDS[e.kind];
                const counts = Object.entries(words)
                  .map(([status, word]) => [e.entries.filter((x) => x.status === status).length, word])
                  .filter(([n]) => n > 0)
                  .map(([n, word]) => `${n} ${word}`);
                return (
                  <li key={e.id} className={`admin-event ${editing?.id === e.id ? 'editing' : ''}`}>
                    <div className="admin-event-text">
                      <p className="label ink">
                        {label(e.kind)} · {label(e.category)} <Pill tone={e.state === 'live' ? '' : e.state === 'ended' ? 'grey' : 'light'}>{label(e.state)}</Pill>
                      </p>
                      <p className="report-headline">{e.title}</p>
                      <p className="label small">{timeRange(e.startsAt, e.endsAt)} · {e.location}</p>
                      <p className="label small">
                        +{e.points} pts · {e.crewCount}{e.capacity != null && `/${e.capacity}`} crews{counts.length > 0 && ` · ${counts.join(' · ')}`}
                      </p>
                    </div>
                    {e.checkinCode && (
                      <p className="code-box"><span className="label small">Code</span><b>{e.checkinCode}</b></p>
                    )}
                    <div className="admin-event-actions">
                      <button type="button" className="btn sm" onClick={() => edit(e)}>Edit<span className="sr-only"> {e.title}</span></button>
                      <button type="button" className="btn sm" onClick={() => remove(e)}>Delete<span className="sr-only"> {e.title}</span></button>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </Window>
      </div>

      <div className="desk-side">
        <EventForm key={editing?.id ?? 'new'} event={editing} onSaved={saved} onCancel={() => setEditing(null)} />
      </div>
    </div>
  );
}
