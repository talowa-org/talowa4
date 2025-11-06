// Minimal Address model for tests and profile writes
class Address {
  final String state;
  final String district;
  final String mandal;
  final String villageCity;
  final String? stateCode;
  final String? districtCode;
  final String? mandalCode;
  final String? villageCode;

  Address({
    required this.state,
    required this.district,
    required this.mandal,
    required this.villageCity,
    this.stateCode,
    this.districtCode,
    this.mandalCode,
    this.villageCode,
  });

  Map<String, dynamic> toMap() => {
    'state': state,
    'district': district,
    'mandal': mandal,
    'villageCity': villageCity,
    'stateCode': stateCode,
    'districtCode': districtCode,
    'mandalCode': mandalCode,
    'villageCode': villageCode,
  };
}

