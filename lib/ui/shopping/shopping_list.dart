import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipes/ui/colors.dart';
import 'package:recipes/ui/screens/empty_shopping_list.dart';
import '../../data/models/ingredient.dart';
import '../../data/repository.dart';

class ShoppingList extends StatefulWidget {
  final Function? onPressed;
  const ShoppingList({
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  State<ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<ShoppingList> {
  final checkBoxValues = Map<int, bool>();

  @override
  Widget build(BuildContext context) {
    final repository = Provider.of<Repository>(context);
    return StreamBuilder(
      stream: repository.watchAllIngredients(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final ingredients = snapshot.data as List<Ingredient>?;
          if (ingredients == null) {
            return Container(
              color: red,
              child: const Center(
                child: Text(
                  'No List',
                  style: TextStyle(color: red, fontSize: 100),
                ),
              ),
            );
          }
          if (ingredients.isEmpty) {
            return const EmptyGroceryScreen();
          }
          return ListView.builder(
            itemCount: ingredients.length,
            itemBuilder: (BuildContext context, int index) {
              return CheckboxListTile(
                activeColor: red,
                selectedTileColor: red,
                checkColor: white,
                tileColor: white,
                value:
                    checkBoxValues.containsKey(index) && checkBoxValues[index]!,
                title: Text(ingredients[index].name ?? ''),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      checkBoxValues[index] = newValue;
                    });
                  }
                },
              );
            },
          );
        } else {
          return Container();
        }
      },
    );
  }
}
