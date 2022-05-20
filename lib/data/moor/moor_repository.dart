import 'dart:async';
import '../models/models.dart';
import '../repository.dart';
import 'moor_db.dart';

class MoorRepository extends Repository {
  late RecipeDatabase recipeDatabase;
  late RecipeDao _recipeDao;
  late IngredientDao _ingredientDao;
  Stream<List<Ingredient>>? ingredientStream;
  Stream<List<Recipe>>? recipeStream;

  @override
  Future<List<Recipe>> findAllRecipes() {
    // Using recipe dao to findAllRecipes
    return _recipeDao.findAllRecipes()
        // executes then after findAllRecipes
        .then<List<Recipe>>(
      (List<MoorRecipeData> moorRecipes) {
        final recipes = <Recipe>[];
        // 3
        moorRecipes.forEach(
          (moorRecipe) async {
            // 4
            final recipe = moorRecipeToRecipe(moorRecipe);
            // 5
            if (recipe.id != null) {
              recipe.ingredients = await findRecipeIngredients(recipe.id!);
            }
            recipes.add(recipe);
          },
        );
        return recipes;
      },
    );
  }

  @override
  Stream<List<Recipe>> watchAllRecipes() {
    if (recipeStream == null) {
      recipeStream = _recipeDao.watchAllRecipes();
    }
    return recipeStream!;
  }

  @override
  Stream<List<Ingredient>> watchAllIngredients() {
    if (ingredientStream == null) {
      final stream = _ingredientDao.watchAllIngredients();
      ingredientStream = stream.map(
        (moorIngredients) {
          final ingredients = <Ingredient>[];
          moorIngredients.forEach(
            (moorIngredient) {
              ingredients.add(moorIngredientToIngredient(moorIngredient));
            },
          );
          return ingredients;
        },
      );
    }
    return ingredientStream!;
  }

  @override
  Future<Recipe> findRecipeById(int id) {
    return _recipeDao
        .findRecipeById(id)
        .then((listOfRecipes) => moorRecipeToRecipe(listOfRecipes.first));
  }

  @override
  Future<List<Ingredient>> findAllIngredients() {
    return _ingredientDao.findAllIngredients().then<List<Ingredient>>(
      (List<MoorIngredientData> moorIngredients) {
        final ingredients = <Ingredient>[];
        moorIngredients.forEach(
          (ingredient) {
            ingredients.add(moorIngredientToIngredient(ingredient));
          },
        );
        return ingredients;
      },
    );
  }

  @override
  Future init() async {
    //creating database
    recipeDatabase = RecipeDatabase();
    // getting dao instances
    _recipeDao = recipeDatabase.recipeDao;
    _ingredientDao = recipeDatabase.ingredientDao;
  }

  @override
  void close() {
    recipeDatabase.close();
  }

  @override
  Future<void> deleteIngredient(Ingredient ingredient) {
    if (ingredient.id != null) {
      return _ingredientDao.deleteIngredient(ingredient.id!);
    } else {
      return Future.value();
    }
  }

  @override
  Future<void> deleteIngredients(List<Ingredient> ingredients) {
    ingredients.forEach((ingredient) {
      if (ingredient.id != null) {
        _ingredientDao.deleteIngredient(ingredient.id!);
      }
    });
    return Future.value();
  }

  @override
  Future<void> deleteRecipe(Recipe recipe) {
    if (recipe.id != null) {
      _recipeDao.deleteRecipe(recipe.id!);
    }
    return Future.value();
  }

  @override
  Future<void> deleteRecipeIngredients(int recipeId) async {
    final ingredients = await findRecipeIngredients(recipeId);
    return deleteIngredients(ingredients);
  }

  @override
  Future<List<Ingredient>> findRecipeIngredients(int recipeId) {
    return _ingredientDao.findRecipeIngredients(recipeId).then(
      (listOfIngredients) {
        final ingredients = <Ingredient>[];
        listOfIngredients.forEach(
          (ingredient) {
            ingredients.add(moorIngredientToIngredient(ingredient));
          },
        );
        return ingredients;
      },
    );
  }

  @override
  Future<List<int>> insertIngredients(List<Ingredient> ingredients) {
    return Future(() async {
      // if no ingredients return empty list
      if (ingredients.length == 0) {
        return <int>[];
      }
      final resultIds = <int>[];
      ingredients.forEach((ingredient) {
        final moorIngredient = ingredientToInsertableMoorIngredient(ingredient);
        // inserting into database and adding new id to resultIds list
        _ingredientDao
            .insertIngredient(moorIngredient)
            .then((int id) => resultIds.add(id));
      });
      return resultIds;
    });
  }

  @override
  Future<int> insertRecipe(Recipe recipe) {
    return Future(() async {
      // inserting converted model recipe
      final id =
          await _recipeDao.insertRecipe(recipeToInsertableMoorRecipe(recipe));
      //setting up recipeId for each ingredient
      if (recipe.ingredients != null) {
        recipe.ingredients!.forEach((ingredient) {
          ingredient.recipeId = id;
        });
        //inserting all ingredients
        insertIngredients(recipe.ingredients!);
      }
      return id;
    });
  }
}
