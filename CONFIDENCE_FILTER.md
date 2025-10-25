# AI Confidence Threshold Filter Documentation 🎯

## Overview

The confidence threshold filter is a critical quality control mechanism that filters out low-confidence AI detections to reduce false positives in the damage detection system.

---

## How It Works

### 1. **Confidence Score**
Every AI detection comes with a confidence score ranging from `0.0` (0%) to `1.0` (100%) indicating how certain the model is about the detection.

### 2. **Threshold Filter**
Detections below the configured threshold are **automatically rejected** and converted to "No Damage" results.

```dart
// Configuration (in rtsp_stream_screen.dart)
static const double CONFIDENCE_THRESHOLD = 0.6; // 60%
```

### 3. **Filter Logic**
```dart
if (isDamageDetected && confidence < CONFIDENCE_THRESHOLD) {
  // REJECT: Convert to "No Damage"
  return {
    'isDamageDetected': false,
    'damageType': 'No Damage',
    'confidence': confidence, // Original confidence preserved
    'rejectedDueToLowConfidence': true,
    'originalDamageType': result['damageType'], // For debugging
  };
}
```

---

## Configuration

### Current Settings
- **Threshold:** `0.6` (60%)
- **Location:** `lib/screens/rtsp/rtsp_stream_screen.dart` line 60
- **User Configurable:** No (backend only)

### Recommended Values

| Threshold | Behavior | Use Case |
|-----------|----------|----------|
| **0.5 (50%)** | More sensitive | High-risk areas, better safe than sorry |
| **0.6 (60%)** | **BALANCED (DEFAULT)** | ✅ Recommended for most scenarios |
| **0.7 (70%)** | Conservative | Low-risk areas, minimize false alarms |
| **0.8 (80%)** | Very strict | Testing/validation, high precision needed |

### How to Adjust

1. Open `lib/screens/rtsp/rtsp_stream_screen.dart`
2. Find line ~60: `static const double CONFIDENCE_THRESHOLD = 0.6;`
3. Change the value (e.g., `0.7` for 70% threshold)
4. Rebuild the app

---

## Impact on Detection

### Example Scenarios

#### ✅ **Accepted Detection**
```dart
Input:
{
  'isDamageDetected': true,
  'damageType': 'Crack',
  'confidence': 0.75  // 75% > 60% threshold
}

Output: Same (passed filter)
Result: ✅ Saved to history, counted in statistics
```

#### ❌ **Rejected Detection**
```dart
Input:
{
  'isDamageDetected': true,
  'damageType': 'Crack',
  'confidence': 0.45  // 45% < 60% threshold
}

Output:
{
  'isDamageDetected': false,
  'damageType': 'No Damage',
  'confidence': 0.45,
  'rejectedDueToLowConfidence': true,
  'originalDamageType': 'Crack'  // For debugging
}

Result: ❌ NOT saved to history, NOT counted in statistics
```

---

## Statistics Impact

### Frame Analysis
```dart
// Before filter
Total Frames: 100
Detections: 25 (including low-confidence)

// After filter (60% threshold)
Total Frames: 100  // All frames still analyzed
Accepted Detections: 15  // Only high-confidence ones counted
Rejected: 10  // Filtered out as false positives
```

### Detection History
Only detections that pass the confidence threshold are:
1. ✅ Saved to detection history
2. ✅ Included in damage count statistics
3. ✅ Added to the generated report

Rejected detections:
1. ❌ NOT saved to history
2. ❌ NOT counted in statistics
3. ❌ NOT included in reports

---

## Code Implementation

### Location
`lib/screens/rtsp/rtsp_stream_screen.dart`

### Key Methods

#### 1. Filter Application (lines ~1090-1115)
```dart
// Extract confidence and damage status
final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
final isDamageDetected = result['isDamageDetected'] == true;

// Apply filter
if (isDamageDetected && confidence < CONFIDENCE_THRESHOLD) {
  print('⚠️ Detection REJECTED: ${(confidence * 100).toStringAsFixed(1)}%');
  
  return {
    'isDamageDetected': false,
    'damageType': 'No Damage',
    'confidence': confidence,
    'rejectedDueToLowConfidence': true,
    'originalDamageType': result['damageType'],
  };
}
```

#### 2. Statistics Update (lines ~1123-1130)
```dart
_debouncedSetState(() {
  _totalFramesAnalyzed++;
  // Only count if confidence passes threshold
  if (result['isDamageDetected'] == true && confidence >= CONFIDENCE_THRESHOLD) {
    _damagesDetected++;
  }
  _lastAnalysisResult = result;
});
```

