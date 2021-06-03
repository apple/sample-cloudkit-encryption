//
//  EncryptionTests.swift
//  EncryptionTests
//

import XCTest
import CloudKit
@testable import Encryption

class EncryptionTests: XCTestCase {

    // MARK: - Properties

    let viewModel = ViewModel()

    var contactsToDelete: [Contact] = []

    // MARK: - Setup & Tear-down

    override func setUp() {
        let expectation = self.expectation(description: "Expect initialization completed")

        viewModel.initializeAndRefresh { result in
            expectation.fulfill()

            if case .failure(let error) = result {
                XCTFail("Initialization failed: \(error)")
            }
        }

        waitForExpectations(timeout: 10)
    }

    override func tearDown() {
        guard !contactsToDelete.isEmpty else {
            return
        }

        let deleteExpectation = expectation(description: "Expect Contacts created during tests to delete.")

        viewModel.deleteContacts(contactsToDelete) { result in
            deleteExpectation.fulfill()

            if case .failure(let error) = result {
                XCTFail("Failed to delete contacts after testing: \(error)")
            }
        }

        waitForExpectations(timeout: 10)
    }

    // MARK: - Tests

    func test_CloudKitReadiness() throws {
        // Fetch zones from the Private Database of the CKContainer for the current user to test for valid/ready state
        let container = CKContainer(identifier: Config.containerIdentifier)
        let database = container.privateCloudDatabase

        let fetchExpectation = expectation(description: "Expect CloudKit fetch to complete")
        database.fetchAllRecordZones { _, error in
            if let error = error as? CKError {
                switch error.code {
                case .badContainer, .badDatabase:
                    XCTFail("Create or select a CloudKit container in this app target's Signing & Capabilities in Xcode")

                case .permissionFailure, .notAuthenticated:
                    XCTFail("Simulator or device running this app needs a signed-in iCloud account")

                default:
                    XCTFail("CKError: \(error)")
                }
            }
            fetchExpectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testCreatingAndFetchingContact() {
        let finishExpectation = expectation(description: "Expect add and fetch operations to complete")

        viewModel.addContact(name: "TestContact-\(UUID().uuidString)",
                             phoneNumber: "555-123-4567") { [weak self] result in
            switch result {
            case .failure(let error):
                XCTFail("Failed to create new contact: \(error)")
                finishExpectation.fulfill()
            case .success(let contact):
                guard let contact = contact else {
                    XCTFail("Contact returned from addContact was nil.")
                    finishExpectation.fulfill()
                    return
                }

                self?.contactsToDelete.append(contact)

                self?.fetchContactsOrFail { contacts in
                    finishExpectation.fulfill()

                    guard let foundContact = contacts.first(where: { $0.id == contact.id }) else {
                        XCTFail("Created contact not found in subsequent fetch.")
                        return
                    }

                    XCTAssert(foundContact.phoneNumber == contact.phoneNumber,
                              "Fetched Contact number does not match created Contact number.")
                }
            }
        }

        waitForExpectations(timeout: 10)
    }

    /// Helper to simply fetch contacts or cause an `XCTFail`
    /// - Parameter completion: Completion handler.
    private func fetchContactsOrFail(completion: @escaping ([Contact]) -> Void) {
        viewModel.fetchContacts { result in
            switch result {
            case .failure(let error):
                XCTFail("Unable to fetch contacts: \(error)")
                completion([])
            case .success(let contacts):
                completion(contacts)
            }
        }
    }
}
