# health-agent-applehealth-sync

iOS app that reads Apple HealthKit data and syncs it to an OpenClaw VPC database.

## What it syncs

- Running workouts (duration, distance, avg heart rate)
- VO2 max measurements

## Components

| Path | Description |
|---|---|
| `HealthSync/` | iOS app (Xcode project) |
| `receiver/` | TypeScript/Express HTTP server running on the VPC |

## Setup

### iOS app

1. Copy `HealthSync/HealthSync/Secrets.swift.template` → `Secrets.swift`
2. Fill in your VPC IP and API key
3. Open `HealthSync/HealthSync.xcodeproj` in Xcode
4. Build and run on your iPhone

### VPC receiver

```bash
cd receiver
npm install
API_KEY=your-key DB_PATH=/path/to/fitness.db npx ts-node server.ts
```

Runs on port 3000. Install as a systemd service for persistence.

## Credentials

`Secrets.swift` is gitignored — never commit it. It holds the VPC IP and API key.
