class PagerRecordData<T> {
  const PagerRecordData({
    this.totalPages = 0,
    this.totalItems = 0,
    this.records = const [],
  });

  final int totalPages;
  final int totalItems;
  final List<T> records;
}
