// Other hackathons, for the leaderboard's hackathon switcher. Each hackathon
// ranks its own crews: you can be in a different crew at every one, so ranks
// are never added up across them.
//
// The live one is this server's own (HACKATHON_NAME, scored from real check-ins
// and challenges). Past results are a fixed archive; members are matched to
// accounts by email, so the demo accounts have a history to show.

export const CURRENT_HACKATHON_ID = 'current';

const DEMO = ['web@crewmatch.dev', 'mobile@crewmatch.dev'];

function board(rows) {
  return rows.map(([name, points, memberEmails = []], i) => ({ id: `${name}`.toLowerCase().replace(/\W+/g, '-'), rank: i + 1, name, points, memberEmails }));
}

export const ARCHIVE = [
  {
    id: 'hackcampus-winter-2026',
    name: 'HackCampus Winter',
    status: 'upcoming',
    startsAt: '2026-12-12T09:00:00+05:30',
  },
  {
    id: 'codesprint-pune-2026',
    name: 'CodeSprint Pune',
    status: 'ended',
    endedAt: '2026-10-18T18:00:00+05:30',
    crews: board([
      ['Async Avengers', 410], ['Ctrl Alt Elite', 360], ['Lambda Lions', 330], ['Bit Flippers', 290],
      ['Kernel Panic', 270], ['Byte Me', 250, DEMO], ['Hello World', 210], ['Null Island', 180],
      ['Stack Overflowers', 150], ['Git Gud', 120],
    ]),
  },
  {
    id: 'devfest-hack-mumbai-2026',
    name: 'DevFest Hack Mumbai',
    status: 'ended',
    endedAt: '2026-08-23T18:00:00+05:30',
    crews: board([
      ['Overclocked', 520], ['Segfault', 480], ['Cache Me', 450], ['Deep Dish', 400], ['Pull Request', 380],
      ['Sudo Make', 355], ['Tab Hoarders', 340], ['Big O', 320], ['Hot Reload', 300], ['Dark Mode', 285],
      ['Merge Kings', 260], ['Stack Smashers', 230, DEMO], ['Ping Pong', 200], ['Code Red', 170],
    ]),
  },
];
