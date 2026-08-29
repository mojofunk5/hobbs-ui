/// Formatting shared across the flight-entry screens - factored out once a third screen
/// (ListFlightEntriesScreen) needed the same date/minutes formatting as
/// CreateFlightEntryScreen/ViewFlightEntryScreen.
String formatDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Deliberately not converted to the viewer's local timezone - departureTime/arrivalTime are
/// wall-clock times at the departure/arrival airfield (see FlightEntry's Javadoc), not "when this
/// happened in whatever timezone the viewer's device is set to".
String formatTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// H:MM, not a float hours value - matches the backend's own storage convention (whole minutes,
/// converted to H:MM only at the presentation edge - see FlightEntry's Javadoc).
String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '$hours:${remainder.toString().padLeft(2, '0')}';
}
