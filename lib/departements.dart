import 'package:flutter/material.dart';
import 'package:interactive_country_map/interactive_country_map.dart';
import 'package:cobroc/diverspml.dart';
class ConfigTrajet {
  int codebrocante = 0;
  double centerLatitude;
  double centerLongitude;
  List<int> tripSelected = [];

  ConfigTrajet(this.codebrocante, this.centerLatitude, this.centerLongitude,
      this.tripSelected);
}

class FranceDepartmentSelector extends StatefulWidget {
  const FranceDepartmentSelector({super.key});

  @override
  _FranceDepartmentSelectorState createState() =>
      _FranceDepartmentSelectorState();
}

class _FranceDepartmentSelectorState extends State<FranceDepartmentSelector> {
  Map<String, Color> departmentColors = {};
  final Color selectedColor = Colors.blue.shade200;
  final Color defaultColor = Colors.grey.shade300;
  Color myColor = Colors.grey.shade300;
  ConfigTrajet configTrajet = ConfigTrajet(1, 0, 0, []);
  Map<String, int> selectedDepartments = {};
  String selectedDepartmentName = "";

  String getDepartmentName(String code) {
    int departmentCode = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    var department = lesDepartements.firstWhere(
          (dep) => dep.departement == departmentCode,
      orElse: () => null,
    );
    return department != null ? department.nom : "Département inconnu";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélecteur de Départements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAndReturn,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _returnWithEmptyList,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveMap(
              MapEntity.franceDepartments,
              theme: InteractiveMapTheme(
                borderColor: Colors.black,
                borderWidth: 1.0,
                selectedBorderWidth: 2.0,
                defaultCountryColor: defaultColor,
                defaultSelectedCountryColor: myColor,
                mappingCode: departmentColors,
              ),
              onCountrySelected: (code) {
                setState(() {
                  if (departmentColors.containsKey(code)) {
                    departmentColors.remove(code);
                    selectedDepartments.remove(code);
                    myColor = defaultColor;
                    selectedDepartmentName = "";
                  } else {
                    departmentColors[code] = selectedColor;
                    selectedDepartments[code] = 1;
                    myColor = selectedColor;
                    selectedDepartmentName = getDepartmentName(code);
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              selectedDepartmentName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _saveAndReturn() {
    print("selectedDepartments: ${selectedDepartments.length}");
    updateConfigTrajet();
    Navigator.pop(context, configTrajet);
  }

  void _returnWithEmptyList() {
    Navigator.of(context).pop(ConfigTrajet(1, 0, 0, []));
  }

  void updateConfigTrajet() {
    configTrajet.tripSelected = selectedDepartments.entries
        .where((entry) => entry.value == 1)
        .map((entry) {
      String numericPart = entry.key.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(numericPart) ?? 0;
    })
        .where((code) => code != 0)
        .toList();

    print("Départements sélectionnés : ${configTrajet.tripSelected}");
    configTrajet.codebrocante = 999;
  }
}