import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useNow } from '../hooks.js';
import EventCard from '../components/EventCard.jsx';
import { Dialog, Tabs, Window } from '../components/retro.jsx';
import { Empty, ErrorNote, FieldError, Scoreboard, Spinner } from '../components/ui.jsx';
import { celebrate } from '../confetti.js';
import { clockTime, dayName } from '../format.js';

// States and crew counts change while the page is open.
const REFRESH_MS = 30_000;

const FILTERS = {
  all: [() => true, 'All'],
  live: [(e) => e.state === 'live', 'Live'],
  upcoming: [(e) => e.state === 'upcoming', 'Upcoming'],
  challenges: [(e) => e.kind === 'challenge', 'Challenges'],
};

function CheckInDialog({ event, onClose, onDone }) {
  const [code, setCode] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await api.post(`/events/${event.id}/checkin`, { code });
      onDone(res.event, res.pointsAwarded);
    } catch (err) {
      setError(err);
      setBusy(false);
    }
  }

  return (
    <Dialog title="Check in" onClose={onClose}>
      <form className="dialog-body" onSubmit={submit}>
        <p className="serif-title small">{event.title}</p>
        <p className="muted">Type the code the organisers show on screen at {event.location}. It's worth {event.points} points to your crew.</p>
        <label className="field">
          <span>Check-in code</span>
          <input
            className="code-input" value={code} onChange={(e) => setCode(e.target.value.toUpperCase())}
            autoComplete="off" autoCapitalize="characters" spellCheck="false" maxLength={20} required data-autofocus
          />
          <FieldError>{error?.fieldErrors.code}</FieldError>
        </label>
        {error && !error.fieldErrors.code && <ErrorNote error={error} />}
        <div className="row end">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !code.trim()}>{busy ? 'Checking…' : 'Check in'}</button>
        </div>
      </form>
    </Dialog>
  );
}

function SubmitDialog({ event, onClose, onDone }) {
  const entry = event.myEntry;
  const [url, setUrl] = useState(entry?.submissionUrl ?? '');
  // After a rejection `note` holds the organiser's reason, so only reuse the crew's own note.
  const [note, setNote] = useState(entry?.status === 'submitted' ? entry.note ?? '' : '');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const fieldErrors = error?.fieldErrors ?? {};

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await api.post(`/events/${event.id}/submit`, { url: url.trim(), ...(note.trim() && { note: note.trim() }) });
      onDone(res.event);
    } catch (err) {
      setError(err);
      setBusy(false);
    }
  }

  return (
    <Dialog title="Submit link" onClose={onClose}>
      <form className="dialog-body" onSubmit={submit} noValidate>
        <p className="serif-title small">{event.title}</p>
        <p className="muted">
          Deadline: {dayName(event.endsAt)}, {clockTime(event.endsAt)}. An organiser reviews your link and awards the points.
          You can replace it until then.
        </p>
        <label className="field">
          <span>Link to your work</span>
          <input type="url" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://…" required data-autofocus />
          <FieldError>{fieldErrors.url}</FieldError>
        </label>
        <label className="field">
          <span>Note, optional ({280 - note.length} left)</span>
          <textarea rows={3} maxLength={280} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Anything the judges should know" />
          <FieldError>{fieldErrors.note}</FieldError>
        </label>
        {error && !fieldErrors.url && !fieldErrors.note && <ErrorNote error={error} />}
        <div className="row end">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy || !url.trim()}>{busy ? 'Sending…' : 'Submit'}</button>
        </div>
      </form>
    </Dialog>
  );
}

