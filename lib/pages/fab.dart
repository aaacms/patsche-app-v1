import 'package:flutter/material.dart';

FloatingActionButton CustomFAB(VoidCallback argument) {
  return FloatingActionButton(
    onPressed: argument,
    backgroundColor: Colors.red,
    shape: const CircleBorder(),
    child: const Icon(
      Icons.add,
      color: Colors.white,
      size: 40,
    ),
  );
}
