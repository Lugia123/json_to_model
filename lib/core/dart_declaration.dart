import 'dart:collection';

import 'package:json_to_model/core/command.dart';
import 'package:json_to_model/core/json_model.dart';
import 'package:json_to_model/core/model_template.dart';

import '../utils/extensions.dart';

class DartDeclaration {
  final keyComands = Commands.keyComands;
  final valueCommands = Commands.valueCommands;

  List<String> imports = [];
  String? type;
  String? originalName;
  String? name;
  String? assignment;
  String? extendsClass;
  String? mixinClass;
  List<String> enumValues = [];
  List<JsonModel> nestedClasses = [];
  bool isNullable = false;
  bool overrideEnabled = false;
  bool ignored = false;

  bool get isEnum => enumValues.isNotEmpty;
  bool get isDatetime => type == 'DateTime';
  bool get isString => type == 'String';
  bool get isInt => type == 'int';
  bool get isBool => type == 'bool';

  String get isNullableString => isNullable ? '?' : '';

  DartDeclaration();

  String toConstructor() {
    final nullable = isNullable ? '' : 'required';
    return ModelTemplates.indented('$nullable this.$name,'.trim());
  }

  String toDeclaration(String className) {
    var declaration = '';

    if (isEnum) {
      declaration += '${getEnum(className).toImport()}\n';
    } else if (overrideEnabled) {
      declaration += '@override ';
    }

    declaration += '$type$isNullableString $name${stringifyAssignment(assignment)};'.trim();

    return ModelTemplates.indented(declaration);
  }

  String fromJsonBody() {
    return checkNestedTypes(type!, (String cleanedType, bool isList, bool isListInList, bool isModel) {
      final jsonVar = 'json[\'$originalName\']';
      String conversion;
      String modelFromJson([String jsonVar = 'e']) => '$cleanedType.fromJson($jsonVar as Map<String, dynamic>)';

      if (isListInList) {
        conversion =
            '($jsonVar as List? ?? []).map((e) => (e as List? ?? []).map((e) => ${modelFromJson()}).toList()).toList()';
      } else if (isList) {
        if (isModel) {
          conversion = '($jsonVar as List? ?? []).map((e) => ${modelFromJson()}).toList()';
        } else if (cleanedType == "DateTime") {
          conversion = '($jsonVar as List? ?? []).map((e) => e as DateTime).toList()';
        } else if (cleanedType == "String") {
          conversion = '($jsonVar as List? ?? []).map((e) => e as String).toList()';
        } else if (cleanedType == "int") {
          conversion = '($jsonVar as List? ?? []).map((e) => e as int).toList()';
        } else if (cleanedType == "bool") {
          conversion = '($jsonVar as List? ?? []).map((e) => e as bool).toList()';
        } else {
          conversion = '($jsonVar as List? ?? []).map((e) => new $cleanedType.fromJson(e)).toList()';
        }
      } else if (isModel) {
        conversion = modelFromJson(jsonVar);
      } else if (isDatetime) {
        conversion = 'DateTime.parse($jsonVar as String)';
      } else if (isString) {
        conversion = '$jsonVar as $type'; 
      } else if (isInt) {
        conversion = '$jsonVar as $type'; 
      } else if (isBool) {
        conversion = '$jsonVar as $type'; 
      } else {
        conversion = '$type.fromJson($jsonVar)'; //lugia
      }

      if (isNullable) {
        return '$name: $jsonVar != null ? $conversion : null';
      } else {
        return '$name: $conversion';
      }
    });
  }

  String toJsonBody(String className) {
    return checkNestedTypes(type!, (String cleanedType, bool isList, bool isListInList, bool isModel) {
      String conversion;

      if (isListInList) {
        conversion = '$name$isNullableString.map((e) => e.map((e) => e.toJson()).toList()).toList()';
      } else if (isList) {
        if (isModel) {
          conversion = '$name$isNullableString.map((e) => e.toJson()).toList()';
        } else {
          conversion = '$name$isNullableString.map((e) => e.toString()).toList()';
        }
      } else if (isModel) {
        conversion = '$name$isNullableString.toJson()';
      } else if (isDatetime) {
        conversion = '$name$isNullableString.toIso8601String()';
      } else {
        conversion = '$name';
      }

      return '\'$originalName\': $conversion';
    });
  }

