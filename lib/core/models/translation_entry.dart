import 'package:hive/hive.dart';

class TranslationEntry {
  final String id;
  final String signLabel;
  final double confidence;
  final DateTime timestamp;
  final bool syncedToCloud;

  const TranslationEntry({
    required this.id,
    required this.signLabel,
    required this.confidence,
    required this.timestamp,
    required this.syncedToCloud,
  });

  TranslationEntry copyWith({
    String? id,
    String? signLabel,
    double? confidence,
    DateTime? timestamp,
    bool? syncedToCloud,
  }) {
    return TranslationEntry(
      id: id ?? this.id,
      signLabel: signLabel ?? this.signLabel,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
    );
  }
}

class TranslationEntryAdapter extends TypeAdapter<TranslationEntry> {
  @override
  final int typeId = 1;

  @override
  TranslationEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return TranslationEntry(
      id: fields[0] as String,
      signLabel: fields[1] as String,
      confidence: fields[2] as double,
      timestamp: fields[3] as DateTime,
      syncedToCloud: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TranslationEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.signLabel)
      ..writeByte(2)
      ..write(obj.confidence)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.syncedToCloud);
  }
}
