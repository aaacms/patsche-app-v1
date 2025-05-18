import 'dart:async';

import 'package:patsche_app/pages/pedidos/card_pedido.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../drawer.dart';
import '../fab.dart';
import 'cadastro_pedidos.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  _PedidosPageState createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  String searchQuery = '';
  Timer? _debounce;
  final Duration debounceDuration = const Duration(milliseconds: 750);

  // Configuração da paginação
  final int pageSize = 10;
  List<DocumentSnapshot> pedidos = [];
  bool isLoading = false;
  bool hasMore = true;
  DocumentSnapshot? lastDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPedidos();

    // Carrega mais pedidos automaticamente ao rolar até próximo do final
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _loadPedidos();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(debounceDuration, () {
      setState(() {
        searchQuery = query;
        // Reinicia a paginação ao alterar a busca
        pedidos.clear();
        lastDocument = null;
        hasMore = true;
      });
      _loadPedidos();
    });
  }

  Future<void> _refreshPedidos() async {
    setState(() {
      pedidos.clear();
      lastDocument = null;
      hasMore = true;
    });
    await _loadPedidos();
  }

  Future<void> _loadPedidos() async {
    if (!hasMore) return;
    setState(() => isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Trate o caso de usuário não autenticado, se necessário.
      setState(() => isLoading = false);
      return;
    }

    Query query;
    if (searchQuery.isNotEmpty) {
      // Se houver pesquisa, adiciona o filtro pelo userId e pesquisa pelo documentId.
      query = FirebaseFirestore.instance
          .collection('orcamento')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy(FieldPath.documentId)
          .startAt([searchQuery]).endAt(['$searchQuery\uf8ff']).limit(pageSize);
    } else {
      // Caso não esteja pesquisando, filtra pelos pedidos do usuário e ordena por data (descendente)
      query = FirebaseFirestore.instance
          .collection('orcamento')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('data', descending: true)
          .limit(pageSize);
    }

    // Aplica a paginação somente se não estiver pesquisando
    if (lastDocument != null && searchQuery.isEmpty) {
      query = query.startAfterDocument(lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();

    if (querySnapshot.docs.length < pageSize) {
      hasMore = false;
    }

    if (querySnapshot.docs.isNotEmpty) {
      lastDocument = querySnapshot.docs.last;
      pedidos.addAll(querySnapshot.docs);
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Como a pesquisa já é feita no Firebase, usamos diretamente a lista 'pedidos'
    return Scaffold(
      appBar: AppBar(
        title: const Text('PEDIDOS'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      drawer: const CustomDrawer(),
      floatingActionButton: CustomFAB(() async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CadastroPedidos()),
        );
        _refreshPedidos();
      }),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Digite o número do pedido...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Lista de pedidos paginada
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPedidos,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: pedidos.length + 1,
                itemBuilder: (context, index) {
                  if (index < pedidos.length) {
                    return CardPedido(doc: pedidos[index]);
                  } else {
                    if (hasMore) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loadPedidos,
                                  child: const Text('Carregar mais'),
                                ),
                        ),
                      );
                    } else {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child:
                            Center(child: Text('Todos os pedidos carregados')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
