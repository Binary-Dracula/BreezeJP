import 'package:flutter_test/flutter_test.dart';
import 'package:breeze_jp/features/learn/state/learn_state.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_detail.dart';

/// 创建一个最小的 WordDetail 用于测试
WordDetail _makeWordDetail(int id) {
  return WordDetail(
    word: Word(id: id, word: 'word_$id'),
    meanings: const [],
    audios: const [],
    examples: const [],
  );
}

void main() {
  group('LearnState - isAtIslandEnd', () {
    test('在岛边界索引处返回 true', () {
      final state = LearnState(
        studyQueue: List.generate(10, (i) => _makeWordDetail(i)),
        currentIndex: 4,
        islandEndIndices: const [4, 9],
      );

      expect(state.isAtIslandEnd, true);
    });

    test('在非边界处返回 false', () {
      final state = LearnState(
        studyQueue: List.generate(10, (i) => _makeWordDetail(i)),
        currentIndex: 3,
        islandEndIndices: const [4, 9],
      );

      expect(state.isAtIslandEnd, false);
    });

    test('空列表返回 false', () {
      final state = LearnState(
        studyQueue: List.generate(5, (i) => _makeWordDetail(i)),
        currentIndex: 2,
        islandEndIndices: const [],
      );

      expect(state.isAtIslandEnd, false);
    });

    test('第二个岛的边界也能正确识别', () {
      final state = LearnState(
        studyQueue: List.generate(10, (i) => _makeWordDetail(i)),
        currentIndex: 9,
        islandEndIndices: const [4, 9],
      );

      expect(state.isAtIslandEnd, true);
    });
  });

  group('LearnState - isAtQueueEnd', () {
    test('仍然正确 - 在末尾返回 true', () {
      final state = LearnState(
        studyQueue: List.generate(5, (i) => _makeWordDetail(i)),
        currentIndex: 4,
      );

      expect(state.isAtQueueEnd, true);
    });

    test('仍然正确 - 不在末尾返回 false', () {
      final state = LearnState(
        studyQueue: List.generate(5, (i) => _makeWordDetail(i)),
        currentIndex: 2,
      );

      expect(state.isAtQueueEnd, false);
    });
  });

  group('LearnState - 多岛边界', () {
    test('copyWith 追加岛后正确记录边界', () {
      // 初始：第一个岛 3 个词 (index 0-2)
      var state = LearnState(
        studyQueue: List.generate(3, (i) => _makeWordDetail(i)),
        islandEndIndices: const [2],
      );

      expect(state.islandEndIndices.length, 1);
      expect(state.islandEndIndices, [2]);

      // 追加第二个岛 4 个词 (index 3-6)
      state = state.copyWith(
        studyQueue: [
          ...state.studyQueue,
          ...List.generate(4, (i) => _makeWordDetail(i + 10)),
        ],
        islandEndIndices: [...state.islandEndIndices, 6],
      );

      expect(state.islandEndIndices.length, 2);
      expect(state.islandEndIndices, [2, 6]);
      expect(state.studyQueue.length, 7);

      // 追加第三个岛 2 个词 (index 7-8)
      state = state.copyWith(
        studyQueue: [
          ...state.studyQueue,
          ...List.generate(2, (i) => _makeWordDetail(i + 20)),
        ],
        islandEndIndices: [...state.islandEndIndices, 8],
      );

      expect(state.islandEndIndices.length, 3);
      expect(state.islandEndIndices, [2, 6, 8]);

      // 验证每个岛的边界
      expect(
        LearnState(
          studyQueue: state.studyQueue,
          currentIndex: 2,
          islandEndIndices: state.islandEndIndices,
        ).isAtIslandEnd,
        true,
        reason: '第一个岛的末尾 index=2',
      );
      expect(
        LearnState(
          studyQueue: state.studyQueue,
          currentIndex: 6,
          islandEndIndices: state.islandEndIndices,
        ).isAtIslandEnd,
        true,
        reason: '第二个岛的末尾 index=6',
      );
      expect(
        LearnState(
          studyQueue: state.studyQueue,
          currentIndex: 8,
          islandEndIndices: state.islandEndIndices,
        ).isAtIslandEnd,
        true,
        reason: '第三个岛的末尾 index=8',
      );
      expect(
        LearnState(
          studyQueue: state.studyQueue,
          currentIndex: 5,
          islandEndIndices: state.islandEndIndices,
        ).isAtIslandEnd,
        false,
        reason: 'index=5 不是任何岛的末尾',
      );
    });
  });
}