#### 3. History Saving (lines ~1133-1136)
```dart
// Only save detections that pass threshold
if (result['isDamageDetected'] == true && confidence >= CONFIDENCE_THRESHOLD) {
  unawaited(_saveDetectionToHistoryAsync(result, frameBytes));
}
```

---

## Testing

### Unit Tests
Located at: `test/confidence_filter_test.dart`

#### Test Coverage (20 tests)
1. ✅ **Confidence Filter Logic** (7 tests)
   - Above threshold acceptance
   - Below threshold rejection
   - Exact threshold handling
   - No damage handling
   - Edge cases

2. ✅ **Detection Transformation** (2 tests)
   - Rejected detection transformation
   - Accepted detection unchanged

3. ✅ **Boundary Tests** (5 tests)
   - 0.0 confidence
   - 1.0 confidence
   - Just below threshold (0.59)
   - Just above threshold (0.61)
   - At threshold (0.60)

4. ✅ **Statistics Tests** (2 tests)
   - Damage counter accuracy
   - History saving logic

5. ✅ **Damage Type Tests** (6 tests)
   - Crack, Corrosion, Deformation
   - High/low confidence for each type

#### Run Tests
```bash
flutter test test/confidence_filter_test.dart
```

**Expected Output:**
```
00:35 +20: All tests passed! ✅
```

---

## Benefits

### 1. **Reduced False Positives** 
- Filters out uncertain detections
- Improves report quality
- Reduces unnecessary alarms

### 2. **Better User Experience**
- More reliable detections
- Fewer false alarms
- Increased trust in AI system

### 3. **Improved Accuracy**
- Only high-confidence detections saved
- Better decision-making data
- Cleaner detection history

### 4. **Debugging Support**
- Original detection info preserved
- `rejectedDueToLowConfidence` flag
- `originalDamageType` for analysis

---

## Monitoring & Debugging

### Console Logs
```
🎯 Confidence filter check:
  - Raw confidence: 75.0%
  - Threshold: 60.0%
  - Is damage detected: true
✅ Detection ACCEPTED: Crack with 75.0% confidence
```

```
🎯 Confidence filter check:
  - Raw confidence: 45.0%
  - Threshold: 60.0%
  - Is damage detected: true
⚠️ Detection REJECTED: Confidence 45.0% below threshold 60.0%
```

### Debug Information
Rejected detections include debug fields:
```dart
{
  'rejectedDueToLowConfidence': true,  // Flag for debugging
  'originalDamageType': 'Crack',       // What model detected
  'confidence': 0.45                    // How confident it was
}
```

---

## FAQ

### Q: Why are some damages not being saved?
**A:** They likely have confidence below the 60% threshold and are being filtered out as potential false positives.

### Q: Can users adjust the threshold?
**A:** No, it's configured at the code level to maintain consistency. Only developers can change it.

### Q: What happens to rejected detections?
**A:** They're converted to "No Damage" results. The original detection info is preserved in debug fields but not saved to history.

### Q: How do I see rejected detections?
**A:** Check the console logs for `⚠️ Detection REJECTED` messages with the original damage type and confidence.

### Q: Should I lower the threshold?
**A:** Only if you're getting too many false negatives (missing real damage). The default 60% is balanced for most scenarios.

### Q: Should I raise the threshold?
**A:** Only if you're getting too many false positives (false alarms). This will make detection more conservative.

---

## Performance Impact

### Memory
- ✅ **Minimal:** Only metadata filtering, no image processing
- ✅ **Efficient:** Rejected detections don't allocate storage

### CPU
- ✅ **Negligible:** Simple numeric comparison
- ✅ **Fast:** O(1) operation per detection

### Storage
- ✅ **Reduced:** Fewer images saved to disk
- ✅ **Efficient:** Only high-confidence detections stored

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | Oct 23, 2025 | Initial implementation with 60% threshold |

---

## Related Files

- **Implementation:** `lib/screens/rtsp/rtsp_stream_screen.dart`
- **Tests:** `test/confidence_filter_test.dart`
- **Model Service:** `lib/services/tflite_service.dart` (generates confidence scores)

---

## Summary

✅ **Implemented:** Confidence threshold filter at 60%  
✅ **Tested:** 20 comprehensive unit tests passing  
✅ **Impact:** Reduced false positives, improved accuracy  
✅ **Maintainable:** Well-documented, easy to adjust  

The confidence filter is a crucial quality control mechanism that significantly improves the reliability of the AI damage detection system! 🎯
