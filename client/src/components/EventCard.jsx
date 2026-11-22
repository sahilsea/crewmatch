import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { Pill } from './retro.jsx';
import { ErrorNote } from './ui.jsx';
import { CheckIcon } from './icons.jsx';
import { label } from '../labels.js';
import { clockTime, dayName, relativeTime, timeRange } from '../format.js';

// Check-in stays open for 30 minutes after an event ends.
const GRACE_MS = 30 * 60_000;

// [when it happens, how far away], e.g. ["Today · 9:30 AM–11:00 AM", "ends in 25 min"].
function when(event, now) {
  if (event.kind === 'challenge') {
    const due = `${dayName(event.endsAt, now)} ${clockTime(event.endsAt)}`;
    if (event.state === 'upcoming') return [`Opens ${dayName(event.startsAt, now)} ${clockTime(event.startsAt)}`, `due ${due}`];
    if (event.state === 'live') return [`Due ${due}`, relativeTime(event.endsAt, now)];
    return [`Closed ${due}`, null];
  }
  const range = timeRange(event.startsAt, event.endsAt, now);
  if (event.state === 'upcoming') return [range, `starts ${relativeTime(event.startsAt, now)}`];
  if (event.state === 'live') return [range, `ends ${relativeTime(event.endsAt, now)}`];
  return [range, null];
}

// Where the crew stands on this one, in a line.
function EntryStatus({ event, entry, checkInOpen }) {
  const challenge = event.kind === 'challenge';
  if (!entry) return null;
  if (entry.status === 'completed') {
    return <p className="entry-status done"><CheckIcon /> {challenge ? 'Approved' : 'Checked in'} · +{entry.pointsAwarded} pts</p>;
  }
  if (entry.status === 'submitted') {
    return (
      <div className="entry-status">
        <p>Submitted · waiting for review</p>
        <a className="entry-link" href={entry.submissionUrl} target="_blank" rel="noreferrer">{entry.submissionUrl}</a>
        {entry.note && <p className="entry-quote">“{entry.note}”</p>}
      </div>
    );
  }
  // A rejected submission goes back to "joined", keeping the link and the organiser's note.
  if (challenge && entry.submissionUrl) {
    return (
      <div className="entry-note" role="note">
        <p><b>Not approved.</b> {entry.note ?? 'No reason given.'}</p>
        <p className="label small ink">Fix it and submit again before the deadline</p>
      </div>
    );
  }
  if (event.state === 'ended') return <p className="entry-status">{challenge ? 'Nothing submitted' : checkInOpen ? 'Your crew is going' : 'No check-in'}</p>;
  return <p className="entry-status">{challenge ? 'Accepted · send a link when it’s ready' : 'Your crew is going'}</p>;
}

// One event or challenge, with the actions that fit its state and your crew's entry.
export default function EventCard({ event, hasCrew, now, onChange, onCheckIn, onSubmit }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [open, setOpen] = useState(false);
  const [crews, setCrews] = useState(null);

  const challenge = event.kind === 'challenge';
  const entry = event.myEntry;
  const ended = event.state === 'ended';
  const full = !entry && event.capacity != null && event.crewCount >= event.capacity;
  const checkInOpen = !challenge && entry?.status !== 'completed'
    && (event.state === 'live' || (ended && now - new Date(event.endsAt) < GRACE_MS));
  const [time, hint] = when(event, now);

  async function act(request) {
    setBusy(true);
    setError(null);
    try {
      onChange((await request()).event);
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }
  const join = () => act(() => api.post(`/events/${event.id}/join`));
  const leave = () => act(() => api.del(`/events/${event.id}/join`));

  // "More" shows the long description and which crews are in, fresh each time.
  async function toggleMore() {
    setOpen(!open);
    if (open) return;
    try {
      setCrews((await api.get(`/events/${event.id}`)).event.crews);
    } catch (err) {
      setError(err);
    }
  }

  const actions = [];
  if (hasCrew && !challenge) {
    if (checkInOpen) actions.push(<button key="in" type="button" className="btn primary sm" onClick={() => onCheckIn(event)}>Check in</button>);
    if (!entry && !ended) actions.push(<button key="go" type="button" className="btn blue sm" disabled={busy || full} onClick={join}>{full ? 'Full' : 'Going'}</button>);
    if (entry?.status === 'joined' && !ended) actions.push(<button key="leave" type="button" className="btn sm" disabled={busy} onClick={leave}>Leave</button>);
  } else if (hasCrew && !ended) {
    if (!entry) actions.push(<button key="accept" type="button" className="btn blue sm" disabled={busy || full} onClick={join}>{full ? 'Full' : 'Accept'}</button>);
    if (entry && entry.status !== 'completed' && event.state === 'live') {
      const text = entry.status === 'submitted' ? 'Update link' : entry.submissionUrl ? 'Submit again' : 'Submit link';
      actions.push(<button key="submit" type="button" className="btn primary sm" onClick={() => onSubmit(event)}>{text}</button>);
    }
    if (entry?.status === 'joined') actions.push(<button key="leave" type="button" className="btn sm" disabled={busy} onClick={leave}>Leave</button>);
  }

  return (
    <article className={`event-card ${event.state} ${entry ? 'mine' : ''}`}>
      <header className={`event-head halftone ${ended ? 'desk' : challenge ? 'pink' : 'blue'}`}>
        <span className="label ink">{label(event.kind)} · {label(event.category)}</span>
        <Pill tone={event.state === 'live' ? '' : ended ? 'grey' : 'light'}>{label(event.state)}</Pill>
      </header>
      <div className="event-body">
        <p className="event-when">{time}{hint && <span className="label small"> · {hint}</span>}</p>
        <h3 className="event-title">{event.title}</h3>
        <p>{event.summary}</p>
        <dl className="event-facts">
          <div><dt>Where</dt><dd>{event.location}</dd></div>
          <div><dt>Points</dt><dd>+{event.points}</dd></div>
          <div>
            <dt>{challenge ? 'In' : 'Going'}</dt>
            <dd>{event.crewCount}{event.capacity != null && `/${event.capacity}`} {event.crewCount === 1 && event.capacity == null ? 'crew' : 'crews'}</dd>
          </div>
        </dl>
        <button type="button" className="link-btn label more" aria-expanded={open} onClick={toggleMore}>{open ? 'Less' : 'More'}</button>
        {open && (
          <div className="event-more">
            {event.details && <p>{event.details}</p>}
            {crews && <p className="label small">{crews.length ? `Crews: ${crews.map((c) => c.name).join(', ')}` : 'No crews yet'}</p>}
          </div>
        )}
      </div>
      <footer className="event-foot">
        <EntryStatus event={event} entry={entry} checkInOpen={checkInOpen} />
        {actions.length > 0 && <div className="row">{actions}</div>}
        {!hasCrew && !ended && <p className="label small">Crews only · <Link to="/crew">get a crew</Link></p>}
        <ErrorNote error={error} />
      </footer>
    </article>
  );
}
