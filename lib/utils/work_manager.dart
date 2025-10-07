import 'dart:async';
import 'dart:collection';

/// Work item representing a queued task
class WorkItem<T> {
  final String id;
  final Future<T> Function() task;
  final Completer<T> completer = Completer<T>();
  final DateTime createdAt = DateTime.now();

  WorkItem(this.id, this.task);
}

/// WorkManager implements a sequential task queue pattern to prevent
/// simultaneous heavy operations from overwhelming the system.
/// 
/// This helps prevent ANR issues by:
/// - Ensuring only one heavy task runs at a time
/// - Preventing task pile-up during long operations
/// - Providing task cancellation capabilities
class WorkManager {
  static final WorkManager _instance = WorkManager._internal();
  factory WorkManager() => _instance;
  WorkManager._internal();

  final Queue<dynamic> _workQueue = Queue<dynamic>();
  bool _isProcessing = false;
  int _processedCount = 0;
  int _failedCount = 0;

  /// Enqueue a task for sequential execution
  /// 
  /// Returns a Future that completes when the task finishes
  /// Tasks are executed in FIFO order
  Future<T> enqueue<T>(String id, Future<T> Function() task) {
    print('📋 WorkManager: Enqueuing task "$id" (queue size: ${_workQueue.length})');
    
    final workItem = WorkItem<T>(id, task);
    _workQueue.add(workItem);
    
    // Start processing if not already running
    _processQueue();
    
    return workItem.completer.future;
  }

  /// Process queued tasks sequentially
  void _processQueue() async {
    // Don't start processing if already running or queue is empty
    if (_isProcessing || _workQueue.isEmpty) {
      return;
    }

    _isProcessing = true;
    print('⚙️ WorkManager: Starting queue processing (${_workQueue.length} tasks)');

    while (_workQueue.isNotEmpty) {
      final workItem = _workQueue.removeFirst();
      final startTime = DateTime.now();
      
      print('▶️ WorkManager: Executing task "${workItem.id}"');
      
      try {
        final result = await workItem.task();
        
        if (!workItem.completer.isCompleted) {
          workItem.completer.complete(result);
          _processedCount++;
          
          final duration = DateTime.now().difference(startTime);
          print('✅ WorkManager: Task "${workItem.id}" completed in ${duration.inMilliseconds}ms');
        }
      } catch (e, stackTrace) {
        print('❌ WorkManager: Task "${workItem.id}" failed: $e');
        print('Stack trace: $stackTrace');
        
        if (!workItem.completer.isCompleted) {
          workItem.completer.completeError(e, stackTrace);
          _failedCount++;
        }
      }

      // Small delay between tasks to let UI breathe
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessing = false;
    print('⏸️ WorkManager: Queue processing paused (processed: $_processedCount, failed: $_failedCount)');
  }

  /// Cancel all pending tasks
  /// Tasks already running will complete
  void cancelAll() {
    print('🛑 WorkManager: Cancelling ${_workQueue.length} pending tasks');
    
    for (final item in _workQueue) {
      if (!item.completer.isCompleted) {
        item.completer.completeError('Task cancelled by user');
      }
    }
    
    _workQueue.clear();
  }

  /// Cancel a specific task by ID
  /// Only works if task hasn't started yet
  bool cancel(String id) {
    final item = _workQueue.cast<WorkItem?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );

    if (item != null) {
      _workQueue.remove(item);
      if (!item.completer.isCompleted) {
        item.completer.completeError('Task cancelled');
      }
      print('🛑 WorkManager: Cancelled task "$id"');
      return true;
    }

    print('⚠️ WorkManager: Task "$id" not found or already started');
    return false;
  }

  /// Get current queue status
  Map<String, dynamic> getStatus() {
    return {
      'isProcessing': _isProcessing,
      'queueSize': _workQueue.length,
      'processedCount': _processedCount,
      'failedCount': _failedCount,
      'pendingTasks': _workQueue.map((item) => item.id).toList(),
    };
  }

  /// Clear statistics
  void resetStats() {
    _processedCount = 0;
    _failedCount = 0;
    print('🔄 WorkManager: Statistics reset');
  }

  /// Check if a specific task is in queue
  bool isQueued(String id) {
    return _workQueue.any((item) => item.id == id);
  }

  /// Get the number of pending tasks
  int get queueSize => _workQueue.length;

  /// Check if work manager is currently processing
  bool get isProcessing => _isProcessing;
}
