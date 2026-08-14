import 'dart:math';

class RandomPickerService {
  RandomPickerService({Random? random}) : _random = random ?? Random();

  final Random _random;

  T pickOne<T>(List<T> source) {
    if (source.isEmpty) {
      throw StateError('Cannot pick from an empty list.');
    }
    return source[_random.nextInt(source.length)];
  }

  List<T> pickMany<T>(List<T> source, int count, {bool avoidDuplicates = true}) {
    if (source.isEmpty) {
      throw StateError('Cannot pick from an empty list.');
    }

    if (!avoidDuplicates) {
      return List<T>.generate(count, (_) => source[_random.nextInt(source.length)], growable: false);
    }

    if (count <= source.length) {
      final shuffled = List<T>.from(source)..shuffle(_random);
      return shuffled.take(count).toList(growable: false);
    }

    final result = <T>[];
    final shuffled = List<T>.from(source)..shuffle(_random);
    result.addAll(shuffled);

    while (result.length < count) {
      result.add(source[_random.nextInt(source.length)]);
    }
    return result;
  }
}
