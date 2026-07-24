# Oro Ticket App User Manual

## Brief User Manual (Quick Guide)

This guide is for ticketing officers using the Oro Ticket App in daily operations.

### 1. Log in
- Open the app and enter your Email and Password.
- Tap Log In.

### 2. Check your dashboard
- Confirm your company name and your name are shown.
- Check the Online or Offline indicator at the top.

### 3. Print and save a ticket
- Open Print Ticket from the bottom menu.
- Confirm the Departure Terminal is auto-filled.
- Type a Plate Number and choose the correct vehicle from suggestions.
- Verify Arrival Terminal, tariff, service charge, and total.
- Make sure a Bluetooth thermal printer is paired and connected.
- Tap Print & Save.

### 4. Review trip records
- From Home, tap Trip list to see locally stored trips.
- Use search to find trips by plate, terminal, or association.

### 5. View local report
- Open Local Report from the bottom menu.
- Search and expand rows to review trip details.

### 6. Sync and logout safely
- Sync pending data before logout.
- Logout is blocked when unsynced trips or service charges still exist.

---

## Detailed User Manual

## A. What the app is for

The Oro Ticket App supports:
- Secure staff sign-in.
- Vehicle-based trip ticket printing.
- Local trip storage when internet is unavailable.
- Automatic or manual sync when internet returns.
- Daily service-charge monitoring.
- Local reporting and search.

## B. Main screens and navigation

### Bottom navigation
- Home: Dashboard and daily information.
- Print Ticket: Ticket creation, printing, and save.
- Local Report: Local reporting of saved trips.

### Side drawer menu
- Vehicles
- Terminal Name (departure terminal)
- Arrival Terminal
- Change Password
- Logout

## C. Sign in

### Steps
1. Enter a valid email address.
2. Enter password (minimum 6 characters).
3. Tap Log In.

### What to expect
- On success, the app navigates to Home.
- If internet is unavailable, the app may allow offline login only when cached user data exists for the same email.
- Multiple failed attempts may trigger temporary login rate limiting.

## D. Home dashboard

### Header information
- Company name
- Employee name
- Connectivity state: Online or Offline

### Home actions
- Trip list button: opens trip list view.
- Sync icon: triggers trip sync.
- Daily Information:
  - Total Service Charge (for the day)
  - Ethiopian date
- Reset Dashboard button:
  - Prompts to sync service charges first.
  - If sync succeeds, dashboard service-charge state is reset.

## E. Print Ticket workflow (core operation)

### Before printing
1. Ensure Bluetooth thermal printer is paired with device.
2. Open Print Ticket.
3. Confirm Departure Terminal is filled automatically.

### Select vehicle and route
1. In Plate Number, type part or full plate.
2. Select the correct vehicle from suggestions.
3. App auto-fills route and ticket fields:
   - Departure and arrival terminals
   - Vehicle level and seat capacity
   - Distance
   - Tariff, service charge, total

### Print and save
1. Review receipt details.
2. Tap Print & Save.
3. The app will:
   - Validate the selected vehicle has a route.
   - Check Bluetooth printer connection.
   - Print passenger ticket and exit ticket (with QR content).
   - Save trip and service-charge data.
   - Try immediate server sync if online.

### Save and sync outcomes
- Posted to server: data posted successfully.
- Saved offline: internet unavailable, data kept locally for auto-sync later.
- Partial sync: some data synced, remaining data queued for retry.

### Important operational behavior
- After successful print/save, vehicle print is temporarily locked to prevent rapid re-printing for the same vehicle.
- If printer is unavailable, print/save does not complete.

## F. Trip list (from Home)

### Purpose
- View locally stored trip entries.

### Actions
- Search by plate number, terminal, or association.
- Pull to refresh list.

## G. Local Report

### Purpose
- Review local trip report entries with summary rows.

### Actions
- Search trips.
- Expand each row for details (route, level, association, pricing).
- Pull to refresh local report data.

## H. Vehicles

### Purpose
- View company vehicle list and details.

### Actions
- Search by plate number or status.
- Pull to refresh.
- Tap sync icon to refresh vehicles when online.
- Expand list items to inspect detailed vehicle info.

## I. Terminal screens

### Terminal Name (Departure)
- Displays current departure terminal name assigned for operations.
- Pull to refresh terminal data.

### Arrival Terminal
- Displays arrival locations with distance and road type.
- Search arrival locations.
- Pull to refresh and sync arrival list.

## J. Change Password

### Steps
1. Open drawer and choose Change Password.
2. Enter current password.
3. Enter new password (minimum 6 characters).
4. Confirm new password.
5. Tap Change Password.

### Result
- On success, password is changed and the app logs out automatically after a short delay.

## K. Logout rules

Logout is blocked if there is unsynced local data, including:
- Unsynced trip records
- Pending service-charge data

If blocked:
1. Sync your data first.
2. Retry logout.

## L. Offline and sync behavior

- The app supports offline ticket data storage.
- When internet is restored, pending data is retried automatically in background.
- Manual sync actions are also available from Home and list screens.

## M. Troubleshooting

### Cannot log in
- Check email format and password.
- Confirm internet access.
- Wait and retry if login rate limit appears.

### Printer not printing
- Confirm printer is paired over Bluetooth.
- Ensure printer is powered on and in range.
- Retry Print & Save after connection is restored.

### Cannot logout
- Open trip list/report and ensure pending records are synced.
- Use available sync actions, then logout again.

### Missing or stale data
- Pull to refresh in Vehicles, Arrival Terminal, Trip list, or Local Report.
- Check online status.

## N. Recommended daily routine

1. Log in and verify online/offline status.
2. Print and save tickets throughout operations.
3. Periodically open Trip list and run sync when online.
4. Before end of shift, verify pending data is synced.
5. Logout only after sync is complete.
