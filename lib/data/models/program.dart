import 'package:freezed_annotation/freezed_annotation.dart';
part 'program.freezed.dart';
part 'program.g.dart';

/// Program model generated by freezed package.
/// flutter pub run build_runner build --delete-conflicting-outputs
@freezed
class Program with _$Program {
  const factory Program({
    int? id,
    String? name,
    String? description,
  }) = _Program;

  factory Program.fromJson(Map<String, Object?> json) =>
      _$ProgramFromJson(json);
}
