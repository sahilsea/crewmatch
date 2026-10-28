import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import confetti from 'canvas-confetti';
import { motion } from 'motion/react';
import { Avatar } from './ui.jsx';

export default function MatchModal({ me, them, onClose }) {
  // Confetti once per match, not on every re-render.
  useEffect(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    confetti({ particleCount: 140, spread: 80, origin: { y: 0.55 }, colors: ['#f0525c', '#ffb347', '#6c63ff', '#2ec4b6'] });
  }, []);

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <motion.div
        className="modal match-modal" role="dialog" aria-modal="true" aria-labelledby="match-title"
        initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="pair">
          <Avatar src={me.avatar} name={me.name} size={88} />
          <span className="heart">♥</span>
          <Avatar src={them.avatar} name={them.name} size={88} />
        </div>
        <h2 id="match-title">It's a match!</h2>
        <p>You and <b>{them.name}</b> both swiped right.</p>
        {them.email && (
          <p className="muted">Say hi: <a href={`mailto:${them.email}`}>{them.email}</a></p>
        )}
        <div className="modal-actions">
          <button className="btn primary" onClick={onClose} autoFocus>Keep swiping</button>
          <Link className="btn ghost" to="/matches">See matches</Link>
        </div>
      </motion.div>
    </div>
  );
}
