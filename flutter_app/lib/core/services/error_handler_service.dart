// lib/core/services/error_handler_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._();

  // Error logs collection
  final List<AppError> _errors = [];
  final List<AppError> _flutterErrors = [];
  final List<AppError> _dartErrors = [];

  void initialize() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = AppError(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Flutter Error',
        message: details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
        type: ErrorType.flutter,
        timestamp: DateTime.now(),
        severity: _getSeverity(details.exceptionAsString()),
      );
      _flutterErrors.add(error);
      _addError(error);
      
      // Print to terminal with colors
      _printToTerminal(error);
    };

    // Catch async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      final appError = AppError(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Async Error',
        message: error.toString(),
        stackTrace: stack.toString(),
        type: ErrorType.dart,
        timestamp: DateTime.now(),
        severity: Severity.high,
      );
      _dartErrors.add(appError);
      _addError(appError);
      _printToTerminal(appError);
      return true;
    };
  }

  void _addError(AppError error) {
    _errors.add(error);
    _saveErrorToFile(error);
  }

  void _printToTerminal(AppError error) {
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════════════════════════╗');
    debugPrint('║ 🔴 ERROR DETECTED                                                              ║');
    debugPrint('╠═══════════════════════════════════════════════════════════════════════════════╣');
    debugPrint('║ 📅 Time: ${error.timestamp}');
    debugPrint('║ 📛 Title: ${error.title}');
    debugPrint('║ 🏷️  Type: ${error.type}');
    debugPrint('║ ⚠️  Severity: ${error.severity}');
    debugPrint('║ 💬 Message: ${error.message}');
    if (error.stackTrace != null && error.stackTrace!.isNotEmpty) {
      debugPrint('║ 📚 Stack Trace:');
      final lines = error.stackTrace!.split('\n');
      for (var line in lines.take(10)) { // Show first 10 lines only
        debugPrint('║    $line');
      }
      if (lines.length > 10) {
        debugPrint('║    ... (${lines.length - 10} more lines)');
      }
    }
    debugPrint('╚═══════════════════════════════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  Future<void> _saveErrorToFile(AppError error) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/error_logs.txt');
      
      final logEntry = '''
${'=' * 100}
[${error.timestamp}] ${error.title}
Type: ${error.type}
Severity: ${error.severity}
Message: ${error.message}
Stack Trace:
${error.stackTrace ?? 'No stack trace'}
${'=' * 100}

''';
      await file.writeAsString(logEntry, mode: FileMode.append);
      
      // Also print file path once
      if (_errors.length == 1) {
        debugPrint('📁 Error logs saved to: ${file.path}');
      }
    } catch (e) {
      debugPrint('Failed to save error log: $e');
    }
  }

  Severity _getSeverity(String message) {
    if (message.contains('null') || message.contains('Null check')) return Severity.high;
    if (message.contains('timeout')) return Severity.medium;
    if (message.contains('permission')) return Severity.high;
    if (message.contains('crash')) return Severity.critical;
    return Severity.low;
  }

  // Utility methods (optional)
  List<AppError> getAllErrors() => _errors;
  int get errorCount => _errors.length;
  
  void printSummary() {
    debugPrint('');
    debugPrint('📊 ERROR SUMMARY');
    debugPrint('Total errors: ${_errors.length}');
    debugPrint('Flutter errors: ${_flutterErrors.length}');
    debugPrint('Dart errors: ${_dartErrors.length}');
    debugPrint('');
  }
}

enum ErrorType { flutter, dart, platform, network, custom }
enum Severity { low, medium, high, critical }

class AppError {
  final String id;
  final String title;
  final String message;
  final String? stackTrace;
  final ErrorType type;
  final DateTime timestamp;
  final Severity severity;

  AppError({
    required this.id,
    required this.title,
    required this.message,
    this.stackTrace,
    required this.type,
    required this.timestamp,
    required this.severity,
  });
}