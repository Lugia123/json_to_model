import 'package:apn_json2model/core/dart_declaration.dart';

import '../utils/extensions.dart';

class JsonModel {
  late String fileName;
  late String constructor;
  late String className;
  String? extendsClass;
  late String mixinClass;
  late String declaration;
  late String copyWith;
  late String cloneFunction;
  late String hashDeclarations;
  late String equalsDeclarations;
  late String imports;
  late String enums;
  late String enumConverters;
  late String nestedClasses;

  JsonModel(String fileName, List<DartDeclaration> dartDeclarations, [String? relativePath]) {
    this.fileName = fileName;
    className = fileName.toTitleCase();
    constructor = dartDeclarations.toConstructor(className);
    mixinClass = dartDeclarations.where((element) => element.mixinClass != null).map((element) => element.mixinClass).join(', ');
    declaration = dartDeclarations.toDeclarationStrings(className);
    copyWith = dartDeclarations.toCopyWith(className);
    cloneFunction = dartDeclarations.toCloneFunction(className);
    equalsDeclarations = dartDeclarations.toEqualsDeclarationString();
    hashDeclarations = dartDeclarations.toHashDeclarationString();
    imports = dartDeclarations.toImportStrings(relativePath);
    enums = dartDeclarations.getEnums(className);
    nestedClasses = dartDeclarations.getNestedClasses();

    final extendsClass = dartDeclarations.where((element) => element.extendsClass != null).toList();
    if(extendsClass.isNotEmpty) {
      this.extendsClass = extendsClass[0].extendsClass;
    }
  }

  // model string from json map
  static JsonModel fromMap(String fileName, Map jsonMap, {String? relativePath}) {
    var dartDeclarations = <DartDeclaration>[];
    jsonMap.forEach((key, value) {
      var declaration = DartDeclaration.fromKeyValue(key, value);

      return dartDeclarations.add(declaration);
    });
    // add key to templatestring
    // add valuetype to templatestring
    return JsonModel(fileName, dartDeclarations, relativePath);
  }
}
