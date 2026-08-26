import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';

class DiseasePrediction {
  const DiseasePrediction({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

/// Runs the bundled CalamansiCare TensorFlow Lite image-classification model.
class DiseaseClassifier {
  DiseaseClassifier._();

  static final DiseaseClassifier instance = DiseaseClassifier._();
  Interpreter? _interpreter;

  Future<DiseasePrediction> classify(
    Uint8List imageBytes,
    List<String> labels,
  ) async {
    final interpreter = await _load();
    final source = image.decodeImage(imageBytes);
    if (source == null)
      throw const FormatException('The selected file is not a valid image.');

    final inputShape = interpreter.getInputTensor(0).shape;
    if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
      throw StateError(
          'The model must accept a [1, height, width, 3] image tensor.');
    }
    final height = inputShape[1];
    final width = inputShape[2];
    final resized = image.copyResize(source, width: width, height: height);
    final inputType = interpreter.getInputTensor(0).type;
    final input = inputType == TensorType.uint8
        ? _uint8Input(resized, width, height)
        : _floatInput(resized, width, height);

    final outputTensor = interpreter.getOutputTensor(0);
    if (outputTensor.type != TensorType.float32) {
      throw StateError(
          'The model output must use Float32 classification scores.');
    }
    final outputShape = outputTensor.shape;
    final outputSize =
        outputShape.skip(1).fold<int>(1, (size, dim) => size * dim);
    final output = List<double>.filled(
      outputSize,
      0,
    ).reshape([1, outputSize]);
    interpreter.run(input, output);
    final rawScores = (output.first as List<double>);
    if (rawScores.isEmpty) {
      throw StateError('The model returned no classification scores.');
    }
    if (rawScores.length > labels.length) {
      throw StateError(
        'The model has ${rawScores.length} outputs but only ${labels.length} labels are configured.',
      );
    }

    // The reference Colab notebook uses best_model(...).numpy()[0] directly
    // as a probability (no tf.nn.softmax call), which means the Keras
    // model's last layer already has softmax baked in and this TFLite
    // export should too. Re-applying softmax on top of already-normalized
    // probabilities badly flattens them (e.g. a genuine 85% collapses to
    // roughly 24%), so only apply softmax when the raw output does NOT
    // already look like a probability distribution (sums to ~1, all values
    // in [0, 1]). This also keeps things working if the model is ever
    // re-exported without a final activation.
    final probabilities =
        _looksAlreadyNormalized(rawScores) ? rawScores : _softmax(rawScores);

    var highest = 0;
    for (var index = 1; index < probabilities.length; index++) {
      if (probabilities[index] > probabilities[highest]) highest = index;
    }

    if (kDebugMode) {
      final ranked = List<int>.generate(probabilities.length, (i) => i)
        ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
      // Index is printed alongside the label on purpose: if predictions look
      // wrong, check whether the RAW index here is actually the correct
      // disease and only the labels[] list has it under the wrong name (a
      // label-order mismatch vs. how the model's classes were indexed during
      // training/export) rather than the model itself being wrong.
      final top3 = ranked.take(3).map(
            (i) =>
                '[$i] ${labels[i]}: ${(probabilities[i] * 100).toStringAsFixed(1)}%',
          );
      debugPrint('CalamansiCare prediction -> ${top3.join(', ')}');
    }

    return DiseasePrediction(
      label: labels[highest],
      confidence: probabilities[highest],
    );
  }

  Future<Interpreter> _load() async {
  return _interpreter ??=
      await Interpreter.fromAsset('assets/model.tflite');
}

  // NOTE: The bundled model (CalamansiCare_MobileNetV2) has its own
  // Rescaling/Normalization step baked into the graph (`truediv` by 127.5,
  // then `Sub` 1.0) ahead of the MobileNetV2 backbone. That means the model
  // already expects raw 0-255 pixel values as input. Dividing by 255 here
  // as well double-normalizes every pixel down to ~-1.0, which flattens
  // almost all image signal before it reaches the network and is the
  // reason predictions were capped around 50-60% confidence. Do NOT divide
  // by 255 here — pass the raw channel values through unchanged.
  List _floatInput(image.Image source, int width, int height) => [
        List.generate(
            height,
            (y) => List.generate(width, (x) {
                  final pixel = source.getPixel(x, y);
                  return [
                    pixel.r.toDouble(),
                    pixel.g.toDouble(),
                    pixel.b.toDouble(),
                  ];
                })),
      ];

  List _uint8Input(image.Image source, int width, int height) => [
        List.generate(
            height,
            (y) => List.generate(width, (x) {
                  final pixel = source.getPixel(x, y);
                  return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
                })),
      ];

  bool _looksAlreadyNormalized(List<double> values) {
    final allInRange = values.every((value) => value >= -1e-6 && value <= 1 + 1e-6);
    final sum = values.fold<double>(0, (total, value) => total + value);
    return allInRange && (sum - 1.0).abs() < 0.02;
  }

  List<double> _softmax(List<double> values) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final exps = values.map((value) => _exp(value - maxValue)).toList();
    final sum = exps.fold<double>(0, (total, value) => total + value);
    return exps.map((value) => value / sum).toList();
  }

  double _exp(double value) {
    // Kept here to avoid another dependency; e is precise enough for softmax.
    var term = 1.0;
    var sum = 1.0;
    for (var n = 1; n <= 24; n++) {
      term *= value / n;
      sum += term;
    }
    return sum;
  }
}
