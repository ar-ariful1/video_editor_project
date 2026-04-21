// lib/core/models/auto_caption.dart
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AutoCaption extends Equatable {
  final String id;
  final String text;
  final double startTime;
  final double endTime;
  final int? wordCount;
  final String? language;
  final double confidence;
  final String? speakerId;

  const AutoCaption({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.wordCount,
    this.language,
    this.confidence = 1.0,
    this.speakerId,
  });

  factory AutoCaption.create({
    required String text,
    required double startTime,
    required double endTime,
    String? language,
  }) => AutoCaption(
    id: _uuid.v4(),
    text: text,
    startTime: startTime,
    endTime: endTime,
    language: language,
  );

  double get duration => endTime - startTime;

  AutoCaption copyWith({
    String? text,
    double? startTime,
    double? endTime,
    double? confidence,
  }) => AutoCaption(
    id: id,
    text: text ?? this.text,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    wordCount: wordCount,
    language: language,
    confidence: confidence ?? this.confidence,
    speakerId: speakerId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'startTime': startTime,
    'endTime': endTime,
    'wordCount': wordCount,
    'language': language,
    'confidence': confidence,
    'speakerId': speakerId,
  };

  factory AutoCaption.fromJson(Map<String, dynamic> j) => AutoCaption(
    id: j['id'] ?? _uuid.v4(),
    text: j['text'],
    startTime: j['startTime'],
    endTime: j['endTime'],
    wordCount: j['wordCount'],
    language: j['language'],
    confidence: j['confidence'] ?? 1.0,
    speakerId: j['speakerId'],
  );

  @override
  List<Object?> get props => [id, text, startTime, endTime, confidence];
}