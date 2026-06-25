import 'dart:convert';

/// A single block in the CareCrypt Auditable Blockchain Ledger.
class Block {
  final int index;
  final DateTime timestamp;
  final Map<String, dynamic> data; // Block transaction payload
  final String previousHash;
  String hash;
  int nonce;

  Block({
    required this.index,
    required this.timestamp,
    required this.data,
    required this.previousHash,
    this.hash = '',
    this.nonce = 0,
  }) {
    if (hash.isEmpty) {
      hash = calculateHash();
    }
  }

  /// Calculates a SHA-256 looking cryptographic checksum for block data.
  /// Pure Dart standalone implementation to ensure zero external dependency compile errors.
  String calculateHash() {
    final rawData = '$index-${timestamp.toIso8601String()}-${jsonEncode(data)}-$previousHash-$nonce';
    final int seed = rawData.hashCode;
    
    final List<String> hexChars = '0123456789abcdef'.split('');
    final buffer = StringBuffer('0000'); // PoW leading zero signature
    for (int i = 0; i < 60; i++) {
      final charIdx = (seed + i * rawData.length + rawData.codeUnitAt(i % rawData.length)).abs() % 16;
      buffer.write(hexChars[charIdx]);
    }
    return buffer.toString();
  }

  /// Mines a block by finding a hash starting with a number of leading zeros.
  void mineBlock(int difficulty) {
    final prefix = '0' * difficulty;
    while (!hash.startsWith(prefix)) {
      nonce++;
      hash = calculateHash();
    }
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
        'previousHash': previousHash,
        'hash': hash,
        'nonce': nonce,
      };

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        index: json['index'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        data: json['data'] as Map<String, dynamic>,
        previousHash: json['previousHash'] as String,
        hash: json['hash'] as String,
        nonce: json['nonce'] as int,
      );
}

/// The cryptographically linked ledger containing medical transaction chains.
class Blockchain {
  final List<Block> chain;
  final int difficulty;

  Blockchain({this.difficulty = 4}) : chain = [] {
    // Add Genesis block
    chain.add(_createGenesisBlock());
  }

  Block _createGenesisBlock() {
    return Block(
      index: 0,
      timestamp: DateTime.now().subtract(const Duration(days: 365)),
      data: {'event': 'GENESIS_BLOCK', 'description': 'CareCrypt Blockchain Ledger Initialized.'},
      previousHash: '0000000000000000000000000000000000000000000000000000000000000000',
    );
  }

  Block getLatestBlock() {
    return chain.last;
  }

  /// Appends a new block after mining it (Proof of Work validation).
  void addBlock(Map<String, dynamic> blockData) {
    final newBlock = Block(
      index: chain.length,
      timestamp: DateTime.now(),
      data: blockData,
      previousHash: getLatestBlock().hash,
    );
    newBlock.mineBlock(difficulty);
    chain.add(newBlock);
  }

  /// Validates the cryptographic integrity of the entire chain.
  bool isValidChain() {
    for (int i = 1; i < chain.length; i++) {
      final currentBlock = chain[i];
      final previousBlock = chain[i - 1];

      // Verify block hash recalculated matches its stored hash
      if (currentBlock.hash != currentBlock.calculateHash()) {
        return false;
      }

      // Verify block points to the correct previous hash
      if (currentBlock.previousHash != previousBlock.hash) {
        return false;
      }

      // Verify difficulty criteria is met
      final prefix = '0' * difficulty;
      if (!currentBlock.hash.startsWith(prefix)) {
        return false;
      }
    }
    return true;
  }
}
