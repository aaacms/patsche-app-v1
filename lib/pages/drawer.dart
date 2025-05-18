import 'package:patsche_app/pages/about.dart';
import 'package:patsche_app/pages/clientes/clientes.dart';
import 'package:patsche_app/pages/home/home.dart';
import 'package:patsche_app/pages/login.dart';
import 'package:patsche_app/pages/pedidos/pedidos.dart';
import 'package:patsche_app/pages/produtos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'clientes/cadastro_clientes.dart';
import 'pedidos/cadastro_pedidos.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Cabeçalho do Drawer
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.red,
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),

          // Item de menu: Início
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('INÍCIO'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            },
          ),

          // Item de menu: Pedidos
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('NOVO PEDIDO'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CadastroPedidos()),
              );
            },
          ),

          // Item de menu: Pedidos
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('NOVO CLIENTE'),
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CadastroCliente(),
                  ));
            },
          ),

          // Item de menu: Pedidos
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('PEDIDOS'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const PedidosPage()));
            },
          ),

          // Item de menu: Pedidos
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('CLIENTES'),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ClientesPage()));
            },
          ),

          // Item de menu: Pedidos
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('PRODUTOS'),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProdutosPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AboutPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Sair'),
            onTap: () {
              // Realize aqui as ações necessárias para efetuar o logout (ex: limpar tokens, etc.)

              FirebaseAuth.instance.signOut();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
