class Asset {
  final int? id;
  final String assetId;
  final String employeeId;
  final String employeeName;
  final String model;
  final String serialNumber;

  Asset({
    this.id,
    required this.assetId,
    required this.employeeId,
    required this.employeeName,
    required this.model,
    required this.serialNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_id': assetId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'model': model,
      'serial_number': serialNumber,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      assetId: map['asset_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      model: map['model'] ?? '',
      serialNumber: map['serial_number'] ?? '',
    );
  }
}
