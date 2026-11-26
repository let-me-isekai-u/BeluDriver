import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showEmailChangeSmsDialog(BuildContext context) {
  var code = '';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Xác nhận đổi email'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Mã SMS',
            helperText: 'Mã gửi tới số đã đăng ký và có hiệu lực 3 phút.',
            helperMaxLines: 2,
          ),
          onChanged: (value) => setState(() => code = value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: code.length == 6
                ? () => Navigator.of(context).pop(code)
                : null,
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ),
  );
}
