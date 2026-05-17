# Hundred Eight (108)

Online multiplayer card game **108**: rooms, invites, real-time play with **Hotwire (Turbo + Stimulus)** and **Solid Cable**, backed by **PostgreSQL 16**.

---

## What this project is

- A **Rails 8.1** web app where players create or join **rooms**, share **invite links**, and play **108** in real time across multiple **rounds** (2–5 players per room).
- **Game state is authoritative on the server**: hands are never sent to other clients; only the current player can act; moves are validated in **service objects** (`CardPlayService`, `SevenResponseService`, `RoundStarterService`, etc.).
- **UUID** primary keys, **Turbo Streams** for live lobby/table updates, **Action Cable** (`RoomChannel`) for online presence, and **Solid Cable** in development/production for durable Cable storage.
- **Move history** per round (plays, suit choices, six/seven penalties as “took N cards”) and a **round archive** page with scoring breakdowns and remaining cards.

---

## Game rules (summary)

Implementation detail: `lib/game/` (pure rules) and `app/services/` (turn flow, DB, broadcasts).

### Deck and basic play

- **Deck**: 36 cards — ranks `6 7 8 9 10 jack queen king ace` × four suits.
- **Turn**: play a card that matches **rank** or **suit** of the top discard (or any **Queen**). After a **Queen**, the player chooses the **required suit** for the next play.
- **Optional draw**: once per turn you may draw one card from the deck; you may **pass** after drawing (or when the deck cannot give a card).
- **Round start**: the previous round’s **loser** is first in turn order. The exposed center card may trigger opening effects (six, seven, eight, ace, queen) via `Game::OpeningStarter`.

### Special cards

| Card | Effect |
|------|--------|
| **6** | Previous active player draws **1** (shown in move history). With **2** players still in the round, the six player keeps the turn; with **3+**, turn advances to the next seat after the six player. |
| **7** | Starts a **seven response** chain: each next player may **stack another 7** or **take** penalty cards, then play continues around the table. **2 players**: take is always **2** cards. **3+ players**: take is **2 × (sevens in the current chain)** — not older sevens left on the pile from a previous chain. Taking ends your turn; the **next active seat** plays (not necessarily the chain root). If you **go out** on a 7 with others still holding cards, you leave the round but the **seven chain must still be resolved**. |
| **8** | **Eight follow-up**: same player may chain **8 → 8 → …** or play **any Queen** or a **same-suit** card on the top discard; that closes the chain and ends the turn. No “close from deck” — only from hand. |
| **Queen** | Choose the **required suit** for the next player. |
| **Ace** | Skips the next seat (**2** players: same player plays again; **3+**: skip one seat). Playing an ace as your **last** card enters **ace tail**: draw from the deck (as needed) and/or play matching cards from hand, then **pass** when allowed. |

### Multi-player rounds (3–5 players)

- The **first player to empty their hand** is **out** for that round (recorded as round winner for scoring) but the round **continues** until at most one player still holds cards.
- Players who are **out** skip turns; **seven** / **six** penalties target the correct **active** seats.
- When only one player still has cards, the round ends and scores are applied.

### Two-player rounds

- Emptying your hand **ends the round** immediately (subject to seven penalties when finishing on a 7).
- Seven take / stack rules use the **2-card** penalty (not multiplied by stacked sevens count).

### Scoring and elimination

- **Round score**: sum of card values left in hand (see `Game::ScoreCalculator`).
- **Queen of Hearts** as the **winning play** (last card on the pile): **−40** bonus on that player’s **cumulative** total (floor 0).
- **Over 108** cumulative → player **eliminated**; **exactly 108** → total reset to **0**.
- Room **game over** when at most one non-eliminated player remains.

### Where to read the code

| Topic | Primary files |
|-------|----------------|
| Legal plays | `lib/game/rules.rb` |
| Seven chains | `lib/game/seven_chain.rb`, `SevenResponseService` |
| Plays / phases | `CardPlayService`, `AceTailService`, `TurnOptionService` |
| Going out | `RoundHandEmptyService`, `RoundFinisher` |
| Opening center card | `lib/game/opening_starter.rb` |
| History labels | `CardPlayRecorder`, `MoveHistoryHelper` |
| Archive UI data | `RoundArchiveHelper`, `GET /rooms/:id/archive` |

---

## Tech stack

| Layer | Choice |
|--------|--------|
| Runtime | Ruby **3.3+** locally; **4.0.4** in `Dockerfile` |
| Framework | Rails **8.1.3** |
| DB | PostgreSQL **16** |
| Realtime | Turbo Streams + Solid Cable + `RoomChannel` (presence) |
| CSS | Tailwind (tailwindcss-rails) |
| JS | Importmap, Stimulus |
| Jobs | Solid Queue (optional locally via `bin/jobs`) |
| Tests | RSpec (**220+** examples), FactoryBot, Capybara (request, service, model, helper, channel specs) |

---

## Prerequisites

- **Ruby** (see `.ruby-version`; **3.3.11** is the default local pin so `bundle install` works out of the box).
- **Bundler** 2.x.
- **Docker Desktop** (or Docker Engine + Compose plugin) for **PostgreSQL** via `docker-compose.yml`.
- **Bash** 4+ (the `Makefile` uses `pipefail` and brace expansion).

---

## Environment variables

