import { useEffect } from 'react';
import { animate, motion, useMotionValue, useTransform } from 'motion/react';
import { Avatar, Meta, Score, Tag } from './ui.jsx';
import { label } from '../labels.js';

const SWIPE_DISTANCE = 120;

// A draggable profile card. Drag past 120px, or set `fling`, to swipe it away.
export default function SwipeCard({ person, onSwipe, fling, active }) {
  const x = useMotionValue(0);
  const rotate = useTransform(x, [-250, 250], [-14, 14]);
  const likeOpacity = useTransform(x, [20, SWIPE_DISTANCE], [0, 1]);
  const passOpacity = useTransform(x, [-SWIPE_DISTANCE, -20], [1, 0]);

  async function flyOut(direction) {
    await animate(x, direction === 'right' ? 700 : -700, { duration: 0.28, ease: 'easeIn' });
    onSwipe(direction);
  }

  // The Like / Pass buttons and arrow keys swipe by setting `fling`.
  useEffect(() => {
    if (fling && active) flyOut(fling);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fling, active]);

  function onDragEnd(_, info) {
    if (info.offset.x > SWIPE_DISTANCE || info.velocity.x > 700) flyOut('right');
    else if (info.offset.x < -SWIPE_DISTANCE || info.velocity.x < -700) flyOut('left');
    else animate(x, 0, { type: 'spring', stiffness: 400, damping: 30 });
  }

  return (
    <motion.article
      className={`swipe-card ${active ? 'active' : 'behind'}`}
      style={{ x, rotate }}
      drag={active ? 'x' : false}
      dragMomentum={false}
      onDragEnd={onDragEnd}
      initial={active ? false : { scale: 0.94, y: 14 }}
      animate={active ? { scale: 1, y: 0 } : { scale: 0.94, y: 14 }}
      aria-hidden={!active}
    >
      <motion.span className="stamp like" style={{ opacity: likeOpacity }}>LIKE</motion.span>
      <motion.span className="stamp pass" style={{ opacity: passOpacity }}>PASS</motion.span>

      <div className="swipe-top">
        <Avatar src={person.avatar} name={person.name} size={112} />
        <Score value={person.score} />
      </div>
      <h2>{person.name}</h2>
      <Meta person={person} />
      {person.bio && <p className="bio">{person.bio}</p>}

      {person.tags.length > 0 && (
        <div className="reasons">
          {person.tags.map((t) => <Tag key={t} tone="accent">✦ {t}</Tag>)}
        </div>
      )}

      <dl className="facts">
        <div><dt>Skills</dt><dd>{person.skills.join(', ')}</dd></div>
        {person.superpowers.length > 0 && (
          <div><dt>Superpowers</dt><dd>{person.superpowers.map(label).join(', ')}</dd></div>
        )}
        <div><dt>Into</dt><dd>{person.interests.map(label).join(', ')}</dd></div>
        <div><dt>Style</dt><dd>{label(person.commitment)} · prefers {label(person.communication).toLowerCase()}</dd></div>
      </dl>
    </motion.article>
  );
}
