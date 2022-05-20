import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlbrite/sqlbrite.dart';
import 'package:synchronized/synchronized.dart';
import '../models/models.dart';

class DatabaseHelper {
  // constants database identifiers
  static const _databaseName = 'MyRecipes.db';
  static const _databaseVersion = 1;
  // defining tables
  static const recipeTable = 'Recipe';
  static const ingredientTable = 'Ingredient';
  static const recipeId = 'recipeId';
  static const ingredientId = 'ingredientId';
  static late BriteDatabase _streamDatabase;
  // make this a singleton class
  // constructor is private
  DatabaseHelper._privateConstructor();
  // constructor public static instance
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  // prevents concurrent access
  static var lock = Lock();
  // private sqlflite database instance
  static Database? _database;

  //SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    // creating recipeTable with columns from model class
    await db.execute('''
                 CREATE TABLE $recipeTable (
                 $recipeId INTEGER PRIMARY KEY,
                 label TEXT, 
                 image TEXT, 
                 url TEXT, 
                 calories REAL, 
                 totalWeight REAL,
                 totalTime REAL
                 )
                  ''');
    // creating ingredient table with columns from model class
    await db.execute('''
          CREATE TABLE $ingredientTable (
          $ingredientId INTEGER PRIMARY KEY, 
          $recipeId INTEGER, 
          name TEXT, 
          weight REAL
          )
    ''');
  }

  // opens the database and creates one if necessary
  Future<Database> _initDatabase() async {
    // getting the apps document directory where well store the database
    final documentsDirectory = await getApplicationDocumentsDirectory();
    // creating path to the database by appending database name to documents
    final path = join(documentsDirectory.path, _databaseName);

    Sqflite.setDebugModeOn(false);
    //  creating and store the database in the path with sqflites openDatabase()
    return openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  // access to get the database
  Future<Database> get database async {
    // returning existing database
    if (_database != null) {
      return _database!;
    }
    // locking code to ensure only one process can access this code at a time
    await lock.synchronized(() async {
      // lazily instantiate database first time it is accessed
      if (_database == null) {
        _database = await _initDatabase();
        // creating a BriteDatabase instance by wrapping our database
        _streamDatabase = BriteDatabase(_database!);
      }
    });
    return database;
  }

  // getter method for BriteDatabase
  Future<BriteDatabase> get streamDatabase async {
    // creating
    await database;
    return _streamDatabase;
  }

  List<Recipe> parseRecipes(List<Map<String, dynamic>> recipeList) {
    final recipes = <Recipe>[];
    recipeList.forEach((recipeMap) {
      //converting each recipe into a Recipe instance
      final recipe = Recipe.fromJson(recipeMap);
      // adding recipe to recipes list
      recipes.add(recipe);
    });
    return recipes;
  }

  List<Ingredient> parseIngredient(List<Map<String, dynamic>> ingredientList) {
    final ingredients = <Ingredient>[];
    ingredientList.forEach((ingredientMap) {
      final ingredient = Ingredient.fromJson(ingredientMap);
      ingredients.add(ingredient);
    });
    return ingredients;
  }

  Future<List<Recipe>> findAllRecipes() async {
    final db = await instance.streamDatabase;
    final recipeList = await db.query(recipeTable);
    final recipes = parseRecipes(recipeList);
    return recipes;
  }

  Stream<List<Recipe>> watchAllRecipes() async* {
    final db = await instance.streamDatabase;
    // creating a stream using query
    yield* db.createQuery(recipeTable).mapToList((row) => Recipe.fromJson(row));
  }

  Stream<List<Ingredient>> watchAllIngredients() async* {
    final db = await instance.streamDatabase;
    yield* db
        .createQuery(ingredientTable)
        .mapToList((row) => Ingredient.fromJson(row));
  }

  Future<Recipe> findRecipeById(int id) async {
    final db = await instance.streamDatabase;
    final recipeList = await db.query(recipeTable, where: 'id = $id');
    final recipes = parseRecipes(recipeList);
    return recipes.first;
  }

  Future<List<Ingredient>> findAllIngredients() async {
    final db = await instance.streamDatabase;
    final ingredientsList = await db.query(ingredientTable);
    final ingredients = parseIngredient(ingredientsList);
    return ingredients;
  }

  Future<List<Ingredient>> findAllRecipeIngredients(int recipeId) async {
    final db = await instance.streamDatabase;
    final ingredientList =
        await db.query(ingredientTable, where: 'recipeId = $recipeId');
    final ingredients = parseIngredient(ingredientList);
    return ingredients;
  }

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await instance.streamDatabase;
    return db.insert(table, row);
  }

  Future<int> insertRecipe(Recipe recipe) {
    return insert(recipeTable, recipe.toJson());
  }

  Future<int> insertIngredient(Ingredient ingredient) {
    return insert(ingredientTable, ingredient.toJson());
  }

  Future<int> _delete(String table, String columnId, int id) async {
    final db = await instance.streamDatabase;
    return db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  // deleting recipe
  Future<int> deleteRecipe(Recipe recipe) async {
    if (recipe.id != null) {
      return _delete(recipeTable, recipeId, recipe.id!);
    } else {
      return Future.value(-1);
    }
  }

  Future<int> deleteIngredient(Ingredient ingredient) async {
    if (ingredient.id != null) {
      return _delete(ingredientTable, ingredientId, ingredient.id!);
    } else {
      return Future.value(-1);
    }
  }

  Future<void> deleteIngredients(List<Ingredient> ingredients) {
    ingredients.forEach((ingredient) {
      if (ingredient.id != null) {
        _delete(ingredientTable, ingredientId, ingredient.id!);
      }
    });
    return Future.value();
  }

  Future<int> deleteRecipeIngredients(int id) async {
    final db = await instance.streamDatabase;
    return db.delete(ingredientTable, where: '$recipeId = ?', whereArgs: [id]);
  }

  void close() {
    _streamDatabase.close();
  }
}
