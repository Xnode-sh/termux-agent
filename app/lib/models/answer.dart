class Answer {
  final String cmd;
  final String explain;
  final String risk; // safe | write | danger
  final int msTotal;

  Answer({required this.cmd, required this.explain, required this.risk, required this.msTotal});

  factory Answer.fromJson(Map<String, dynamic> j) => Answer(
    cmd: j['cmd'] as String,
    explain: j['explain'] as String,
    risk: j['risk'] as String,
    msTotal: (j['ms_total'] as num).toInt(),
  );
}

class AskResult {
  final Answer? answer;
  final String? blocked;

  AskResult({this.answer, this.blocked});

  factory AskResult.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('blocked')) {
      return AskResult(blocked: j['blocked'] as String);
    }
    return AskResult(answer: Answer.fromJson(j));
  }
}
