// import 'package:pager/paging/paging_state.dart';
// import 'package:pager/paging/remote_mediator.dart';
//
// abstract class AbstractServiceResultMediator<K, V> extends RemoteMediator<K, V> {
//
//   Future<void> saveToDB(List<V> value);
//
//   Future<ServiceResult<List<V>>> serviceCall(K? page);
//
//   Future<void> clearDB(List<V> items);
//
//   K? _page;
//
//   @override
//   Future<MediatorResult> load(LoadType loadType, PagingState pagingState) async {
//     try {
//       switch(loadType) {
//         case LoadType.REFRESH:
//           _page = null;
//           break;
//         case LoadType.APPEND:
//           _page = pagingState.data.last.nextKey;
//           break;
//         case LoadType.PREPEND:
//           return MediatorResult.success(endOfPaginationReached :true);
//       }
//       final response = await serviceCall(_page);
//       if(loadType == LoadType.REFRESH) {
//         clearDB(response.result ?? []);
//         saveToDB(response.result ?? []);
//       }
//
//       return MediatorResult.success(endOfPaginationReached : response.result?.isEmpty == true);
//     } catch(e) {
//       return MediatorResult.error(exception: e as Exception);
//     }
//   }
//
// }