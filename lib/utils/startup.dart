import 'package:cloud_firestore/cloud_firestore.dart';

import 'cache_manager.dart';

void OnStartup() async {
   FirestoreCacheManager.getInstance(
    cacheKey: 'clientes',
    collectionName: 'cliente',
    queryBuilder: (firestore, userId) =>
        firestore.collection('cliente').where('userId', isEqualTo: userId),
  );
  FirestoreCacheManager.getInstance(
    cacheKey: 'produtos',
    collectionName: 'produto',
  );
  FirestoreCacheManager.getInstance(
    cacheKey: 'ultimoOrcamento',
    collectionName: 'orcamento',
    queryBuilder: (firestore, userId) =>
        firestore.collection('orcamento').where('userId', isEqualTo: userId).orderBy(FieldPath.documentId, descending: true).limit(1),
  );
}
