import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pager/paging/load_state.dart';
import 'package:pager/paging/paging_data.dart';


mixin PagingDataViewDisplayDelegate {
  Widget _animateOrReturnChild(
      bool animate, Widget? child, {Widget? bottomLoadingIndicator}) {
    final Widget? itemChild;

    if (null != bottomLoadingIndicator) {
      itemChild = Expanded(
          child: Column(
            children: [
              child ?? const SizedBox.shrink(),
              const SizedBox(height: 16),
              SizedBox(height: 20,width: 20, child: bottomLoadingIndicator)
            ],
          )
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

  /// On first page load, data from local source will not be displayed
  /// until it has been updated with data fetched from the remote source
  ///
  /// Use this if you need to display updated data at first rather than cached
  /// data e.g Transaction Data
  Widget renderOnlyWhenRemoteIsUpdated<T>({
    required PagingData<T> data,
    Widget? loadingView,
    bool animate = false,
    Widget Function()? emptyView,
    Widget? Function(List<T> data)? successView,
    Widget? Function(Exception? error)? errorView,
    Widget? bottomLoadingIndicator
  }) {
    final refreshState = data.loadStates?.refresh;

    if (refreshState == null || refreshState is Loading) {
      return _animateOrReturnChild(animate, loadingView);
    }
    else if (refreshState is Error) {
      return _animateOrReturnChild(
          animate,
          errorView?.call(refreshState.exception)
      );
    }

    final Widget? mBottomLoadingIndicator;

    if (data.loadStates?.append is Loading) {
      mBottomLoadingIndicator = null;
    } else {
      mBottomLoadingIndicator = null;
    }

    final isListEmpty =
        data.loadStates?.refresh is NotLoading && data.data.isEmpty;

    if(isListEmpty) {
      return _animateOrReturnChild(animate, emptyView?.call());
    }

    return _animateOrReturnChild(
        animate, successView?.call(data.data),
        bottomLoadingIndicator: mBottomLoadingIndicator
    );
  }

  ///On the initial page load, this will first display cached data from the db
  ///and when data from the remote source is fetched it'll be refreshed
  ///automatically
  ///
  /// Use this if it's okay to display the cached data first and then display
  /// an updated data when it's available.
  // TODO(paul): implement logic
  Widget renderLocalAndThenRemote<T>({
    required PagingData<T> data,
    Widget? loadingView,
    Widget emptyView = const SizedBox.shrink(),
    Widget? Function(List<T> data)? successView,
    Widget? Function(Exception? error)? errorView
  }) {
    // final refreshState = data.loadStates?.refresh;
    final refreshState = data.loadStates?.source?.refresh;

    if(refreshState == null || refreshState is Loading) {
      return loadingView ?? const SizedBox.shrink();
    } else if(refreshState is Error) {
      return errorView?.call(refreshState.exception) ?? const SizedBox.shrink();
    }

    final isListEmpty =
        data.loadStates?.refresh is NotLoading && data.data.isEmpty;

    if(isListEmpty) {
      return emptyView;
    }

    return successView?.call(data.data) ?? const SizedBox.shrink();
  }

}