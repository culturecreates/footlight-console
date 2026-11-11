# Event collection and dashboard monitoring

Console expects Condenser's `/websites/:seedurl/events.json` to return the complete matching collection. It calculates status counts and applies status filters before its own view pagination. Deploy the matching Condenser JSON pagination fix first.

If Condenser advertises a `total_events` different from the number of supplied event objects, Console logs the contract error and shows a retry message rather than displaying partial totals. Invalid or unavailable responses use the same error path. A valid empty collection is distinct from an unavailable response. Responses without a total remain supported for compatibility; a server that supplies an incorrect total equal to its page length cannot be detected by this guard alone.

Monitoring metrics come from a separate endpoint. Missing metrics stay unknown: they must not produce a zero-event badge, 0% publishability, a zero-day horizon, or a healthy pipeline score. A measured zero remains distinguishable from an absent value. Statement activity remains independent of health availability.

The dashboard continues to use the two bulk statistics endpoints and on-demand pipeline links. Do not restore a per-website event-fetching loop to the dashboard.

Focused checks with the normal development/test runtime:

```sh
bin/rails test test/controllers/concerns/condenser_safe_test.rb test/services/metrics_interpreter_test.rb test/controllers/events_controller_test.rb test/controllers/static_pages_controller_test.rb
```

Staging verification after both branches are deployed:

1. Open a site with more than 100 matching upcoming events. The heading and status counts must cover every matching event, including events beyond the first 25.
2. Apply a status filter whose matching event lies beyond that first page. It must remain discoverable.
3. Compare the same date scope and snapshot; production may have changed since the staging database copy. Monitoring event-page totals can differ from upcoming event totals grouped by URI.
4. Confirm sites absent from the monitoring JSON show unknown metrics while retaining available webpage/statement/activity statistics.

This change does not alter monitorable flags in either database or redefine Health, Publishable, scheduling risk, or the horizon calculation. Remaining flag assignments and metric-definition improvements are separate follow-up work.
