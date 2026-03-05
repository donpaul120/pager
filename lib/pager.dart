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
/// ---
///
/// ## Simple usage — Pager manages everything internally
/// ```dart
/// Pager<int, MyItem>(
///   source: myPagingSource,
///   builder: (context, data) {
///     if (data.isLoading) return const CircularProgressIndicator();
///     if (data.isEmpty)   return const Text('No items');
///     return ListView.builder(
///       itemCount: data.itemCount,
///       itemBuilder: (_, i) => ItemWidget(data.data[i]),
///     );
///   },
/// )
/// ```
///
/// ## With an external controller — access data outside the builder
///
/// Pass a [PagerController] to get a handle on the controller outside the
/// widget tree (e.g. to read [PagerController.totalItems] in an app bar or
/// badge). The Pager still drives the data source; you manage the controller
/// lifecycle.
///
/// ```dart
/// class _MyPageState extends State<MyPage> {
///   late final _controller = PagerController<int, MyItem>(source: mySource);
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         // Access totalItems, isLoading, etc. anywhere:
///         ValueListenableBuilder(
///           valueListenable: _controller,
///           builder: (_, data, __) => Text('${data.totalItems} items'),
///         ),
///         Expanded(
///           child: Pager<int, MyItem>(
///             source: mySource,
///             controller: _controller, // ← pass it here
///             builder: (context, data) => ListView.builder(...),
///           ),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Headless — data without a visible Pager widget
///
/// Use [Pager.withController] when the controller was created and initialised
/// independently (e.g. in a ViewModel or bloc) before the widget is mounted.
///
/// ```dart
/// final controller = PagerController<int, MyItem>(source: mySource);
/// controller.initialize();
///
/// // Later:
/// Pager.withController(controller: controller, builder: (ctx, data) => ...);
/// ```
class Pager<K, T> extends StatefulWidget {
  /// Creates a [Pager] driven by a [PagingSource].
  ///
  /// If [controller] is omitted the widget creates and disposes its own
  /// internal [PagerController] automatically.
  ///
  /// Pass an explicit [controller] when you need to read pagination state
  /// (e.g. [PagerController.totalItems]) outside of the [builder] callback.
  /// In that case you are responsible for calling [PagerController.dispose].
  const Pager({
    Key? key,
    required this.source,
    required this.builder,
    this.controller,
    this.pagingConfig = const PagingConfig.fromDefault(),
    this.keepAlive = false,
    this.scrollController,
  }) : super(key: key);

  /// Creates a [Pager] driven by an already-initialised [PagerController].
  ///
  /// Use this when the controller is owned by a ViewModel, bloc, or any object
  /// that lives outside the widget tree. The caller is responsible for calling
  /// [PagerController.initialize] and [PagerController.dispose].
  Pager.withController({
    Key? key,
    required PagerController<K, T> controller,
    required this.builder,
    this.keepAlive = false,
    this.scrollController,
  })  : controller = controller, // ignore: prefer_initializing_formals
        source = PagingSource.empty(),
        pagingConfig = const PagingConfig.fromDefault(),
        super(key: key);

  /// The data source. Used when no external [controller] is provided.
  final PagingSource<K, T> source;

  /// An optional external controller.
  ///
  /// - When provided via the default constructor, Pager uses it to drive data
  ///   but does **not** call [PagerController.initialize] or
  ///   [PagerController.dispose] — that is the caller's responsibility.
  /// - When provided via [Pager.withController], same rules apply.
  /// - When `null`, Pager creates an internal controller automatically.
  final PagerController<K, T>? controller;

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
  ///         scrollController: _scrollController,
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
  /// Created only when no external controller is provided.
  PagerController<K, T>? _internalController;

  /// The active controller — external if provided, otherwise internal.
  PagerController<K, T> get _controller =>
      widget.controller ?? _internalController!;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    _initController();
    _attachScrollController(widget.scrollController);
  }

  void _initController() {
    if (widget.controller == null) {
      _internalController = PagerController<K, T>(
        source: widget.source,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    } else {
      // External controller: only initialize if it has never been started.
      // loadStates == null means dispatchUpdates() has never run, i.e. the
      // controller is brand-new and hasn't begun loading yet.
      // If the controller already has data (or is mid-load), we leave it
      // completely untouched so the widget simply shows what's already there.
      _maybeInitExternalController(widget.controller!);
    }
  }

  void _maybeInitExternalController(PagerController<K, T> controller) {
    if (controller.value.loadStates == null) {
      controller.initialize();
    }
  }

  @override
  void didUpdateWidget(covariant Pager<K, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If no external controller and the source changed, recreate internally.
    if (widget.controller == null && widget.source != oldWidget.source) {
      _internalController?.dispose();
      _internalController = PagerController<K, T>(
        source: widget.source,
        pagingConfig: widget.pagingConfig,
      );
      _internalController!.initialize();
    }

    // If the external controller instance was swapped, initialize the new one
    // only if it hasn't been started yet.
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _maybeInitExternalController(widget.controller!);
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
    // Only dispose the controller we created ourselves.
    _internalController?.dispose();
    super.dispose();
  }
}