  String copyWithConstructorDeclaration() {
    return '$type? $name';
  }

  String copyWithBodyDeclaration() {
    return '$name: $name ?? this.$name';
  }

  String toCloneDeclaration() {
    return checkNestedTypes(type!, (String cleanedType, bool isList, bool isListInList, bool isModel) {
      if (isListInList) {
        return '$name: $name${isNullable ? '?' : ''}.map((x) => x.map((y) => y.clone()).toList()).toList()';
      } else if (isList) {
        if (isModel) {
          return '$name: $name${isNullable ? '?' : ''}.map((e) => e.clone()).toList()';
        } else {
          return '$name: $name${isNullable ? '?' : ''}.toList()';
        }
      } else if (isModel) {
        return '$name: $name${isNullable ? '?' : ''}.clone()';
      } else {
        return '$name: $name';
      }
    });
  }

  String checkNestedTypes(String type, NestedCallbackFunction callback) {
    var cleanType = type;

    var isList = type.startsWith('List') == true;
    var isListInList = false;

    if (isList) {
      cleanType = type.substring(5, type.length - 1);
      isListInList = cleanType.startsWith('List') == true;

      if (isListInList) {
        cleanType = cleanType.substring(5, cleanType.length - 1);
      }
    }

    final importExists = imports.indexWhere((element) => element == cleanType.toSnakeCase()) != -1;
    final nestedClassExists = nestedClasses.indexWhere((element) => element.className == cleanType) != -1;
    final isModel = !isEnum && (importExists || nestedClassExists);

    return callback(cleanType, isList, isListInList, isModel);
  }

  String toEquals() {
    return '$name == other.$name';
  }

  String toHash() {
    return '$name.hashCode';
  }

  String stringifyAssignment(value) {
    return value != null ? ' = $value' : '';
  }

  void setIsNullable(bool isNullable) {
    this.isNullable = isNullable;
  }

  List<String> getImportStrings(String? relativePath) {
    var prefix = '';

    if (relativePath != null) {
      final matches = RegExp(r'\/').allMatches(relativePath).length;
      List.filled(matches, (i) => i).forEach((_) => prefix = '$prefix../');
    }

    return imports.where((element) => element.isNotEmpty).map((e) => "import '$prefix$e.dart';").toList();
  }

  static String? getTypeFromJsonKey(String theString) {
    var declare = theString.split(')').last.trim().split(' ');
    if (declare.isNotEmpty) return declare.first;
    return null;
  }

  static String? getNameFromJsonKey(String theString) {
    var declare = theString.split(')').last.trim().split(' ');
    if (declare.length > 1) return declare.last;
    return null;
  }

  static String getParameterString(String theString) {
    return theString.split('(')[1].split(')')[0];
  }

  void setName(String name) {
    this.originalName = name;
    this.name = name.cleaned().toCamelCase();
  }

  void setEnumValues(List<String> values) {
    enumValues = values;
    type = _detectType(values.first);
  }

  Enum getEnum(String className) {
    return Enum(className, name!, enumValues, isNullable);
  }

  void addImport(import) {
    if (import == null && !import.isNotEmpty) {
      return;
    }
    if (import is List) {
      imports.addAll(import.map((e) => e));
    } else if (import != null && import.isNotEmpty) {
      imports.add(import);
    }

    imports = LinkedHashSet<String>.from(imports).toList();
  }

  void setExtends(String extendsClass) {
    this.extendsClass = extendsClass;
  }

  void setMixin(String mixinClass) {
    this.mixinClass = mixinClass;
  }

