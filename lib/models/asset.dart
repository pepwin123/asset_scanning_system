class Asset {
  final int? id;
  final String uniqueCode;
  final String itemName;
  final String empId;
  final String empName;
  final bool isCompanyProperty;

  Asset({
    this.id,
    required this.uniqueCode,
    required this.itemName,
    required this.empId,
    required this.empName,
    required this.isCompanyProperty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unique_code': uniqueCode,
      'item_name': itemName,
      'emp_id': empId,
      'emp_name': empName,
      'is_company_property': isCompanyProperty ? 1 : 0,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      uniqueCode: map['unique_code'],
      itemName: map['item_name'],
      empId: map['emp_id'],
      empName: map['emp_name'],
      isCompanyProperty: map['is_company_property'] == 1,
    );
  }
}
