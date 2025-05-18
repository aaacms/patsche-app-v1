import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:patsche_app/utils/cache_manager.dart';

class CadastroCliente extends StatefulWidget {
  final CachedDocument? cliente;
  const CadastroCliente({Key? key, this.cliente}) : super(key: key);

  @override
  _CadastroClienteState createState() => _CadastroClienteState();
}

class _CadastroClienteState extends State<CadastroCliente> {
  final _formKey = GlobalKey<FormState>();
  bool get isEditMode => widget.cliente != null;

  // Controllers...
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _regiaoController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _estadoController =
      TextEditingController(text: 'RS');
  final TextEditingController _cepController = TextEditingController();

  DateTime? _selectedDate;

  final maskFormatter = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Função para aplicar a máscara manualmente
  String formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return "(${digits.substring(0, 2)}) ${digits.substring(2, 3)} ${digits.substring(3, 7)}-${digits.substring(7, 11)}";
    }
    // Você pode adicionar formatação para outros casos se necessário
    return phone;
  }

  @override
  void initState() {
    super.initState();
    if (widget.cliente != null) {
      final data = widget.cliente!.data;
      // Atribui o id do documento ao campo código
      _codigoController.text = widget.cliente!.id;
      _nomeController.text = data['nome'] ?? '';

      String rawPhone = data['telefone'] ?? '';
      _telefoneController.text = formatPhone(rawPhone);

      _regiaoController.text = data['regiao'] ?? '';
      _cnpjController.text = data['cnpj'] ?? '';
      if (data['data_nascimento'] != null) {
        Timestamp timestamp = data['data_nascimento'];
        _selectedDate = timestamp.toDate();
        _dataNascimentoController.text =
            DateFormat('dd/MM/yyyy').format(_selectedDate!);
      }
      _emailController.text = data['email'] ?? '';
      _enderecoController.text = data['endereco'] ?? '';
      _numeroController.text = data['numero']?.toString() ?? '';
      _bairroController.text = data['bairro'] ?? '';
      _cidadeController.text = data['cidade'] ?? '';
      _estadoController.text = data['estado'] ?? 'RS';
      _cepController.text = data['cep'] ?? '';
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _regiaoController.dispose();
    _cnpjController.dispose();
    _dataNascimentoController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _cepController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dataNascimentoController.text =
            DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveCliente() async {
    if (_formKey.currentState!.validate()) {
      final String codigo = _codigoController.text.trim();
      final String nome = _nomeController.text.trim();
      final String telefone =
          _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

      final String regiao = _regiaoController.text.trim();
      final String cnpj = _cnpjController.text.trim();
      final DateTime? dataNascimento = _selectedDate;
      final String email = _emailController.text.trim();
      final String endereco = _enderecoController.text.trim();
      final int? numero = int.tryParse(_numeroController.text.trim());
      final String bairro = _bairroController.text.trim();
      final String cidade = _cidadeController.text.trim();
      final String estado = _estadoController.text.trim();
      final String cep = _cepController.text.trim();

      final Map<String, dynamic> clienteData = {
        // opcional, se você deseja salvar o código também
        'nome': nome,
        'nome_lower': nome.toLowerCase(),
        'telefone': telefone,
        'regiao': regiao,
        'cnpj': cnpj,
        'data_nascimento':
            dataNascimento != null ? Timestamp.fromDate(dataNascimento) : null,
        'email': email,
        'endereco': endereco,
        'numero': numero,
        'bairro': bairro,
        'cidade': cidade,
        'estado': estado,
        'cep': cep,
        'userId': FirebaseAuth.instance.currentUser!.uid,
      };

      if (isEditMode) {
        // Atualiza o documento existente
        await widget.cliente!.reference.update(clienteData);
        FirebaseFirestore.instance
            .collection('cliente')
            .doc(codigo)
            .update(clienteData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente atualizado com sucesso!')),
        );
      } else {
        // Cria um novo documento

        FirebaseFirestore.instance
            .collection('cliente')
            .doc(codigo)
            .set(clienteData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente cadastrado com sucesso!')),
        );
      }
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Cliente'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Campo para o código do cliente (será o ID do documento)
              TextFormField(
                controller: _codigoController,
                decoration:
                    const InputDecoration(labelText: 'Código do Cliente *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o código do cliente';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _telefoneController,
                inputFormatters: [maskFormatter],
                decoration: const InputDecoration(labelText: 'Telefone *'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o telefone';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _regiaoController,
                decoration: const InputDecoration(labelText: 'Região *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a região';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _cnpjController,
                decoration: const InputDecoration(labelText: 'CNPJ'),
              ),
              TextFormField(
                controller: _dataNascimentoController,
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: 'Endereço'),
              ),
              TextFormField(
                controller: _numeroController,
                decoration: const InputDecoration(labelText: 'Número'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _bairroController,
                decoration: const InputDecoration(labelText: 'Bairro'),
              ),
              TextFormField(
                controller: _cidadeController,
                decoration: const InputDecoration(labelText: 'Cidade *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a cidade';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _estadoController,
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              TextFormField(
                controller: _cepController,
                decoration: const InputDecoration(labelText: 'CEP'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveCliente,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Salvar Cliente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
