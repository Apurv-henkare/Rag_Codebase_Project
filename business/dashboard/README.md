# Ball game dashboard (React)

A one-page React dashboard: what players love and hate about ball games, game by game, where players are, money, trends and design choices.
All of its data comes from one file, `src/data.json`, built from `../data/processed/` and the HPC model outputs in `../data/model_outputs/`.

```
npm install
npm run dev        # http://localhost:5173
npm run build      # static site in dist/, can be opened from any web server
npm run data       # rebuild src/data.json after the data or the models change (runs ../scripts/dashboard_data.py)
```

Charts are hand-built in HTML/SVG (`src/charts.jsx`), so the app needs no chart library. Every chart has a hover/focus tooltip and a table view.
Colours: praise is blue, complaints are orange, plain amounts are aqua. They were checked for colour-blind separation in light and dark mode.
A sidebar lists the sections and shows one at a time (the address keeps it, e.g. `#games`). Sections already opened keep a ring, and the open one gets the red ball.
Each section has its own looping bouncing-ball banner (`src/Bouncer.jsx`), and the hero bounce loops too. The red ball is decoration only. The page follows the system light/dark setting, and the hero animation is skipped when reduced motion is on.
Fonts (Unbounded, Atkinson Hyperlegible Next) load from Google Fonts; without a connection the page falls back to system fonts.
