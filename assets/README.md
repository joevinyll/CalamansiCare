# CalamansiCare model

Place the exported TensorFlow Lite classification model in this folder as
`model.tflite`. The app expects a single image input shaped
`[1, height, width, 3]` and one classification output. Output positions must
match the labels in `lib/main.dart` (`diseaseLabels`). Keep the class-index
order exported with the model; changing the order causes valid model scores to
be displayed under the wrong disease name.

The included inference service supports Float32 and UInt8 image input tensors
and requires Float32 classification scores as the output. For a Float32
model, raw 0-255 pixel values are passed through unchanged (this model has
its own Rescaling/normalization baked into the graph as its first layer, so
dividing by 255 in the app would double-normalize the input). Rebuild the
app after replacing the model file.

The bundled model has eight output classes in this order (from `class_names.json`
exported alongside `CalamansiCare_Final.keras` — this is the authoritative
source, since Keras assigns class indices by sorting training folder names,
not by whatever order a person expects):

1. Anthracnose
2. Brown Spot
3. Citrus Canker
4. Citrus Scab
5. HLB (Greening)
6. Healthy
7. Melanose
8. Nutrient Deficiency

If you ever retrain or re-export the model, re-check `class_names.json` and
update `diseaseLabels` in `lib/main.dart` to match exactly, in the same
order — a mismatch here silently relabels every prediction as the wrong
disease without throwing any error.
