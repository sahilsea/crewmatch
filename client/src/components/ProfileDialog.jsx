import { Dialog } from './retro.jsx';
import { Meta, Photo, Tag } from './ui.jsx';
import { HeartIcon, PassIcon } from './icons.jsx';
import { label } from '../labels.js';
import { fileName } from '../format.js';

// Everything on a deck card, including what doesn't fit on it, with Pass and Like.
export default function ProfileDialog({ person, onClose, onDecide }) {
  return (
    <Dialog title={fileName(person.name, 'profile')} onClose={onClose} className="profile-window">
      <Photo src={person.avatar} name={person.name} />
      <div className="dialog-body">
        <p className="serif-title">{person.name}</p>
        <Meta person={person} />
        {person.bio && <p>{person.bio}</p>}
        {person.tags.length > 0 && <div>{person.tags.map((t) => <Tag key={t} tone="blue">{t}</Tag>)}</div>}
        <dl className="facts">
          <div><dt>Fit</dt><dd>{person.score}%</dd></div>
          <div><dt>Skills</dt><dd>{person.skills.join(', ')}</dd></div>
          {person.superpowers.length > 0 && (
            <div><dt>Superpowers</dt><dd>{person.superpowers.map(label).join(', ')}</dd></div>
          )}
          <div><dt>Into</dt><dd>{person.interests.map(label).join(', ')}</dd></div>
          <div><dt>Style</dt><dd>{label(person.commitment)} · prefers {label(person.communication).toLowerCase()}</dd></div>
        </dl>
        <div className="row">
          <button type="button" className="btn" onClick={() => onDecide('left')}><PassIcon /> Pass</button>
          <button type="button" className="btn blue" onClick={() => onDecide('right')} data-autofocus><HeartIcon /> Like</button>
        </div>
      </div>
    </Dialog>
  );
}
