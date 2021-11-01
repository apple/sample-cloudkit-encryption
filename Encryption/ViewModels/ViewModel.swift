//
//  ViewModel.swift
//  (cloudkit-samples) Encryption
//

import Foundation
import CloudKit
import OSLog

@MainActor
final class ViewModel: ObservableObject {

    // MARK: - State

    enum State {
        case idle
        case loading
        case loaded(contacts: [Contact])
        case error(Error)
    }

    // MARK: - Properties

    /// State directly observable by our view.
    @Published private(set) var state = State.idle
    /// Use the specified iCloud container ID, which should also be present in the entitlements file.
    private lazy var container = CKContainer(identifier: Config.containerIdentifier)
    /// This project uses the user's private database.
    private lazy var database = container.privateCloudDatabase
    /// This project uses custom record zone.
    let recordZone = CKRecordZone(zoneName: "EncryptedContacts")

    // MARK: - API

    nonisolated init() {}

    /// Initializes the ViewModel, preparing for CloudKit interaction.
    func initialize() async throws {
        state = .loading

        do {
            try await createZoneIfNeeded()
        } catch {
            state = .error(error)
        }
    }

    /// Fetches contacts from the database and updates local state.
    func refresh() async throws {
        state = .loading

        do {
            let contacts = try await fetchContacts()
            state = .loaded(contacts: contacts)
        } catch {
            state = .error(error)
        }
    }

    /// Fetches records from iCloud Database and returns converted Contacts.
    func fetchContacts() async throws -> [Contact] {
        let changes = try await database.recordZoneChanges(inZoneWith: recordZone.zoneID, since: nil)

        /// Map new/changed records to `Contact` objects.
        let contacts = changes.modificationResultsByID.values
            .compactMap { try? $0.get().record }
            .compactMap { Contact(record: $0) }

        return contacts
    }

    /// Adds a new Contact to the database, using `encryptedValues` to encrypt the Contact's phone number.
    /// - Parameters:
    ///   - name: Name of the Contact.
    ///   - phoneNumber: Phone number of the contact which will be stored in an encrypted field.
    /// - Returns: The newly created Contact.
    func addContact(name: String, phoneNumber: String) async throws -> Contact? {
        let record = CKRecord(recordType: "Contact", recordID: CKRecord.ID(zoneID: recordZone.zoneID))
        record["name"] = name
        record.encryptedValues["phoneNumber"] = phoneNumber

        do {
            let savedRecord = try await database.save(record)
            return Contact(record: savedRecord)
        } catch {
            handleError(error)
            throw error
        }
    }

    /// Deletes a given list of Contacts from the database.
    /// - Parameters:
    ///   - contacts: Contacts to delete.
    func deleteContacts(_ contacts: [Contact]) async throws {
        let recordIDs = contacts.map { $0.associatedRecord.recordID }
        guard !recordIDs.isEmpty else {
            debugPrint("Attempted to delete empty array of Contacts. Skipping.")
            return
        }

        do {
            _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
        } catch {
            handleError(error)
        }
    }

    /// Creates the custom zone in use if needed.
    private func createZoneIfNeeded() async throws {
        // Avoid the operation if this has already been done.
        guard !UserDefaults.standard.bool(forKey: "isZoneCreated") else {
            return
        }

        do {
            _ = try await database.modifyRecordZones(saving: [recordZone], deleting: [])
        } catch {
            print("ERROR: Failed to create custom zone: \(error.localizedDescription)")
            throw error
        }

        UserDefaults.standard.setValue(true, forKey: "isZoneCreated")
    }

    private func handleError(_ error: Error) {
        guard let ckerror = error as? CKError else {
            os_log("Not a CKError: \(error.localizedDescription)")
            return
        }

        switch ckerror.code {
        case .zoneNotFound:
            if ckerror.userInfo[CKErrorUserDidResetEncryptedDataKey] != nil {
                // CloudKit is unable to decrypt previously encrypted data. This occurs when a user
                // resets their iCloud Keychain and thus deletes the key material previously used
                // to encrypt and decrypt their encrypted fields stored via CloudKit.
                // In this case, it is recommended to delete the associated zone and re-upload any
                // locally cached data, which will be encrypted with the new key.
                os_log("Encryption key has been reset by user.")
            }

        case .partialFailure:
            // Iterate through error(s) in partial failure and report each one.
            let dict = ckerror.userInfo[CKPartialErrorsByItemIDKey] as? [NSObject: CKError]
            if let errorDictionary = dict {
                for (_, error) in errorDictionary {
                    os_log("An error occurred: \(error.localizedDescription)")
                }
            }

        default:
            os_log("CKError: Code \(ckerror.code.rawValue): \(ckerror.localizedDescription)")
        }
    }
}
