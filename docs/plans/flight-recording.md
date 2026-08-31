# Plan: on-device flight recording

**Status:** Designed 2026-08-31, not yet implemented. Depends on the iOS app existing first (roadmap
item 3 in `docs/architecture-brief.md`) - this doc can be reviewed and merged ahead of that, but
implementation waits for it, same as roadmap item 4 already noted. Companion doc:
[`hobbs`'s `docs/plans/flight-track-derivation.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/plans/flight-track-derivation.md)
covers what the backend does with the uploaded track.

## Context

`docs/architecture-brief.md`'s roadmap item 4, GPS-recording-to-logbook, is the MVP-completing
feature: William hits "record" before a flight, the app tracks it, and it comes back as a draft
logbook entry to confirm. `hobbs`'s `CLAUDE.md` had already decided the shape of background tracking
itself (2026-08-24, recorded in project memory): `flutter_background_geolocation`, adaptive accuracy,
offline-first local buffering, GPS recording always optional. This doc is the next layer down - what
runs in real time on the device to make "adaptive accuracy" actually adaptive, and how to validate
any of it without waiting for William's next flight, which is only monthly.

## Confirmed decisions

- **The client runs a thin, real-time phase classifier whose only job is picking the GPS sampling
  interval - it is not the authoritative record of what phase the flight is in.** See the backend
  doc's reasoning for why this is deliberately a second, simpler thing rather than a shared state
  machine: Dart and Java share no code, so two full implementations kept in lockstep is pure drift
  risk. The client's classifier only needs three buckets - `ground-slow`, `ground-fast`, `airborne` -
  off raw GPS speed (barometer rate-of-change as a secondary signal where available). Being wrong for
  a few seconds costs a slightly denser or sparser track segment, never a wrong logbook entry, so it
  can be cheap and approximate in a way the backend's classifier doesn't get to be.

- **Sampling interval by bucket, tuned around circuit work specifically, not just cruise flight.**
  Roughly: `ground-slow`/stationary - sparse (30-60s) or motion-triggered off the accelerometer;
  `ground-fast`/taxi - 1-2s; low-altitude/high-rate-of-change (takeoff roll, landing roll, and
  crucially the whole circuit pattern, not just "airborne") - the fastest rate
  `flutter_background_geolocation`'s adaptive-accuracy mode supports; only relax to a slower rate
  (5-10s) once genuinely in cruise beyond the pattern. This is a deliberate correction on the naive
  "airborne = relax sampling" framing: William grinding touch-and-goes spends most of a session in
  the pattern at low altitude, exactly where dense sampling matters most for the backend to get
  touch-and-go detection right - relaxing sampling the moment the wheels leave the ground would throw
  away the data the whole feature depends on for his use case specifically.

- **The device's barometric pressure sensor feeds the local classifier as a secondary signal where
  available.** iOS: `CMAltimeter`. Android: `Sensor.TYPE_PRESSURE`. Relative altitude change from a
  pressure sensor is materially cleaner than GPS vertical speed at low altitude and short timescales -
  exactly the touch-and-go case. Optional, not required: a device/OS without barometer access still
  works off GPS speed alone, same fallback posture as everywhere else in this design.

- **Raw points, including barometer/accelerometer readings where available, are buffered locally and
  uploaded as-is - the client never uploads its own phase classification.** Consistent with the
  existing offline-first decision (local SQLite during the flight, synced once landed and back on
  connectivity - airfields often have poor signal). The backend doc's per-point JSON schema
  (`barometricAltitudeM`, `verticalAccelerationG`, both optional) is what gets populated from these
  readings on upload.

- **A car-based test/dry-run mode, to close the feedback loop between real flights.** William flies
  roughly monthly - too slow a loop to validate "does the sampling-rate logic behave sensibly" or
  "does the recording survive the app being backgrounded for two hours" only against real flights.
  Decided: the recording feature itself needs no special test mode - a car drive genuinely exercises
  the real code path (background location, local buffering, upload on reconnect) end-to-end, just
  with speed/altitude profiles that don't match a real flight. What that gets you and doesn't:
  - **Validates:** background recording survives real-world conditions (screen off, app backgrounded,
    a poor-signal patch), local buffering and sync-on-reconnect actually work, the `ground-slow`/
    `ground-fast` sampling-rate switching responds sensibly to real speed changes, battery drain over
    a multi-hour session is measurable.
  - **Doesn't validate:** the `airborne` bucket at all (a car never leaves the ground), barometric
    altitude behaviour (a car's pressure-sensor signal doesn't resemble a climb/descent), or anything
    in the backend's phase-classification/derivation logic - that needs a real `FlightTrack`, since a
    car drive never produces a `takeoffRoll`→`airborne` transition to classify.
  - No new recording mode or fixture-data feature to build for this - it's a way of *using* the
    already-planned recording feature to get a faster feedback loop on the parts of it a car drive can
    actually exercise, not a separate thing this doc needs to scope work for.

## Expected result

- A new, small real-time classifier (tentative name TBD at implementation time) consuming the
  `flutter_background_geolocation` location stream, exposing the current sampling bucket to both the
  plugin's accuracy config and a live status indicator on the recording screen.
- The recording screen shows the client's own live phase guess (e.g. "Taxiing" / "Airborne") purely as
  in-flight feedback - explicitly not the source of truth once the track is uploaded and processed
  server-side (see backend doc).
- Barometer readings (where the platform exposes them) and accelerometer peaks are captured alongside
  each GPS point and included in the local buffer / upload payload, matching the backend's extended
  `FlightTrack` point schema.

## Explicitly out of scope

- **Any phase-classification logic beyond the three-bucket sampling-rate decision.** No
  touch-and-go/landing detection, no departure/arrival derivation - all backend-side, see the
  companion doc.
- **A dedicated simulated-flight/fixture-data test mode.** Considered and rejected above - a real car
  drive exercises the actual code path more faithfully than synthetic data would, for the parts a
  ground-based test can exercise at all.
- **The iOS app itself.** This doc assumes it exists (`docs/architecture-brief.md` roadmap item 3);
  building it is its own, prior body of work.
- **Wiring the derived draft entry into the create-flight-entry screen's pre-fill, once `hobbs` gains
  the `POST /flight-track/{id}/derive` endpoint from the companion doc.** Separate, later UI work.
- **Battery-usage tuning beyond the bucket-based sampling rates above.** If a real flight or car test
  shows the fast-sampling pattern-work rate draining the battery faster than a multi-hour session can
  tolerate, that's a follow-up tuning pass against real data, not guessed thresholds now.
