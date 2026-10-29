// A tourist's pre-arrival registration, filled out across the 3-step
// registration form. passCode/validFrom/validTo start out null and only
// get filled in once RegistrationRepository.submit() succeeds.
class Registration {
  final String fullName;
  final String nationality;
  final DateTime dateOfBirth;
  final String gender;
  final String email;
  final String mobileNumber;
  final DateTime dateOfArrival;
  final String portOfEntry;
  final DateTime dateOfDeparture;
  final String travelingWith;
  final String purposeOfVisit;
  final List<String> municipalitiesToVisit;
  final String? passCode;
  final DateTime? validFrom;
  final DateTime? validTo;

  const Registration({
    required this.fullName,
    required this.nationality,
    required this.dateOfBirth,
    required this.gender,
    required this.email,
    required this.mobileNumber,
    required this.dateOfArrival,
    required this.portOfEntry,
    required this.dateOfDeparture,
    required this.travelingWith,
    required this.purposeOfVisit,
    required this.municipalitiesToVisit,
    this.passCode,
    this.validFrom,
    this.validTo,
  });

  // Used to stamp in passCode/validFrom/validTo after a successful submit,
  // without needing to re-type every other field.
  Registration copyWith({
    String? passCode,
    DateTime? validFrom,
    DateTime? validTo,
  }) {
    return Registration(
      fullName: fullName,
      nationality: nationality,
      dateOfBirth: dateOfBirth,
      gender: gender,
      email: email,
      mobileNumber: mobileNumber,
      dateOfArrival: dateOfArrival,
      portOfEntry: portOfEntry,
      dateOfDeparture: dateOfDeparture,
      travelingWith: travelingWith,
      purposeOfVisit: purposeOfVisit,
      municipalitiesToVisit: municipalitiesToVisit,
      passCode: passCode ?? this.passCode,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
    );
  }
}
