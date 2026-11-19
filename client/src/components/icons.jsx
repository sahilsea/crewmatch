// Line icons for the retro desktop. All are decorative: the buttons around them carry the labels.
const line = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };

export const CloseIcon = () => (
  <svg aria-hidden="true" width="12" height="12" viewBox="0 0 14 14" stroke="currentColor" strokeWidth="1.6"><path d="M2 2l10 10M12 2L2 12" /></svg>
);

// Shown on a minimised window: a window outline to bring it back.
export const RestoreIcon = () => (
  <svg aria-hidden="true" width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="1.5" y="2.5" width="11" height="9" /><path d="M1.5 5.5h11" /></svg>
);

export const LogoIcon = ({ size = 24 }) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round">
    <circle cx="11" cy="11" r="4" /><circle cx="21" cy="11" r="4" />
    <path d="M4 26c1.2-5 4-7.5 7-7.5s5.8 2.5 7 7.5M14 26c1.2-5 4-7.5 7-7.5s5.8 2.5 7 7.5" />
  </svg>
);

export const ClockIcon = () => (
  <svg aria-hidden="true" width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="8" cy="8" r="6.5" /><path d="M8 4v4.3l2.8 1.7" /></svg>
);

export const PassIcon = () => (
  <svg aria-hidden="true" width="14" height="14" viewBox="0 0 14 14" stroke="currentColor" strokeWidth="2"><path d="M2 2l10 10M12 2L2 12" /></svg>
);

export const HeartIcon = ({ size = 18 }) => (
  <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 21s-7.5-4.6-9.5-9.3C1.2 8.4 3.3 5 6.6 5c2 0 3.4 1.1 4.1 2.4l1.3 1.9 1.3-1.9C14 6.1 15.4 5 17.4 5c3.3 0 5.4 3.4 4.1 6.7C19.5 16.4 12 21 12 21z" />
  </svg>
);

export const UndoIcon = () => (
  <svg aria-hidden="true" width="18" height="18" viewBox="0 0 20 20" {...line}><path d="M6 4L2.5 7.5 6 11" /><path d="M3 7.5h9a5 5 0 010 10H8" /></svg>
);

export const SkipIcon = () => (
  <svg aria-hidden="true" width="18" height="18" viewBox="0 0 20 20" fill="currentColor"><path d="M3 4l9 6-9 6zM13 4h3v12h-3z" /></svg>
);

// An ID card, for "full profile".
export const CardIcon = () => (
  <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" {...line}>
    <rect x="2" y="4" width="16" height="12" rx="1.5" /><circle cx="7" cy="9" r="2" />
    <path d="M4.5 14c.5-1.6 1.4-2.4 2.5-2.4s2 .8 2.5 2.4M12 8h4M12 11h3" />
  </svg>
);

export const CaretIcon = () => (
  <svg aria-hidden="true" width="12" height="8" viewBox="0 0 12 8" fill="currentColor"><path d="M0 0h12L6 8z" /></svg>
);

export const CheckIcon = () => (
  <svg aria-hidden="true" width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 6.5l2.5 2.5L10 3" /></svg>
);

export const LinkIcon = () => (
  <svg aria-hidden="true" width="14" height="14" viewBox="0 0 16 16" {...line} strokeWidth="1.6"><path d="M6.5 9.5l3-3M7 4.5l1.2-1.2a2.8 2.8 0 014 4L11 8.5M9 11.5l-1.2 1.2a2.8 2.8 0 01-4-4L5 7.5" /></svg>
);

// Dock icons: 40px, ink outlines over the desktop's pink, blue and cream.
const dock = { width: 40, height: 40, viewBox: '0 0 36 36', fill: 'none', stroke: '#1a1a1a', strokeWidth: 1.8, strokeLinejoin: 'round', 'aria-hidden': true };

export const DiscoverIcon = () => (
  <svg {...dock}>
    <rect x="10" y="4" width="20" height="26" rx="3" fill="#f3cfcd" transform="rotate(8 20 17)" />
    <rect x="6" y="6" width="20" height="26" rx="3" fill="#fbf8f3" /><circle cx="16" cy="15" r="4" fill="#a6d9e7" />
    <path d="M10 27c1-3 3.5-4.5 6-4.5s5 1.5 6 4.5" />
  </svg>
);

export const MatchesIcon = () => (
  <svg {...dock}>
    <path d="M18 31s-12-7.4-15-14.8C1 11 4.4 5.5 9.6 5.5c3.2 0 5.5 1.8 6.6 3.9L18 12l1.8-2.6c1.1-2.1 3.4-3.9 6.6-3.9 5.2 0 8.6 5.5 6.6 10.7C30 23.6 18 31 18 31z" fill="#f5b8c4" />
  </svg>
);

export const CrewIcon = () => (
  <svg {...dock}>
    <circle cx="12" cy="12" r="5" fill="#a6d9e7" /><circle cx="24" cy="12" r="5" fill="#f3cfcd" />
    <path d="M3 31c1.5-6 5-9 9-9s7.5 3 9 9z" fill="#a6d9e7" /><path d="M15 31c1.5-6 5-9 9-9s7.5 3 9 9z" fill="#f3cfcd" />
  </svg>
);

export const EventsIcon = () => (
  <svg {...dock}>
    <rect x="4" y="7" width="28" height="25" rx="3" fill="#fbf8f3" />
    <path d="M4 14v-4a3 3 0 013-3h22a3 3 0 013 3v4z" fill="#f5b8c4" />
    <path d="M11 4v6M25 4v6M20 21h7M9 27h18" strokeLinecap="round" />
    <rect x="9" y="18" width="7" height="5" fill="#a6d9e7" />
  </svg>
);

export const LeaderboardIcon = () => (
  <svg {...dock}>
    <rect x="13" y="13" width="10" height="19" fill="#f5b8c4" /><rect x="3" y="19" width="10" height="13" fill="#a6d9e7" />
    <rect x="23" y="23" width="10" height="9" fill="#f3cfcd" />
    <path d="M18 2.5l1.6 3.2 3.4.5-2.5 2.4.6 3.4-3.1-1.6-3.1 1.6.6-3.4-2.5-2.4 3.4-.5z" fill="#fbf8f3" />
  </svg>
);

export const ProfileIcon = () => (
  <svg {...dock}>
    <rect x="3" y="7" width="30" height="22" rx="3" fill="#fbf8f3" /><circle cx="12" cy="16" r="4" fill="#f5b8c4" />
    <path d="M6 25c1-3 3.3-4.3 6-4.3s5 1.3 6 4.3M21 13h8M21 18h8M21 23h5" />
  </svg>
);

export const DashboardIcon = () => (
  <svg {...dock}>
    <rect x="3" y="5" width="30" height="26" rx="3" fill="#fbf8f3" /><path d="M3 11h30" />
    <rect x="8" y="20" width="5" height="7" fill="#a6d9e7" /><rect x="15.5" y="15" width="5" height="12" fill="#f5b8c4" />
    <rect x="23" y="18" width="5" height="9" fill="#f3cfcd" />
  </svg>
);
