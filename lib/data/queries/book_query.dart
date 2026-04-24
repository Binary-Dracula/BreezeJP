import '../models/vocab_book.dart';
import '../repositories/book_repository.dart';

class BookQuery {
  BookQuery(this._repository);

  final BookRepository _repository;

  Future<List<VocabBook>> getAvailableBooks() {
    return _repository.getAvailableBooks();
  }

  Future<VocabBook?> getBookById(String id) {
    return _repository.getBookById(id);
  }

  Future<bool> isBookAvailable(String id) async {
    final book = await _repository.getBookById(id);
    return book?.isAvailable ?? false;
  }
}
