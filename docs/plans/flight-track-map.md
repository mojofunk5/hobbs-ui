# Plan: show a `FlightTrack`'s route on a map

**Status:** Designed 2026-08-31, not yet implemented. Depends on GPS recording actually landing
first (see "Depends on" below) - this doc is reviewable/mergeable now, implementation isn't
scheduled yet. Companion doc:
[`hobbs`'s `docs/plans/flight-track-map-endpoint.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/plans/flight-track-map-endpoint.md)
covers the backend read endpoint this widget consumes.

## Context

Once GPS recording (`docs/plans/flight-recording.md`) and server-side derivation (`hobbs`'s
`docs/plans/flight-track-derivation.md`) exist, a `FlightEntry` created from a recorded flight has a
`flightTrackId` - `FlightEntryDto` already carries the field. `ViewFlightEntryScreen` currently has
nothing to show for it beyond the id itself. Being able to see the actual flown route - especially
the circuit pattern shape, given how much of William's flying is touch-and-go work at Sherburn - is
the obvious payoff of having recorded a track at all.

Two questions had to be settled before this could be designed: which map library/tile provider (and
whether that means a Google Cloud billing account for a two-person family app), and what happens on
the vast majority of flight entries that have no track at all.

## Confirmed decisions

- **`flutter_map` + OpenStreetMap tiles, not Google Maps.** `flutter_map` is Leaflet's Flutter
  equivalent - same `Polyline`/`Marker` primitives, and it's already the de facto standard for
  Flutter apps that want a map without a cloud billing account. Google Maps' JS/Flutter SDK would
  work equally well technically, but needs a Google Cloud project with billing enabled (even though
  usage here would sit comfortably inside the free monthly credit) - there's no reason to take on API
  key management and a billing account for a feature two people will use, when a no-key, no-account
  alternative does the same job. No new backend infrastructure either way - tiles are fetched
  client-side directly from the tile provider, not proxied through `hobbs`.
- **New widget, `FlightTrackMap`**, taking a `FlightTrackDto` (see companion doc) and rendering: the
  route as a `Polyline` (`flutter_map`'s built-in), start/end `Marker`s, and the map's initial camera
  fit to the track's lat/lon bounding box (`flutter_map`'s `CameraFit.bounds`) rather than a fixed
  zoom - a short circuit-only flight and a long cross-country need very different default zooms.
- **`ViewFlightEntryScreen` renders `FlightTrackMap` only when `flightTrackId` is non-null; nothing
  otherwise.** `flightTrackId` is nullable and GPS recording is explicitly optional
  (`hobbs`'s `CLAUDE.md`) - the overwhelming majority of entries (every manually-entered flight) will
  never have a track, and that's a completely normal entry, not a degraded one. No placeholder "no
  route recorded" map or empty state - the map section simply isn't part of the layout for those
  entries, same as any other optional field on that screen.
- **The screen fetches `GET /flight-track/{id}` itself, on demand, not as part of the existing
  `FlightEntry` fetch.** Keeps `GET /flight-entry/{id}`'s response shape and cost unchanged for the
  common (no-track) case; only entries that actually have a track pay for the extra round trip, and
  only when that screen is actually opened.
- **No airspace/aeronautical chart overlay for this first cut.** OpenAIP's free VFR chart tiles would
  be a genuinely useful later addition (airspace boundaries mean more to a PPL student than a bare
  street map), but that's a separate tile-layer-toggle feature on top of a working route-on-a-map -
  not needed to ship the core "see where I flew" payoff. Noted for later, not designed here.

## Expected result

- `flutter_map` and `latlong2` added to `pubspec.yaml`.
- New widget `lib/widgets/flight_track_map.dart` (`FlightTrackMap`), taking a `FlightTrackDto`.
- A matching Dart model/deserializer for the companion doc's `FlightTrackDto`/`FlightTrackPointDto`
  response shape, plus a `flightTrack(id)` method on the API client, mirroring the existing pattern
  for other GET-by-id resources.
- `ViewFlightEntryScreen` fetches and conditionally renders `FlightTrackMap` as described above.

## Depends on

- **`hobbs`'s `GET /flight-track/{id}`** (companion doc) - not built yet.
- **GPS recording and derivation actually being implemented** (`docs/plans/flight-recording.md`,
  `hobbs`'s `docs/plans/flight-track-derivation.md`, both designed, neither built - gated on the iOS
  app existing per `docs/architecture-brief.md`'s roadmap item 3). There's no real `FlightTrack` data
  to show on a map until that lands, and no way to exercise this widget against anything but
  hand-built fixture data before then.

## Explicitly out of scope

- **Time-scrubbable replay or altitude/speed graphs.** Mirrors the companion doc's equivalent
  exclusion - the backend endpoint doesn't return per-point timestamps for this first cut, so replay
  isn't buildable yet regardless.
- **An aeronautical chart tile layer.** See "Confirmed decisions" above - a real but separate later
  feature.
- **Editing or annotating the track from the map (e.g. manually correcting a mismatched airfield
  match).** Any correction happens through the existing create/edit-entry form fields, not the map
  view - the map here is read-only, display-only.
- **The backend endpoint, simplification, and response shape.** See the companion `hobbs` doc.
