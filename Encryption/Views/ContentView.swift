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
                    Button { vm.refresh() } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isAddingContact = true } label: { Image(systemName: "plus") }
                }
            }
        }.onAppear { vm.initializeAndRefresh() }
    }

    private var contentView: some View {
        let view: AnyView = {
            switch vm.state {
            case .loaded(let contacts):
                let listView = List {
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading) {
                            Text(contact.name)
                            Text(contact.phoneNumber)
                                .textContentType(.telephoneNumber)
                                .font(.footnote)
                        }
                    }.onDelete(perform: deleteContacts(at:))
                }

                return AnyView(listView)

            case .error(let error):
                return AnyView(Text("An error occurred: \(error.localizedDescription)"))

            default:
                return AnyView(EmptyView())
            }
        }()

        return view
    }

    private func addContact(name: String, phoneNumber: String) {
        isAddingContact = false

        vm.addContact(name: name, phoneNumber: phoneNumber) { _ in
            vm.refresh()
        }
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

        vm.deleteContacts(contactsToDelete) { _ in
            vm.refresh()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(ViewModel())
    }
}
