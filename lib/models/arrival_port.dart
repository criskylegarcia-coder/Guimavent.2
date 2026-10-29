// A tourist arrival point (e.g. Jordan Wharf, Buenavista Port) — offered on
// MapDirectionsShellScreen as a directions origin alternative to the
// user's live GPS position, for previewing travel time before actually
// arriving. Backed by the same arrival_port table the admin portal's
// check-in port dropdown uses (see AdminCheckinRepository.getPorts()), but
// kept as its own model/repository here rather than importing that one —
// that repository is admin-only plumbing and its ArrivalPort doesn't carry
// coordinates, which is the whole point of this one.
class ArrivalPort {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const ArrivalPort({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
