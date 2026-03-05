library pager;

import 'package:flutter/widgets.dart' hide Page;

import 'paging/page_config.dart';
import 'paging/pager_controller.dart';
import 'paging/paging_data.dart';
import 'paging/paging_source.dart';

export 'paging/combined_load_state.dart';
export 'paging/load_state.dart';
export 'paging/load_states.dart';
export 'paging/page_config.dart';
export 'paging/pager_controller.dart';
export 'paging/paging_data.dart';
export 'paging/paging_source.dart';
export 'paging/paging_state.dart';
export 'paging/remote_mediator.dart';

/// @author Paul Okeke
/// A Paging Library

typedef PagingBuilder<T> = Widget Function(BuildContext context, T value);

/// A widget that renders paginated data from a [PagingSource].
///
/// The [builder] callback receives the full [PagingData] (items + load states).
///
/// ## Basic usage
/// ```dart
/// Pager<int, MyItem>(
///   source: myPagingSource,
///   builder: (context, data) {
///     if (data.isLoading) return const CircularProgressIndicator();
///     if (data.isEmpty)   return const Text('No items');
///     return ListView.builder(
///       itemCount: data.data.length,
///       itemBuilder: (_, i) => ItemWidget(data.data[i]),
///     );
///   },
/// )
/// ```
///
/// ## Headless / external-controller usage
/// ```dart
/// final controller = PagerController<int, MyItem>(source: mySource);
/// controller.initialize();
///
/// // Access data anywhere without a widget:
/// print(controller.totalItems);
/// print(controller.items);
///
/// // Render it when ready:
/// Pager.withController(
///   controller: controller,
///   builder: (context, data) => ...,
/// )
/// ```
class Pager<K, T> extends StatefulWidget {
  /// Creates a [Pager] driven by a [PagingSource].
  ///
  /// The widget manages its own internal [PagerController] and disposes it
  /// automatically. For externally managed controllers use [Pager.withController].
  const Pager({
    Key? key,
    required this.source,
    required this.builder,
    this.pagingConfig = const PagingConfig.fromDefault(),
    this.keepAlive = false,
    // Kept for backward compatibility — scroll detection now uses
    // NotificationListener and no longer requires an explicit ScrollController.
    this.scrollController,
  })  : _controller = null,
        super(key: key);

  /// Creates a [Pager] driven by an externally managed [PagerController].
  ///
  /// The caller is responsible for calling [PagerController.initialize] before
  /// passing the controller here, and for calling [PagerController.dispose]
  /// when done.
  Pager.withController({
    Key? key,
    required PagerController<K, T> controller,
    required this.builder,
    this.keepAlive = false,
  })  : _controller = controller,
        source = PagingSource.empty(),
        pagingConfig = const PagingConfig.fromDefault(),
        scrollController = null,
        super(key: key);

  final PagingSource<K, T> source;

  /// An externally managed controller. When non-null, [source] and
  /// [pagingConfig] are ignored.
  final PagerController<K, T>? _controller;

  final PagingBuilder<PagingData<T>> builder;

  final PagingConfig pagingConfig;

  final bool keepAlive;

  /// Optional scroll controller for use inside a [CustomScrollView].
  ///
  /// When [Pager] wraps a scroll view directly (e.g. a [ListView] returned
  /// from [builder]), scroll events are detected automatically via
  /// [NotificationListener] and this parameter is not needed.
  ///
  /// When [Pager] is placed **inside** a [CustomScrollView] (where the outer
  /// scroll view drives scrolling), pass the [CustomScrollView]'s
  /// [ScrollController] here so that scroll-to-bottom can still be detected:
  ///
  /// ```dart
  /// final _scrollController = ScrollController();
  ///
  /// CustomScrollView(
  ///   controller: _scrollController,
  ///   slivers: [
  ///     SliverAppBar(...),
  ///     SliverToBoxAdapter(
  ///       child: Pager(
  ///         source: source,
  ///         scrollController: _scrollController, // ← pass it here
  ///         builder: (ctx, data) => ...,
  ///       ),
  ///     ),
  ///   ],
  /// )
  /// ```
  final ScrollController? scrollController;

  @override
  State<StatefulWidget> createState() => _PagerState<K, T>();
}

class _PagerState<K, T> extends State<Pager<K, T>>
    with AutomaticKeepAliveClientMixin {
  PagerController<K, T>? _internalController;

  PagerController<K, T> get _controller =>
      widget._controller ?? _internalController!;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    if (widget._controller == null) {
      _internalController = PagerController<K, T>(
        source: widget.source,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    }
    _attachScrollController(widget.scrollController);
  }

  @override
  void didUpdateWidget(covariant Pager<K, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._controller == null && widget.source != oldWidget.source) {
      _internalController?.dispose();
      _internalController = PagerController<K, T>(
        source: widget.source,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    }
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScrollControllerUpdate);
      _attachScrollController(widget.scrollController);
    }
  }

  void _attachScrollController(ScrollController? sc) {
    sc?.removeListener(_onScrollControllerUpdate);
    sc?.addListener(_onScrollControllerUpdate);
  }

  /// Handles scroll events from an explicit [ScrollController] — used when
  /// [Pager] is inside a [CustomScrollView] and the scroll view is a parent.
  void _onScrollControllerUpdate() {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final pos = sc.position;
    _controller.onScrollPositionChanged(pos.pixels, pos.maxScrollExtent);
  }

  /// Handles scroll events from a scroll view that is a CHILD of [Pager] —
  /// e.g. a [ListView] returned directly from [builder].
  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical) {
      _controller.onScrollPositionChanged(
          metrics.pixels, metrics.maxScrollExtent);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (wantKeepAlive) super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ValueListenableBuilder<PagingData<T>>(
        valueListenable: _controller,
        builder: (context, pagingData, _) =>
            widget.builder(context, pagingData),
      ),
    );
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScrollControllerUpdate);
    _internalController?.dispose();
    super.dispose();
  }
}
