import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patsche_app/utils/cache_manager.dart';

import 'drawer.dart';

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  _ProdutosPageState createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  String searchQuery = '';
  Timer? _debounce;
  final Duration debounceDuration = const Duration(milliseconds: 1500);

  // Formatter para exibir valores em Real
  final currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // Configurações para paginação
  final int pageSize = 10;
  List<CachedDocument> produtos = [];
  List<CachedDocument> _allProducts = [];
  bool isLoading = false;
  bool hasMore = true;
  int lastIndex = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProdutos();

    // Carrega automaticamente ao rolar até próximo do final da lista
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _loadProdutos();
      }
    });
  }

  Future<void> _fetchProdutos() async {
    _allProducts = await FirestoreCacheManager.getCachedDataByKey('produtos');
    _loadProdutos();
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
        searchQuery = query.toUpperCase();
        // Reinicia a paginação ao alterar a busca
        produtos.clear();
        lastIndex = 0;
        hasMore = true;
      });
      _loadProdutos();
    });
  }

  Future<void> _loadProdutos() async {
    if (!hasMore) return;
    setState(() => isLoading = true);

    // 1) filtra pelo nome (prefixo, case-insensitive)
    final filtered = _allProducts.where((cd) {
      final nome = (cd.data['nome'] as String).toUpperCase();
      return searchQuery.isEmpty || nome.startsWith(searchQuery);
    }).toList();

    // 2) ordena por 'nome'
    filtered.sort((a, b) =>
        (a.data['nome'] as String).compareTo(b.data['nome'] as String));

    // 3) calcula índices da “página” atual
    final start = lastIndex;
    final end = (start + pageSize < filtered.length)
        ? start + pageSize
        : filtered.length;
    final pageItems = filtered.sublist(start, end);

    // 4) atualiza flags e cursor
    produtos.addAll(pageItems);
    lastIndex = end;
    if (end >= filtered.length) hasMore = false;

    setState(() => isLoading = false);
  }

  Widget _buildProdutoCard(CachedDocument doc) {
    final data = doc.data;
    final productName = data['nome'] ?? 'Produto sem nome!';
    final priceNumber = data['preco'] is num ? data['preco'] as num : 0;
    final formattedPrice = currencyFormatter.format(priceNumber);
    final bool emLinha = data['em_linha'] as bool? ?? false;
    final bool emEstoque = data['em_estoque'] as bool? ?? false;
    final category = data['categoria'] as String? ?? 'Sem categoria';

    // Define os status conforme os booleanos
    final statusEmLinha = emLinha ? "Em Linha" : "Fora de Linha";
    final statusEmEstoque = emEstoque ? "Em Estoque" : "Em Falta";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.grey.withAlpha(128), width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(128),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Alinha o texto à esquerda
        children: [
          // Nome do produto
          Text(
            productName,
            maxLines: 2,
            style: const TextStyle(fontSize: 18, color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: switch (category) {
                'AUTOMOTIVO' => Colors.purple.shade100,
                'GERAL' => Colors.pink.shade100,
                'GRAMPOS/PINOS' => Colors.blue.shade100,
                'TECIDO' => Colors.orange.shade100,
                _ => Colors.grey,
              },
              borderRadius: BorderRadius.circular(7.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 14,
                color: switch (category) {
                  'AUTOMOTIVO' => Colors.purple.shade900,
                  'GERAL' => Colors.pink.shade900,
                  'GRAMPOS/PINOS' => Colors.blue.shade900,
                  'TECIDO' => Colors.orange.shade900,
                  _ => Colors.black,
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Linha com status e preço
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status (fora de linha e em estoque)
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: emLinha ? Colors.green[200] : Colors.red[200],
                      borderRadius: BorderRadius.circular(7.0),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    child: Text(
                      statusEmLinha,
                      style: TextStyle(
                        fontSize: 14,
                        color: emLinha ? Colors.green[900] : Colors.red[900],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: emEstoque ? Colors.green[200] : Colors.red[200],
                      borderRadius: BorderRadius.circular(7.0),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    child: Text(
                      statusEmEstoque,
                      style: TextStyle(
                        fontSize: 14,
                        color: emEstoque ? Colors.green[900] : Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
              // Preço do produto
              Text(
                formattedPrice,
                style: const TextStyle(fontSize: 20, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Como a pesquisa já é feita no Firebase, usamos diretamente a lista 'produtos'
    return Scaffold(
      appBar: AppBar(
        title: const Text('PRODUTOS'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Digite o nome do produto...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Lista de produtos paginada
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: produtos.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < produtos.length) {
                  return _buildProdutoCard(produtos[index]);
                } else {
                  if (hasMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _loadProdutos,
                                child: const Text('Carregar mais'),
                              ),
                      ),
                    );
                  } else {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('Todos os produtos carregados'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
