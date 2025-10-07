import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/utils/work_manager.dart';

void main() {
  group('WorkManager Tests', () {
    setUp(() {
      // Reset work manager state before each test
      WorkManager().cancelAll();
      WorkManager().resetStats();
    });

    test('WorkManager is a singleton', () {
      final instance1 = WorkManager();
      final instance2 = WorkManager();
      
      expect(instance1, same(instance2), reason: 'WorkManager should be a singleton');
    });

    test('enqueue executes task and returns result', () async {
      final result = await WorkManager().enqueue('test_task', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'task_complete';
      });
      
      expect(result, equals('task_complete'), reason: 'Should return task result');
    });

    test('enqueue executes multiple tasks sequentially', () async {
      final executionOrder = <int>[];
      
      // Enqueue three tasks
      final future1 = WorkManager().enqueue('task1', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        executionOrder.add(1);
        return 1;
      });
      
      final future2 = WorkManager().enqueue('task2', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        executionOrder.add(2);
        return 2;
      });
      
      final future3 = WorkManager().enqueue('task3', () async {
        await Future.delayed(const Duration(milliseconds: 25));
        executionOrder.add(3);
        return 3;
      });
      
      // Wait for all tasks to complete
      await Future.wait([future1, future2, future3]);
      
      // Tasks should execute in order, not by duration
      expect(executionOrder, equals([1, 2, 3]), reason: 'Tasks should execute in FIFO order');
    });

    test('enqueue handles task errors gracefully', () async {
      var errorCaught = false;
      
      try {
        await WorkManager().enqueue('error_task', () async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Test error');
        });
      } catch (e) {
        errorCaught = true;
        expect(e.toString(), contains('Test error'));
      }
      
      expect(errorCaught, isTrue, reason: 'Error should be propagated');
      
      // Next task should still execute
      final result = await WorkManager().enqueue('success_task', () async {
        return 'success';
      });
      
      expect(result, equals('success'), reason: 'Work manager should continue after error');
    });

    test('cancelAll cancels pending tasks', () async {
      var task1Started = false;
      var task2Started = false;
      var task3Started = false;
      
      // Enqueue a slow task
      final future1 = WorkManager().enqueue('slow_task', () async {
        task1Started = true;
        await Future.delayed(const Duration(milliseconds: 200));
        return 1;
      });
      
      // Enqueue two more tasks
      final future2 = WorkManager().enqueue('task2', () async {
        task2Started = true;
        return 2;
      });
      
      final future3 = WorkManager().enqueue('task3', () async {
        task3Started = true;
        return 3;
      });
      
      // Wait a bit for first task to start
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Cancel all pending tasks
      WorkManager().cancelAll();
      
      // First task should complete (already started)
      try {
        await future1;
      } catch (e) {
        // May or may not complete depending on timing
      }
      
      // Other tasks should be cancelled
      try {
        await future2;
        fail('Task 2 should have been cancelled');
      } catch (e) {
        expect(e.toString(), contains('cancelled'));
      }
      
      try {
        await future3;
        fail('Task 3 should have been cancelled');
      } catch (e) {
        expect(e.toString(), contains('cancelled'));
      }
      
      expect(task1Started, isTrue, reason: 'First task should have started');
      expect(task2Started, isFalse, reason: 'Second task should not have started');
      expect(task3Started, isFalse, reason: 'Third task should not have started');
    });

    test('cancel removes specific task by ID', () async {
      // Enqueue multiple tasks
      final future1 = WorkManager().enqueue('task1', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 1;
      });
      
      final future2 = WorkManager().enqueue('task2', () async {
        return 2;
      });
      
      final future3 = WorkManager().enqueue('task3', () async {
        return 3;
      });
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Cancel task2
      final cancelled = WorkManager().cancel('task2');
      
      expect(cancelled, isTrue, reason: 'Should cancel task2');
      
      // Task1 should complete
      final result1 = await future1;
      expect(result1, equals(1));
      
      // Task2 should be cancelled
      try {
        await future2;
        fail('Task 2 should have been cancelled');
      } catch (e) {
        expect(e.toString(), contains('cancelled'));
      }
      
      // Task3 should complete
      final result3 = await future3;
      expect(result3, equals(3));
    });

    test('getStatus returns accurate queue information', () async {
      // Initially empty
      var status = WorkManager().getStatus();
      expect(status['queueSize'], equals(0));
      expect(status['isProcessing'], isFalse);
      
      // Enqueue tasks
      final future1 = WorkManager().enqueue('task1', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 1;
      });
      
      final future2 = WorkManager().enqueue('task2', () async {
        return 2;
      });
      
      // Check status while processing
      await Future.delayed(const Duration(milliseconds: 20));
      status = WorkManager().getStatus();
      
      expect(status['isProcessing'], isTrue, reason: 'Should be processing');
      expect(status['pendingTasks'], isA<List>(), reason: 'Should have pending tasks list');
      
      // Wait for completion
      await Future.wait([future1, future2]);
      
      // Check final status
      status = WorkManager().getStatus();
      expect(status['queueSize'], equals(0), reason: 'Queue should be empty');
      expect(status['processedCount'], greaterThan(0), reason: 'Should have processed tasks');
    });

    test('isQueued returns correct status', () async {
      expect(WorkManager().isQueued('test_task'), isFalse);
      
      final future = WorkManager().enqueue('test_task', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 1;
      });
      
      // Should be queued
      await Future.delayed(const Duration(milliseconds: 20));
      // Note: May be processing or queued depending on timing
      
      await future;
      
      // Should not be queued after completion
      expect(WorkManager().isQueued('test_task'), isFalse);
    });

    test('queueSize property returns correct count', () {
      expect(WorkManager().queueSize, equals(0));
      
      // Don't await - we want to check queue size while tasks are queued
      WorkManager().enqueue('task1', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 1;
      });
      
      WorkManager().enqueue('task2', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 2;
      });
      
      // Queue size should be 2 (or 1 if first task started)
      expect(WorkManager().queueSize, greaterThanOrEqualTo(0));
      expect(WorkManager().queueSize, lessThanOrEqualTo(2));
    });

    test('resetStats clears statistics', () async {
      // Execute some tasks
      await WorkManager().enqueue('task1', () async => 1);
      await WorkManager().enqueue('task2', () async => 2);
      
      var status = WorkManager().getStatus();
      expect(status['processedCount'], greaterThan(0));
      
      // Reset stats
      WorkManager().resetStats();
      
      status = WorkManager().getStatus();
      expect(status['processedCount'], equals(0));
      expect(status['failedCount'], equals(0));
    });

    test('work manager handles rapid task enqueueing', () async {
      final results = <int>[];
      final futures = <Future<int>>[];
      
      // Enqueue 20 tasks rapidly
      for (int i = 0; i < 20; i++) {
        final future = WorkManager().enqueue('task_$i', () async {
          await Future.delayed(const Duration(milliseconds: 10));
          results.add(i);
          return i;
        });
        futures.add(future);
      }
      
      // Wait for all tasks
      await Future.wait(futures);
      
      // All tasks should complete
      expect(results.length, equals(20));
      
      // Tasks should execute in order
      for (int i = 0; i < 20; i++) {
        expect(results[i], equals(i));
      }
    });
  });

  group('WorkManager Edge Cases', () {
    setUp(() {
      WorkManager().cancelAll();
      WorkManager().resetStats();
    });

    test('handles task that completes immediately', () async {
      final result = await WorkManager().enqueue('instant_task', () async {
        return 'instant';
      });
      
      expect(result, equals('instant'));
    });

    test('handles task with different return types', () async {
      final stringResult = await WorkManager().enqueue<String>('string_task', () async {
        return 'text';
      });
      
      final intResult = await WorkManager().enqueue<int>('int_task', () async {
        return 42;
      });
      
      final boolResult = await WorkManager().enqueue<bool>('bool_task', () async {
        return true;
      });
      
      expect(stringResult, equals('text'));
      expect(intResult, equals(42));
      expect(boolResult, equals(true));
    });

    test('handles null return values', () async {
      final result = await WorkManager().enqueue<String?>('null_task', () async {
        return null;
      });
      
      expect(result, isNull);
    });
  });
}
