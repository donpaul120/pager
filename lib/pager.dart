library pager;

import 'package:flutter/widgets.dart' hide Page;

import 'paging/combined_load_state.dart';
import 'paging/load_state.dart';
import 'paging/load_states.dart';
import 'paging/page_cache.dart';
import 'paging/page_config.dart';
import 'paging/pager_controller.dart';
import 'paging/paging_data.dart';
import 'paging/paging_source.dart';
import 'paging/paging_state.dart';
import 'paging/remote_mediator.dart';

export 'paging/combined_load_state.dart';
export 'paging/load_state.dart';
export 'paging/load_states.dart';
export 'paging/page_cache.dart';
export 'paging/page_config.dart';
export 'paging/pager_controller.dart';
export 'paging/paging_data.dart';
export 'paging/paging_source.dart';
export 'paging/paging_state.dart';
export 'paging/remote_mediator.dart';

/// @author Paul Okeke
/// A Paging Library

typedef PagingBuilder<T> = Widget Function(BuildContext context, T value);

/// A widget that renders paginated data from a [PagingSource] or an external
/// [PagerController].
///
/// ## Basic usage (source only)
/// ```dart
/// Pager<int, MyItem>(
///   source: myPagingSource,
///   loadingBuilder: (_) => const CircularProgressIndicator(),
///   emptyBuilder: (_) => const Text('No items'),
///   builder: (context, data) => ListView.builder(
///     itemCount: data.data.length,
///     itemBuilder: (_, i) => ItemWidget(data.data[i]),
///   ),
/// )
/// ```
///
/// ## Headless usage (controller outside widget tree)
/// ```dart
/// final controller = PagerController<int, MyItem>(source: mySource);
/// controller.initialize();
///
/// // Access data anywhere
/// print(controller.items);
/// print(controller.totalItems);
///
/// // Pass to Pager for rendering
/// Pager<int, MyItem>(
///   controller: controller,
///   builder: (context, data) => ...,
/// )
/// ```
class Pager<K, T> extends StatefulWidget {
  const Pager({
    Key? key,
    this.source,
    this.controller,
    required this.builder,
    this.pagingConfig = const PagingConfig.fromDefault(),
    this.scrollController,
    this.keepAlive = false,
    this.loadingBuilder,
    this.emptyBuilder,
    this.appendLoadingBuilder,
  })  : assert(
          source != null || controller != null,
          'Provide either a source or a controller.',
        ),
        super(key: key);

  /// The data source. Required when [controller] is not provided.
  final PagingSource<K, T>? source;

  /// An external controller. When provided, [source] and [pagingConfig] are
  /// ignored in favour of the controller's own configuration.
  ///
  /// The caller is responsible for calling [PagerController.initialize] and
  /// [PagerController.dispose].
  final PagerController<K, T>? controller;

  /// Builds the main content. Receives the full [PagingData] including items,
  /// load states, and [PagingData.totalItems].
  final PagingBuilder<PagingData<T>> builder;

  final PagingConfig pagingConfig;

  /// An optional external [ScrollController]. Only used when the widget
  /// returned by [builder] is not itself a [ScrollView].
  final ScrollController? scrollController;

  final bool keepAlive;

  /// Shown in place of [builder] while the first page is loading and there
  /// is no cached data to display.
  final WidgetBuilder? loadingBuilder;

  /// Shown in place of [builder] when the loaded data is empty and not
  /// loading.
  final WidgetBuilder? emptyBuilder;

  /// Shown below the content returned by [builder] while the next page is
  /// being loaded. Wraps the builder output in a [Column] with an [Expanded]
  /// child, so make sure your builder fills available space (e.g. a
  /// [ListView]).
  final WidgetBuilder? appendLoadingBuilder;

  @override
  State<StatefulWidget> createState() => _PagerState<K, T>();
}

class _PagerState<K, T> extends State<Pager<K, T>>
    with AutomaticKeepAliveClientMixin {
  /// The controller managed internally when no external controller is provided.
  PagerController<K, T>? _internalController;

  ScrollController? _scrollController;

  PagerController<K, T> get _controller =>
      widget.controller ?? _internalController!;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = PagerController<K, T>(
        source: widget.source!,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    }
  }

  @override
  void didUpdateWidget(covariant Pager<K, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Source changed and we own the controller — recreate it
    if (widget.controller == null && widget.source != oldWidget.source) {
      _internalController?.dispose();
      _internalController = PagerController<K, T>(
        source: widget.source!,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    }
  }

  void _scrollListener() {
    final ctrl = _scrollController ?? widget.scrollController;
    if (ctrl == null) return;
    _controller.onScrollPositionChanged(
      ctrl.position.pixels,
      ctrl.position.maxScrollExtent,
    );
  }

  void _registerScrollListener(ScrollController? ctrl) {
    ctrl?.removeListener(_scrollListener);
    ctrl?.addListener(_scrollListener);
  }

  @override
  Widget build(BuildContext context) {
    if (wantKeepAlive) super.build(context);

    return ValueListenableBuilder<PagingData<T>>(
      valueListenable: _controller,
      builder: (context, pagingData, _) {
        // Initial loading — show placeholder if no data yet
        if (pagingData.isLoading &&
            pagingData.data.isEmpty &&
            widget.loadingBuilder != null) {
          return widget.loadingBuilder!(context);
        }

        // Empty state
        if (pagingData.isEmpty && widget.emptyBuilder != null) {
          return widget.emptyBuilder!(context);
        }

        final content = widget.builder(context, pagingData);

        // Detect scroll controller from the built widget
        if (content is ScrollView) {
          _scrollController = content.controller;
        } else {
          _scrollController = widget.scrollController;
        }
        _registerScrollListener(_scrollController ?? widget.scrollController);

        // Append loading indicator
        if (pagingData.isAppending && widget.appendLoadingBuilder != null) {
          return Column(
            children: [
              Expanded(child: content),
              widget.appendLoadingBuilder!(context),
            ],
          );
        }

        return content;
      },
    );
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }
}
