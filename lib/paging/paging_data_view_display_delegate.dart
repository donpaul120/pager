import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pager/paging/load_state.dart';
import 'package:pager/paging/paging_data.dart';

/// A mixin that provides helpers for rendering [PagingData] with appropriate
/// loading, empty, error, and success states.
///
/// Mix this into any widget class and call [renderOnlyWhenRemoteIsUpdated] or
/// [renderLocalAndThenRemote] inside [build] to handle all paging display
/// states declaratively.
///
/// ## Example
/// ```dart
/// class MyListView extends StatelessWidget with PagingDataViewDisplayDelegate {
///   final PagingData<MyItem> data;
///   const MyListView({required this.data});
///
///   @override
///   Widget build(BuildContext context) {
///     return renderOnlyWhenRemoteIsUpdated(
///       data: data,
///       loadingView: const CircularProgressIndicator(),
///       emptyView: () => const Text('No items'),
///       errorView: (e) => Text('Error: $e'),
///       successView: (items) => ListView.builder(
///         itemCount: items.length,
///         itemBuilder: (_, i) => ItemWidget(items[i]),
///       ),
///       bottomLoadingIndicator: const CircularProgressIndicator(),
///     );
///   }
/// }
/// ```
mixin PagingDataViewDisplayDelegate {
  Widget _animateOrReturnChild(
    bool animate,
    Widget? child, {
    Widget? bottomLoadingIndicator,
  }) {
    final Widget itemChild;

    if (bottomLoadingIndicator != null) {
      itemChild = Expanded(
        child: Column(
          children: [
            child ?? const SizedBox.shrink(),
            const SizedBox(height: 16),
            SizedBox(height: 20, width: 20, child: bottomLoadingIndicator),
          ],
        ),
      );
    } else {
      itemChild = child ?? const SizedBox.shrink();
    }

    if (animate) {
      return AnimatedSwitcher(
        duration: Duration(milliseconds: Platform.isAndroid ? 400 : 600),
        child: itemChild,
      );
    }
    return itemChild;
  }

  /// Renders the appropriate widget based on the remote refresh state.
  ///
  /// On first page load, cached (local) data is NOT displayed until the remote
  /// source has returned an updated result. Use this when stale data should
  /// never be shown (e.g. transaction lists).
  ///
  /// - While [PagingData.loadStates.refresh] is [Loading], shows [loadingView].
  /// - On [Error], calls [errorView] with the exception.
  /// - When the list is empty (refresh succeeded, no items), calls [emptyView].
  /// - Otherwise calls [successView] with the loaded items.
  /// - While appending the next page, [bottomLoadingIndicator] is shown below
  ///   the success content.
  Widget renderOnlyWhenRemoteIsUpdated<T>({
    required PagingData<T> data,
    Widget? loadingView,
    bool animate = false,
    Widget Function()? emptyView,
    Widget? Function(List<T> data)? successView,
    Widget? Function(Exception? error)? errorView,
    Widget? bottomLoadingIndicator,
  }) {
    final refreshState = data.loadStates?.refresh;

    if (refreshState == null || refreshState is Loading) {
      return _animateOrReturnChild(animate, loadingView);
    }

    if (refreshState is Error) {
      return _animateOrReturnChild(
        animate,
        errorView?.call(refreshState.exception),
      );
    }

    final isListEmpty =
        data.loadStates?.refresh is NotLoading && data.data.isEmpty;

    if (isListEmpty) {
      return _animateOrReturnChild(animate, emptyView?.call());
    }

    final Widget? activeBottomIndicator =
        data.loadStates?.append is Loading ? bottomLoadingIndicator : null;

    return _animateOrReturnChild(
      animate,
      successView?.call(data.data),
      bottomLoadingIndicator: activeBottomIndicator,
    );
  }

  /// Renders the appropriate widget, showing cached local data first.
  ///
  /// On the initial page load this displays cached data from the local source
  /// immediately, then refreshes automatically once remote data arrives. Use
  /// this when showing slightly stale data is acceptable (e.g. a contact list).
  ///
  /// - While [PagingData.loadStates.source.refresh] is [Loading], shows
  ///   [loadingView].
  /// - On [Error], calls [errorView] with the exception.
  /// - When the list is empty (refresh succeeded, no items), shows [emptyView].
  /// - Otherwise calls [successView] with the loaded items.
  // TODO(paul): wire up mediator/source split for true local-then-remote behaviour
  Widget renderLocalAndThenRemote<T>({
    required PagingData<T> data,
    Widget? loadingView,
    Widget emptyView = const SizedBox.shrink(),
    Widget? Function(List<T> data)? successView,
    Widget? Function(Exception? error)? errorView,
  }) {
    final refreshState = data.loadStates?.source?.refresh;

    if (refreshState == null || refreshState is Loading) {
      return loadingView ?? const SizedBox.shrink();
    }

    if (refreshState is Error) {
      return errorView?.call(refreshState.exception) ?? const SizedBox.shrink();
    }

    final isListEmpty =
        data.loadStates?.refresh is NotLoading && data.data.isEmpty;

    if (isListEmpty) {
      return emptyView;
    }

    return successView?.call(data.data) ?? const SizedBox.shrink();
  }
}
