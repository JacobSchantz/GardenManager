# GitHub Listener

Listens to GitHub webhooks and triggers actions based on events.

## Setup

```bash
cd github-listener
npm install
```

## Run

```bash
npm start
```

Server runs on port 8765 by default.

## Webhook URL

`https://your-server.com/webhook`

## Environment Variables

- `PORT` - Server port (default: 8765)
- `GITHUB_SECRET` - GitHub webhook secret (optional)

## Events Handled

- `push` - Code pushed to repository
- `pull_request` - PR opened/updated
- `release` - New release published

## Currently Configured For

- ATG Monorepo: triggers iOS build on push to Peaches branch
