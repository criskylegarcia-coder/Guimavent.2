import '../models/arrival_port.dart';

// The contract MapDirectionsShellScreen depends on for the origin picker's
// port list. Screens must only ever import THIS file, never
// SupabaseArrivalPortRepository directly — mirrors the pattern used
// throughout lib/repositories/.
abstract class ArrivalPortRepository {
  Future<List<ArrivalPort>> getPorts();
}
