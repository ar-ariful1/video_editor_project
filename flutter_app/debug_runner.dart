// debug_runner.dart
import 'dart:io';

void main() async {
  print('═══════════════════════════════════════════════════════════════════');
  print('              VIDEO EDITOR PRO - DEBUG RUNNER                      ');
  print('═══════════════════════════════════════════════════════════════════');
  print('');
  
  // Run flutter with error capturing
  final result = await Process.run('flutter', ['run', '--verbose'], 
    runInShell: true,
  );
  
  // Print all output
  print(result.stdout);
  
  if (result.stderr.isNotEmpty) {
    print('');
    print('╔═══════════════════════════════════════════════════════════════════╗');
    print('║                          ERROR OUTPUT                              ║');
    print('╚═══════════════════════════════════════════════════════════════════╝');
    print(result.stderr);
  }
  
  // Save to file
  final logFile = File('debug_log_${DateTime.now().millisecondsSinceEpoch}.txt');
  await logFile.writeAsString('''
═══════════════════════════════════════════════════════════════════
DEBUG LOG - ${DateTime.now()}
═══════════════════════════════════════════════════════════════════

STDOUT:
${result.stdout}

STDERR:
${result.stderr}
''');
  
  print('');
  print('📁 Log saved to: ${logFile.path}');
}