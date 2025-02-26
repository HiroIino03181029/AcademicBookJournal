AcademicBookJournal/
├── AcademicBookJournal/
│   ├── AcademicBookJournalApp.swift
│   ├── Models/
│   │   ├── Book.swift
│   │   └── JournalEntry.swift
│   ├── Views/
│   │   ├── BookSearchView.swift
│   │   ├── BookDetailView.swift
│   │   ├── JournalView.swift
│   │   └── Components/
│   │       ├── BookRow.swift
│   │       └── JournalEntryRow.swift
│   ├── ViewModels/
│   │   ├── BookSearchViewModel.swift
│   │   └── JournalStore.swift
│   ├── Services/
│   │   ├── JapaneseBookAPI.swift
│   │   └── JapaneseTextAnalyzer.swift
│   ├── Utilities/
│   │   └── Constants.swift
│   ├── Resources/
│   │   └── Assets.xcassets
│   └── AcademicBookJournal.xcdatamodeld
└── README.md
import SwiftUI

@main
struct AcademicBookJournalApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var journalStore = JournalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(journalStore)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            BookSearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
            
            JournalView()
                .tabItem {
                    Label("読書日記", systemImage: "book")
                }
        }
    }
}

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "AcademicBookJournal")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("CoreDataコンテナの読み込みエラー: \(error)")
            }
        }
    }
}
import Foundation

struct JournalEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var bookId: String
    var date: Date
    var content: String
    var rating: Int // 5段階評価
    var tags: [String] = []
    var quotes: [String] = [] // 印象に残った引用
    var readingStatus: ReadingStatus = .completed
    
    enum ReadingStatus: String, Codable, CaseIterable {
        case wantToRead = "読みたい"
        case reading = "読書中"
        case completed = "読了"
        case abandoned = "中断"
    }
    
    // ダミーデータ生成用
    static func sample(for book: Book) -> JournalEntry {
        return JournalEntry(
            bookId: book.id,
            date: Date(),
            content: "この本は学術的な視点から非常に興味深い考察が展開されていた。特に第3章の議論は新たな視点を与えてくれた。",
            rating: 4,
            tags: ["哲学", "学術", "教養"],
            quotes: ["知とは、単なる情報の集積ではなく、それを構造化する視点である。"],
            readingStatus: .completed
        )
    }
}
import SwiftUI

struct BookSearchView: View {
    @StateObject private var viewModel = BookSearchViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    TextField("書籍を検索", text: $viewModel.searchText)
                        .padding(7)
                        .padding(.horizontal, 25)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                                
                                if !viewModel.searchText.isEmpty {
                                    Button(action: {
                                        viewModel.searchText = ""
                                    }) {
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                        )
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    Button(action: viewModel.performSearch) {
                        Text("検索")
                            .padding(.horizontal, 10)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 5)
                
                // 関連キーワード表示
                if !viewModel.relatedKeywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.relatedKeywords, id: \.self) { keyword in
                                Button(action: {
                                    viewModel.searchText = keyword
                                    viewModel.performSearch()
                                }) {
                                    Text(keyword)
                                        .font(.footnote)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(15)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6).opacity(0.3))
                }
                
                // 検索結果一覧
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Spacer()
                } else if viewModel.books.isEmpty && viewModel.hasSearched {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("該当する学術書が見つかりませんでした")
                            .font(.headline)
                        Text("別のキーワードで検索してみてください")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.books) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                BookRow(book: book)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("学術書検索")
        }
    }
}
import SwiftUI

