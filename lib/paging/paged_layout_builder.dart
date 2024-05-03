import 'package:flutter/material.dart';
import 'package:pager/paging/load_state.dart';
import 'package:pager/paging/paged_list_view_display_deligate.dart';
import 'package:pager/paging/paging_data.dart';

class PagedLayoutBuilder<T> extends StatelessWidget {
  const PagedLayoutBuilder({
    Key? key,
    required this.data,
    required this.delegate,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
  }) : super(key: key);

  final PagingData<T> data;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final PagingBuilderDelegate<T> delegate;

  @override
  Widget build(BuildContext context) {
    final refreshState = data.loadStates?.refresh;

    if (refreshState == null || refreshState is Loading) {
      return _padView(delegate.loadingViewBuilder?.call(context) ??
          const SizedBox.shrink());
    } else if (refreshState is Error) {
      return _padView(delegate.errorViewBuilder?.call(refreshState.exception) ??
          const SizedBox.shrink());
    }

    final isListEmpty =
        data.loadStates?.refresh is NotLoading && data.data.isEmpty;

    if (isListEmpty) {
      return _padView(
          delegate.emptyViewBuilder?.call(context) ?? const SizedBox.shrink());
    }

    return _PagedListView(
      itemBuilder: (ctx, index) =>
          delegate.itemBuilder.call(context, data.data[index], index),
      controller: controller ?? ScrollController(),
      separatorBuilder: delegate.separatorBuilder,
      itemCount: data.data.length,
      bottomLoadingIndicator: delegate.bottomLoadingIndicator?.call(context),
      loadState: data.loadStates?.append,
      padding: padding,
      shrinkWrap: shrinkWrap,
    );
  }

  Widget _padView(Widget view) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: view,
    );
  }
}

class _PagedListView extends StatelessWidget {
  const _PagedListView(
      {Key? key,
      required this.itemBuilder,
      required this.controller,
      this.loadState,
      this.separatorBuilder,
      this.itemCount = 0,
      this.shrinkWrap = false,
      this.padding,
      this.bottomLoadingIndicator})
      : super(key: key);

  final LoadState? loadState;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final Widget? bottomLoadingIndicator;
  final ScrollController controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: padding,
      separatorBuilder: separatorBuilder ?? (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, index) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            itemBuilder(context, index),
            if (index == itemCount - 1 &&
                loadState is Loading &&
                bottomLoadingIndicator != null) ...[
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: bottomLoadingIndicator!)
            ]
          ],
        );
      },
      itemCount: itemCount,
    );
  }
}
