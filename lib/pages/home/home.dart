import 'package:patsche_app/pages/clientes/clientes.dart';
import 'package:patsche_app/pages/pedidos/pedidos.dart';
import 'package:patsche_app/pages/produtos.dart';
import 'package:flutter/material.dart';

import 'button.dart';
import '../drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('VENDAS EVANDRO'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),

      drawer: const CustomDrawer(), 
      
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 5.0),
          customButton("PEDIDOS", Icons.add_shopping_cart, context, () => 
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const PedidosPage())
            )
          ),
          customButton("CLIENTES", Icons.person, context, () => 
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const ClientesPage())
            )),
          customButton("PRODUTOS", Icons.format_list_bulleted_rounded, context, () => 
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const ProdutosPage())
            )),
        ],
      ),
      
    );
  }
}