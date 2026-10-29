import { useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Dialog } from './retro.jsx';
import { Avatar } from './ui.jsx';
import { HeartIcon } from './icons.jsx';
import { celebrate } from '../confetti.js';

export default function MatchModal({ me, them, onClose }) {
  const canvas = useRef(null);

  // Confetti once per match, not on every re-render. It draws on a canvas inside
  // the dialog, because a modal dialog sits above everything else on the page.
  useEffect(() => celebrate(canvas.current), []);

  return (
    <Dialog title="It's a match" onClose={onClose} className="match-window">
      <canvas ref={canvas} className="confetti" aria-hidden="true" />
      <div className="match-art halftone pink">
        <Avatar src={me.avatar} name={me.name} size={96} tone="blue" />
        <span className="match-heart"><HeartIcon size={28} /></span>
        <Avatar src={them.avatar} name={them.name} size={96} tone="desk" />
      </div>
      <div className="dialog-body center">
        <p className="serif-title">You and {them.name}</p>
        <p>You both swiped right.</p>
        {them.email && <p className="muted">Say hi: <a href={`mailto:${them.email}`}>{them.email}</a></p>}
        <div className="row">
          <button type="button" className="btn primary" onClick={onClose} data-autofocus>Keep swiping</button>
          <Link className="btn" to="/matches">See matches</Link>
        </div>
      </div>
    </Dialog>
  );
}
