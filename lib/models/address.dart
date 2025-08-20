// Minimal Address model for tests and profile writes
class Address {
  final String state;
  final String district;
  final String mandal;
  final String villageCity;

  Address({
    required this.state,
    required this.district,
    required this.mandal,
    required this.villageCity,
  });

  Map<String, dynamic> toMap() => {
    'state': state,
    'district': district,
    'mandal': mandal,
    'villageCity': villageCity,
  };
}
