import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Whatsapp {
  static void sendMessage(String phoneNumber, String message) async {
    var contact = "+55$phoneNumber";
    var encodedMessage = Uri.encodeComponent(message);

    var androidUrl = "whatsapp://send?phone=$contact&text=$encodedMessage";
    var iosUrl = "https://wa.me/$contact?text=$encodedMessage";

    try {
      if (Platform.isIOS) {
        await launchUrl(Uri.parse(iosUrl));
      } else {
        await launchUrl(Uri.parse(androidUrl));
      }
    } on Exception {
      print("Falha na abertura do WhatsApp!");
    }
  }

  static Future<String> formatPedidoMessage(DocumentSnapshot doc, String intro) async {
    final data = doc.data() as Map<String, dynamic>;
    final pedidoNumber = doc.id;

    // Formata a data do pedido
    final Timestamp? timestamp = data['data'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
        : "Data não definida";
    final uuid = data['uuid'];
    // Informações do pedido
    final String frete = data['frete'] ?? "";
    // final double totalOrcamento = data['total_orcamento'] != null
    //     ? (data['total_orcamento'] as num).toDouble()
    //     : 0.0;
    // final String formattedTotal = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(totalOrcamento);
    // final bool pagamento = data['pagamento'] as bool? ?? false;
    // final String pagamentoStatus = pagamento ? "Pago" : "Pendente de pagamento";
    String observacao = data['observacao'] ?? "";
    if (observacao != "") {
      observacao =
          "-----------------------------------\n\n*OBSERVAÇÃO:*\n" + observacao;
    }

    // Recupera informações do cliente
    String clientName = "Não definido";
    String clientNumber = "Não definido";
    String clientCity = "Não definida";
    String clientEstado = "Não definido";
    final DocumentReference? clientRef = data['cliente'] as DocumentReference?;
    if (clientRef != null) {
      try {
        final clientDoc = await clientRef.get();
        if (clientDoc.exists) {
          final clientData = clientDoc.data() as Map<String, dynamic>;
          clientName = clientData['nome'] ?? "Não definido";
          // Adiciona o id do documento do cliente (número do cliente)
          clientNumber = clientDoc.id;
          // Adiciona a cidade do cliente
          clientCity = clientData['cidade'] ?? "Não definida";
          clientEstado = clientData['estado'] ?? "Não definida";
        }
      } catch (e) {
        clientName = "Erro ao carregar cliente";
      }
    }

    // Processa os itens do pedido
    List<dynamic> itens = data['itens'] as List<dynamic>? ?? [];
    String itensMessage = "";
    for (var item in itens) {
      final itemMap = item as Map<String, dynamic>;
      final String nomeProduto = itemMap['nome_produto'] ?? "";
      final dynamic quantidade = itemMap['quantidade'] ?? 0;
      final dynamic preco = itemMap['preco'] ?? 0;
      // final dynamic totalItem = itemMap['total'] ?? 0;
      final String unidade = itemMap['unidade'] ?? "";

      // Formata o preço unitário e o preço total dos itens
      final String formattedPreco = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: 'R\$',
      ).format((preco as num).toDouble());
      // final String formattedTotalItem = NumberFormat.currency(
      //   locale: 'pt_BR',
      //   symbol: 'R\$',
      // ).format((totalItem as num).toDouble());

      itensMessage +=
          " - $nomeProduto\nQtd: $quantidade $unidade\nPreço Unitário: $formattedPreco\n\n\n";
      // " - $nomeProduto\nQtd: $quantidade $unidade\nPreço Unitário: $formattedPreco\n*Preço total:* $formattedTotalItem\n\n\n";
    }

    // Monta a mensagem final com as novas informações do cliente e formatação dos valores
    final String message = "*NOVO PEDIDO:* $pedidoNumber\n"
        "Data: $formattedDate\n\n"
        "$intro\nhttps://patsche.com.br/orcamento/$uuid"
        "\n-----------------------------------\n"
        "\n*CLIENTE:*\n"
        "$clientNumber - $clientName\n"
        "Cidade: $clientCity, $clientEstado\n"
        "\n-----------------------------------\n"
        "\n*FRETE:*\n$frete\n"
        "\n-----------------------------------\n"
        "\n*ITENS DO PEDIDO:*\n"
        "\n$itensMessage"
        // "-----------------------------------\n"
        // "\n*TOTAL:*\n"
        // "$formattedTotal"
        "$observacao"
        // "$pagamentoStatus"
        ;

    return message;
  }
}
