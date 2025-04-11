import 'package:uuid/uuid.dart';

class NoteModel {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime? updatedAt;
  int timerDuration; // in seconds
  bool isTimerActive;
  DateTime? timerStartedAt;

  NoteModel({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    this.updatedAt,
    this.timerDuration = 0,
    this.isTimerActive = false,
    this.timerStartedAt,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.createdAt = createdAt ?? DateTime.now();

  // Calculate remaining time in seconds
  int get remainingTime {
    if (!isTimerActive || timerStartedAt == null) {
      return timerDuration;
    }
    
    final elapsedSeconds = DateTime.now().difference(timerStartedAt!).inSeconds;
    final remaining = timerDuration - elapsedSeconds;
    
    return remaining > 0 ? remaining : 0;
  }

  // Check if timer is completed
  bool get isTimerCompleted {
    return isTimerActive && remainingTime <= 0;
  }

  // Start the timer
  void startTimer() {
    isTimerActive = true;
    timerStartedAt = DateTime.now();
  }

  // Pause the timer
  void pauseTimer() {
    if (isTimerActive && timerStartedAt != null) {
      final elapsedSeconds = DateTime.now().difference(timerStartedAt!).inSeconds;
      timerDuration = timerDuration - elapsedSeconds;
      isTimerActive = false;
      timerStartedAt = null;
    }
  }

  // Reset the timer
  void resetTimer() {
    isTimerActive = false;
    timerStartedAt = null;
  }

  // Set a new duration for the timer
  void setTimerDuration(int seconds) {
    timerDuration = seconds;
    isTimerActive = false;
    timerStartedAt = null;
  }

  // Convert NoteModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'timerDuration': timerDuration,
      'isTimerActive': isTimerActive,
      'timerStartedAt': timerStartedAt?.toIso8601String(),
    };
  }

  // Create NoteModel from JSON
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      timerDuration: json['timerDuration'],
      isTimerActive: json['isTimerActive'],
      timerStartedAt: json['timerStartedAt'] != null ? DateTime.parse(json['timerStartedAt']) : null,
    );
  }

  // Create a copy of the note with optional updates
  NoteModel copyWith({
    String? title,
    String? content,
    int? timerDuration,
    bool? isTimerActive,
    DateTime? timerStartedAt,
  }) {
    return NoteModel(
      id: this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
      timerDuration: timerDuration ?? this.timerDuration,
      isTimerActive: isTimerActive ?? this.isTimerActive,
      timerStartedAt: timerStartedAt ?? this.timerStartedAt,
    );
  }
}