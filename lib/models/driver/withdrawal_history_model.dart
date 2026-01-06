class WithdrawalHistoryModel {
  final int id;
  final double amount;
  final String status;
  final String createDate;
  final String? reasonCancel;

  WithdrawalHistoryModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.createDate,
    this.reasonCancel,
  });

  factory WithdrawalHistoryModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalHistoryModel(
      id: json['id'] ?? 0,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] ?? '',
      createDate: json['createdDate'] ?? '',
      reasonCancel: json['reasonCancel'],
    );
  }

}