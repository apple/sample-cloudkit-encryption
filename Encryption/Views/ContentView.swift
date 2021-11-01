//
//  ContentView.swift
//  (cloudkit-samples) Encryption
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: ViewModel

    @State var nameInput: String = ""
    @State var isAddingContact: Bool = false

    var body: some View {
        NavigationView {
            contentView.sheet(isPresented: $isAddingContact) {
                AddContactView(onAdd: addContact, onCancel: { isAddingContact = false })
            }
            .navigationTitle("Encrypted Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { try await vm.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isAddingContact = true } label: { Image(systemName: "plus") }
                }
            }
        }.onAppear {
            Task {
                try await vm.initialize()
                try await vm.refresh()
            }
        }
    }

    private var contentView: some View {
        let listView = List {
            switch vm.state {
            case .loaded(contacts: let contacts):
                ForEach(contacts) { contact in
                    VStack(alignment: .leading) {
                        Text(contact.name)
                        Text(contact.phoneNumber)
                            .textContentType(.telephoneNumber)
                            .font(.footnote)
                    }
                }.onDelete(perform: deleteContacts(at:))

            case .loading:
                ProgressView()

            case .error(let error):
                Text("An error occurred: \(error.localizedDescription)")

            case .idle:
                EmptyView()
            }
        }

        return AnyView(listView)
    }

    private func addContact(name: String, phoneNumber: String) async throws {
        isAddingContact = false

        _ = try await vm.addContact(name: name, phoneNumber: phoneNumber)
        try await vm.refresh()
    }

    private func deleteContacts(at indexSet: IndexSet) {
        guard case .loaded(let contacts) = vm.state else {
            debugPrint("Tried to delete contacts without loaded VM state.")
            return
        }

        // Get set of Contacts based on indexSet argument.
        let contactsToDelete = contacts.enumerated()
            .filter { index, _ in indexSet.contains(index) }
            .map { _, contact in contact }

        Task {
            try await vm.deleteContacts(contactsToDelete)
            try await vm.refresh()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(ViewModel())
    }
}
