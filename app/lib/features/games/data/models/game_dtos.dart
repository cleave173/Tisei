/// Identifier for each supported game on the frontend.
enum GameKind { wordMatch, wordScramble, sentenceBuilder, hangman }

extension GameKindX on GameKind {
  String get apiPath {
    switch (this) {
      case GameKind.wordMatch:
        return 'word-match';
      case GameKind.wordScramble:
        return 'word-scramble';
      case GameKind.sentenceBuilder:
        return 'sentence-builder';
      case GameKind.hangman:
        return 'hangman';
    }
  }
}

class WordPairDto {
  WordPairDto({required this.word, required this.translation});
  final String word;
  final String translation;

  factory WordPairDto.fromJson(Map<String, dynamic> j) => WordPairDto(
        word: j['word'] as String,
        translation: j['translation'] as String,
      );
}

class WordMatchDto {
  WordMatchDto({this.topicLabel, required this.level, required this.pairs});
  final String? topicLabel;
  final String level;
  final List<WordPairDto> pairs;

  factory WordMatchDto.fromJson(Map<String, dynamic> j) => WordMatchDto(
        topicLabel: j['topic_label'] as String?,
        level: j['level'] as String,
        pairs: ((j['pairs'] as List?) ?? <dynamic>[])
            .map((dynamic e) => WordPairDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ScrambleItemDto {
  ScrambleItemDto({required this.word, required this.translation, this.hint});
  final String word;
  final String translation;
  final String? hint;

  factory ScrambleItemDto.fromJson(Map<String, dynamic> j) => ScrambleItemDto(
        word: j['word'] as String,
        translation: j['translation'] as String,
        hint: j['hint'] as String?,
      );
}

class WordScrambleDto {
  WordScrambleDto({this.topicLabel, required this.level, required this.items});
  final String? topicLabel;
  final String level;
  final List<ScrambleItemDto> items;

  factory WordScrambleDto.fromJson(Map<String, dynamic> j) => WordScrambleDto(
        topicLabel: j['topic_label'] as String?,
        level: j['level'] as String,
        items: ((j['items'] as List?) ?? <dynamic>[])
            .map((dynamic e) => ScrambleItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class SentenceItemDto {
  SentenceItemDto({required this.sentence, required this.translation});
  final String sentence;
  final String translation;

  factory SentenceItemDto.fromJson(Map<String, dynamic> j) => SentenceItemDto(
        sentence: j['sentence'] as String,
        translation: j['translation'] as String,
      );
}

class SentenceBuilderDto {
  SentenceBuilderDto({this.topicLabel, required this.level, required this.items});
  final String? topicLabel;
  final String level;
  final List<SentenceItemDto> items;

  factory SentenceBuilderDto.fromJson(Map<String, dynamic> j) => SentenceBuilderDto(
        topicLabel: j['topic_label'] as String?,
        level: j['level'] as String,
        items: ((j['items'] as List?) ?? <dynamic>[])
            .map((dynamic e) => SentenceItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class HangmanDto {
  HangmanDto({
    this.topicLabel,
    required this.level,
    required this.word,
    required this.translation,
    required this.hint,
  });
  final String? topicLabel;
  final String level;
  final String word;
  final String translation;
  final String hint;

  factory HangmanDto.fromJson(Map<String, dynamic> j) => HangmanDto(
        topicLabel: j['topic_label'] as String?,
        level: j['level'] as String,
        word: j['word'] as String,
        translation: j['translation'] as String,
        hint: j['hint'] as String,
      );
}
