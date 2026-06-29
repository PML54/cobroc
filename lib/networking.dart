import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:cobroc/pmltools.dart' show Brocabrac;

class NetworkHelper {
  static const String _eventType = "Event";
  static const String _jsonScriptType = "application/ld+json";

  NetworkHelper();

  Future<List> getDataBrocabrac(Uri myUrl, List fullMaster) async {
    try {
      final response = await http.get(myUrl);
      if (response.statusCode != 200) {
        throw Exception('Failed to load http: ${response.statusCode}');
      }

      var stepOne = parse(response.body);
      List nbExposants = _extractExposantsInfo(stepOne);
      _parseBrocabracEvents(stepOne, nbExposants, fullMaster);

      return fullMaster;
    } catch (e) {
      print('Error in getDataBrocabrac: $e');
      return [];
    }
  }

  List _extractExposantsInfo(dom.Document document) {
    return document
        .getElementsByClassName("dots")
        .where((element) => element.attributes.containsKey("title"))
        .map((element) => element.attributes["title"])
        .toList();
  }
  void _parseBrocabracEvents(dom.Document document, List nbExposants, List fullMaster) {
    int countBroc = 0;
    for (var script in document.getElementsByTagName("script")) {
      if (script.attributes["type"] == _jsonScriptType && script.hasChildNodes()) {
        var jsonData = _parseJsonFromScript(script);
        if (jsonData != null && jsonData["@type"] == _eventType) {
          String? eventId = _extractEventIdFromContext(script);

          _processBrocabracEvent(jsonData, nbExposants, countBroc, fullMaster, eventId);
          countBroc++;
        }
      }
    }
    print("Total brocantes processed: $countBroc"); // Ligne de débogage
  }
  String? _extractEventIdFromContext(dom.Element script) {
    var parentDiv = script.parent;
    if (parentDiv != null) {
      var linkElement = parentDiv.querySelector('a');
      return _extractEventId(linkElement?.attributes['href']);
    }
    return null;
  }

  String? _extractEventId(String? href) {
    if (href == null) return null;
    var parts = href.split('/');
    if (parts.length >= 4) {
      var lastPart = parts[3];
      var idParts = lastPart.split('-');
      if (idParts.isNotEmpty) {
        return idParts[0];
      }
    }
    return null;
  }

  Map<String, dynamic>? _parseJsonFromScript(dom.Element script) {
    try {
      return jsonDecode(script.nodes[0].text!);
    } catch (e) {
      print('Error parsing JSON: $e');
      return null;
    }
  }

  void _processBrocabracEvent(Map<String, dynamic> user, List nbExposants, int countBroc, List fullMaster, String? eventId) {
    String brocEventStatus = user["eventStatus"] ?? "";
    brocEventStatus = brocEventStatus.toLowerCase().contains('cancelled') ? 'KO' : 'OK';

    Brocabrac brocabrac = Brocabrac(
        user["@type"] ?? "",
        user["location"]["address"]["addressLocality"] ?? "",
        user["location"]["address"]["postalCode"] ?? "",
        user["location"]["address"]["streetAddress"] ?? "",
        user["name"] ?? "",
        user["location"]["geo"]["latitude"] ?? -100,
        user["location"]["geo"]["longitude"] ?? -100,
        brocEventStatus,
        user["organizer"]?["name"] ?? "Unknown",
        user["startDate"] ?? "",
        user["endDate"] ?? "",
        user["description"] ?? "",
        countBroc < nbExposants.length ? nbExposants[countBroc] ?? "" : "",
        user["location"]["name"] ?? "",
        eventId ?? "" // Ajout de l'ID de l'événement
    );

    brocabrac.debugBrocLocality();
    fullMaster.add(brocabrac);
  }
}