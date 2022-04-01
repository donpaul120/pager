class PagingConfig {
  PagingConfig({
    this.pageSize = 20,
    this.preFetchDistance = 60,
    this.initialPageSize = 2
  });

  final int pageSize;
  
  final int preFetchDistance;

  final int initialPageSize;

  const PagingConfig.fromDefault({
    this.pageSize = 10,
    this.preFetchDistance = 60,
    this.initialPageSize = 30
  });
}