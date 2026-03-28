# Agency Ops & Profit-Share Mobile App: Feature Hierarchy

## 1. Authentication & Role Management
* **Secure Authentication:** Firebase login for the four equal co-founders.
* **Role-Based Access Control (RBAC):** Distinct interface views for the Admin (Core Founder) and the Members (Cousins).

## 2. Client & CRM Engine
* **Multi-Client Profiles:** Add and manage multiple active clients per month.
* **Client Financials:** Track total project value, amount received, and pending balances.
* **Deadline Tracking:** Log project start dates and payment due dates.
* **Service Allocation:** Assign specific deliverables to a client from your 11 defined agency services.

## 3. Task & Workflow State Machine
* **Custom Task Creation:** Assign tasks to cousins with a specific allocated time (e.g., "2 Days").
* **Urgent Flagging:** Mark tasks as urgent for an instant +25 point bonus potential.
* **Internal Operations:** Create non-revenue tasks (cleaning, meetings) disconnected from client profiles.
* **The Verification Pipeline:** Members push tasks to `PENDING_VERIFICATION`.
* **Admin Approval/Rejection:** The Admin reviews work to either move it to `VERIFIED` (awarding points) or return it to `ASSIGNED` (no penalty).

## 4. Financial & Expense Ledger
* **Revenue Aggregation:** Automatically sum all `amount_received` from active clients to build the month's Gross Revenue.
* **Setup Costs Tracker:** Log pre-work app/tool investments (deducted from revenue, does not impact team scores).
* **Team Spending Tracker:** Log daily operational expenses incurred by the cousins.
* **Live Net Profit Pool:** Real-time calculation of Revenue minus Setup Costs and Team Expenses.

## 5. The Attendance Gatekeeper
* **Admin QR Generator:** A dashboard button that generates a secure, daily QR code.
* **Member QR Scanner:** A mobile camera view for cousins to scan the daily code upon office arrival or approved WFH.
* **Automated Attendance Scoring:** Instantly awards the flat 10 points to the scanning member's daily tally.

## 6. Meritocratic Profit-Share Engine
* **Dynamic Point Tally:** Real-time aggregation of a member's Verified Task points and Attendance points.
* **Weighted Service Math:** Automatic calculation of base points using the 11 predefined service weights (e.g., Mobile App = 100).
* **Live Payout Estimation:** Calculates each cousin's current slice of the Net Profit Pool based on their percentage of the total team points.

## 7. History & Archiving System
* **Granular Activity Log:** Tracks exact timestamps of task completions and financial entries for the current month and the first 7 days of the next month.
* **Automated Pruning:** A background script that triggers on Day 8 to delete granular data and save a "Major History" summary.
* **Exportable Reports:** Downloadable PDF/CSV files detailing client histories, monthly P&L, and team performance payouts.

## 8. Admin Controls & Edge Cases
* **Manual Attendance Override:** An Admin function to manually award the 10 daily points for approved Work From Home (WFH) days without requiring a physical QR scan.
* **"Close & Lock Month" Trigger:** A manual Admin button to freeze the Net Profit Pool and lock Verified Tasks before triggering the Day 8 history pruning, ensuring accurate payroll calculations.
* **Service Weight Configuration:** An Admin-accessible settings panel to adjust the point values of the 11 services (e.g., changing Mobile App from 100 to 120) without needing to rewrite the core code.

## 9. UI & Data Refinements
* **Task Deadline Enforcement:** Visual countdown timers and red "Overdue" UI flags on the Member dashboard based on the custom allocated time for assigned tasks.
* **Granular Client History:** Extended history logs specifically tracking exact payment timestamps and service delivery dates for each client, subject to the standard 7-day retention rule.