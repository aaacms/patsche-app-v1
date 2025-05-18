import 'package:flutter/material.dart';

/// Função que retorna um botão customizado.
/// [label] é o texto que aparecerá no botão;
/// [icon] é o ícone exibido;
/// [context] é necessário para a navegação.
Widget customButton(String label, IconData icon, BuildContext context, VoidCallback argument) {
  // Define a ação de navegação com base no label

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
    child: SizedBox(
      width: double.infinity,
      height: 100,
      child: ElevatedButton.icon(
        onPressed: argument,
        icon: Icon(icon, size: 50, color: Colors.white,),
        label: Text(label, style: const TextStyle(fontSize: 30)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0), // Menos arredondado
          ),
        ),
      ),
    ),
  );
  
}
