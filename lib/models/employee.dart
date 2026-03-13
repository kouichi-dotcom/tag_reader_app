/// 担当者（[担当者台帳] 取得用）
class Employee {
  const Employee({
    required this.employeeCode,
    required this.employeeName,
  });

  final int employeeCode;
  final String employeeName;

  static Employee fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeCode: (json['employeeCode'] as num).toInt(),
      employeeName: json['employeeName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeCode': employeeCode,
        'employeeName': employeeName,
      };
}
