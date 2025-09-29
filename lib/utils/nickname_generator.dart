import 'dart:math';

/// A utility class to generate random, anonymous nicknames.
class NicknameGenerator {
  static final Random _random = Random();

  static const List<String> _adjectives = [
    'Silent', 'Wandering', 'Cosmic', 'Swift', 'Hidden', 'Brave',
    'Lone', 'Ancient', 'Starlight', 'Solar', 'Lunar', 'Arctic',
    'Crimson', 'Azure', 'Golden', 'Shadow', 'Whispering', 'Lost',
    'Forgotten', 'Phantom', 'Celestial', 'Ethereal', 'Nomadic',

    // New ones
    'Mystic', 'Frosty', 'Iron', 'Velvet', 'Radiant', 'Stormy',
    'Nebula', 'Emerald', 'Obsidian', 'Galactic', 'Echoing', 'Roaming',
    'Fuzzy', 'Jolly', 'Turbo', 'Glowing', 'Quantum', 'Playful',
    'Cheerful', 'Dizzy', 'Curious', 'Bubbly', 'Midnight', 'Electric',
    'Shiny', 'Rusty', 'Magnetic', 'Pixelated', 'Wobbly'
  ];

  static const List<String> _nouns = [
    'Voyager', 'Pilgrim', 'Drifter', 'Explorer', 'Seeker', 'Traveler',
    'Nomad', 'Ranger', 'Pathfinder', 'Wayfarer', 'Comet', 'Star',
    'Wolf', 'Falcon', 'Lion', 'Tiger', 'Shadow', 'Spirit', 'Ghost',
    'Dreamer', 'Pioneer', 'Wanderer', 'Odyssey',

    // New ones
    'Meteor', 'Phoenix', 'Dragon', 'Hawk', 'Eagle', 'Serpent',
    'Wizard', 'Knight', 'Samurai', 'Ninja', 'Bot', 'Alien',
    'Asteroid', 'Rocket', 'Pilot', 'Captain', 'Pirate', 'Golem',
    'Sloth', 'Penguin', 'Otter', 'Platypus', 'Duck', 'Banana',
    'Pickle', 'Muffin', 'Potato', 'Taco', 'Marshmallow', 'Panda',
    'Koala', 'Squirrel', 'Chipmunk', 'Cactus', 'Octopus'
  ];

  /// Generates a single random nickname.
  ///
  /// Example: "Cosmic Voyager"
  static String generate() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];
    return '$adjective $noun';
  }
}
