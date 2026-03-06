import 'package:flutter/material.dart';
import 'dart:async';
import 'load_state.dart';
import 'paging_data.dart';

/// A [ListView] that displays paginated data from a [PagingData] stream
class PagingListView<T> extends StatefulWidget {
  /// Stream of [PagingData] to display
  final Stream<PagingData<T>> pagingDataStream;
  
  /// Builder for individual items
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  
  /// Builder for loading state
  final Widget Function(BuildContext context)? loadingBuilder;
  
  /// Builder for error state
  final Widget Function(BuildContext context, Exception error)? errorBuilder;
  
  /// Builder for empty state  
  final Widget Function(BuildContext context)? emptyBuilder;
  
  /// Callback when append load should be triggered
  final VoidCallback? onAppend;
  
  /// Callback when prepend load should be triggered
  final VoidCallback? onPrepend;
  
  /// Distance from end to trigger append load
  final int appendTriggerDistance;
  
  /// Distance from start to trigger prepend load
  final int prependTriggerDistance;
  
  /// Scroll controller
  final ScrollController? controller;
  
  /// Scroll direction
  final Axis scrollDirection;
  
  /// Whether to reverse the scroll view
  final bool reverse;
  
  /// Scroll physics
  final ScrollPhysics? physics;
  
  /// Whether to shrink wrap the content
  final bool shrinkWrap;
  
  /// Padding for the list
  final EdgeInsetsGeometry? padding;
  
  const PagingListView({
    Key? key,
    required this.pagingDataStream,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.onAppend,
    this.onPrepend,
    this.appendTriggerDistance = 3,
    this.prependTriggerDistance = 3,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  }) : super(key: key);

  @override
  State<PagingListView<T>> createState() => _PagingListViewState<T>();
}

class _PagingListViewState<T> extends State<PagingListView<T>> {
  late StreamSubscription<PagingData<T>> _subscription;
  PagingData<T>? _currentData;
  ScrollController? _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController!.addListener(_onScroll);
    
    _subscription = widget.pagingDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentData = data;
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(PagingListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.pagingDataStream != oldWidget.pagingDataStream) {
      _subscription.cancel();
      _subscription = widget.pagingDataStream.listen((data) {
        if (mounted) {
          setState(() {
            _currentData = data;
          });
        }
      });
    }
    
    if (widget.controller != oldWidget.controller) {
      _scrollController?.removeListener(_onScroll);
      _scrollController = widget.controller ?? ScrollController();
      _scrollController!.addListener(_onScroll);
    }
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    if (widget.controller == null) {
      _scrollController?.dispose();
    } else {
      _scrollController?.removeListener(_onScroll);
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (!mounted || _currentData == null) return;
    
    final position = _scrollController!.position;
    final itemCount = _currentData!.itemCount;
    
    // Calculate current visible index based on scroll position
    final averageItemHeight = position.maxScrollExtent / itemCount;
    final currentIndex = (position.pixels / averageItemHeight).floor();
    
    // Check if we should trigger append
    if (widget.onAppend != null && 
        !_currentData!.loadStates.append.isLoading &&
        !_currentData!.loadStates.append.isCompleted) {
      
      if (currentIndex >= itemCount - widget.appendTriggerDistance) {
        widget.onAppend!();
      }
    }
    
    // Check if we should trigger prepend
    if (widget.onPrepend != null &&
        !_currentData!.loadStates.prepend.isLoading &&
        !_currentData!.loadStates.prepend.isCompleted) {
      
      if (currentIndex <= widget.prependTriggerDistance) {
        widget.onPrepend!();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final data = _currentData;
    
    // Handle initial loading state
    if (data == null || (data.itemCount == 0 && data.loadStates.refresh.isLoading)) {
      return widget.loadingBuilder?.call(context) ?? 
          const Center(child: CircularProgressIndicator());
    }
    
    // Handle refresh error state
    if (data.itemCount == 0 && data.loadStates.refresh.isError) {
      final error = (data.loadStates.refresh as LoadStateError).error;
      return widget.errorBuilder?.call(context, error) ?? 
          Center(child: Text('Error: $error'));
    }
    
    // Handle empty state
    if (data.itemCount == 0) {
      return widget.emptyBuilder?.call(context) ?? 
          const Center(child: Text('No data'));
    }
    
    // Calculate total item count including loading indicators
    int totalItemCount = data.itemCount;
    
    // Add loading indicator for prepend
    if (data.loadStates.prepend.isLoading) {
      totalItemCount++;
    }
    
    // Add loading indicator for append  
    if (data.loadStates.append.isLoading) {
      totalItemCount++;
    }
    
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        // Handle prepend loading indicator
        if (data.loadStates.prepend.isLoading && index == 0) {
          return widget.loadingBuilder?.call(context) ?? 
              const Center(child: CircularProgressIndicator());
        }
        
        // Adjust index if prepend loading indicator is shown
        int dataIndex = index;
        if (data.loadStates.prepend.isLoading) {
          dataIndex--;
        }
        
        // Handle append loading indicator
        if (data.loadStates.append.isLoading && dataIndex >= data.itemCount) {
          return widget.loadingBuilder?.call(context) ?? 
              const Center(child: CircularProgressIndicator());
        }
        
        // Handle normal data item
        if (dataIndex >= 0 && dataIndex < data.itemCount) {
          final item = data.getItem(dataIndex);
          if (item != null) {
            return widget.itemBuilder(context, item, dataIndex);
          }
        }
        
        // Fallback - shouldn't happen
        return const SizedBox.shrink();
      },
    );
  }
}

