import 'package:flutter/material.dart';
import 'package:pager/paging/load_state.dart';

class PagedListView extends StatelessWidget {

  const PagedListView({Key? key,
    required this.itemBuilder,
    required this.controller,
    this.loadState,
    this.separatorBuilder,
    this.itemCount = 0,
    this.shrinkWrap = false,
    this.bottomLoadingIndicator}) : super(key: key);

  final LoadState? loadState;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final Widget? bottomLoadingIndicator;
  final ScrollController controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      shrinkWrap: shrinkWrap,
      separatorBuilder: separatorBuilder ?? (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, index) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            itemBuilder(context, index),
            if (index == itemCount - 1 && loadState is Loading) ...[
              const SizedBox(height: 16),
              SizedBox(height: 20,width: 20, child: bottomLoadingIndicator),
              const SizedBox(height: 16),
            ]
          ],
        );
      },
      itemCount: itemCount,
    );
  }
}