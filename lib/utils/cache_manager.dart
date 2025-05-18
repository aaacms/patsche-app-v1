import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic _encodeValue(dynamic value) {
  if (value is DocumentReference) {
    return value.path; // Converte DocumentReference para seu caminho em String.
  } else if (value is Timestamp) {
    return value.toDate().toIso8601String(); // Converte Timestamp para String.
  } else if (value is Map) {
    return value.map((key, val) => MapEntry(key, _encodeValue(val)));
  } else if (value is List) {
    return value.map((item) => _encodeValue(item)).toList();
  }
  return value;
}

/// Classe que guarda os dados essenciais do DocumentSnapshot.
class CachedDocument {
  final String id;
  final Map<String, dynamic> data;
  final String referencePath;

  CachedDocument({
    required this.id,
    required this.data,
    required this.referencePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': _encodeValue(data),
      'referencePath': referencePath,
    };
  }

  factory CachedDocument.fromJson(Map<String, dynamic> json) {
    return CachedDocument(
      id: json['id'],
      data: Map<String, dynamic>.from(json['data']),
      referencePath: json['referencePath'],
    );
  }

  factory CachedDocument.fromDocumentSnapshot(DocumentSnapshot doc) {
    return CachedDocument(
      id: doc.id,
      data: doc.data() as Map<String, dynamic>,
      referencePath: doc.reference.path,
    );
  }

  /// Reconstrói a referência do documento a partir do caminho salvo.
  DocumentReference get reference =>
      FirebaseFirestore.instance.doc(referencePath);
}

class FirestoreCacheManager {
  final String collectionName;
  final String cacheKey;
  final Query Function(FirebaseFirestore firestore, String userId) queryBuilder;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  FirestoreCacheManager({
    required this.collectionName,
    required this.cacheKey,
    Query Function(FirebaseFirestore firestore, String userId)? queryBuilder,
  }) : queryBuilder = queryBuilder ??
            ((firestore, userId) =>
                firestore.collection(collectionName));

  /// Inicializa o cache: atualiza imediatamente e inicia o listener.
  Future<void> initialize() async {
    await refreshCache();
    _startListening();
  }

  void _startListening() {
    queryBuilder(firestore, userId).snapshots().listen((snapshot) async {
      List<CachedDocument> data = snapshot.docs.map((doc) {
        return CachedDocument.fromDocumentSnapshot(doc);
      }).toList();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data.map((e) => e.toJson()).toList()));
      print('Cache atualizado para a coleção $collectionName (chave: $cacheKey)');
    });
  }

  /// Retorna os dados armazenados no cache como uma lista de CachedDocument.
  /// Se não houver cache salvo, realiza um refresh.
  Future<List<CachedDocument>> getCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(cacheKey);

    if (jsonString != null) {
      List<dynamic> jsonData = jsonDecode(jsonString);
      return jsonData.map((e) => CachedDocument.fromJson(e)).toList();
    } else {
      return await refreshCache();
    }
  }

  /// Realiza uma nova consulta completa no Firestore e atualiza o cache.
  Future<List<CachedDocument>> refreshCache() async {
    QuerySnapshot snapshot = await queryBuilder(firestore, userId).get();
    List<CachedDocument> data = snapshot.docs.map((doc) {
      Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
      return CachedDocument(
        id: doc.id,
        data: docData,
        referencePath: doc.reference.path,
      );
    }).toList();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(data.map((e) => e.toJson()).toList()));
    return data;
  }

  /// Limpa o cache para a chave.
  Future<void> clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
  }

  // =================================================================
  // Métodos estáticos para gerenciar instâncias únicas por chave.
  // =================================================================

  static final Map<String, FirestoreCacheManager> _instances = {};

  /// Retorna a instância única do cache manager para a [cacheKey] informada.
  /// Se a instância ainda não existir, ela é criada e inicializada.
  static FirestoreCacheManager getInstance({
    required String cacheKey,
    required String collectionName,
    Query Function(FirebaseFirestore firestore, String userId)? queryBuilder,
  }) {
    if (_instances.containsKey(cacheKey)) {
      return _instances[cacheKey]!;
    } else {
      final instance = FirestoreCacheManager(
        collectionName: collectionName,
        cacheKey: cacheKey,
        queryBuilder: queryBuilder,
      );
      _instances[cacheKey] = instance;
      instance.initialize();
      return instance;
    }
  }

  /// Método estático para obter os dados em cache a partir da [cacheKey].
  /// Caso a instância não tenha sido criada, retorna um erro.
  static Future<List<CachedDocument>> getCachedDataByKey(String cacheKey) async {
    if (_instances.containsKey(cacheKey)) {
      return await _instances[cacheKey]!.getCachedData();
    } else {
      throw Exception("Nenhum cache manager encontrado para a chave: $cacheKey");
    }
  }
}
