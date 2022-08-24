import 'package:freezed_annotation/freezed_annotation.dart';
part 'day.freezed.dart';
part 'day.g.dart';

/// Load model generated by freezed package.
/// flutter pub run build_runner build --delete-conflicting-outputs
@freezed
class Day with _$Day {
  const factory Day({
    int? id,
    int? ord,
    String? name,
    String? description,
  }) = _Day;

  factory Day.fromJson(Map<String, Object?> json) => _$DayFromJson(json);
}
