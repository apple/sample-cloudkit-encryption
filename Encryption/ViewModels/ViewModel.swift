//
//  ViewModel.swift
//  (cloudkit-samples) Encryption
//

import Foundation
import CloudKit
import OSLog

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

    /// Creates custom zone if needed and performs initial fetch afterwards.
    func initializeAndRefresh(completionHandler: ((Result<Void, Error>) -> Void)? = nil) {
        createZoneIfNeeded { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self?.state = .error(error)
                    completionHandler?(.failure(error))

                case .success:
                    self?.refresh()
                    completionHandler?(.success(()))
                }
            }
        }
    }

    /// Fetches contacts from the database and updates local state.
    func refresh() {
        DispatchQueue.main.async {
            self.state = .loading
        }

        fetchContacts { [weak self] result in
            switch result {
            case .success(let contacts):
                self?.state = .loaded(contacts: contacts)
            case .failure(let error):
                self?.state = .error(error)
            }
        }
    }

    /// Fetch contacts from iCloud database.
    /// - Parameter completionHandler: Handler to process Contact results or error.
    func fetchContacts(completionHandler: @escaping (Result<[Contact], Error>) -> Void) {
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZone.zoneID],
                                                          configurationsByRecordZoneID: [:])
        var contacts: [Contact] = []

        /// For each contact received from the operation, convert it to a `Contact` object and add it to an accumulating list.
        operation.recordWasChangedBlock = { _, result in
            if let record = try? result.get(), let contact = Contact(record: record) {
                contacts.append(contact)
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self?.handleError(error)
                    completionHandler(.failure(error))

                case .success:
                    completionHandler(.success(contacts))
                }
            }
        }

        database.add(operation)
    }

    /// Adds a new Contact to the database, using `encryptedValues` to encrypt the Contact's phone number.
    /// - Parameters:
    ///   - name: Name of the Contact.
    ///   - phoneNumber: Phone number of the contact which will be stored in an encrypted field.
    ///   - completionHandler: Handler to process success or failure of the operation.
    func addContact(
        name: String,
        phoneNumber: String,
        completionHandler: @escaping (Result<Contact?, Error>) -> Void
    ) {
        let record = CKRecord(recordType: "Contact", recordID: CKRecord.ID(zoneID: recordZone.zoneID))
        record["name"] = name
        record.encryptedValues["phoneNumber"] = phoneNumber

        let saveOperation = CKModifyRecordsOperation(recordsToSave: [record])
        saveOperation.savePolicy = .allKeys

        saveOperation.modifyRecordsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self?.handleError(error)
                    completionHandler(.failure(error))

                case .success:
                    let contact = Contact(record: record)
                    completionHandler(.success(contact))
                }
            }
        }

        database.add(saveOperation)
    }

    /// Deletes a given list of Contacts from the database.
    /// - Parameters:
    ///   - contacts: Contacts to delete.
    ///   - completionHandler: Handler to process success or failure of the operation.
    func deleteContacts(_ contacts: [Contact], completionHandler: @escaping (Result<Void, Error>) -> Void) {
        let recordIDs = contacts.map { $0.associatedRecord.recordID }
        guard !recordIDs.isEmpty else {
            debugPrint("Attempted to delete empty array of Contacts. Skipping.")
            return
        }

        let deleteOperation = CKModifyRecordsOperation(recordIDsToDelete: recordIDs)

        deleteOperation.modifyRecordsResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.handleError(error)
                }

                completionHandler(result)
            }
        }

        database.add(deleteOperation)
    }

    /// Creates the custom zone in use if needed.
    /// - Parameter completionHandler: An optional completion handler to track operation success or failure.
    private func createZoneIfNeeded(completionHandler: ((Result<Void, Error>) -> Void)? = nil) {
        // Avoid the operation if this has already been done.
        guard !UserDefaults.standard.bool(forKey: "isZoneCreated") else {
            completionHandler?(.success(()))
            return
        }

        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone])
        createZoneOperation.modifyRecordZonesResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    debugPrint("Error: Failed to create custom zone: \(error)")

                case .success:
                    UserDefaults.standard.setValue(true, forKey: "isZoneCreated")
                }

                completionHandler?(result)
            }
        }

        database.add(createZoneOperation)
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
