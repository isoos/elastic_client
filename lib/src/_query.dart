part of 'elastic_client_impl.dart';

abstract class Query {
  static Map matchAll() => {'match_all': {}};

  static Map matchNone() => {'match_none': {}};

  static Map bool({
    dynamic must,
    dynamic filter,
    dynamic should,
    dynamic mustNot,
  }) {
    return {
      'bool': {
        if (must != null) 'must': must,
        if (filter != null) 'filter': filter,
        if (should != null) 'should': should,
        if (mustNot != null) 'mustNot': mustNot,
      }
    };
  }

  static Map exists(String field) => {
        'exists': {'field': field}
      };

  static Map term(String field, List<String> terms) => {
        'terms': {field: terms}
      };

  static Map prefix(String field, String value) => {
        'prefix': {field: value},
      };

  static Map match(String field, String text, {String? minimum}) {
    return {
      'match': {
        field: {
          'query': text,
          if (minimum != null) 'minimum_should_match': minimum,
        }
      },
    };
  }

  static Map queryString(String query, {String? defaultField}) {
    return {
      'query_string': {
        'query': query,
        if (defaultField != null) 'default_field': defaultField,
      },
    };
  }

  static Map range(
    String field, {
    dynamic gt,
    dynamic gte,
    dynamic lt,
    dynamic lte,
  }) {
    return {
      'range': {
        field: {
          if (gt != null) 'gt': gt,
          if (gte != null) 'gte': gte,
          if (lt != null) 'lt': lt,
          if (lte != null) 'lte': lte,
        },
      },
    };
  }

  static Map ids(List<String> values) => {
        'ids': {'values': values}
      };

  static Map functionScore({
    required dynamic query,
    dynamic scriptScore,
  }) {
    return {
      'function_score': {
        'query': query,
        if (scriptScore != null) 'script_score': scriptScore,
      }
    };
  }
}
