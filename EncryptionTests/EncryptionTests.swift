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

        Task {
            try await viewModel.initialize()
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    override func tearDown() {
        guard !contactsToDelete.isEmpty else {
            return
        }

        let deleteExpectation = expectation(description: "Expect Contacts created during tests to delete.")

        Task {
            try await viewModel.deleteContacts(contactsToDelete)
            deleteExpectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    // MARK: - Tests

    func test_CloudKitReadiness() async throws {
        // Fetch zones from the Private Database of the CKContainer for the current user to test for valid/ready state
        let container = CKContainer(identifier: Config.containerIdentifier)
        let database = container.privateCloudDatabase

        do {
            _ = try await database.allRecordZones()
        } catch let error as CKError {
            switch error.code {
            case .badContainer, .badDatabase:
                XCTFail("Create or select a CloudKit container in this app target's Signing & Capabilities in Xcode")

            case .permissionFailure, .notAuthenticated:
                XCTFail("Simulator or device running this app needs a signed-in iCloud account")

            default:
                XCTFail("CKError: \(error)")
            }
        }
    }

    func testCreatingAndFetchingContact() async throws {
        do {
            let contact = try await viewModel.addContact(name: "TestContact-\(UUID().uuidString)", phoneNumber: "555-123-4567")

            guard let contact = contact else {
                XCTFail("Contact returned from addContact was nil.")
                return
            }

            contactsToDelete.append(contact)

            let contacts = try await viewModel.fetchContacts()
            guard let foundContact = contacts.first(where: { $0.id == contact.id }) else {
                XCTFail("Created contact not found in subsequent fetch.")
                return
            }

            XCTAssert(foundContact.phoneNumber == contact.phoneNumber,
                      "Fetched Contact number does not match created Contact number.")
        } catch {
            XCTFail("Failed to create new contact: \(error)")
        }
    }
}
