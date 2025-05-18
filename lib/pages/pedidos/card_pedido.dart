import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patsche_app/utils/whatsapp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/cache_manager.dart';
import 'cadastro_pedidos.dart';

class CardPedido extends StatelessWidget {
  final DocumentSnapshot doc;

  CardPedido({super.key, required this.doc});

  final currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final ScrollController scrollController = ScrollController();

  void _showPedidoDetails(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp? timestamp = data['data'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
        : 'Data não definida';
    final String frete = data['frete'] ?? '';
    final totalOrcamento = data['total_orcamento'] ?? 0;
    final formattedTotal = currencyFormatter.format(totalOrcamento);
    final DocumentReference? clientRef = data['cliente'] as DocumentReference?;
    final List<dynamic> itens = data['itens'] as List<dynamic>? ?? [];
    final bool pagamento = data['pagamento'] as bool? ?? false;
    final String observacao = data['observacao'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Pedido ${doc.id}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Data: $formattedDate"),
                clientRef != null
                    ? FutureBuilder<List<CachedDocument>>(
                        future: FirestoreCacheManager.getCachedDataByKey(
                            'clientes'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text("Carregando cliente...");
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text("Cliente não definido");
                          }
                          // Procura no cache o documento que possui o mesmo caminho que o clientRef.
                          CachedDocument? clientCachedDoc;
                          try {
                            clientCachedDoc = snapshot.data!.firstWhere(
                                (doc) => doc.referencePath == clientRef.path);
                          } catch (e) {
                            clientCachedDoc = null;
                          }
                          if (clientCachedDoc == null) {
                            return const Text("Cliente não definido");
                          }
                          final clientData = clientCachedDoc.data;
                          final clientName =
                              clientData['nome'] ?? 'Nome não definido';
                          return Text("Cliente: $clientName");
                        },
                      )
                    : const Text("Cliente: Não definido"),

                const SizedBox(height: 12),
                Text("Frete: $frete"),
                const SizedBox(height: 12),
                const Text(
                  "Itens do Pedido:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Scrollbar(
                  thumbVisibility: true,
                  controller: scrollController,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: scrollController,
                    child: DataTable(
                      columns: [
                        DataColumn(
                          label: Container(
                            width: 100,
                            child: const Text(
                              "Produto",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Container(
                            width: 40,
                            child: const Text(
                              "Qtd",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Container(
                            width: 100,
                            child: const Text(
                              "Total",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      rows: itens.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final nomeProduto = itemMap['nome_produto'] ?? '';
                        final quantidade = itemMap['quantidade'] ?? 0;
                        final double quantidadeDouble = quantidade is int
                            ? quantidade.toDouble()
                            : quantidade;
                        final formattedQuantidade = quantidadeDouble
                            .toStringAsFixed(1)
                            .replaceAll('.', ',');
                        final unidade = itemMap['unidade'] ?? 0;

                        final total = itemMap['total'] ?? 0;
                        return DataRow(cells: [
                          DataCell(Text(nomeProduto)),
                          DataCell(
                            Container(
                              width: 50,
                              child: Text(
                                "$formattedQuantidade $unidade",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 100,
                              child: Text(
                                currencyFormatter.format(total),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Total do Orçamento: $formattedTotal",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: pagamento ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pagamento ? 'Pago' : 'Não Pago',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (observacao != "") Text("Observação: $observacao"),

                const SizedBox(height: 25),

                ElevatedButton.icon(
                  onPressed: () async {
                    // Formata a mensagem com os dados do pedido
                    final message = await Whatsapp.formatPedidoMessage(doc,
                        "Acessando o link abaixo é possível visualizar o orçamento:\n\n");

                    // Envia a mensagem utilizando a função utilitária (assumindo que ela esteja implementada)
                    Whatsapp.sendMessage("55991529409", message);
                  },
                  icon: Image.asset(
                    'assets/whatsapp.png',
                    width: 25,
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromRGBO(50, 217, 81, 1)),
                  label: const Text(
                    'Enviar para a loja',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (data['cliente'] != null) {
                      final DocumentReference clientRef =
                          data['cliente'] as DocumentReference;
                      final clientDoc = await clientRef.get();
                      final clientData =
                          clientDoc.data() as Map<String, dynamic>;
                      final phoneNumber =
                          clientData['telefone']?.toString().trim() ?? '';

                      if (phoneNumber.isNotEmpty) {
                        final message = await Whatsapp.formatPedidoMessage(doc,
                            "Olá, ${clientData['nome']}, aqui é o vendedor Evandro da empresa Patsche, acessando o link abaixo é possível visualizar a ficha do seu orçamento:\n\n");
                        Whatsapp.sendMessage(phoneNumber, message);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Telefone do cliente não encontrado")),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cliente não definido")),
                      );
                    }
                  },
                  icon: Image.asset(
                    'assets/whatsapp.png',
                    width: 25,
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromRGBO(50, 217, 81, 1)),
                  label: const Text(
                    'Enviar para o cliente',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () async {
                    final String uuid =
                        data['uuid']; // ou data.uuid, se for objeto
                    final Uri fichaUri =
                        Uri.parse('https://patsche.com.br/orcamento/$uuid');
                    if (!await launchUrl(
                      fichaUri,
                      mode: LaunchMode
                          .externalApplication, // abre no navegador externo
                    )) {
                      // Caso falhe, você pode mostrar um aviso
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Não foi possível abrir o link')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text(
                    'Visualizar ficha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // TextButton(
                //   onPressed: () async {
                //     final bool? confirm = await showDialog<bool>(
                //       context: context,
                //       builder: (context) => AlertDialog(
                //         title: const Text('Excluir Pedido'),
                //         content: const Text(
                //             'Tem certeza que deseja excluir esse pedido?'),
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
                //       await FirebaseFirestore.instance
                //           .collection('orcamento')
                //           .doc(doc.id)
                //           .delete();

                //       ScaffoldMessenger.of(context).showSnackBar(
                //         const SnackBar(
                //             content: Text('Pedido excluído com sucesso!')),
                //       );
                //       Navigator.pop(context);
                //     }
                //   },
                //   child: const Text('Excluir Pedido'),
                // ),
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
                    builder: (context) => CadastroPedidos(order: doc),
                  ),
                );
              },
              child: const Text('Editar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final pedidoNumber = doc.id;
    final Timestamp? timestamp = data['data'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
        : 'Data não definida';
    final String frete = data['frete'] ?? '';
    final totalOrcamento = data['total_orcamento'] ?? 0;
    final formattedTotal = currencyFormatter.format(totalOrcamento);
    final bool pagamento = data['pagamento'] as bool? ?? false;
    final DocumentReference? clientRef = data['cliente'] as DocumentReference?;

    return InkWell(
      onTap: () => _showPedidoDetails(context, doc),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmall = constraints.maxWidth < 300;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.0),
              border:
                  Border.all(width: 0.7, color: Colors.grey.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
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
                // Linha superior: número do pedido e data
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "#$pedidoNumber",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                // const SizedBox(height: 8),
                !isSmall
                    ? FutureBuilder<List<CachedDocument>>(
                        future: FirestoreCacheManager.getCachedDataByKey(
                            'clientes'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text("Carregando cliente...");
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text("Cliente não definido");
                          }
                          // Procura no cache o documento que possui o mesmo caminho que o clientRef.
                          CachedDocument? clientCachedDoc;
                          try {
                            clientCachedDoc = snapshot.data!.firstWhere(
                                (doc) => doc.referencePath == clientRef?.path);
                          } catch (e) {
                            clientCachedDoc = null;
                          }
                          if (clientCachedDoc == null) {
                            return const Text("Cliente não definido");
                          }
                          final clientData = clientCachedDoc.data;
                          final clientName =
                              clientData['nome'] ?? 'Nome não definido';
                          return Text("$clientName",
                              style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold));
                        },
                      )
                    : const SizedBox(),
                const SizedBox(height: 4),
                Text(
                  frete,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 4),
                isSmall
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedTotal,
                            style: const TextStyle(
                                fontSize: 18, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pagamento ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pagamento ? 'Pago' : 'Não Pago',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedTotal,
                            style: const TextStyle(
                                fontSize: 18, color: Colors.black),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pagamento ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pagamento ? 'Pago' : 'Não Pago',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
