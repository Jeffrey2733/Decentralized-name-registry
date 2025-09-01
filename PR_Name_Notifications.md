# Name Expiration Notification System

**Title:** feat: add name expiration notification system for user engagement

## Summary

Implements a comprehensive notification system that allows users to subscribe to expiration alerts for names in the registry. This feature enhances user experience by providing proactive notifications before names expire, helping users manage their registrations effectively.

## Key Features

### Core Functionality
- **Subscription Management**: Users can subscribe to expiration notifications for any name with customizable reminder periods (1-7 days before expiration)
- **Payment System**: Small fee (0.05 STX) for notification service to cover operational costs
- **Batch Operations**: Admin can set expiration dates for multiple names efficiently
- **Active Subscription Tracking**: Users can monitor their notification subscription count

### Smart Contract Functions
- `subscribe-to-expiration(name, reminder-period)`: Subscribe to notifications
- `cancel-subscription(name)`: Cancel existing notification subscription  
- `check-expiration-reminder(name, subscriber)`: Check if notification is due
- `is-name-expiring-soon(name, days-ahead)`: Check expiration status
- `set-name-expiration(name, date)`: Admin function to set expiration dates
- `batch-set-expirations(names-and-dates)`: Batch expiration setting

### Analytics & Monitoring
- Real-time expiration status checking
- User subscription statistics
- Configurable reminder periods (1-10,080 blocks, ~1 day to 7 days)

## Technical Implementation

### Data Structure
```clarity
;; Notification subscriptions
(define-map notification-subscriptions 
  {name: (string-ascii 50), subscriber: principal} 
  {reminder-period: uint, created-at: uint, active: bool})

;; Name expiration tracking  
(define-map name-expiration-dates (string-ascii 50) uint)

;; User statistics
(define-map user-notification-count principal uint)
```

### Key Constants
- `DEFAULT_REMINDER_PERIOD`: u1440 (24 hours)
- `MAX_REMINDER_PERIOD`: u10080 (7 days) 
- `NOTIFICATION_FEE`: u50000 (0.05 STX)

## Business Value

1. **User Retention**: Proactive notifications reduce accidental name losses
2. **Revenue Generation**: Small notification fees create additional revenue stream
3. **Enhanced UX**: Users feel more secure knowing they'll be reminded of expirations
4. **Operational Efficiency**: Automated notification system reduces support burden

## Integration Points

- Works alongside existing name registry functionality
- Admin controls for setting expiration dates
- Independent payment system using STX transfers
- Read-only functions for UI integration

## Testing Scenarios

The contract handles:
- Valid subscription creation with payment
- Duplicate subscription prevention
- Reminder period validation
- Active subscription management
- Expiration date tracking
- Batch operations for efficiency

## Security Considerations

- Owner-only administrative functions
- Payment validation for all subscriptions
- Input validation for reminder periods
- Prevents duplicate subscriptions

## Future Enhancements

- Email/SMS integration through oracles
- Bulk subscription discounts
- Referral rewards for notification service
- Integration with reputation system for premium users

## Lines of Code
Contract: 115 lines (well under 200 line limit)

## Deployment Notes
- Contract owner can adjust notification fees
- Requires initial setup of name expiration dates
- Compatible with existing name registry without modifications
