// Mock data models that match the jikan_api structure
// These can be easily replaced with real jikan_api models later

class MockAnime {
  final int malId;
  final String url;
  final String imageUrl;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final int? episodes;
  final String? status;
  final String? aired;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? synopsis;
  final String? background;
  final String? season;
  final int? year;
  final String? broadcast;
  final List<MockGenre> genres;
  final List<MockStudio> studios;
  final String? source;
  final String? duration;
  final String? rating;

  MockAnime({
    required this.malId,
    required this.url,
    required this.imageUrl,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.episodes,
    this.status,
    this.aired,
    this.score,
    this.scoredBy,
    this.rank,
    this.popularity,
    this.members,
    this.favorites,
    this.synopsis,
    this.background,
    this.season,
    this.year,
    this.broadcast,
    this.genres = const [],
    this.studios = const [],
    this.source,
    this.duration,
    this.rating,
  });
}

class MockGenre {
  final int malId;
  final String name;

  MockGenre({required this.malId, required this.name});
}

class MockStudio {
  final int malId;
  final String name;

  MockStudio({required this.malId, required this.name});
}

class MockEpisode {
  final int malId;
  final String title;
  final String? aired;
  final double? score;

  MockEpisode({
    required this.malId,
    required this.title,
    this.aired,
    this.score,
  });
}

class MockCharacter {
  final int malId;
  final String name;
  final String? nameKanji;
  final List<String> nicknames;
  final String imageUrl;
  final int favorites;
  final String? about;
  final String? birthday;
  final List<MockAnimeAppearance> animeography;
  final List<MockVoiceActor> voiceActors;

  MockCharacter({
    required this.malId,
    required this.name,
    this.nameKanji,
    this.nicknames = const [],
    required this.imageUrl,
    required this.favorites,
    this.about,
    this.birthday,
    this.animeography = const [],
    this.voiceActors = const [],
  });
}

class MockAnimeAppearance {
  final MockAnime anime;
  final String role; // Main, Supporting, etc.

  MockAnimeAppearance({
    required this.anime,
    required this.role,
  });
}

class MockVoiceActor {
  final int malId;
  final String name;
  final String imageUrl;
  final String language;

  MockVoiceActor({
    required this.malId,
    required this.name,
    required this.imageUrl,
    required this.language,
  });
}

class MockProducer {
  final int malId;
  final String name;
  final String imageUrl;
  final String? established;
  final String? about;
  final int count;
  final List<String> titles;
  final String? website;
  final List<MockAnime> animeProduced;

  MockProducer({
    required this.malId,
    required this.name,
    required this.imageUrl,
    this.established,
    this.about,
    required this.count,
    this.titles = const [],
    this.website,
    this.animeProduced = const [],
  });
} 