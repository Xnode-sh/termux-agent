import 'package:flutter/material.dart';
import '../models/answer.dart';

Future<bool> showConfirmDialog(BuildContext context, Answer answer) async {
  if (answer.risk == 'danger') {
    return await _showDangerDialog(context, answer);
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: Text(answer.risk == 'safe' ? 'Выполнить?' : 'Изменит файлы. Выполнить?',
        style: const TextStyle(fontSize: 16)),
      content: SelectableText(answer.cmd,
        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF7EE787))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> _showDangerDialog(BuildContext context, Answer answer) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('ОПАСНАЯ КОМАНДА',
        style: TextStyle(fontSize: 16, color: Color(0xFFF85149))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(answer.cmd,
            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF85149))),
          const SizedBox(height: 8),
          Text(answer.explain, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 16),
          const Text('Введите «да, выполнить» для подтверждения:',
            style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF85149)),
          onPressed: () {
            Navigator.pop(ctx, controller.text.trim().toLowerCase() == 'да, выполнить');
          },
          child: const Text('Подтвердить'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result ?? false;
}
