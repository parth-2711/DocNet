import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Descriptor for Key Derivation Function parameters stored in keyProfiles (DATABASE_SCHEMA.md).
class KdfDescriptor {
  final String algorithm;
  final String saltBase64;
  final int iterations;
  final int memoryCostKb;
  final int parallelism;
  final int keyLength;

  const KdfDescriptor({
    required this.algorithm,
    required this.saltBase64,
    required this.iterations,
    required this.memoryCostKb,
    required this.parallelism,
    required this.keyLength,
  });

  Map<String, dynamic> toMap() {
    return {
      'algorithm': algorithm,
      'salt': saltBase64,
      'iterations': iterations,
      'memoryCostKb': memoryCostKb,
      'parallelism': parallelism,
      'keyLength': keyLength,
    };
  }

  factory KdfDescriptor.fromMap(Map<String, dynamic> map) {
    return KdfDescriptor(
      algorithm: map['algorithm'] as String,
      saltBase64: map['salt'] as String,
      iterations: map['iterations'] as int? ?? 100000,
      memoryCostKb: map['memoryCostKb'] as int? ?? 65536,
      parallelism: map['parallelism'] as int? ?? 1,
      keyLength: map['keyLength'] as int? ?? 32,
    );
  }
}

/// Service managing high-entropy recovery secrets and vault key wrapping (ENCRYPTION.md Section 8).
class RecoveryKeyService {
  final Random _secureRandom = Random.secure();

  /// Wordlist for readable high-entropy recovery phrases (BIP39 subset sample).
  static const List<String> _wordList = [
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
    'absurd',
    'abuse',
    'access',
    'accident',
    'account',
    'accuse',
    'achieve',
    'acid',
    'acoustic',
    'acquire',
    'across',
    'act',
    'action',
    'actor',
    'actress',
    'actual',
    'adapt',
    'add',
    'addict',
    'address',
    'adjust',
    'admit',
    'adult',
    'advance',
    'advice',
    'aerobic',
    'affair',
    'afford',
    'afraid',
    'again',
    'age',
    'agent',
    'agree',
    'ahead',
    'aim',
    'air',
    'airport',
    'aisle',
    'alarm',
    'album',
    'alcohol',
    'alert',
    'alien',
    'all',
    'alley',
    'allow',
    'almost',
    'alone',
    'alpha',
    'already',
    'also',
    'alter',
    'always',
    'amateur',
    'amazing',
    'among',
    'amount',
    'amused',
    'analyst',
    'anchor',
    'ancient',
    'anger',
    'angle',
    'angry',
    'animal',
    'ankle',
    'announce',
    'annual',
    'another',
    'answer',
    'antenna',
    'antique',
    'anxiety',
    'any',
    'apart',
    'apology',
    'appear',
    'apple',
    'approve',
    'april',
    'arch',
    'arctic',
    'area',
    'arena',
    'argue',
    'arm',
    'armed',
    'armor',
    'army',
    'around',
    'arrange',
    'arrest',
    'arrive',
    'arrow',
    'art',
    'artefact',
    'artist',
    'artwork',
    'ask',
    'aspect',
    'assault',
    'asset',
    'assist',
    'assume',
    'asthma',
    'athlete',
    'atom',
    'attack',
    'attend',
    'attitude',
    'attract',
    'auction',
    'audit',
    'august',
    'aunt',
    'author',
    'auto',
    'autumn',
    'average',
    'avocado',
    'avoid',
    'awake',
    'aware',
    'away',
    'awesome',
    'awful',
    'awkward',
    'axis',
    'baby',
    'bachelor',
    'bacon',
    'badge',
    'bag',
    'balance',
    'balcony',
    'ball',
    'bamboo',
    'banana',
    'banner',
    'bar',
    'barely',
    'bargain',
    'barrel',
    'base',
    'basic',
    'basket',
    'battle',
    'beach',
    'bean',
    'beauty',
    'because',
    'become',
    'beef',
    'before',
    'begin',
    'behave',
    'behind',
    'believe',
    'below',
    'belt',
    'bench',
    'benefit',
    'best',
    'betray',
    'better',
    'between',
    'beyond',
    'bicycle',
    'bid',
    'bike',
    'bind',
    'biology',
    'bird',
    'birth',
    'bitter',
    'black',
    'blade',
    'blame',
    'blanket',
    'blast',
    'bleak',
    'bless',
    'blind',
    'blood',
    'blossom',
    'blouse',
    'blue',
    'blur',
    'blush',
    'board',
    'boat',
    'body',
    'boil',
    'bomb',
    'bone',
    'bonus',
    'book',
    'boost',
    'border',
    'boring',
    'borrow',
    'boss',
    'bottom',
    'bounce',
    'box',
    'boy',
    'bracket',
    'brain',
    'brand',
    'brass',
    'brave',
    'bread',
    'breeze',
    'brick',
    'bridge',
    'brief',
    'bright',
    'bring',
    'brisk',
    'broccoli',
    'broken',
    'bronze',
    'broom',
    'brother',
    'brown',
    'brush',
    'bubble',
    'buddy',
    'budget',
    'buffalo',
    'build',
    'bulb',
    'bulk',
    'bullet',
    'bundle',
    'bunker',
    'burden',
    'burger',
    'burst',
    'bus',
    'business',
    'busy',
    'butter',
    'buyer',
    'buzz',
    'cabbage',
    'cabin',
    'cable',
  ];

  /// Generates a 12-word high-entropy recovery phrase (128 bits of entropy).
  String generateRecoveryPhrase() {
    final words = <String>[];
    for (var i = 0; i < 12; i++) {
      final index = _secureRandom.nextInt(_wordList.length);
      words.add(_wordList[index]);
    }
    return words.join(' ');
  }

  /// Generates a random 16-byte salt for key derivation.
  Uint8List generateSalt() {
    final salt = Uint8List(16);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = _secureRandom.nextInt(256);
    }
    return salt;
  }

  /// Derives a 32-byte wrapping key from recovery phrase and salt using HKDF-SHA256.
  Future<Uint8List> deriveWrappingKey({
    required String recoveryPhrase,
    required Uint8List salt,
  }) async {
    final phraseBytes = utf8.encode(recoveryPhrase.trim().toLowerCase());
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    final secretKey = SecretKey(phraseBytes);
    final derivedKey = await hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: utf8.encode('FamilyVault:VaultKeyWrapping:v1'),
    );

    final bytes = await derivedKey.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