Used by `config/database.yml` (ERB) and Postgres clients:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DB_HOST` | `127.0.0.1` | Primary + cable DB host when using Docker-mapped Postgres |
| `DB_USER` | `postgres` | DB username |
| `DB_PASSWORD` | `postgres` | DB password |
| `PGHOST` / `PGUSER` / `PGPASSWORD` | same as above | Libpq / `rails db` CLI |

Override when needed, e.g. `DB_HOST=db make test` inside a Compose network.

---

## Makefile (quick reference)

Run **`make`** or **`make help`** for the list with descriptions.

| Target | What it does |
|--------|----------------|
| **`help`** | Default — prints all targets (this table is the short version). |
| **`start`** | `docker compose up -d`, wait for Postgres, `rails db:prepare`, then **`bin/dev`** (web + Tailwind; blocking). |
| **`dev`** | **`bin/dev`** only — use when Postgres is already up. |
| **`stop`** | `docker compose down` (stops Postgres container). |
| **`clean`** | `docker compose down --remove-orphans`. |
| **`reset`** | Ensures Postgres is up, then **`rails db:reset`** (drops & recreates DBs — local data loss). |
| **`lint`** | `bundle exec rubocop` (Omakase config). |
| **`lint-ci`** | RuboCop with **`--format github`** (CI annotations). |
| **`test`** | `db:test:prepare` + **`rspec`**. |
| **`check`** | **`lint`**, **`test`**, **`brakeman`**, **`bundler-audit`**, **`importmap audit`**. |

Underlying targets: `docker-up`, `db-prepare`, `brakeman`, `bundler-audit`, `importmap-audit`, `security` (Brakeman + bundler-audit).

---

## How to start (first time)

1. **Clone** and install gems:

   ```bash
   bundle install
   ```

2. **Start everything** (Postgres in Docker + migrations + Rails + Tailwind):

   ```bash
   make start
   ```

   - Opens **http://localhost:3000** (default Puma port).
   - Stop the Rails process with **Ctrl+C** in that terminal.
   - Stop Postgres with **`make stop`** when finished.

3. **Create an account** (`/registration/new`), create a **room**, generate an **invite link**, join with a second browser/profile, and **Start game** from the lobby when **2–5** players are seated.
4. During play, open **move history** on the table; after rounds complete, use **Round archive** on the room page.

### Without Make

```bash
docker compose up -d
# wait for Postgres, then:
DB_HOST=127.0.0.1 DB_USER=postgres DB_PASSWORD=postgres bin/rails db:prepare
bin/dev
```

### Solid Queue (optional)

Process background jobs locally:

```bash
bin/jobs
```

(`Procfile.dev` mentions this; you can run it in a second terminal.)

---

## Quality gates

```bash
make test       # db:test:prepare + rspec (uses DB_HOST from Makefile)
make check      # rubocop + rspec + brakeman + bundler-audit + importmap audit
make lint-ci    # CI-style RuboCop output
```

Specs cover services, `lib/game`, models, helpers, Action Cable, and HTTP endpoints for auth, game actions, and host controls (`spec/requests/`).

---

## Docker (production image)

- **`Dockerfile`**: multi-stage build; **`ARG RUBY_VERSION=4.0.4`** for production alignment.
- **`docker-compose.yml`**: local **PostgreSQL 16** only; the Rails app runs on the host via `make start` / `bin/dev` unless you extend Compose with a `web` service.

Build production image (example):

```bash
docker build -t hundred-eight .
```

---

## Project layout (where logic lives)

| Path | Role |
|------|------|
| `app/services/` | Game and room workflows (transactions, `RoomBroadcaster`). Key: `CardPlayService`, `SevenResponseService`, `RoundHandEmptyService`, `RoundStarterService`, `RoundFinisher`, `AceTailService`, `TurnOptionService`, `DrawCardService`, `EliminationService`. |
| `lib/game/` | Pure rules: `Card`, `Deck`, `Rules`, `SevenChain`, `OpeningStarter`, `ScoreCalculator`. |
| `app/queries/` | Read-side helpers (`RoomPlayersQuery`, `ReconnectStateQuery`). |
| `app/helpers/` | `MoveHistoryHelper`, `RoundArchiveHelper`, `CardsHelper`, `ApplicationHelper` (player panel cache busting). |
| `app/views/rooms/` | Lobby, table, player panel (per-user hand), move history, between-rounds, archive, Turbo partials. |
| `app/channels/` | `RoomChannel` (presence + online flags), `ApplicationCable::Connection` (session cookie). |
| `app/controllers/rooms_controller.rb` | Play, seven take, suit, ace tail, draw/pass, host start/next round, invite, archive. |
| `spec/` | Model, service, lib, helper, channel, and request specs; system spec for landing. |

### HTTP game actions (member routes on `rooms`)

| Method | Route | Purpose |
|--------|--------|---------|
| `POST` | `play` | Play a card from hand |
| `POST` | `seven_take` | Take penalty cards during `seven_response` |
| `POST` | `suit` | Choose suit after a Queen |
| `POST` | `ace_tail_draw` / `ace_pass` | Ace follow-up draw or pass |
| `POST` | `optional_draw` / `turn_pass` | Draw once or pass when stuck |
| `POST` | `start` / `next_round` | Host starts game or next round |
| `POST` | `remove_player` | Host removes guest (lobby only) |
| `POST` | `create_invite` | Host generates invite token |
| `GET` | `archive` | Completed rounds with scoring breakdown |
| `GET` | `player_panel` | Turbo frame: current player’s hand only |

---

## Troubleshooting

- **`connection refused` to Postgres**: run `docker compose ps`, then `make docker-up` or `make start`.
- **Cable / Turbo oddities in console**: Solid Cable runs in the **web** process; trigger updates from a request or the in-browser console, not only a plain `rails console` terminal.
- **Port 5432 already in use**: change the host port mapping in `docker-compose.yml` and set `DB_HOST` / `PGHOST` accordingly.

---

## License

Add your license here (repository default is unset).
