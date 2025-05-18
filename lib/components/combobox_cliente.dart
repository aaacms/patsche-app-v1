import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:patsche_app/utils/cache_manager.dart';

class ClientDropdown extends StatelessWidget {
  final List<CachedDocument> clients;
  final CachedDocument? selectedClient;
  final void Function(CachedDocument?) onChanged;

  const ClientDropdown({
    Key? key,
    required this.clients,
    this.selectedClient,
    required this.onChanged,
  }) : super(key: key);

  // Filtra localmente a lista completa de clientes com base no nome.
  Future<List<String>> _getFilteredClients(String query) async {
    final filtered = clients.where((doc) {
      final nome =
          (doc.data['nome'] ?? '').toString();
      return nome.toLowerCase().contains(query.toLowerCase());
    }).toList();
    return filtered
        .map((doc) =>
            (doc.data['nome'] ?? '').toString())
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Exibe inicialmente os primeiros 5 clientes.
    final initialItems = clients
        .map((doc) =>
            (doc.data['nome'] ?? '').toString())
        .take(5)
        .toList();

    // Valor pré-selecionado caso esteja em modo edição.
    final preselectedValue = selectedClient != null
        ? (selectedClient!.data['nome'] ?? '')
            .toString()
        : null;

    return CustomDropdown<String>.searchRequest(
      futureRequest: _getFilteredClients,
      hintText: 'Selecione um cliente',
      items: initialItems,
      initialItem: preselectedValue,
      onChanged: (selectedValue) {
        // Procura o documento que corresponde ao nome selecionado.
        final selected = clients.firstWhere(
          (doc) {
            final nome =
                (doc.data['nome'] ?? '').toString();
            return nome == selectedValue;
          },
          orElse: () => throw Exception('Cliente não encontrado'),
        );
        onChanged(selected);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecione um cliente existente';
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
