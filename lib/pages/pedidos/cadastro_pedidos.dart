import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patsche_app/utils/cache_manager.dart';
import 'package:patsche_app/utils/whatsapp.dart';
import 'package:uuid/uuid.dart';

import '../../components/combobox_cliente.dart';
import '../../components/combobox_produto.dart';

class CadastroPedidos extends StatefulWidget {
  // Se 'order' for fornecido, estamos em modo de edição.
  final DocumentSnapshot? order;

  const CadastroPedidos({Key? key, this.order}) : super(key: key);

  @override
  _CadastroPedidosState createState() => _CadastroPedidosState();
}

class _CadastroPedidosState extends State<CadastroPedidos> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _pedidoNumberController;
  late TextEditingController _dataController;
  late TextEditingController _clientController; // Para o nome do cliente
  late TextEditingController _observacaoController;

  // Cliente selecionado via autocomplete (documento da coleção 'cliente')
  CachedDocument? _selectedClient;

  // Tipo de frete selecionado
  String _selectedFrete = 'VENDEDOR (11 leva)';
  final List<String> _freteOptions = [
    'TRANSP TIPO 1',
    'TRANSP TIPO 2',
    'ÔNIBUS',
    'VENDEDOR (11 leva)',
    'OUTROS'
  ];
  String _selectedUnity = 'm';
  final List<String> _unityOptions = ['un', 'Kg', 'm', 'pc', 'tb', 'cx'];

  // Lista de itens do pedido (cada item é um ItemEntry)
  final List<ItemEntry> _items = [];

  // Cache local das coleções para autocomplete
  List<CachedDocument> _clients = [];
  List<CachedDocument> _products = [];
  bool _isLoadingClients = false;
  bool _isLoadingProducts = false;

  // Variável para controlar se o pagamento foi realizado
  bool _isPagamento = false;

  Future<void> _inicializarNumeroPedido() async {
    List<CachedDocument> lastOrcamento =
        await FirestoreCacheManager.getCachedDataByKey('ultimoOrcamento');

    String numeroPedido = lastOrcamento.isNotEmpty ? lastOrcamento[0].id : '0';

    int incrementedNumeroPedido = int.parse(numeroPedido) + 1;
    _pedidoNumberController.text = incrementedNumeroPedido.toString();
  }

  @override
  void initState() {
    super.initState();
    _pedidoNumberController = TextEditingController();
    _dataController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    _clientController = TextEditingController();

    _fetchClients();
    _fetchProducts();
    _observacaoController = TextEditingController();

    if (widget.order != null) {
      // Modo de edição: pré-preenche os campos com os dados do pedido.
      final orderData = widget.order!.data() as Map<String, dynamic>;

      _pedidoNumberController.text =
          orderData['numeroPedido']?.toString() ?? widget.order!.id;

      if (orderData['data'] != null) {
        _dataController.text = DateFormat('dd/MM/yyyy')
            .format((orderData['data'] as Timestamp).toDate());
      } else {
        _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      }

      _selectedFrete = orderData['frete'] ?? _selectedFrete;
      _isPagamento = orderData['pagamento'] ?? _isPagamento;

      // Pré-carrega o cliente, se existir
      if (orderData['cliente'] != null) {
        final DocumentReference clientRef =
            orderData['cliente'] as DocumentReference;

        // Tenta obter os dados do cliente a partir do cache
        FirestoreCacheManager.getCachedDataByKey('clientes').then((cachedList) {
          CachedDocument? cachedClient;
          try {
            cachedClient = cachedList
                .firstWhere((doc) => doc.referencePath == clientRef.path);
          } catch (e) {
            cachedClient = null;
          }

          if (cachedClient != null) {
            // Se o cliente foi encontrado no cache, utiliza seus dados
            setState(() {
              _selectedClient = cachedClient;
              _clientController.text = cachedClient?.data['nome'] ?? '';
            });
          } else {
            // Se não estiver no cache, busca no Firestore
            clientRef.get().then((clientDoc) {
              setState(() {
                _selectedClient =
                    CachedDocument.fromDocumentSnapshot(clientDoc);
                final clientData = clientDoc.data() as Map<String, dynamic>;
                _clientController.text = clientData['nome'] ?? '';
              });
            });
          }
        });
      }

      if (orderData['observacao'] != null) {
        _observacaoController.text = orderData['observacao'] as String;
      }

      // Carrega os itens do pedido, se existirem.
      final List<dynamic> itensData =
          orderData['itens'] as List<dynamic>? ?? [];
      _items.clear();
      if (itensData.isNotEmpty) {
        for (var item in itensData) {
          final newItem = ItemEntry();
          final itemMap = item as Map<String, dynamic>;
          newItem.codigo = itemMap['codigo'] ?? 0; // Carrega o código salvo
          newItem.unitController.text = itemMap['unidade'] ?? '';
          newItem.quantityController.text =
              itemMap['quantidade']?.toString() ?? '';
          newItem.unitPriceController.text = itemMap['preco']?.toString() ?? '';
          newItem.total = (itemMap['total'] as num?)?.toDouble() ?? 0.0;
          newItem.productName = itemMap['nome_produto'] ?? '';
          _items.add(newItem);
        }
      } else {
        _items.add(ItemEntry());
      }
    } else {
      // Novo pedido: valores padrão.
      _inicializarNumeroPedido();
      _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      _items.add(ItemEntry());
    }
  }

  @override
  void dispose() {
    _pedidoNumberController.dispose();
    _dataController.dispose();
    _clientController.dispose();
    _observacaoController.dispose();
    for (var item in _items) {
      item.productController.dispose();
      item.unitController.dispose();
      item.quantityController.dispose();
      item.unitPriceController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    List<CachedDocument> cachedClients =
        await FirestoreCacheManager.getCachedDataByKey('clientes');

    _clients = cachedClients;
    setState(() {
      _isLoadingClients = false;
    });
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });
    List<CachedDocument> cachedProducts =
        await FirestoreCacheManager.getCachedDataByKey('produtos');
    _products = cachedProducts;
    setState(() {
      _isLoadingProducts = false;
    });
  }

  /// Atualiza o total de um item com base na quantidade e preço unitário
  void _updateItemTotal(ItemEntry entry) {
    final double quantity = double.tryParse(entry.quantityController.text) ?? 0;
    // Converte o preço unitário, substituindo vírgula por ponto
    final double unitPrice =
        double.tryParse(entry.unitPriceController.text.replaceAll(',', '.')) ??
            0;
    setState(() {
      entry.total = quantity * unitPrice;
    });
  }

  /// Soma os totais de todos os itens do pedido
  double get _orderTotal {
    double total = 0;
    for (var item in _items) {
      total += item.total;
    }
    return total;
  }

  Future<void> _savePedido(VoidCallback callback) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selecione um cliente válido")),
        );
        return;
      }
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Adicione pelo menos um item ao pedido")),
        );
        return;
      }

      // Monta a lista de itens para o pedido
      List<Map<String, dynamic>> itensData = [];
      for (var item in _items) {
        // Usa os dados do produto, se disponíveis; caso contrário, utiliza o texto do productController
        String nomeProduto;
        int codigo;
        if (item.product != null) {
          final productData = item.product!.data;
          codigo = productData['codigo'] ??
              int.tryParse(item.product!.id) ??
              item.codigo;
          nomeProduto = productData['nome'] ?? '';
        } else {
          nomeProduto = item.productController.text;
          codigo = item.codigo; // Usa o código previamente salvo
        }

        if (nomeProduto.isEmpty) continue;
        final quantidade = double.tryParse(item.quantityController.text) ?? 0;
        final double precoUnitario =
            double.parse(item.unitPriceController.text.replaceAll(',', '.'));

        final total = item.total;
        // Se a unidade não for alterada, utiliza _selectedUnity
        final unidade = item.unitController.text.isNotEmpty
            ? item.unitController.text
            : _selectedUnity;
        itensData.add({
          'codigo': codigo,
          'nome_produto': nomeProduto,
          'preco': precoUnitario,
          'quantidade': quantidade,
          'total': total,
          'unidade': unidade,
        });
      }

      // Dados do pedido, enviando _isPagamento e a data selecionada
      final pedidoData = {
        'cliente': _selectedClient!.reference,
        'data': Timestamp.fromDate(
          DateFormat('dd/MM/yyyy').parse(_dataController.text),
        ),
        'frete': _selectedFrete,
        'itens': itensData,
        'pagamento': _isPagamento,
        'total_orcamento': _orderTotal,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'observacao': _observacaoController.text,
      };

      if (widget.order != null) {
        // Atualiza o pedido existente
        FirebaseFirestore.instance
            .collection('orcamento')
            .doc(widget.order!.id)
            .update(pedidoData)
            .then((_) => callback());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pedido atualizado com sucesso!")),
        );
      } else {
        pedidoData['uuid'] = Uuid().v4();
        final pedidoNumber = _pedidoNumberController.text.trim();
        FirebaseFirestore.instance
            .collection('orcamento')
            .doc(pedidoNumber)
            .set(pedidoData)
            .then((_) => callback());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pedido cadastrado com sucesso!")),
        );
      }
      Navigator.pop(context);
    }
  }

  /// Widget que constrói o formulário de entrada de um item do pedido
  Widget _buildItemEntry(ItemEntry entry, int index) {
    if (!_isLoadingProducts && entry.codigo > 0) {
      final selected =
          _products.firstWhere((doc) => int.parse(doc.id) == entry.codigo);
      entry.product = selected;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item ${index + 1}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            // Autocomplete para selecionar um produto da base "produto"
            _isLoadingProducts
                ? const CircularProgressIndicator()
                : ProductDropdown(
                    products: _products,
                    selectedProductId:
                        entry.codigo, // Valor já selecionado (modo edição)
                    onChanged: (doc) {
                      setState(() {
                        entry.product = doc;
                        // Atualiza o campo com o nome do produto selecionado
                        entry.productController.text =
                            (doc!.data['nome'] ?? '').toString();
                        // Atualiza o preço unitário a partir do produto selecionado
                        final preco = doc.data['preco'];
                        entry.unitPriceController.text = preco.toString();
                        entry.emEstoque = doc.data['em_estoque'] ?? true;
                        entry.emLinha = doc.data['em_linha'] ?? true;

                        _updateItemTotal(entry);
                      });
                    },
                  ),
            const SizedBox(height: 5),
            if (!entry.emEstoque)
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(7.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  "Este produto está fora de estoque",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            const SizedBox(height: 5),
            if (!entry.emLinha)
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(7.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  "Este produto está fora de linha",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              // Se o unitController já tem um valor, usa-o; caso contrário, usa _selectedUnity
              value: entry.unitController.text.isNotEmpty
                  ? entry.unitController.text
                  : _selectedUnity,
              decoration: const InputDecoration(labelText: 'Unidade'),
              items: _unityOptions
                  .map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  entry.unitController.text = value!;
                });
              },
            ),

            TextFormField(
              controller: entry.quantityController,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _updateItemTotal(entry);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe a quantidade';
                }
                if (double.tryParse(value) == null) {
                  return 'Informe um número válido';
                }
                return null;
              },
            ),
            TextFormField(
              controller: entry.unitPriceController,
              decoration: const InputDecoration(labelText: 'Preço Unitário'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Se o usuário digitar um ponto, substitua por vírgula.
                if (value.contains('.')) {
                  final newValue = value.replaceAll('.', ',');
                  entry.unitPriceController.value =
                      entry.unitPriceController.value.copyWith(
                    text: newValue,
                    selection: TextSelection.collapsed(offset: newValue.length),
                  );
                }
                _updateItemTotal(entry);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o preço unitário';
                }
                // Converter a string para double substituindo vírgula por ponto.
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return 'Informe um número válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),
            Text(
              'Total do item: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(entry.total)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.order != null ? 'Editar Pedido' : 'Cadastro de Pedidos'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Número do Pedido
              TextFormField(
                controller: _pedidoNumberController,
                decoration:
                    const InputDecoration(labelText: 'Número do Pedido'),
                keyboardType: TextInputType.number,
                // Caso queira que o campo seja apenas para exibição, pode definir enabled: false
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o número do pedido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Data com DatePicker
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(labelText: 'Data'),
                readOnly: true,
                onTap: () async {
                  DateTime initialDate;
                  try {
                    initialDate =
                        DateFormat('dd/MM/yyyy').parse(_dataController.text);
                  } catch (_) {
                    initialDate = DateTime.now();
                  }
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dataController.text =
                          DateFormat('dd/MM/yyyy').format(pickedDate);
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              // Autocomplete para selecionar o Cliente
              _isLoadingClients
                  ? const CircularProgressIndicator()
                  : ClientDropdown(
                      clients: _clients,
                      selectedClient: _selectedClient,
                      onChanged: (doc) {
                        setState(() {
                          _selectedClient = doc;
                        });
                      },
                    ),

              const SizedBox(height: 10),
              // Dropdown para selecionar o tipo de frete
              DropdownButtonFormField<String>(
                value: _selectedFrete,
                decoration: const InputDecoration(labelText: 'Tipo de Frete'),
                items: _freteOptions
                    .map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFrete = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Switch para indicar se o pagamento foi realizado
              SwitchListTile(
                title: const Text('Pagamento Realizado'),
                value: _isPagamento,
                onChanged: (bool value) {
                  setState(() {
                    _isPagamento = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Itens do Pedido:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Lista dinâmica de itens
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return Dismissible(
                    key: Key(_items[index].hashCode.toString()),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: _buildItemEntry(_items[index], index),
                  );
                },
              ),

              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _items.add(ItemEntry());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar novo item'),
              ),
              const SizedBox(height: 16),
              Text(
                'Total do Pedido: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_orderTotal)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _observacaoController,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  hintText: 'Digite aqui a observação do pedido',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Aguarda o salvamento do pedido
                    await _savePedido(() async {
                      // Determina o ID do pedido salvo

                      final pedidoId = widget.order != null
                          ? widget.order!.id
                          : _pedidoNumberController.text.trim();

                      // Obtém o documento salvo do Firestore
                      final savedDoc = await FirebaseFirestore.instance
                          .collection('orcamento')
                          .doc(pedidoId)
                          .get();

                      // Formata a mensagem com os dados do pedido
                      final message = await Whatsapp.formatPedidoMessage(
                          savedDoc,
                          "Acessando o link abaixo é possível visualizar o orçamento:\n\n");

                      // Envia a mensagem para o número desejado
                      Whatsapp.sendMessage("55991529409", message);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Salvar Pedido e enviar para a loja'),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => {_savePedido(() => {})},
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Salvar Pedido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Classe que representa a entrada de um item do pedido.
class ItemEntry {
  CachedDocument? product;
  String? productName;
  int codigo = 0; // Adicionado para armazenar o código do produto
  TextEditingController productController = TextEditingController();
  TextEditingController unitController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  bool emEstoque = true;
  bool emLinha = true;

  double total = 0.0;
}