struct BookDetailView: View {
    let book: Book
    @State private var showingJournalForm = false
    @EnvironmentObject var journalStore: JournalStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 書籍画像とタイトル情報
                HStack(alignment: .top, spacing: 16) {
                    // 書籍画像
                    if let imageUrl = book.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 120, height: 180)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 180)
                                    .cornerRadius(8)
                            case .failure:
                                Image(systemName: "book.closed")
                                    .font(.system(size: 40))
                                    .frame(width: 120, height: 180)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(8)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .frame(width: 120, height: 180)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    
                    // 書籍情報
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.headline)
                            .lineLimit(3)
                        
                        if let author = book.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let publisher = book.publisher {
                            Text(publisher)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let publishDate = book.publishDate {
                            Text(publishDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // 書籍概要
                if let description = book.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("概要")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)
                }
                
                // 読書記録ボタン
                Button(action: {
                    showingJournalForm = true
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("読書記録を追加")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 既存の読書記録表示
                let entries = journalStore.entriesForBook(id: book.id)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("読書記録")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(entries) { entry in
                            JournalEntryRow(entry: entry)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("書籍詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingJournalForm) {
            JournalFormView(book: book, isPresented: $showingJournalForm)
        }
    }
  import SwiftUI

struct JournalView: View {
    @EnvironmentObject var journalStore: JournalStore
    @State private var selectedStatus: JournalEntry.ReadingStatus?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ステータスフィルター
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterButton(title: "すべて", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        
                        ForEach(JournalEntry.ReadingStatus.allCases, id: \.self) { status in
                            FilterButton(title: status.rawValue, isSelected: selectedStatus == status) {
                                selectedStatus = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6).opacity(0.5))
                
                // 日記一覧
                if filteredEntries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("読書記録がありません")
                            .font(.headline)
                        Text("本を読んだら、感想を記録しましょう")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: JournalDetailView(entry: entry)) {
                                JournalEntryRow(entry: entry)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("読書日記")
        }
    }
    
    private var filteredEntries: [JournalEntry] {
        if let status = selectedStatus {
            return journalStore.entries.filter { $0.readingStatus == status }
        } else {
            return journalStore.entries
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct JournalDetailView: View {
    let entry: JournalEntry
    @EnvironmentObject var journalStore: JournalStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 日付と評価
                HStack {
                    Text(entry.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= entry.rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                // 読書状態
                Text(entry.readingStatus.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(for: entry.readingStatus).opacity(0.2))
                    .foregroundColor(statusColor(for: entry.readingStatus))
                    .cornerRadius(8)
                
                // タグ
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Divider()
                
                // 感想内容
                Text(entry.content)
                    .font(.body)
                    .lineSpacing(4)
                
                // 引用
                if !entry.quotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("印象に残った文章")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        ForEach(entry.quotes, id: \.self) { quote in
                            Text(""" + quote + """)
                                .font(.body)
                                .italic()
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("読書記録")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func statusColor(for status: JournalEntry.ReadingStatus) -> Color {
        switch status {
        case .wantToRead:
            return .blue
        case .reading:
            return .green
        case .completed:
            return .purple
        case .abandoned:
            return .gray
        }
    }
}
  import SwiftUI

struct BookRow: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 書籍画像
            if let imageUrl = book.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 90)
                    case .failure:
                        Image(systemName: "book.closed")
                            .font(.system(size: 30))
                            .frame(width: 60, height: 90)
                            .background(Color.gray.opacity(0.3))
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(4)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 90)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            
            // 書籍情報
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let publisher = book.publisher {
                    Text(publisher)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
  import SwiftUI

struct JournalEntryRow: View {
    let entry: JournalEntry
    @EnvironmentObject var journalStore: JournalStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 書籍情報
                if let book = journalStore.getBook(id: entry.bookId) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("不明な書籍")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 日付
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 読書状態とレーティング
            HStack {
                Text(entry.readingStatus.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(for: entry.readingStatus).opacity(0.2))
                    .foregroundColor(statusColor(for: entry.readingStatus))
                    .cornerRadius(4)
                
                Spacer()
                
                // 評価
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= entry.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // 感想プレビュー
            Text(entry.content)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: JournalEntry.ReadingStatus) -> Color {
        switch status {
        case .wantToRead:
            return .blue
        case .reading:
            return .green
        case .completed:
            return .purple
        case .abandoned:
            return .gray
        }
    }
}
  import Foundation
import Combine

class BookSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var books: [Book] = []
    @Published var isSearching = false
    @Published var relatedKeywords: [String] = []
    @Published var hasSearched = false
    
    private let japaneseBookAPI = JapaneseBookAPI()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 検索テキストの変更を監視（オプション）
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty && $0.count >= 2 }
            .sink { [weak self] _ in
                // 自動検索をしたい場合はここでperformSearch()を呼ぶ
            }
            .store(in: &cancellables)
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        
        // 1. メインキーワードでの検索
        japaneseBookAPI.searchBooks(query: searchText) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let bookResults):
                // 指定出版社でフィルタリング
                let filteredBooks = self.filterByPublishers(books: bookResults)
                self.books = filteredBooks
                
                // 関連キーワードの抽出
                self.extractRelatedKeywords(from: filteredBooks)
                
                // 関連キーワードでの追加検索
                self.searchWithRelatedKeywords()
                
            case .failure(let error):
                print("検索エラー: \(error)")
                self.isSearching = false
            }
        }
    }
    
    private func filterByPublishers(books: [BookAPIResult]) -> [Book] {
        return books.filter { book in
            // 出版社名でのフィルタリング
            if let publisher = book.publisherName {
                return Constants.academicPublishers.contains { publisher.contains($0) }
            }
            return false
        }.map { Book(from: $0) }
    }
    
    private func extractRelatedKeywords(from books: [Book]) {
        // 本のタイトル、著者、説明文から関連キーワードを抽出
        var keywords = Set<String>()
        
        for book in books {
            // タイトルから抽出
            if let title = book.title {
                let extractedWords = JapaneseTextAnalyzer.extractKeywords(from: title)
                keywords.formUnion(extractedWords)
            }
            
            // 説明文から抽出
            if let description = book.description {
                let extractedWords = JapaneseTextAnalyzer.extractKeywords(from: description)
                keywords.formUnion(extractedWords)
            }
        }
        
        // 元の検索語を除外
        keywords.remove(searchText)
        relatedKeywords = Array(keywords).prefix(5).map { $0 }
    }
    
    private func searchWithRelatedKeywords() {
        let dispatchGroup = DispatchGroup()
        var additionalBooks: [Book] = []
        
        for keyword in relatedKeywords {
            dispatchGroup.enter()
            
            japaneseBookAPI.searchBooks(query: keyword) { [weak self] result in
                guard let self = self else { 
                    dispatchGroup.leave()
                    return 
                }
                
                switch result {
                case .success(let bookResults):
                    let filteredBooks = self.filterByPublishers(books: bookResults)
                    
                    // 既存の検索結果と重複しないものを追加
                    let newBooks = filteredBooks.filter { newBook in
                        !self.books.contains { $0.id == newBook.id }
                    }
                    
                    additionalBooks.append(contentsOf: newBooks)
                    
                case .failure:
                    // エラー処理
                    break
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.books.append(contentsOf: additionalBooks)
            self.isSearching = false
        }
    }
}
  import Foundation
import Combine

class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var books: [Book] = []
    
    private let entriesKey = "journal_entries"
    private let booksKey = "saved_books"
    
    init() {
        loadData()
    }
    
    func addEntry(_ entry: JournalEntry, for book: Book) {
        // 既存のエントリーを更新するか、新しいエントリーを追加
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        
        // 関連する本が保存されていなければ追加
        if !books.contains(where: { $0.id == book.id }) {
            books.append(book)
        }
        
        saveData()
    }
    
    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveData()
    }
    
    func entriesForBook(id: String) -> [JournalEntry] {
        return entries.filter { $0.bookId == id }
    }
    
    func getBook(id: String) -> Book? {
        return books.first { $0.id == id }
    }
    
    private func saveData() {
        if let encodedEntries = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encodedEntries, forKey: entriesKey)
        }
        
        if let encodedBooks = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encodedBooks, forKey: booksKey)
        }
    }
    
    private func loadData() {
        if let savedEntries = UserDefaults.standard.data(forKey: entriesKey),
           let decodedEntries = try? JSONDecoder().decode([JournalEntry].self, from: savedEntries) {
            entries = decodedEntries
        }
        
        if let savedBooks = UserDefaults.standard.data(forKey: booksKey),
           let decodedBooks = try? JSONDecoder().decode([Book].self, from: savedBooks) {
            books