/// A [SliverList] that displays paginated data from a [PagingData] stream
class PagingSliverList<T> extends StatefulWidget {
  /// Stream of [PagingData] to display
  final Stream<PagingData<T>> pagingDataStream;
  
  /// Builder for individual items
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  
  /// Builder for loading state
  final Widget Function(BuildContext context)? loadingBuilder;
  
  /// Builder for error state
  final Widget Function(BuildContext context, Exception error)? errorBuilder;
  
  /// Builder for empty state
  final Widget Function(BuildContext context)? emptyBuilder;
  
  /// Callback when append load should be triggered
  final VoidCallback? onAppend;
  
  /// Callback when prepend load should be triggered  
  final VoidCallback? onPrepend;
  
  /// Distance from end to trigger append load
  final int appendTriggerDistance;
  
  /// Distance from start to trigger prepend load
  final int prependTriggerDistance;
  
  const PagingSliverList({
    Key? key,
    required this.pagingDataStream,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.onAppend,
    this.onPrepend,
    this.appendTriggerDistance = 3,
    this.prependTriggerDistance = 3,
  }) : super(key: key);

  @override
  State<PagingSliverList<T>> createState() => _PagingSliverListState<T>();
}

class _PagingSliverListState<T> extends State<PagingSliverList<T>> {
  late StreamSubscription<PagingData<T>> _subscription;
  PagingData<T>? _currentData;
  
  @override
  void initState() {
    super.initState();
    
    _subscription = widget.pagingDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentData = data;
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(PagingSliverList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.pagingDataStream != oldWidget.pagingDataStream) {
      _subscription.cancel();
      _subscription = widget.pagingDataStream.listen((data) {
        if (mounted) {
          setState(() {
            _currentData = data;
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final data = _currentData;
    
    // Handle initial loading state
    if (data == null || (data.itemCount == 0 && data.loadStates.refresh.isLoading)) {
      return SliverToBoxAdapter(
        child: widget.loadingBuilder?.call(context) ?? 
            const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Handle refresh error state
    if (data.itemCount == 0 && data.loadStates.refresh.isError) {
      final error = (data.loadStates.refresh as LoadStateError).error;
      return SliverToBoxAdapter(
        child: widget.errorBuilder?.call(context, error) ?? 
            Center(child: Text('Error: $error')),
      );
    }
    
    // Handle empty state
    if (data.itemCount == 0) {
      return SliverToBoxAdapter(
        child: widget.emptyBuilder?.call(context) ?? 
            const Center(child: Text('No data')),
      );
    }
    
    // Calculate total item count including loading indicators
    int totalItemCount = data.itemCount;
    
    if (data.loadStates.prepend.isLoading) {
      totalItemCount++;
    }
    
    if (data.loadStates.append.isLoading) {
      totalItemCount++;
    }
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Handle prepend loading indicator
          if (data.loadStates.prepend.isLoading && index == 0) {
            return widget.loadingBuilder?.call(context) ?? 
                const Center(child: CircularProgressIndicator());
          }
          
          // Adjust index if prepend loading indicator is shown
          int dataIndex = index;
          if (data.loadStates.prepend.isLoading) {
            dataIndex--;
          }
          
          // Handle append loading indicator
          if (data.loadStates.append.isLoading && dataIndex >= data.itemCount) {
            return widget.loadingBuilder?.call(context) ?? 
                const Center(child: CircularProgressIndicator());
          }
          
          // Trigger loads based on position
          if (widget.onAppend != null && 
              !data.loadStates.append.isLoading &&
              !data.loadStates.append.isCompleted &&
              dataIndex >= data.itemCount - widget.appendTriggerDistance) {
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onAppend!();
            });
          }
          
          if (widget.onPrepend != null &&
              !data.loadStates.prepend.isLoading &&
              !data.loadStates.prepend.isCompleted &&
              dataIndex <= widget.prependTriggerDistance) {
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onPrepend!();
            });
          }
          
          // Handle normal data item
          if (dataIndex >= 0 && dataIndex < data.itemCount) {
            final item = data.getItem(dataIndex);
            if (item != null) {
              return widget.itemBuilder(context, item, dataIndex);
            }
          }
          
          // Fallback
          return const SizedBox.shrink();
        },
        childCount: totalItemCount,
      ),
    );
  }
}