import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:patsche_app/utils/cache_manager.dart';

class ProductDropdown extends StatelessWidget {
  final List<CachedDocument> products;
  final int? selectedProductId;
  final void Function(CachedDocument?) onChanged;

  const ProductDropdown({
    Key? key,
    required this.products,
    this.selectedProductId,
    required this.onChanged,
  }) : super(key: key);

  // Filtra localmente a lista completa de produtos com base no nome.
  Future<List<String>> _getFilteredProducts(String query) async {
    final filtered = products.where((doc) {
      final nome =
          (doc.data['nome'] ?? '').toString();
      return nome.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return filtered
        .map((doc) =>
            (doc.data['nome'] ?? '').toString())
        .take(30)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Exibe inicialmente os primeiros 5 produtos.
    final initialItems = products
        .map((doc) =>
            (doc.data['nome'] ?? '').toString())
        .take(30)
        .toList();

    // Valor pré-selecionado, se estiver em modo edição.
    String? preselectedValue;

    if (selectedProductId != null && selectedProductId! > 0) {
      final selected =
          products.firstWhere((doc) => int.parse(doc.id) == selectedProductId);
      preselectedValue = selected.data['nome'];
    }

    return CustomDropdown<String>.searchRequest(
      futureRequest: _getFilteredProducts,
      hintText: 'Selecione um produto',
      items: initialItems,
      initialItem: preselectedValue,
      onChanged: (selectedValue) {
        // Procura o documento que corresponde ao nome selecionado.
        final selected = products.firstWhere(
          (doc) {
            final nome =
                (doc.data['nome'] ?? '').toString();
            return nome == selectedValue;
          },
          orElse: () => throw Exception('Produto não encontrado'),
        );
        onChanged(selected);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecione um produto';
        }
        return null;
      },
      searchHintText: "Pesquisar",
      decoration: CustomDropdownDecoration(
        closedBorder: Border.all(color: Colors.black, width: 1),
      ),
    );
  }
}
