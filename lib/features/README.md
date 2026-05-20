Target feature structure for this project:

- `features/auth`: login, register, forgot password, splash, account security
- `features/driver/activity`: activity history and ongoing/history/pushed rides
- `features/driver/finance`: wallet history, withdrawal history, deposit/withdraw flows
- `features/driver/profile`: driver profile and update profile flows
- `features/driver/rides`: ride detail and ride models
- `features/chat`: driver chat group list and group chat
- `features/kyc`: KYC flow, face detection, related providers
- `features/routes`: route registration flow

During migration, old imports under `screens/`, `providers/`, and `models/` can continue to work.
New code should prefer importing through `features/...` barrels where available.
