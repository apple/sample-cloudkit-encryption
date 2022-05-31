# CloudKit Samples: Encryption

### Goals

This project demonstrates using encrypted values with CloudKit and iCloud containers. CloudKit encrypts data with key material stored in a customer’s iCloud Keychain. If a customer loses access to their iCloud Keychain, CloudKit cannot access the key material previously used to encrypt data stored in the cloud, meaning that data can no longer be decrypted and accessed by the customer. More information about this is covered in the “Error Handling” section below.

### Prerequisites

* A Mac with [Xcode 12](https://developer.apple.com/xcode/) (or later) installed is required to build and test this project.
* An active [Apple Developer Program membership](https://developer.apple.com/support/compare-memberships/) is needed to create a CloudKit container.

### Setup Instructions

* Ensure the simulator or device you run the project on is signed in to an Apple ID account with iCloud enabled. This can be done in the Settings app.
* If you wish to run the app on a device, ensure the correct developer team is selected in the “Signing & Capabilities” tab of the Encryption app target, and a valid iCloud container is selected under the “iCloud” section.

#### Using Your Own iCloud Container

* Create a new iCloud container through Xcode’s “Signing & Capabilities” tab of the Queries app target.
* Update the `containerIdentifier` property in [Config.swift](Encryption/Config.swift) with your new iCloud container ID.

### How it Works

This project only differs very slightly from other samples, in that it uses the `encryptedValues` property of [`CKRecord`](https://developer.apple.com/documentation/cloudkit/ckrecord) in two places.

Setting the `phoneNumber` value in ViewModel.swift `addContact`:
```swift
contactRecord.encryptedValues["phoneNumber"] = phoneNumber
```

…and retrieving the `phoneNumber` value (in Contact.swift `Contact.init(record:)`):
```swift
let phoneNumber = record.encryptedValues["phoneNumber"] as? String
```

You can confirm that the value is encrypted by viewing the schema in [CloudKit Dashboard](https://icloud.developer.apple.com) and confirming that the `phoneNumber` custom field under the Contact type shows “Encrypted Bytes” for its “Field Type”.

### Notes on Encrypted Fields

* Encrypted fields cannot have indexes.
* Existing fields in a CloudKit schema are not eligible for encryption.
* `CKReference` fields cannot be encrypted.
* `CKAsset` fields are encrypted by default, and therefore should not be set as `encryptedValues` fields.
* `CKRecordID`, `CKRecordZoneID` or any other data types that is not one of `NSString`, `NSNumber`, `NSDate`, `NSData`, `CLLocation` and `NSArray` cannot be set as `encryptedValues` fields.

### Error Handling

* As described above, CloudKit encrypts data with key material store in a customer’s iCloud Keychain. If this key material is lost, for example by a customer resetting their iCloud Keychain, CloudKit is unable to decrypt previously encrypted data and returns a specific error code.
* This is demonstrated in the `handleError` function, where a `CKError` with a `zoneNotFound` code may have a `CKErrorUserDidResetEncryptedDataKey` `NSNumber` value in the `userInfo` dictionary.
* It is outside the scope of this sample, but it is recommended when encountering this error to first delete the relevant zone(s), re-create them, and then re-upload locally-cached data from the device to those zones. This new data is encrypted using the new key material from the user’s iCloud Keychain.

### Things To Learn

* Creating, fetching from, and saving to a custom zone.
* Saving and retrieving encrypted values in a record in the remote Private Database.
* Handling errors specifically related to using Encrypted Fields.
* Using XCTest to asynchronously test creating new temporary records, fetching records, and cleaning up records created during tests with `tearDown` functions.

### Note on Swift Concurrency

This project uses Swift concurrency APIs. A prior `completionHandler`-based implementation has been tagged [`pre-async`](https://github.com/apple/cloudkit-sample-encryption/tree/pre-async).

### Further Reading

* [Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting_user_data)
