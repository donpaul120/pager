class PagingConfig {
  PagingConfig({
    this.pageSize = 15,
    this.preFetchDistance = 5,
    this.initialPageSize = 15
  });

  final int pageSize;
  
  final int preFetchDistance;

  final int initialPageSize;

  const PagingConfig.fromDefault({
    this.pageSize = 20,
    this.preFetchDistance = 5,
    this.initialPageSize = 20
  });
}