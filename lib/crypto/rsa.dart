import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import "package:pointycastle/pointycastle.dart";

/// RSA PEM parser.
class RSAKeyParser {
  /// Parses the PEM key no matter it is public or private, it will figure it out.
  RSAPublicKey parsePublic(String key) {
    List<String> rows = key.split('\n'); // LF-only, this could be a problem
    String header = rows.first;

    if (header == '-----BEGIN RSA PUBLIC KEY-----') {
      return _parsePublic(_parseSequence(rows));
    }

    if (header == '-----BEGIN PUBLIC KEY-----') {
      return _parsePublic(_pkcs8PublicSequence(_parseSequence(rows)));
    }

    // NOTE: Should we throw an exception?
    return null;
  }

  RSAPrivateKey parsePrivate(String key) {
    List<String> rows = key.split('\n'); // LF-only, this could be a problem
    String header = rows.first;

    if (header == '-----BEGIN RSA PRIVATE KEY-----') {
      return _parsePrivate(_parseSequence(rows));
    }

    if (header == '-----BEGIN PRIVATE KEY-----') {
      return _parsePrivate(_pkcs8PrivateSequence(_parseSequence(rows)));
    }

    // NOTE: Should we throw an exception?
    return null;
  }

  RSAPublicKey _parsePublic(ASN1Sequence sequence) {
    BigInt modulus = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
    BigInt exponent = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;

    return RSAPublicKey(modulus, exponent);
  }

  RSAPrivateKey _parsePrivate(ASN1Sequence sequence) {
    BigInt modulus = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    BigInt exponent = (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    BigInt p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    BigInt q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;

    return RSAPrivateKey(modulus, exponent, p, q);
  }

  ASN1Sequence _parseSequence(List<String> rows) {
    String keyText = rows
        .skipWhile((String row) => row.startsWith('-----BEGIN'))
        .takeWhile((String row) => !row.startsWith('-----END'))
        .map((String row) => row.trim())
        .join('');

    Uint8List keyBytes = Uint8List.fromList(base64.decode(keyText));
    ASN1Parser asn1Parser = ASN1Parser(keyBytes);

    return asn1Parser.nextObject() as ASN1Sequence;
  }

  ASN1Sequence _pkcs8PublicSequence(ASN1Sequence sequence) {
    ASN1BitString bitString = sequence.elements[1];
    Uint8List bytes = bitString.valueBytes().sublist(1);
    ASN1Parser parser = ASN1Parser(Uint8List.fromList(bytes));

    return parser.nextObject() as ASN1Sequence;
  }

  ASN1Sequence _pkcs8PrivateSequence(ASN1Sequence sequence) {
    ASN1BitString bitString = sequence.elements[2];
    Uint8List bytes = bitString.valueBytes();
    ASN1Parser parser = ASN1Parser(bytes);

    return parser.nextObject() as ASN1Sequence;
  }
}

class RSASigner {
  RSASigner(this.rsaSigner, this.privateKey);

  final Signer rsaSigner;
  final RSAPrivateKey privateKey;

  List<int> sign(List<int> message) {
    rsaSigner
      ..reset()
      ..init(true, PrivateKeyParameter<PrivateKey>(privateKey));
    Signature signature =
        rsaSigner.generateSignature(Uint8List.fromList(message));
    return Uint8List.fromList(signature.toString().codeUnits);
  }

  static RSASigner sha1Rsa(String privateKey) {
    return RSASigner(
        Signer('SHA-1/RSA'), RSAKeyParser().parsePrivate(privateKey));
  }

  static RSASigner sha256Rsa(String privateKey) {
    return RSASigner(
        Signer('SHA-256/RSA'), RSAKeyParser().parsePrivate(privateKey));
  }
}

class RSAVerifier {
  RSAVerifier(this.rsaSigner, this.publicKey);

  final Signer rsaSigner;
  final RSAPublicKey publicKey;

  bool verify(List<int> message, List<int> signature) {
    rsaSigner
      ..reset()
      ..init(false, PublicKeyParameter<PublicKey>(publicKey));
    return rsaSigner.verifySignature(Uint8List.fromList(message),
        RSASignature(Uint8List.fromList(signature)));
  }

  static RSAVerifier sha1Rsa(String publicKey) {
    return RSAVerifier(
        Signer('SHA-1/RSA'), RSAKeyParser().parsePublic(publicKey));
  }

  static RSAVerifier sha256Rsa(String publicKey) {
    return RSAVerifier(
        Signer('SHA-256/RSA'), RSAKeyParser().parsePublic(publicKey));
  }
}