## 0.0.1

* initial release.

## 0.0.2

* Fixed concurrent modification issue when closing page subscriptions.

## 0.1.8

* First release on pub.dev, published as `pagerx` (the `pager` name is taken). Import with `package:pagerx/pagerx.dart`.
* Added prepend support to `PagerController`.
* Exposed the record mediator helper.
* Cached local data is shown before the remote mediator fetch completes.
* Fixed race conditions in `PagerController.initialize()` and `refresh()`.
* Fixed items being dropped when merging groups with the same key across pages.
* Added `collection` as an explicit dependency.
* Licensed under the MIT License.
* `pagerRecordMediator` now forwards `PagerRecordData.totalItems` (when greater than 0) to the controller's `totalItems`.
