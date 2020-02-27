import 'package:build/build.dart' show AssetId;
import 'package:built_graphql/src/builders/config.dart';
import 'package:built_graphql/src/reader.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:dart_style/dart_style.dart';

final _bgPrefix = '_bg';

String _abstractClass(String className,
        {List<String> implements = const [], @required String body}) =>
    format('''
    abstract class ${className} ${implements.isNotEmpty ? 'implements' : ''} ${implements.join(', ')} {
      $body
    }
''');

String builtClass(String className,
        {List<String> implements = const [], @required String body}) =>
    _abstractClass(
      className,
      implements: [
        ...implements,
        '$_bgPrefix.Built<$className, ${className}Builder>',
      ],
      body: '''
        $className._();
        factory $className([void Function(${className}Builder) updates]) = _\$${className};

        $body
      ''',
    );

String builderClassFor(String className, {@required String body}) =>
    _abstractClass(
      className,
      implements: ['$_bgPrefix.<$className, ${className}Builder>'],
      body: '''
        factory ${className}Builder() = _\$${className}Builder;
        ${className}Builder._();

        $body
      ''',
    );

final _dartfmt = DartFormatter();

/// Attempt to format a block
String format(String source) {
  try {
    return _dartfmt.format(source);
  } catch (e) {
    return source;
  }
}

String dartName(String name) => ReCase(name).camelCase;
String className(String name) => ReCase(name).pascalCase;

String docstring(String description, [String trailing = '\n']) {
  if (description != null && description.trim().isNotEmpty) {
    return '/// ' + description.trim().split('\n').join('\n///') + trailing;
  }
  return '';
}

typedef ItemTemplate<T> = Iterable<String> Function(T item);

/// Templating helper for printing iterables
@immutable
class ListPrinter<T> {
  ListPrinter({
    this.itemTemplate,
    this.items,
    this.spacing = ' ',
    this.divider = ',',
    this.leading = '',
    this.trailing = '',
    this.shouldTrailDivider = _defaultShouldTrailDivider,
  });

  /// Template with which to render [items].
  ///
  /// Each individual result will be joined with [spacing],
  /// and the collective result will be joined with [divider].
  final ItemTemplate<T> itemTemplate;

  /// The items to render
  final Iterable<T> items;

  /// Spacing to add between each item returned by [template]
  final String spacing;

  /// Divider to join the results of [template] on
  final String divider;

  /// Leading prefix for the final result with **if** it is not empty
  final String leading;

  /// Trailing suffix for the final result with **if** it is not empty
  final String trailing;

  /// Determines if the divider should trail
  final bool Function(List<T> items, String innerResults) shouldTrailDivider;

  ListPrinter<T> copyWith({
    ItemTemplate<T> itemTemplate,
    Iterable<T> items,
    String spacing,
    String divider,
    String leading,
    String trailing,
    bool Function(List<T> items, String innerResult) shouldTrailDivider,
  }) =>
      ListPrinter(
        itemTemplate: itemTemplate ?? this.itemTemplate,
        items: items ?? this.items,
        spacing: spacing ?? this.spacing,
        divider: divider ?? this.divider,
        leading: leading ?? this.leading,
        trailing: trailing ?? this.trailing,
        shouldTrailDivider: shouldTrailDivider ?? this.shouldTrailDivider,
      );

  ListPrinter<T> over(Iterable<T> items) => copyWith(items: items);

  ListPrinter<T> map(ItemTemplate<T> itemTemplate) =>
      copyWith(itemTemplate: itemTemplate);

  /// Wraps the printer in { }. alias for `copyWith(leading: '{', trailing: '}')`
  ListPrinter<T> get braced => copyWith(leading: '{', trailing: '}');

  ListPrinter<T> get options => copyWith(leading: '{', trailing: '}');

  /// Alias for `copyWith(divider: ';\n', shouldTrailDivider: (items) => true,);`
  ListPrinter<T> get semicolons => copyWith(
        divider: ';\n',
        shouldTrailDivider: (items, inner) => true,
      );

  //trailingCommaWhen({ int length =  }): (items, inner) => true,

  @override
  String toString() {
    final _items = items.toList();
    var inner =
        _items.map((item) => itemTemplate(item).join(spacing)).join(divider);
    if (shouldTrailDivider(_items, inner)) {
      inner += divider;
    }
    return inner.isEmpty ? inner : '$leading$inner$trailing';
  }
}

bool _defaultShouldTrailDivider(List<Object> items, String inner) => false;

String generatedPartOf(String path) =>
    p.basenameWithoutExtension(path) + extensions.generatedPart;

AssetId dartTargetOf(AssetId assetId) => assetId.changeExtension(
      extensions.dartTarget,
    );

String printImport(AssetId asset, [String alias]) => [
      'import',
      "'${dartTargetOf(asset).uri}'",
      if (alias != null) 'as ${alias}',
      ';'
    ].join(' ');

String printDirectives(GraphQLDocumentAsset asset,
    {Map<AssetId, String> additionalImports = const {}}) {
  final additional = additionalImports.entries
      .map((imp) => printImport(imp.key, imp.value))
      .join('\n');
  return format('''
    /// GENERATED CODE, DO NOT MODIFY BY HAND
    /// 
    import 'package:built_graphql/built_graphql.dart' as $_bgPrefix;
    ${additional}
    ${asset.imports.map(printImport).join('\n')}

    part '${generatedPartOf(asset.path)}';

    ''');
}
