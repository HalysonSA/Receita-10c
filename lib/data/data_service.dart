import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../util/ordenador.dart';

var values = [3, 7, 15];

enum TableStatus { idle, loading, ready, error }

enum ItemType {
  stripe,
  subscription,
  restaurant,
  none;

  String get asString => '$name';

  List<String> get columns => this == stripe
      ? ["id", "Token", "Ano"]
      : this == restaurant
          ? ["Nome", "Descrição", "Tipo"]
          : this == subscription
              ? ["Plano", "Status", "Forma de Pagamento"]
              : [];

  List<String> get properties => this == stripe
      ? ["uid", "token", "year"]
      : this == restaurant
          ? ["name", "description", "type"]
          : this == subscription
              ? ["plan", "status", "payment_method"]
              : [];
}

class DataService {
  static final values = [3, 7, 15];

  static int get MAX_N_ITEMS => values[2];
  static int get MIN_N_ITEMS => values[0];
  static int get DEFAULT_N_ITEMS => values[1];

  int _numberOfItems = DEFAULT_N_ITEMS;

  set numberOfItems(n) {
    _numberOfItems = n < 0
        ? MIN_N_ITEMS
        : n > MAX_N_ITEMS
            ? MAX_N_ITEMS
            : n;
  }

  int get numberOfItems {
    return _numberOfItems;
  }

  final ValueNotifier<Map<String, dynamic>> tableStateNotifier =
      ValueNotifier<Map<String, dynamic>>({
    'status': TableStatus.idle,
    'dataObjects': [],
    'itemType': ItemType.none
  });

  void carregar(index) {
    final params = [
      ItemType.stripe,
      ItemType.restaurant,
      ItemType.subscription
    ];
    carregarPorTipo(params[index]);
  }

  // Ordem crescente e decrescente ao apertar duas vezes na propriedade.
  void ordenarEstadoAtual(String propriedade, [bool cresc = true]) {
    List objetos = tableStateNotifier.value['dataObjects'] ?? [];
    if (objetos.isEmpty) return;
    Ordenador ord = Ordenador();
    var objetosOrdenados = [];
    bool crescente = cresc;
    bool precisaTrocar(atual, proximo) {
      final ordemCorreta = crescente ? [atual, proximo] : [proximo, atual];
      return ordemCorreta[0][propriedade]
              .compareTo(ordemCorreta[1][propriedade]) >
          0;
    }

    objetosOrdenados = ord.ssOrdenar(objetos, precisaTrocar);
    emitirEstadoOrdenado(objetosOrdenados, propriedade);
  }

  void emitirEstadoOrdenado(
    List objetosOrdenados,
    String propriedade,
  ) {
    var estado = Map<String, dynamic>.from(tableStateNotifier.value);
    estado['dataObjects'] = objetosOrdenados;
    tableStateNotifier.value = estado;
  }

  Uri montarUri(ItemType type) {
    return Uri(
        scheme: 'https',
        host: 'random-data-api.com',
        path: 'api/${type.asString}/random_${type.asString}',
        queryParameters: {'size': '$_numberOfItems'});
  }

  Future<List<dynamic>> acessarApi(Uri uri) async {
    var jsonString = await http.read(uri);
    var json = jsonDecode(jsonString);
    json = [...tableStateNotifier.value['dataObjects'], ...json];
    return json;
  }

  void emitirEstadoCarregando(ItemType type) {
    tableStateNotifier.value = {
      'status': TableStatus.loading,
      'dataObjects': [],
      'itemType': type
    };
  }

  void emitirEstadoPronto(ItemType type, var json) {
    tableStateNotifier.value = {
      'itemType': type,
      'status': TableStatus.ready,
      'dataObjects': json,
      'propertyNames': type.properties,
      'columnNames': type.columns
    };
  }

  bool temRequisicaoEmCurso() =>
      tableStateNotifier.value['status'] == TableStatus.loading;
  bool mudouTipoDeItemRequisitado(ItemType type) =>
      tableStateNotifier.value['itemType'] != type;

  void carregarPorTipo(ItemType type) async {
    //ignorar solicitação se uma requisição já estiver em curso
    if (temRequisicaoEmCurso()) {
      return;
    }
    if (mudouTipoDeItemRequisitado(type)) {
      emitirEstadoCarregando(type);
    }

    var uri = montarUri(type);
    var json = await acessarApi(uri); //, type);

    emitirEstadoPronto(type, json);
  }
}

final dataService = DataService();

class DecididorJson implements Decididor {
  final String prop;
  final bool crescente;

  DecididorJson(this.prop, [this.crescente = true]);
  @override
  bool precisaTrocarAtualPeloProximo(
      dynamic atual, dynamic proximo, bool crescente) {
    try {
      final ordemCorreta = crescente ? [atual, proximo] : [proximo, atual];
      return ordemCorreta[0][prop].compareTo(ordemCorreta[1][prop]) > 0;
    } catch (error) {
      return false;
    }
  }
}
