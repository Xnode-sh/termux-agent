import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/pty_service.dart';
import '../models/answer.dart';
import '../widgets/risk_badge.dart';
import '../widgets/confirm_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _history = <_Entry>[];
  bool _loading = false;

  Future<void> _ask() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _history.add(_Entry.user(text));
      _loading = true;
    });
    _scrollDown();

    final result = await AiService.ask(text);
    setState(() => _loading = false);

    if (result == null) {
      setState(() => _history.add(_Entry.error('Модель не загружена')));
      _scrollDown();
      return;
    }
    if (result.blocked != null) {
      setState(() => _history.add(_Entry.blocked(result.blocked!)));
      _scrollDown();
      return;
    }
    final answer = result.answer!;
    setState(() => _history.add(_Entry.suggestion(answer)));
    _scrollDown();

    final confirmed = await showConfirmDialog(context, answer);
    if (!confirmed) {
      setState(() => _history.add(_Entry.info('Отменено')));
      _scrollDown();
      return;
    }

    final output = await PtyService.exec(answer.cmd);
    setState(() => _history.add(_Entry.output(output)));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTL Agent', style: TextStyle(fontFamily: 'monospace')),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length + (_loading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _history.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return _buildEntry(_history[i]);
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildEntry(_Entry e) {
    switch (e.type) {
      case _EntryType.user:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('> ', style: TextStyle(color: Color(0xFF58A6FF), fontFamily: 'monospace')),
              Expanded(child: Text(e.text, style: const TextStyle(fontFamily: 'monospace'))),
            ],
          ),
        );
      case _EntryType.suggestion:
        final a = e.answer!;
        return Card(
          color: const Color(0xFF161B22),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: SelectableText(a.cmd,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: Color(0xFF7EE787))),
                  ),
                  RiskBadge(risk: a.risk),
                ]),
                const SizedBox(height: 6),
                Text(a.explain, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                Text('${a.msTotal} мс', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
        );
      case _EntryType.output:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            border: Border.all(color: const Color(0xFF30363D)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(e.text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFC9D1D9))),
        );
      case _EntryType.blocked:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('BLOCK: ${e.text}',
            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF85149))),
        );
      case _EntryType.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(e.text, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF0883E))),
        );
      case _EntryType.info:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(e.text, style: TextStyle(fontFamily: 'monospace', color: Colors.grey[500])),
        );
    }
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Что сделать?',
                  hintStyle: TextStyle(color: Color(0xFF484F58)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _ask(),
                textInputAction: TextInputAction.send,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, size: 20),
              onPressed: _loading ? null : _ask,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

enum _EntryType { user, suggestion, output, blocked, error, info }

class _Entry {
  final _EntryType type;
  final String text;
  final Answer? answer;

  _Entry._(this.type, this.text, [this.answer]);
  factory _Entry.user(String t) => _Entry._(_EntryType.user, t);
  factory _Entry.suggestion(Answer a) => _Entry._(_EntryType.suggestion, a.cmd, a);
  factory _Entry.output(String t) => _Entry._(_EntryType.output, t);
  factory _Entry.blocked(String t) => _Entry._(_EntryType.blocked, t);
  factory _Entry.error(String t) => _Entry._(_EntryType.error, t);
  factory _Entry.info(String t) => _Entry._(_EntryType.info, t);
}
