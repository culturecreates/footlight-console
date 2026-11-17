# Monitoring

Administrators can open **Account → Monitoring**. The page reads the authenticated Condenser `/monitoring.json` endpoint through the existing API client and shows only errors explicitly flagged by DSL. It supports site/status filters, source/statement inspection links and 100 issues per page. Successful refreshes in Condenser resolve issues. Console never maintains a second issue store or sends additional emails.

Deploy the matching Condenser `harden-dsl-reliability` changes and run its database migration first. If the endpoint is missing or unavailable, Console returns an explicit unavailable state rather than claiming there are no errors. Configure the optional monitoring mailbox in **Condenser Options**. Its weekly pulse includes the same open issues as this page and sends even when there are none. It replaces the daily error digest on pulse day. Delivery and the separate daily digest task are documented in Condenser `docs/monitoring.md`.

Non-administrators cannot access this page. Existing site refreshes, schedules and dashboard behavior are unchanged.
