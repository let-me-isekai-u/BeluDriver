/// Client feedback only; the server must recheck balance and bank details.
String? validateWithdrawal({
  required String amountText,
  required num currentWallet,
  required String? bankCode,
  required String? bankName,
  required String accountNumber,
  required String accountName,
}) {
  if (amountText.trim().isEmpty) return 'Vui lòng nhập số tiền muốn rút';
  final amount = int.tryParse(amountText.replaceAll(',', '').trim());
  if (amount == null || amount <= 0) {
    return 'Số tiền rút phải là số nguyên lớn hơn 0';
  }
  if (amount > currentWallet) return 'Số dư ví không đủ để rút tiền';
  if (bankCode == null ||
      bankCode.trim().isEmpty ||
      bankName == null ||
      bankName.trim().isEmpty) {
    return 'Vui lòng chọn ngân hàng';
  }
  if (accountNumber.trim().isEmpty) return 'Vui lòng nhập số tài khoản';
  if (!RegExp(r'^[0-9]+$').hasMatch(accountNumber.trim())) {
    return 'Số tài khoản chỉ được chứa chữ số';
  }
  if (accountName.trim().isEmpty) return 'Vui lòng nhập tên chủ tài khoản';
  return null;
}