export default function EventsPage() {
  const [events, setEvents] = useState(null);
  const [crew, setCrew] = useState(undefined);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [dialog, setDialog] = useState(null);
  const [flash, setFlash] = useState(null);
  const now = useNow(REFRESH_MS);

  useEffect(() => {
    let live = true;
    const load = () => api.get('/events')
      .then((d) => { if (live) { setEvents(d.events); setError(null); } })
      .catch((err) => { if (live) { setError(err); setEvents((list) => list ?? []); } });
    load();
    api.get('/crews/mine')
      .then((d) => live && setCrew(d.crew))
      .catch(() => live && setCrew(null));
    const id = setInterval(load, REFRESH_MS);
    return () => { live = false; clearInterval(id); };
  }, []);

  const replace = (event) => setEvents((list) => list.map((e) => (e.id === event.id ? event : e)));
  const reloadCrew = () => api.get('/crews/mine').then((d) => setCrew(d.crew)).catch(() => {});

  function checkedIn(event, points) {
    replace(event);
    setDialog(null);
    setFlash(`Checked in to ${event.title}: +${points} points for ${crew.name}.`);
    celebrate();
    reloadCrew();
  }

  function submitted(event) {
    replace(event);
    setDialog(null);
    setFlash(`Link sent for ${event.title}. An organiser will review it.`);
  }

  if (!events || crew === undefined) return <Spinner text="Loading events" />;

  const shown = events.filter(FILTERS[filter][0]);
  const tabs = Object.entries(FILTERS).map(([key, [test, text]]) => [key, text, events.filter(test).length]);

  return (
    <div className="workspace events-desk">
      <div className="desk-main">
        {!crew && (
          <Window title="Crew needed" inset={false} front>
            <div className="cta halftone pink">
              <p className="serif-title">Events and challenges are for crews.</p>
              <p>Match with people and start a crew of up to 4. Then come back to RSVP, check in and take on challenges. Points go to the whole crew.</p>
              <Link className="btn dark" to="/crew">Go to Crew →</Link>
            </div>
          </Window>
        )}

        <Window title="Events & challenges" titleAs="h1" inset={false} strip={`${shown.length} of ${events.length} · live first`}>
          <div className="events-toolbar">
            <Tabs label="Show" options={tabs} value={filter} onChange={setFilter} />
          </div>
          {(flash || error) && (
            <div className="window-messages">
              {flash && <p className="flash" role="status">{flash}</p>}
              <ErrorNote error={error} />
            </div>
          )}
          {shown.length === 0 ? (
            <div className="inset">
              <Empty title={filter === 'live' ? 'Nothing live right now' : 'Nothing here yet'}>
                <p>{events.length ? 'Try another tab.' : 'Organisers add events and challenges through the day. Check back soon.'}</p>
              </Empty>
            </div>
          ) : (
            <div className="event-grid">
              {shown.map((e) => (
                <EventCard
                  key={e.id} event={e} hasCrew={Boolean(crew)} now={now} onChange={replace}
                  onCheckIn={(ev) => setDialog({ type: 'checkin', event: ev })}
                  onSubmit={(ev) => setDialog({ type: 'submit', event: ev })}
                />
              ))}
            </div>
          )}
        </Window>
      </div>

      <div className="desk-side">
        {crew && (
          <Window title={crew.name} inset={false}>
            <Scoreboard crew={crew} />
            <p className="side-note">Every check-in and approved challenge adds to the crew's total. Any member can act for the crew.</p>
          </Window>
        )}
        <Window title="How it works">
          <ol className="how-list">
            <li><b>Events.</b> Tap Going so the organisers can plan. At the venue, check in with the code on screen. Check-in stays open 30 minutes after the end.</li>
            <li><b>Challenges.</b> Accept, then submit a link before the deadline. An organiser reviews it and awards the points.</li>
            <li><b>Leaderboard.</b> Crews are ranked by points. <Link to="/leaderboard">See who's ahead</Link>.</li>
          </ol>
        </Window>
      </div>

      {dialog?.type === 'checkin' && <CheckInDialog event={dialog.event} onClose={() => setDialog(null)} onDone={checkedIn} />}
      {dialog?.type === 'submit' && <SubmitDialog event={dialog.event} onClose={() => setDialog(null)} onDone={submitted} />}
    </div>
  );
}
