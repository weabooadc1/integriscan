# Engineer Verification System Setup

This document explains how the engineer verification system works and how to set up engineer roles.

## System Overview

When users flag reports for verification:
1. The flagged report is sent to a dedicated Firestore collection called `flagged_reports`
2. Only users with engineer privileges can approve or reject flagged reports
3. Regular users cannot approve/reject their own flagged reports

## Firestore Collections

### 1. `flagged_reports` Collection
Contains all reports that have been flagged for engineer verification:
```
{
  id: "report_id",
  originalReportId: "report_id", 
  flaggedByUserId: "user_id_who_flagged",
  flaggedAt: "2025-01-21T10:30:00Z",
  flaggedComments: "User's reason for flagging",
  status: "pending|approved|rejected",
  reportData: { /* complete report snapshot */ },
  engineerComments: "Engineer's review comments",
  engineerId: "engineer_user_id", 
  reviewedAt: "2025-01-21T11:30:00Z"
}
```

### 2. `users` Collection 
Contains user profile information including roles:
```
{
  uid: "user_id",
  firstName: "John",
  lastName: "Doe", 
  email: "john@example.com",
  role: "user|engineer|admin",
  createdAt: "2025-01-21T09:00:00Z",
  updatedAt: "2025-01-21T09:00:00Z"
}
```

## Setting Up Engineer Roles

To grant engineer privileges to a user:

1. Go to your Firebase Console
2. Navigate to Firestore Database
3. Find the `users` collection
4. Locate the user document by their UID
5. Edit the document and set the `role` field to `"engineer"` 

Alternatively, you can update via code:
```dart
await FirestoreService.updateUserRole(userId, 'engineer');
```

## Role Permissions

- **user**: Can flag reports for verification, view their own reports
- **engineer**: Can approve/reject flagged reports, all user permissions  
- **admin**: Can manage user roles, all engineer permissions

## Security Rules

Make sure your Firestore security rules enforce these permissions:

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Engineers can read all flagged reports
    match /flagged_reports/{reportId} {
      allow read: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['engineer', 'admin'];
      allow write: if request.auth != null;
    }
  }
}
```

## Testing the System

1. Create test users with different roles
2. Flag some reports as a regular user
3. Log in as an engineer to approve/reject reports  
4. Verify regular users cannot see approve/reject buttons
5. Confirm flagged reports appear in the Firestore `flagged_reports` collection

## Troubleshooting

- If approval/rejection fails, check if user has engineer role in Firestore
- Verify Firebase security rules allow engineers to read flagged_reports collection
- Check network connectivity for Firestore sync operations
- Review app logs for detailed error messages
