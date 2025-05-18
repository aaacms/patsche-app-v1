import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  // Função para abrir uma URL externa
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Não foi possível abrir $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sobre"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Texto explicativo sobre o projeto (parte superior)
            const Text(
              "O app_vendas é um projeto de um aplicativo de vendas desenvolvido para facilitar a gestão de clientes, pedidos e produtos pelos vendedores. "
              "Nele é possível visualizar, cadastrar e editar informações de forma prática.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                _launchURL("https://github.com/aaacms");
              },
              icon: const Icon(Icons.question_mark),
              label: const Text("Dúvidas e Sugestões"),
            ),
            const SizedBox(height: 16),
            // Botão para o GitHub
            ElevatedButton.icon(
              onPressed: () {
                _launchURL("https://github.com/aaacms");
              },
              icon: const Icon(Icons.code),
              label: const Text("GitHub"),
            ),
            const SizedBox(height: 16),
            // Botão para o LinkedIn
            ElevatedButton.icon(
              onPressed: () {
                _launchURL("https://www.linkedin.com/in/amandasiebeneichler");
              },
              icon: const Icon(Icons.business),
              label: const Text("LinkedIn"),
            ),
            const SizedBox(height: 20),
            // Texto na parte inferior
            const Text("made by Amanda and Henrique with <3"),
          ],
        ),
      ),
    );
  }
}
