import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patsche_app/pages/clientes/cadastro_clientes.dart';
import 'package:patsche_app/pages/pedidos/card_pedido.dart';
import 'package:patsche_app/utils/cache_manager.dart';
import 'package:patsche_app/utils/whatsapp.dart';

import '../drawer.dart';
import '../fab.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  _ClientesPageState createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String searchQuery = '';
  Timer? _debounce;
  final Duration debounceDuration = const Duration(milliseconds: 750);

  // Configurações de paginação
  final int pageSize = 10;
  List<CachedDocument> clientes = [];
  List<CachedDocument> _allClients = [];
  bool _isLoadingClients = false;
  bool isLoading = false;
  bool hasMore = true;
  int lastIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchClients();

    // Carrega mais clientes automaticamente ao chegar próximo do final da lista
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        _loadClientes();
      }
    });
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    _allClients = await FirestoreCacheManager.getCachedDataByKey('clientes');

    setState(() {
      _isLoadingClients = false;
    });

    _loadClientes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce para não disparar várias vezes seguidas
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(debounceDuration, () {
      if (!mounted) return;

      setState(() {
        searchQuery = query; // ou .toUpperCase(), conforme seu filtro
        clientes.clear(); // limpa a lista atual
        lastIndex = 0; // reseta o cursor
        hasMore = true; // habilita nova paginação
      });

      // carrega a primeira “página” com o novo filtro
      _loadClientes();
    });
  }

  Future<void> _loadClientes() async {
    if (!hasMore || isLoading) return;
    setState(() => isLoading = true);

    // 1) filtra por userId e prefixo de nome_lower
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final filtered = _allClients.where((cd) {
      final data = cd.data;
      // filtra pelo usuário
      if (data['userId'] != userId) return false;
      // se houver busca, filtra prefixo (case-insensitive)
      final nome = (data['nome_lower'] as String);
      return searchQuery.isEmpty || nome.startsWith(searchQuery.toLowerCase());
    }).toList();

    // 2) ordena por 'nome_lower'
    filtered.sort((a, b) => (a.data['nome_lower'] as String)
        .compareTo(b.data['nome_lower'] as String));

    // 3) calcula índices da página atual
    final start = lastIndex;
    final end = min(start + pageSize, filtered.length);
    final pageItems = filtered.sublist(start, end);

    // 4) atualiza a lista, cursor e flags
    clientes.addAll(pageItems);
    lastIndex = end;
    if (end >= filtered.length) hasMore = false;

    setState(() => isLoading = false);
  }

  Future<void> _refreshClientes() async {
    setState(() {
      clientes.clear();
      lastIndex = 0;
      hasMore = true;
    });
    await _fetchClients();
  }

  // Exibe uma janela flutuante com os detalhes do cliente e seus pedidos
  void _showClientDetails(CachedDocument doc) {
    final data = doc.data;
    final Timestamp? birthTimestamp = data['data_nascimento'] as Timestamp?;
    final formattedBirthDate = birthTimestamp != null
        ? DateFormat('dd/MM/yyyy').format(birthTimestamp.toDate())
        : 'Não definido';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(doc.id),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dados básicos do cliente
                Text("${data['nome'] ?? ''}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),

                Text("Telefone: ${data['telefone'] ?? ''}"),

                Text("Região: ${data['regiao']?.toString() ?? ''}"),

                if (data['cnpj'].isNotEmpty ||
                    data['data_nascimento'] != null ||
                    data['email'].isNotEmpty)
                  const SizedBox(height: 20),

                if (data['cnpj'].isNotEmpty)
                  Text("CNPJ: ${data['cnpj'] ?? ''}"),

                if (data['data_nascimento'] != null)
                  Text("Data de Nascimento: $formattedBirthDate"),

                if (data['email'].isNotEmpty)
                  Text("Email: ${data['email'] ?? ''}"),

                const SizedBox(height: 20),

                if (data['endereco'].isNotEmpty &&
                    data['numero'] != null &&
                    data['bairro'].isNotEmpty &&
                    data['cep'].isNotEmpty)
                  Text("Endereço:",
                      style: const TextStyle(fontWeight: FontWeight.bold)),

                if (data['endereco'].isNotEmpty && data['numero'] != null)
                  Text(
                      "${data['endereco'] ?? ''}, ${data['numero']?.toString() ?? ''}"),

                if (data['bairro'].isNotEmpty) Text("${data['bairro'] ?? ''}"),

                Text("${data['cidade'] ?? ''}, ${data['estado'] ?? ''}"),

                if (data['cep'].isNotEmpty) Text("${data['cep'] ?? ''}"),

                const SizedBox(height: 20),
                // Seção dos pedidos relacionados
                const Text("Pedidos do Cliente:",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orcamento')
                      .where('userId',
                          isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .where('cliente', isEqualTo: doc.reference)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("Nenhum pedido encontrado");
                    }
                    final orders = snapshot.data!.docs;
                    return SizedBox(
                      width: double.maxFinite,
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return CardPedido(doc: orders[index]);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 5),
                ElevatedButton.icon(
                  onPressed: () => Whatsapp.sendMessage(
                      data['telefone'], "Olá, " + data['nome'] + "!"),
                  icon: Image.asset(
                    'assets/whatsapp.png',
                    width: 25,
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromRGBO(50, 217, 81, 1)),
                  label: const Text(
                    'Entrar em contato',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Fecha o diálogo
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CadastroCliente(cliente: doc),
                  ),
                );
                _refreshClientes();
              },
              child: const Text('Editar'),
            ),
            // TextButton(
            //   onPressed: () async {
            //     // Exibe um diálogo de confirmação
            //     final bool? confirm = await showDialog<bool>(
            //       context: context,
            //       builder: (context) => AlertDialog(
            //         title: const Text('Excluir'),
            //         content: const Text(
            //             'Tem certeza que deseja excluir esse cliente?'),
            //         actions: [
            //           TextButton(
            //             onPressed: () => Navigator.pop(context, false),
            //             child: const Text('Cancelar'),
            //           ),
            //           TextButton(
            //             onPressed: () => Navigator.pop(context, true),
            //             child: const Text('Excluir'),
            //           ),
            //         ],
            //       ),
            //     );

            //     if (confirm == true) {
            //       // Exclui o documento do Firestore usando o ID do cliente (_codigoController.text)
            //       await FirebaseFirestore.instance
            //           .collection('cliente')
            //           .doc(doc.id)
            //           .delete();

            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(
            //             content: Text('Cliente excluído com sucesso!')),
            //       );
            //       Navigator.pop(context);
            //     }
            //   },
            //   child: const Text('Excluir Cliente'),
            // ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  // Constrói o card de cada cliente
  Widget _buildClientCard(CachedDocument doc) {
    final data = doc.data;
    final clientNumber = doc.id;
    final clientName = data['nome'] ?? 'Nome não definido';
    final clientRegion = data['regiao'] ?? '';
    final clientFoneNumber = data['telefone'] ?? '';
    final clientCity = data['cidade'] ?? '';
    final clientState = data['estado'] ?? '';

    return InkWell(
      onTap: () => _showClientDetails(doc),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(width: 0.7, color: Colors.grey.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(128),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primeira linha: Nome e Número
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  clientNumber,
                  style: const TextStyle(fontSize: 24, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Segunda linha: Telefone
            Text(
              clientFoneNumber,
              style: const TextStyle(fontSize: 20, color: Colors.black),
            ),
            // Terceira linha: Região
            Text(
              'Região $clientRegion',
              style: const TextStyle(fontSize: 20, color: Colors.black),
            ),
            // Quarta linha: Cidade e Estado
            Text(
              '$clientCity, $clientState',
              style: const TextStyle(fontSize: 20, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aqui não fazemos filtragem local, pois a pesquisa já é feita no Firebase
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLIENTES'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      drawer: const CustomDrawer(),
      floatingActionButton: CustomFAB(() async {
        // Navega para o cadastro e, ao retornar, atualiza a lista
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CadastroCliente()),
        );
        //set time out to allow the page to load
        await Future.delayed(const Duration(milliseconds: 500));
        _refreshClientes();
      }),
      body: Column(
        children: [
          // Barra de pesquisa
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Digite o nome do cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Text(
            'Total de clientes: ${_allClients.length}',
            style: const TextStyle(fontSize: 12),
          ),
          // Lista de clientes com RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshClientes,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: clientes.length + 1,
                itemBuilder: (context, index) {
                  if (index < clientes.length) {
                    return _buildClientCard(clientes[index]);
                  } else {
                    // Último item: botão "Carregar mais" ou indicador final
                    if (hasMore) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loadClientes,
                                  child: const Text('Carregar mais'),
                                ),
                        ),
                      );
                    } else {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('Todos os clientes carregados'),
                        ),
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
