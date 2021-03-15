part of 'elastic_client_impl.dart';

class HighlightOptions {
  final String type;
  final int numberOfFragments;
  final int fragmentSize;
  final Map<String, HighlightField> fields;

  HighlightOptions({
    this.type,
    this.numberOfFragments,
    this.fragmentSize,
    this.fields,
  });

  Map toMap() {
    return {
      if (type != null) 'type': type,
      if (numberOfFragments != null) 'number_of_fragments': numberOfFragments,
      if (fragmentSize != null) 'fragment_size': fragmentSize,
      if (fields != null)
        'fields': fields.map((k, v) => MapEntry<String, Map>(k, v.toMap())),
    };
  }
}

class HighlightField {
  final String type;
  final int numberOfFragments;
  final int fragmentSize;
  final String order;

  HighlightField({
    this.type,
    this.fragmentSize,
    this.numberOfFragments,
    this.order,
  });

  Map toMap() {
    return {
      if (type != null) 'type': type,
      if (fragmentSize != null) 'fragment_size': fragmentSize,
      if (numberOfFragments != null) 'number_of_fragments': numberOfFragments,
      if (order != null) 'order': order,
    };
  }
}
