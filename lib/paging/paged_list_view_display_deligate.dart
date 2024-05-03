import 'package:flutter/material.dart';


class PagingBuilderDelegate<T> {

  /// A function that builds a widget for a given item of type [T] at a given index.
  ///
  /// This function is called for each item in the list. It takes in the [BuildContext],
  /// the item of type [T], and the index of the item in the list, and returns a widget
  /// that represents the item.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// A function that builds a separator widget for a given index.
  ///
  /// This function is called between each pair of items in the list. It takes in the
  /// [BuildContext] and the index of the separator, and returns a widget that represents
  /// the separator. If this function is null, no separators are displayed.
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// A function that builds a widget to be displayed when the list is loading more items.
  ///
  /// This function is called when the list is loading more items. It takes in the
  /// [BuildContext] and returns a widget that represents the loading state. If this
  /// function is null, no loading indicator is displayed.
  final WidgetBuilder? bottomLoadingIndicator;

  /// A function that builds a widget to be displayed when the list is loading.
  ///
  /// This function is called when the list is loading. It takes in the [BuildContext]
  /// and returns a widget that represents the loading state. If this function is null,
  /// no loading view is displayed.
  final WidgetBuilder? loadingViewBuilder;

  /// A function that builds a widget to be displayed when the list is empty.
  ///
  /// This function is called when the list is empty. It takes in the [BuildContext]
  /// and returns a widget that represents the empty state. If this function is null,
  /// no empty view is displayed.
  final WidgetBuilder? emptyViewBuilder;

  /// A function that builds a widget to be displayed when an error occurs.
  ///
  /// This function is called when an error occurs. It takes in the exception that
  /// caused the error and returns a widget that represents the error state. If this
  /// function is null, no error view is displayed.
  final Widget Function(Exception? error)? errorViewBuilder;

  /// A function that builds a widget to be displayed when an error occurs while loading a new page.
  ///
  /// This function is called when an error occurs while loading a new page. It takes in the
  /// exception that caused the error and returns a widget that represents the error state.
  /// If this function is null, no error indicator is displayed.
  final Widget Function(Exception? error)? newPageErrorIndicatorBuilder;

  const PagingBuilderDelegate(
      {Key? key,
      required this.itemBuilder,
      this.separatorBuilder,
      this.bottomLoadingIndicator,
      this.loadingViewBuilder,
      this.emptyViewBuilder,
      this.errorViewBuilder,
      this.newPageErrorIndicatorBuilder});
}