  void setIgnored() {
    ignored = true;
  }

  void enableOverridden() {
    overrideEnabled = true;
  }

  static DartDeclaration fromKeyValue(String key, dynamic val) {
    var dartDeclaration = DartDeclaration();
    dartDeclaration = fromCommand(
      Commands.valueCommands,
      dartDeclaration,
      testSubject: val,
      key: key.cleaned(),
      value: val,
    );

    dartDeclaration = fromCommand(
      Commands.keyComands,
      dartDeclaration,
      testSubject: key,
      key: key.cleaned(),
      value: val,
    );

    return dartDeclaration;
  }

  static DartDeclaration fromCommand(
    List<Command> commandList,
    DartDeclaration self, {
    required String key,
    dynamic testSubject,
    dynamic value,
  }) {
    var newSelf = self;

    for (var command in commandList) {
      if (testSubject is String) {
        if ((command.prefix != null && testSubject.startsWith(command.prefix!))) {
          final commandPrefixMatch = command.prefix != null &&
              command.command != null &&
              testSubject.startsWith(command.prefix! + command.command!);
          final commandMatch = command.command == null || testSubject.startsWith(command.command!);

          if (commandPrefixMatch || commandMatch) {
            final notprefixnull = command.notprefix == null;
            final notprefix = !notprefixnull && !testSubject.startsWith(command.notprefix!);

            if (notprefix || notprefixnull) {
              newSelf = command.callback(self, testSubject, key: key, value: value);
              break;
            }
          }
        }
      }
      if (testSubject.runtimeType == command.type) {
        newSelf = command.callback(self, testSubject, key: key, value: value);
        break;
      }
    }

    return newSelf;
  }

  @override
  String toString() {
    return 'Instance of DartDeclaration --> $type => $name';
  }
}

class Enum {
  final String className;
  final String name;
  final List<String> values;
  final bool isNullable;

  var valueType = 'String';

  String get isNullableString => isNullable ? '?' : '';

  String get enumName => '$className${name.toTitleCase()}Enum';

  String get converterName => '_${enumName.toTitleCase()}Converter';

  String get enumValuesMapName => '_${enumName.toCamelCase()}Values';

  Enum(
    this.className,
    this.name,
    this.values,
    this.isNullable,
  ) {
    valueType = _detectType(values.first);
  }

  String valueName(String input) {
    if (input.contains('(')) {
      return input.substring(0, input.indexOf('(')).toTitleCase();
    } else {
      return input.toTitleCase();
    }
  }

  String valuesForTemplate() {
    return values.map((e) {
      final value = e.between('(', ')');
      if (value != null) {
        return '  $value: $enumName.${valueName(e)},';
      } else {
        return '  \'$e\': $enumName.${valueName(e)},';
      }
    }).join('\n');
  }

  String toTemplateString() {
    return '''
enum $enumName { ${values.map((e) => valueName(e)).toList().join(', ')} }

extension ${enumName}Ex on $enumName{
  $valueType? get value => $enumValuesMapName.reverse[this];
}

final $enumValuesMapName = $converterName({
${valuesForTemplate()}
});


class $converterName<$valueType, O> {
  final Map<$valueType, O> map;
  Map<O, $valueType>? reverseMap;

  $converterName(this.map);

  Map<O, $valueType> get reverse => reverseMap ??= map.map((k, v) => MapEntry(v, k));
}
''';
  }

  String toImport() {
    return '''
$enumName$isNullableString get ${enumName.toCamelCase()} => $enumValuesMapName.map[$name]${isNullable ? '' : '!'};''';
  }
}

String _detectType(String value) {
  final firstValue = value.between('(', ')');
  if (firstValue != null) {
    final isInt = (int.tryParse(firstValue) ?? '') is int;
    if (isInt) {
      return 'int';
    }
  }
  return 'String';
}

typedef NestedCallbackFunction = String Function(String cleanedType, bool isList, bool isListInList, bool isModel);
