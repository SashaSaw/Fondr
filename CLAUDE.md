# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fondr is a couples app — two partners pair up and share lists, calendar availability, vault facts (partner preferences), significant dates, and swipe sessions to decide on date ideas. It has a **SwiftUI iOS client** (`Fondr/`) and a **NestJS TypeScript backend** (`backend/`).

## Build & Run Commands

### Backend (NestJS + PostgreSQL + Prisma)
```bash
cd backend
npm install
npm run start:dev          # Watch mode with hot reload
npm run build              # Compile TypeScript
npm run start:prod         # Production (node dist/main)
npm run prisma:generate    # Regenerate Prisma client after schema changes
npm run prisma:migrate     # Create + run migrations (dev)
npm run prisma:migrate:deploy  # Deploy migrations (prod/Docker)
```
Backend runs on port 3000. Requires `.env` (see `.env.example`): DATABASE_URL, JWT_SECRET, APPLE_CLIENT_ID, APNS credentials, TMDB_API_KEY, S3 storage config.

### iOS App
- Open `Fondr.xcodeproj` in Xcode, Cmd+R to build and run
- Bundle ID: `com.incept5.Fondr`, iOS 18.0+, Swift 5.9
- API base URL hardcoded in `Fondr/Services/APIClient.swift`

## Architecture

### Data Flow
```
SwiftUI Views ← @Observable Services ← APIClient (REST) + WebSocketManager (real-time)
                                              ↕                      ↕
                                       NestJS Controllers → Services → Prisma/PostgreSQL
                                                              ↓
                                                    EventEmitter → RealtimeGateway → WebSocket broadcast
                                                              ↓
                                                    NotificationsService → APNs (when user offline)
```

### iOS Client (`Fondr/`)

**State management**: `AppState` (in `Fondr/App/AppState.swift`) holds all service instances. It's `@Observable` and injected via `@Environment`. Each service is also `@Observable` — views reactively update when service properties change.

**ContentView routing** (`Fondr/App/ContentView.swift`): The top-level router. Checks `isReady → isAuthenticated → isPaired → needsOnboarding` to show the correct screen. Also handles scenePhase changes (foreground refresh), listener setup via onChange, and local notification scheduling.

**Key services** (all in `Fondr/Services/`):
- `AuthService` — Apple Sign-In, email auth, JWT token management, user caching to UserDefaults for instant startup
- `APIClient` — Singleton REST client. Auto-refreshes expired tokens on 401 via `RefreshCoordinator` actor (serializes concurrent refresh attempts). Generic `get/post/patch/delete` methods
- `TokenStore` — Keychain-backed storage for accessToken, refreshToken, userId
- `WebSocketManager` — WSS connection with event handler registry (`on<T>(_ event:, handler:)`), auto-reconnect, ping/pong heartbeat
- `PairService`, `ListService`, `CalendarService`, `SessionService`, `OurStoryService` — Each follows the same pattern: `startListening(pairId:)` fetches initial data via REST then registers WebSocket handlers for real-time updates

**Adding a new real-time feature on iOS**: Create a service with `startListening`/`stopListening`, register WebSocket handlers with `WebSocketManager.shared.on("entity:created")`, call `startListening` from `AppState.setupXListener()`, trigger that from ContentView's `onChange(of:)`.

### Backend (`backend/`)

**NestJS module structure**: Each feature is a module in `backend/src/` — `auth/`, `users/`, `pairs/`, `vault/`, `lists/`, `sessions/`, `calendar/`, `our-story/`, `realtime/`, `notifications/`, `storage/`, `tmdb/`.

**Event-driven real-time**: Services emit domain events via `EventEmitter2` (e.g., `this.events.emit('item.created', { pairId, item })`). `RealtimeGateway` (`backend/src/realtime/realtime.gateway.ts`) listens to all events and broadcasts them to WebSocket clients in the pair. `NotificationsService` sends APNs push when the recipient is offline.

**Auth**: JWT access tokens (30-day expiry), UUID refresh tokens stored in DB (not rotated on refresh). Apple Sign-In verified server-side. `PairMemberGuard` protects all pair-scoped endpoints.

**Database schema**: `backend/prisma/schema.prisma` — User, Pair, SharedList, ListItem, SwipeSession, AvailabilitySlot, CalendarEvent, SignificantDate, VaultFact. All pair-linked data cascades on pair deletion.

**Adding a new backend feature**: Create a NestJS module with controller + service + DTOs. Emit events from the service. Add `@OnEvent` listeners in `RealtimeGateway` and `NotificationsService`. Add the module to `AppModule` imports.

### View Hierarchy (`Fondr/Views/`)
Auth, Pairing, OurStory (vault/significant dates), Lists (shared lists + items), Swipe (swipe sessions), Calendar (availability + events), Settings, Main (tab bar)

## Technical Debt & Future Work

See [TODO.md](TODO.md) for tracked items including GDPR compliance gaps, security hardening, and App Store submission blockers.

## Key Conventions

- All iOS models are `Codable`, `Identifiable`, and `Sendable` (in `Fondr/Models/`)
- WebSocket events follow `entity:action` naming (e.g., `item:created`, `pair:updated`)
- Backend emits events as `entity.action` (dots), gateway converts to `entity:action` (colons) for clients
- All pair-scoped API routes are `/pairs/:pairId/...` protected by `PairMemberGuard`
- Date strings use `yyyy-MM-dd` format, times are stored/transmitted in UTC
- `CalendarService` handles UTC↔local timezone conversion for display
