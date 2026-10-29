class ArrivalPort {
  final int portId;
  final String portName;
  final String municipality;
  final String description;
  final double latitude;
  final double longitude;

  ArrivalPort({
    required this.portId,
    required this.portName,
    required this.municipality,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory ArrivalPort.fromJson(Map<String, dynamic> json) {
    return ArrivalPort(
      portId: json['port_id'],
      portName: json['port_name'],
      municipality: json['municipality'] ?? '',
      description: json['description'] ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
    );
  }
}