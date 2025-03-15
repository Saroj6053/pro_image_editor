// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' hide Layer;
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_matrix.dart';
import 'package:pro_image_editor/features/filter_editor/widgets/filtered_image.dart';
import 'package:pro_image_editor/shared/widgets/transform/transformed_content_generator.dart';

import '/core/mixin/example_helper.dart';
import '/shared/widgets/material_icon_button.dart';
import '/shared/widgets/pixel_transparent_painter.dart';
import 'frame_template_manager.dart';

/// Frame template class to manage different frame designs
class FrameTemplate {
  final String name;
  final String frameAsset;
  final List<TextFieldConfig> textFields;

  FrameTemplate({
    required this.name,
    required this.frameAsset,
    required this.textFields,
  });
}

/// Configuration for text fields in frame templates
class TextFieldConfig {
  final String initialText;
  final TextStyle style;
  double topPosition; // Position from top as percentage (0.0 to 1.0)
  double leftPosition; // Position from left as percentage (0.0 to 1.0)
  final EdgeInsets padding;
  final TextEditingController controller;

  // Added for dragging and scaling functionality
  final ValueNotifier<Offset> positionOffset =
      ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<double> scale = ValueNotifier<double>(1.0);
  final ValueNotifier<double> rotation = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isSelected = ValueNotifier<bool>(false);

  TextFieldConfig({
    required this.initialText,
    required this.style,
    required this.topPosition,
    this.leftPosition = 0.5, // Center horizontally by default
    this.padding = const EdgeInsets.symmetric(horizontal: 0.1),
  }) : controller = TextEditingController(text: initialText);

  void dispose() {
    controller.dispose();
    positionOffset.dispose();
    scale.dispose();
    rotation.dispose();
    isSelected.dispose();
  }

  void notifyListeners() {
    // This is a hack to force the UI to update
    // We're just changing the value and then changing it back
    final currentOffset = positionOffset.value;
    positionOffset.value = currentOffset + const Offset(0.001, 0.001);
    positionOffset.value = currentOffset;
  }
}

/// Manager for frame templates
class FrameTemplateManager {
  final List<FrameTemplate> templates;
  int _currentTemplateIndex = 0;

  // Variables to track initial scale and rotation during gesture
  double _initialScale = 1.0;
  double _initialRotation = 0.0;

  // Callback for when a text field is selected
  final Function(TextFieldConfig)? onTextFieldSelected;

  // Callback for when all text fields are deselected
  final Function()? onAllTextFieldsDeselected;

  FrameTemplateManager({
    required this.templates,
    this.onTextFieldSelected,
    this.onAllTextFieldsDeselected,
  });

  FrameTemplate get currentTemplate => templates[_currentTemplateIndex];

  String get currentFrameAsset => currentTemplate.frameAsset;

  int get currentIndex => _currentTemplateIndex;

  int get templatesCount => templates.length;

  void nextTemplate() {
    _currentTemplateIndex = (_currentTemplateIndex + 1) % templates.length;
  }

  void previousTemplate() {
    _currentTemplateIndex =
        (_currentTemplateIndex - 1 + templates.length) % templates.length;
  }

  void selectTemplate(int index) {
    if (index >= 0 && index < templates.length) {
      _currentTemplateIndex = index;
    }
  }

  void dispose() {
    for (var template in templates) {
      for (var textField in template.textFields) {
        textField.dispose();
      }
    }
  }

  // Method to deselect all text fields
  void deselectAllTextFields() {
    for (var textField in currentTemplate.textFields) {
      textField.isSelected.value = false;
    }
    onAllTextFieldsDeselected?.call();
  }

  // Method to select a specific text field
  void selectTextField(TextFieldConfig textField) {
    // First deselect all text fields
    for (var field in currentTemplate.textFields) {
      field.isSelected.value = false;
    }

    // Then select this text field
    textField.isSelected.value = true;

    // Notify the parent
    onTextFieldSelected?.call(textField);
  }

  void showTextEditDialog(BuildContext context, TextFieldConfig textConfig) {
    // Create a temporary controller with the current text
    final tempController = TextEditingController(
      text: textConfig.controller.text,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 10),
            Text('Edit Text',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                )),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempController,
                decoration: InputDecoration(
                  hintText: "Enter text",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                autofocus: true,
                style: TextStyle(fontSize: 16),
                maxLines: 3,
                minLines: 1,
              ),
              SizedBox(height: 16),
              Text(
                'Tip: Double-tap to edit, drag to move, pinch to resize',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.restart_alt, size: 18),
            label: Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            onPressed: () {
              // Reset position, scale and rotation
              textConfig.positionOffset.value = Offset.zero;
              textConfig.scale.value = 1.0;
              textConfig.rotation.value = 0.0;
              // Force UI update
              textConfig.notifyListeners();
              Navigator.pop(dialogContext);
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.close, size: 18),
            label: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.check, size: 18),
            label: Text('Apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // Update the text
              textConfig.controller.text = tempController.text;
              // Force UI update
              textConfig.notifyListeners();
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    ).then((_) {
      // Dispose the temporary controller
      tempController.dispose();
      // Force UI update one more time
      textConfig.notifyListeners();
    });
  }

  /// Build a frame with the current template
  ReactiveWidget buildTemplateFrame(
    Size bodySize,
    Stream<void> rebuildStream,
    ValueNotifier<bool> controlsVisibleNotifier,
    BuildContext context,
    ValueNotifier<bool> isCapturingResult,
  ) {
    return ReactiveWidget(
      stream: rebuildStream,
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: controlsVisibleNotifier,
        builder: (context, isVisible, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: isCapturingResult,
            builder: (context, isCapturing, _) {
              return Stack(
                children: [
                  // Frame image as the base layer with opacity control
                  Opacity(
                    opacity: isVisible && !isCapturing
                        ? 0.6
                        : 1.0, // Reduce opacity when controls are visible but not when capturing
                    child: IgnorePointer(
                      child: Image.asset(
                        currentFrameAsset,
                        width: bodySize.width,
                        height: bodySize.height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Instructions overlay - only show when not capturing
                  if (!isCapturing)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '• Tap to select text\n• Drag to move\n• Pinch to resize\n• Rotate with handle\n• Double-tap to edit',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),

                  // Text fields from the current template
                  ...currentTemplate.textFields
                      .map((textConfig) => ValueListenableBuilder<Offset>(
                            valueListenable: textConfig.positionOffset,
                            builder: (context, offset, _) {
                              return ValueListenableBuilder<double>(
                                valueListenable: textConfig.scale,
                                builder: (context, scale, _) {
                                  return ValueListenableBuilder<double>(
                                    valueListenable: textConfig.rotation,
                                    builder: (context, rotation, _) {
                                      return ValueListenableBuilder<bool>(
                                        valueListenable: textConfig.isSelected,
                                        builder: (context, isSelected, _) {
                                          // Calculate base position from percentage values
                                          final baseTop = bodySize.height *
                                              textConfig.topPosition;
                                          final baseLeft = bodySize.width *
                                              textConfig.leftPosition;

                                          // Apply the offset from dragging
                                          final top = baseTop + offset.dy;
                                          final left = baseLeft + offset.dx;

                                          // Calculate width based on padding
                                          final width = bodySize.width -
                                              (bodySize.width *
                                                  textConfig.padding.left) -
                                              (bodySize.width *
                                                  textConfig.padding.right);

                                          // Calculate the actual width after scaling
                                          final scaledWidth = width * scale;

                                          return Positioned(
                                            top: top,
                                            left: left -
                                                (scaledWidth /
                                                    2), // Center horizontally
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                // Main text field
                                                GestureDetector(
                                                  onTap: isCapturing
                                                      ? null // Disable interactions when capturing
                                                      : () {
                                                          print(
                                                              "Text field tapped: ${textConfig.controller.text}");

                                                          // Use the manager's method to select this text field
                                                          selectTextField(
                                                              textConfig);
                                                        },
                                                  onScaleStart: isCapturing
                                                      ? null // Disable interactions when capturing
                                                      : (details) {
                                                          // Select this text field when scaling starts
                                                          selectTextField(
                                                              textConfig);

                                                          // Store initial scale and rotation for relative changes
                                                          _initialScale =
                                                              textConfig
                                                                  .scale.value;
                                                          _initialRotation =
                                                              textConfig
                                                                  .rotation
                                                                  .value;
                                                        },
                                                  onScaleUpdate: isCapturing
                                                      ? null // Disable interactions when capturing
                                                      : (details) {
                                                          // Handle both panning and scaling in the scale update

                                                          // If it's a pure pan operation (scale = 1.0, no rotation)
                                                          if (details.scale ==
                                                                  1.0 &&
                                                              details.rotation ==
                                                                  0.0) {
                                                            // Update position offset based on drag
                                                            textConfig
                                                                    .positionOffset
                                                                    .value +=
                                                                details
                                                                    .focalPointDelta;
                                                          } else {
                                                            // Update scale (with limits)
                                                            final newScale =
                                                                (_initialScale *
                                                                        details
                                                                            .scale)
                                                                    .clamp(0.5,
                                                                        3.0); // Limit scale between 0.5x and 3x
                                                            textConfig.scale
                                                                    .value =
                                                                newScale;

                                                            // Update rotation if rotation is enabled
                                                            if (details
                                                                    .rotation !=
                                                                0.0) {
                                                              textConfig
                                                                      .rotation
                                                                      .value =
                                                                  _initialRotation +
                                                                      details
                                                                          .rotation;
                                                            }
                                                          }
                                                        },
                                                  child: Transform.rotate(
                                                    angle: rotation,
                                                    child: Container(
                                                      width: scaledWidth,
                                                      constraints:
                                                          BoxConstraints(
                                                        maxWidth: scaledWidth,
                                                        minWidth: textConfig
                                                                .controller
                                                                .text
                                                                .isEmpty
                                                            ? 100.0 // Default minimum width
                                                            : scaledWidth *
                                                                0.5, // Use a percentage of the scaled width
                                                      ),
                                                      decoration: BoxDecoration(
                                                        // Visual feedback for selection - only when not capturing
                                                        border: isCapturing
                                                            ? null // No border when capturing
                                                            : Border.all(
                                                                color: isSelected
                                                                    ? Colors
                                                                        .blue
                                                                        .withOpacity(
                                                                            0.8)
                                                                    : Colors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.3),
                                                                width:
                                                                    isSelected
                                                                        ? 2
                                                                        : 1,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        color: isCapturing
                                                            ? Colors
                                                                .transparent // Transparent when capturing
                                                            : isSelected
                                                                ? Colors.black
                                                                    .withOpacity(
                                                                        0.3)
                                                                : Colors
                                                                    .transparent,
                                                      ),
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: InkWell(
                                                          onTap:
                                                              null, // Disable tap to prevent conflict with GestureDetector
                                                          onDoubleTap: isCapturing
                                                              ? null // Disable when capturing
                                                              : () {
                                                                  showTextEditDialog(
                                                                      context,
                                                                      textConfig);
                                                                },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8.0),
                                                            child: Text(
                                                              textConfig
                                                                  .controller
                                                                  .text,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: textConfig
                                                                  .style
                                                                  .copyWith(
                                                                fontSize: textConfig
                                                                        .style
                                                                        .fontSize! *
                                                                    scale,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ))
                      .toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The example for a frame around the images
class FrameExample extends StatefulWidget {
  /// Creates a new [FrameExample] widget.
  const FrameExample({super.key});

  @override
  State<FrameExample> createState() => _FrameExampleState();
}

class _FrameExampleState extends State<FrameExample>
    with ExampleHelperState<FrameExample> {
  late final ScrollController _bottomBarScrollCtrl;

  String _frameUrl = 'assets/frame.png';
  bool _useTemplateFrame = false; // Flag to track if template frame is active

  /// Better scale experience
  final double _initScale = 10;
  final double _layerInitWidth = 200;

  final _bottomTextStyle = const TextStyle(fontSize: 10.0, color: Colors.white);

  Uint8List? _transparentBytes;

  Map<String, Uint8List> _layerImageData = {};
  Layer? _selectedLayer;

  // Replace boolean with ValueNotifier for better reactivity
  final ValueNotifier<bool> _controlsVisibleNotifier =
      ValueNotifier<bool>(false);

  // Frame template manager
  late final FrameTemplateManager _templateManager;

  // _FrameExampleState क्लास में एक नया ValueNotifier जोड़ें
  final ValueNotifier<bool> _isCapturingResult = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _bottomBarScrollCtrl = ScrollController();

    // Initialize frame templates
    _templateManager = FrameTemplateManager(
      templates: [
        // Birthday template
        FrameTemplate(
          name: 'Birthday',
          frameAsset: 'assets/frame.png',
          textFields: [
            TextFieldConfig(
              initialText: 'Happy Birthday',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.3,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
            TextFieldConfig(
              initialText: 'Avik',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.45,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
          ],
        ),
        // Anniversary template
        FrameTemplate(
          name: 'Anniversary',
          frameAsset: 'assets/frame1.png',
          textFields: [
            TextFieldConfig(
              initialText: 'Happy Anniversary',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.2,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
            TextFieldConfig(
              initialText: 'John & Jane',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.35,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
            TextFieldConfig(
              initialText: '5 Years',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.55,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
          ],
        ),
        // Greeting template
        FrameTemplate(
          name: 'Greeting',
          frameAsset: 'assets/frame.png',
          textFields: [
            TextFieldConfig(
              initialText: 'Hello',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.25,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
            TextFieldConfig(
              initialText: 'Beautiful World',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.4,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
            TextFieldConfig(
              initialText: '2024',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              topPosition: 0.6,
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),
          ],
        ),
      ],
      // Only include callbacks that don't affect frame opacity
      onTextFieldSelected: (textField) {
        // No frame opacity changes here
      },
      onAllTextFieldsDeselected: () {
        // No frame opacity changes here
      },
    );

    // Set initial frame URL from template manager
    _frameUrl = _templateManager.currentFrameAsset;

    preCacheImage(assetPath: _frameUrl);
    _createTransparentBackgroundImage();

    // Add a post-frame callback to check for controls visibility after the editor is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLayerSelectionListener();
    });
  }

  @override
  void dispose() {
    _controlsVisibleNotifier.dispose();
    _bottomBarScrollCtrl.dispose();
    _templateManager.dispose(); // Dispose template manager
    super.dispose();
  }

  // Toggle between regular frame and template frame
  void _toggleTemplateFrame() {
    setState(() {
      _useTemplateFrame = !_useTemplateFrame;
    });
  }

  // Navigate to the next template
  void _nextTemplate() {
    setState(() {
      _templateManager.nextTemplate();
      _frameUrl = _templateManager.currentFrameAsset;
    });
    _updateFrameImage();
  }

  // Navigate to the previous template
  void _previousTemplate() {
    setState(() {
      _templateManager.previousTemplate();
      _frameUrl = _templateManager.currentFrameAsset;
    });
    _updateFrameImage();
  }

  // Update the frame image when template changes
  Future<void> _updateFrameImage() async {
    try {
      // Precache the new frame image
      await precacheImage(AssetImage(_frameUrl), context);

      // Mark screenshots as broken to regenerate them
      if (editorKey.currentState != null) {
        for (var el in editorKey.currentState!.stateManager.screenshots) {
          el.broken = true;
        }
      }

      // Update the transparent background
      await _createTransparentBackgroundImage();

      // Update the editor image
      if (editorKey.currentState != null && _transparentBytes != null) {
        editorKey.currentState!.editorImage = EditorImage(
          byteArray: _transparentBytes,
        );
        await editorKey.currentState!.decodeImage();
      }
    } catch (e) {
      print('Error updating frame image: $e');
    }
  }

  // Method to capture a rendered widget as an image - optimized version
  Future<Uint8List?> captureWidgetAsImage(Widget widget, Size size) async {
    try {
      // Create a GlobalKey for the RepaintBoundary
      final GlobalKey repaintBoundaryKey = GlobalKey();

      // Create a temporary widget with RepaintBoundary
      final tempWidget = RepaintBoundary(
        key: repaintBoundaryKey,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: widget,
        ),
      );

      // Create a BuildContext for the widget
      final BuildContext? context = editorKey.currentContext;
      if (context == null) return null;

      // Create an overlay entry to render the widget
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: 0,
          top: 0,
          child: Opacity(
            opacity: 0.01, // Nearly invisible but still rendered
            child: tempWidget,
          ),
        ),
      );

      // Add the overlay entry to render the widget
      Overlay.of(context).insert(overlayEntry);

      // Wait for the widget to be rendered
      await Future.delayed(const Duration(milliseconds: 50));

      // Capture the image
      final RenderRepaintBoundary? boundary = repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        overlayEntry.remove();
        return null;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      // Remove the overlay entry
      overlayEntry.remove();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      print('Error capturing widget as image: $e');
    }
    return null;
  }

  void _openPicker(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    Uint8List? bytes;

    bytes = await image.readAsBytes();

    if (!mounted) return;
    await precacheImage(MemoryImage(bytes), context);
    var decodedImage = await decodeImageFromList(bytes);

    if (!mounted) return;
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      Navigator.pop(context);
    }

    // Create the image layer
    final imageLayer = WidgetLayer(
      /// Adjust the offset position to place the image at any desired
      /// location. Note that a zero offset places the image at the center
      /// of the editor.
      offset: Offset.zero,
      scale: _initScale,
      widget: Image.memory(
        bytes,
        width: 100,
        height: 100 /
            Size(
              decodedImage.width.toDouble(),
              decodedImage.height.toDouble(),
            ).aspectRatio,
        fit: BoxFit.cover,
      ),
    );

    // Add the layer to the editor
    editorKey.currentState!.addLayer(imageLayer);

    // Directly update the selected layer and controls visibility
    setState(() {
      _selectedLayer = imageLayer;
    });

    // Since this is an image layer, we want to show controls (reduce opacity)
    if (!_controlsVisibleNotifier.value) {
      _controlsVisibleNotifier.value = true;
    }
  }

  void _chooseCameraOrGallery() async {
    /// Open directly the gallery if the camera is not supported
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _openPicker(ImageSource.gallery);
      return;
    }

    if (!kIsWeb && Platform.isIOS) {
      await showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoTheme(
          data: const CupertinoThemeData(),
          child: CupertinoActionSheet(
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.camera),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo_camera),
                    Text('Camera'),
                  ],
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.gallery),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo),
                    Text('Gallery'),
                  ],
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        constraints: BoxConstraints(
          minWidth: min(MediaQuery.sizeOf(context).width, 360),
        ),
        builder: (context) {
          return Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                child: Wrap(
                  spacing: 45,
                  runSpacing: 30,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFEC407A),
                      secondaryColor: const Color(0xFFD3396D),
                      icon: Icons.photo_camera,
                      text: 'Camera',
                      onTap: () => _openPicker(ImageSource.camera),
                    ),
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFBF59CF),
                      secondaryColor: const Color(0xFFAC44CF),
                      icon: Icons.image,
                      text: 'Gallery',
                      onTap: () => _openPicker(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  void _toggleFrame() async {
    String newFrameUrl = _frameUrl == 'assets/frame.png'
        ? 'assets/frame1.png'
        : 'assets/frame.png';

    /// Important to precache the frame before we add it to the editor
    await precacheImage(AssetImage(newFrameUrl), context);

    _frameUrl = newFrameUrl;

    /// Mark all background-generated screenshots as broken, as the user has
    /// selected a different frame. This will trigger the screenshot to
    /// regenerate when the user selects 'Done.'
    for (var el in editorKey.currentState!.stateManager.screenshots) {
      el.broken = true;
    }

    /// To allow users to switch between multiple frames efficiently,
    /// consider caching the image bytes.
    await _createTransparentBackgroundImage();

    /// Set the background bounds
    editorKey.currentState!.editorImage = EditorImage(
      byteArray: _transparentBytes,
    );
    await editorKey.currentState!.decodeImage();
  }

  Future<void> _createTransparentBackgroundImage() async {
    Size frameSize = await _frameSize;
    double width = frameSize.width;
    double height = frameSize.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final paint = Paint()..color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()), paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = pngBytes!.buffer.asUint8List();
    // ignore: use_build_context_synchronously
    await precacheImage(MemoryImage(bytes), context);

    _transparentBytes = bytes;
    if (mounted) setState(() {});
  }

  Future<Size> get _frameSize async {
    var bytes = await _frameImage.safeByteArray(context);

    var decodedImage = await decodeImageFromList(bytes);

    return Size(
      decodedImage.width.toDouble(),
      decodedImage.height.toDouble(),
    );
  }

  EditorImage get _frameImage => EditorImage(
        assetPath: _frameUrl,

        /// Optional use another option below
        ///
        /// networkUrl: ,
        /// byteArray: ,
        /// file: ,
      );

  @override
  Widget build(BuildContext context) {
    if (!isPreCached || _transparentBytes == null) {
      return const PrepareImageWidget();
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: const PixelTransparentPainter(
              primary: Colors.white,
              secondary: Color(0xFFE2E2E2),
            ),
            child: _buildEditor(constraints),
          ),
        ],
      );
    });
  }

  Widget _buildEditor(BoxConstraints constraints) {
    return ProImageEditor.memory(
      _transparentBytes!,
      key: editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingStarted: () {
          // Set capturing flag to true to hide UI elements during capture
          _isCapturingResult.value = true;

          // First deselect all text fields when saving the image
          if (_useTemplateFrame) {
            _templateManager.deselectAllTextFields();
          }

          // Hide controls when saving the image
          _controlsVisibleNotifier.value = false;

          // Reset selected layer when saving
          setState(() {
            _selectedLayer = null;
          });

          // Deselect any selected layer
          if (editorKey.currentState != null) {
            editorKey.currentState!.layerInteractionManager.selectedLayerId =
                '';
          }
        },
        onImageEditingComplete: (bytes) async {
          // Call the original callback
          await onImageEditingComplete(bytes);

          // Reset capturing flag after completion
          _isCapturingResult.value = false;
        },
        onCloseEditor: () => onCloseEditor(enablePop: !isDesktopMode(context)),
        mainEditorCallbacks: MainEditorCallbacks(
          // Use onUpdateUI to detect layer selection changes
          onUpdateUI: () {
            // Check if a layer is selected
            final selectedLayerId =
                editorKey.currentState?.layerInteractionManager.selectedLayerId;

            // Get all active layers for debugging
            final activeLayers =
                editorKey.currentState?.stateManager.activeLayers;

            // IMPORTANT: Check if we have a selected layer from the manager
            final hasSelectedLayerFromManager =
                selectedLayerId != null && selectedLayerId.isNotEmpty;

            // Check if we have a selected layer from our local state
            final hasSelectedLayerFromState = _selectedLayer != null;

            // If we have a selected layer from either source, process it
            if (hasSelectedLayerFromManager || hasSelectedLayerFromState) {
              Layer? selectedLayer;

              // First try to find the layer from the manager's ID
              if (hasSelectedLayerFromManager && activeLayers != null) {
                for (var layer in activeLayers) {
                  if (layer.id == selectedLayerId) {
                    selectedLayer = layer;
                    break;
                  }
                }
              }

              // If we couldn't find it from the manager, use our local state
              if (selectedLayer == null && hasSelectedLayerFromState) {
                selectedLayer = _selectedLayer;
              }

              if (selectedLayer != null) {
                // Check if it's an image layer
                final isImageLayer = selectedLayer is WidgetLayer &&
                    (selectedLayer as WidgetLayer).widget is Image;

                setState(() {
                  _selectedLayer = selectedLayer;
                });

                // FIXED LOGIC: We want opacity reduced (controls visible) when editing image layers
                if (_controlsVisibleNotifier.value != isImageLayer) {
                  _controlsVisibleNotifier.value = isImageLayer;
                }
              }
            } else {
              // Check if we need to update the controls visibility
              if (_controlsVisibleNotifier.value) {
                // No layer selected, restore full opacity (hide controls)
                _controlsVisibleNotifier.value = false;
              }
            }
          },

          // Handle taps on the background (outside layers)
          onTap: () {
            // This is called when tapping on the background

            // If controls are visible, hide them (restore full opacity)
            if (_controlsVisibleNotifier.value) {
              _controlsVisibleNotifier.value = false;
            }

            // Deselect all text fields when tapping outside
            if (_useTemplateFrame) {
              _templateManager.deselectAllTextFields();
            }
          },

          // Keep these for backward compatibility
          onAddLayer: (Layer layer) {
            // Check if it's an image layer
            final isImageLayer =
                layer is WidgetLayer && (layer as WidgetLayer).widget is Image;

            // Update our local state
            setState(() {
              _selectedLayer = layer;
            });

            // Directly update controls visibility for image layers
            if (isImageLayer && !_controlsVisibleNotifier.value) {
              _controlsVisibleNotifier.value = true;
            }
          },
          onUpdateLayer: (Layer layer) {
            // Check if it's an image layer
            final isImageLayer =
                layer is WidgetLayer && (layer as WidgetLayer).widget is Image;

            // Update our local state
            setState(() {
              _selectedLayer = layer;
            });

            // Update controls visibility based on layer type
            if (_controlsVisibleNotifier.value != isImageLayer) {
              _controlsVisibleNotifier.value = isImageLayer;
            }
          },
          // Add these callbacks to handle sub-editor opening/closing
          onOpenSubEditor: (subEditor) {
            _controlsVisibleNotifier.value = true;
          },
          onEndCloseSubEditor: (subEditor) {
            // Let onUpdateUI handle visibility after sub-editor closes
          },
        ),
      ),
      configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
          imageGeneration: const ImageGenerationConfigs(
            enableUseOriginalBytes: false,

            /// Optional set the output format to png. Default format is jpeg
            /// outputFormat: OutputFormat.png,
          ),
          layerInteraction: LayerInteractionConfigs(
            selectable: LayerInteractionSelectable.enabled,
            initialSelected: true,
            style: const LayerInteractionStyle(
              buttonRadius: 10,
              strokeWidth: 1.2,
              borderElementWidth: 7,
              borderElementSpace: 5,
              borderColor: Colors.blue,
            ),
            widgets: LayerInteractionWidgets(
              editButton: (rebuildStream, onTap, rotation) => ReactiveWidget(
                stream: rebuildStream,
                builder: (_) {
                  return Positioned(
                    top: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: rotation,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            // Set controls visible when edit button is clicked
                            _controlsVisibleNotifier.value = true;

                            // Call the original onTap handler
                            onTap();

                            // Get the selected layer and open the editor
                            final selectedLayerId = editorKey.currentState
                                    ?.layerInteractionManager.selectedLayerId ??
                                '';
                            if (selectedLayerId.isNotEmpty) {
                              final selectedLayer = editorKey
                                  .currentState?.stateManager.activeLayers
                                  .firstWhere(
                                      (layer) => layer.id == selectedLayerId);
                              if (selectedLayer != null) {
                                setState(() {
                                  _selectedLayer = selectedLayer;
                                  _editSelectedImageLayer();
                                });
                              }
                            }
                          },
                          child: Tooltip(
                            message: 'Edit',
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          mainEditor: MainEditorConfigs(
            enableCloseButton: !isDesktopMode(context),
            widgets: MainEditorWidgets(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildCurrentFrame(editor.sizesManager.bodySize, rebuildStream),
              ],
              bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                stream: rebuildStream,
                key: key,
                builder: (_) => _buildBottomBar(
                  editor,
                  constraints,
                ),
              ),
            ),
            style: const MainEditorStyle(
              background: Colors.transparent,
              uiOverlayStyle:
                  SystemUiOverlayStyle(statusBarColor: Colors.black),
            ),
          ),
          paintEditor: PaintEditorConfigs(
            widgets: PaintEditorWidgets(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildCurrentFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
            style: const PaintEditorStyle(
              background: Colors.transparent,
              uiOverlayStyle:
                  SystemUiOverlayStyle(statusBarColor: Colors.black),
            ),
          ),

          /// Crop-Rotate, Filter, Tune and Blur editors are not supported
          cropRotateEditor: const CropRotateEditorConfigs(
            enabled: false,

            /// widgets: CropRotateEditorWidgets(
            ///   bodyItems: (editor, rebuildStream) => [
            ///     _buildFrame(editor.editorBodySize, rebuildStream),
            ///   ],
            /// ),
          ),
          filterEditor: FilterEditorConfigs(
            enabled: true,
            style: const FilterEditorStyle(),
            widgets: FilterEditorWidgets(
              bodyItemsRecorded: (editor, rebuildStream) => [
                _buildCurrentFrame(editor.editorBodySize, rebuildStream),
              ],
            ),
          ),
          blurEditor: const BlurEditorConfigs(
            enabled: false,

            /// widgets: BlurEditorWidgets(
            ///   bodyItemsRecorded: (editor, rebuildStream) => [
            ///     _buildFrame(editor.editorBodySize, rebuildStream),
            ///   ],
            /// ),
          ),
          tuneEditor: const TuneEditorConfigs(
            enabled: false,

            /// widgets: TuneEditorWidgets(
            ///   bodyItemsRecorded: (editor, rebuildStream) => [
            ///     _buildFrame(editor.editorBodySize, rebuildStream),
            ///   ],
            /// ),
          ),
          stickerEditor: StickerEditorConfigs(
            enabled: false,
            initWidth: _layerInitWidth / _initScale,
            buildStickers: (setLayer, scrollController) {
              // Optionally your code to pick layers
              return const SizedBox();
            },
          )),
    );
  }

  // Return a ReactiveWidget based on the current frame mode
  ReactiveWidget _buildCurrentFrame(Size bodySize, Stream<void> rebuildStream) {
    if (_useTemplateFrame) {
      return _templateManager.buildTemplateFrame(
        bodySize,
        rebuildStream,
        _controlsVisibleNotifier,
        context,
        _isCapturingResult,
      );
    } else {
      // Simple frame without text
      return ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => Image.asset(
          _frameUrl,
          width: bodySize.width,
          height: bodySize.height,
          fit: BoxFit.contain,
        ),
      );
    }
  }

  Widget _buildBottomBar(
    ProImageEditorState editor,
    BoxConstraints constraints,
  ) {
    return Scrollbar(
      controller: _bottomBarScrollCtrl,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: isDesktop ? null : 0,
      child: BottomAppBar(
        /// kBottomNavigationBarHeight is important so that helper lines work
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            controller: _bottomBarScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: min(constraints.maxWidth, 700), // Increased width
                maxWidth: 700, // Increased width
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FlatIconTextButton(
                      label: Text('Frame', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.filter_frames_outlined,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFrame,
                    ),
                    FlatIconTextButton(
                      label: Text(
                        _useTemplateFrame ? 'Plain Frame' : 'Template',
                        style: _bottomTextStyle,
                      ),
                      icon: Icon(
                        _useTemplateFrame ? Icons.image : Icons.text_fields,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _toggleTemplateFrame,
                    ),
                    if (_useTemplateFrame) ...[
                      FlatIconTextButton(
                        label: Text('Previous', style: _bottomTextStyle),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          size: 22.0,
                          color: Colors.white,
                        ),
                        onPressed: _previousTemplate,
                      ),

                      // Template indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_templateManager.currentTemplate.name} '
                          '(${_templateManager.currentIndex + 1}/${_templateManager.templatesCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      FlatIconTextButton(
                        label: Text('Next', style: _bottomTextStyle),
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          size: 22.0,
                          color: Colors.white,
                        ),
                        onPressed: _nextTemplate,
                      ),
                    ],
                    const VerticalDivider(width: 2),
                    FlatIconTextButton(
                      label: Text('Image', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _chooseCameraOrGallery,
                    ),
                    FlatIconTextButton(
                      label: Text('Paint', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openPaintEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Text', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.text_fields,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openTextEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Emoji', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openEmojiEditor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _editSelectedImageLayer() {
    if (_selectedLayer == null) return;

    // For image layers, we want to show controls (reduce opacity)
    if (_selectedLayer is WidgetLayer &&
        (_selectedLayer as WidgetLayer).widget is Image) {
      _controlsVisibleNotifier.value = true;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      constraints: BoxConstraints(
        minWidth: min(MediaQuery.sizeOf(context).width, 360),
      ),
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Wrap(
                spacing: 45,
                runSpacing: 30,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.center,
                alignment: WrapAlignment.spaceAround,
                children: [
                  MaterialIconActionButton(
                    primaryColor: const Color(0xFFBF59CF),
                    secondaryColor: const Color(0xFFAC44CF),
                    icon: Icons.filter,
                    text: 'Filter',
                    onTap: () {
                      Navigator.pop(context);
                      _openFilterEditorForLayer();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // After bottom sheet is closed, check if any layer is still selected
      final selectedLayerId =
          editorKey.currentState?.layerInteractionManager.selectedLayerId;
      final hasSelectedLayer =
          selectedLayerId != null && selectedLayerId.isNotEmpty;
      Layer? selectedLayer;
      if (hasSelectedLayer) {
        // Find the selected layer

        final activeLayers = editorKey.currentState?.stateManager.activeLayers;
        if (activeLayers != null) {
          for (var layer in activeLayers) {
            if (layer.id == selectedLayerId) {
              selectedLayer = layer;
              break;
            }
          }
        }
      }

      if (selectedLayer != null) {
        // Check if it's an image layer
        final isImageLayer = selectedLayer is WidgetLayer &&
            (selectedLayer as WidgetLayer).widget is Image;

        // Update controls visibility based on layer type
        _controlsVisibleNotifier.value = isImageLayer;
      } else {
        // No layer selected, restore full opacity
        _controlsVisibleNotifier.value = false;
      }
    });
  }

  void _openFilterEditorForLayer() async {
    if (_selectedLayer == null) return;

    if (_selectedLayer is! WidgetLayer ||
        (_selectedLayer as WidgetLayer).widget is! Image) return;

    final widgetLayer = _selectedLayer as WidgetLayer;
    final Image imageWidget = widgetLayer.widget as Image;
    if (imageWidget.image is! MemoryImage) return;

    final imageData = (imageWidget.image as MemoryImage).bytes;
    if (imageData == null) return;

    // For image layers in filter editor, we want to show controls (reduce opacity)
    _controlsVisibleNotifier.value = true;

    // Show loading indicator
    final loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => FilterEditor.memory(
          imageData,
          initConfigs: FilterEditorInitConfigs(
            convertToUint8List: false, // Set to false to get FilterMatrix
            theme: Theme.of(context),
            configs: ProImageEditorConfigs(
              designMode: platformDesignMode,
            ),
            onImageEditingStarted: onImageEditingStarted,
            onImageEditingComplete: onImageEditingComplete,
            onCloseEditor: onCloseEditor,
          ),
        ),
      ),
    );

    // After filter editor is closed, check if any layer is still selected
    final selectedLayerId =
        editorKey.currentState?.layerInteractionManager.selectedLayerId;
    final hasSelectedLayer =
        selectedLayerId != null && selectedLayerId.isNotEmpty;

    if (hasSelectedLayer) {
      // Find the selected layer
      Layer? selectedLayer;
      final activeLayers = editorKey.currentState?.stateManager.activeLayers;
      if (activeLayers != null) {
        for (var layer in activeLayers) {
          if (layer.id == selectedLayerId) {
            selectedLayer = layer;
            break;
          }
        }
      }

      if (selectedLayer != null) {
        // Check if it's an image layer
        final isImageLayer = selectedLayer is WidgetLayer &&
            (selectedLayer as WidgetLayer).widget is Image;

        // Update controls visibility based on layer type
        _controlsVisibleNotifier.value = isImageLayer;
      }
    } else {
      // No layer selected, restore full opacity
      _controlsVisibleNotifier.value = false;
    }

    if (result != null && mounted) {
      // Show loading indicator while processing
      Overlay.of(context).insert(loadingOverlay);

      try {
        // When convertToUint8List is false, we get FilterMatrix instead of Uint8List
        if (result is FilterMatrix) {
          // Create an EditorImage from the memory image
          final editorImage = EditorImage(byteArray: imageData);

          // Get the image dimensions
          var decodedImage = await decodeImageFromList(imageData);
          final imageSize = Size(
              decodedImage.width.toDouble(), decodedImage.height.toDouble());

          // Create a filtered image widget
          final filteredImageWidget = FilteredImage(
            image: editorImage,
            filters: result,
            width: imageSize.width,
            height: imageSize.height,
            configs: ProImageEditorConfigs(designMode: platformDesignMode),
            tuneAdjustments: [], // No tune adjustments
            blurFactor: 0, // No blur
            fit: BoxFit.cover,
          );

          // Capture the filtered image as Uint8List for future edits
          final capturedImage =
              await captureWidgetAsImage(filteredImageWidget, imageSize);

          if (capturedImage != null) {
            // Store the captured image data for future edits
            _layerImageData[_selectedLayer!.id] = capturedImage;

            // Create a simple Image widget with the filtered content
            final wrappedImage = Image.memory(
              capturedImage,
              width: imageSize.width,
              height: imageSize.height,
              fit: BoxFit.cover,
            );

            // Find the index of the selected layer
            final index = editorKey.currentState!.stateManager.activeLayers
                .indexWhere((layer) => layer.id == _selectedLayer!.id);

            if (index != -1) {
              // Replace the layer with the filtered image
              editorKey.currentState?.replaceLayer(
                layer: WidgetLayer(
                  offset: widgetLayer.offset,
                  scale: widgetLayer.scale,
                  rotation: widgetLayer.rotation,
                  widget: wrappedImage,
                ),
                index: index,
              );

              setState(() {
                _selectedLayer =
                    editorKey.currentState!.stateManager.activeLayers[index];
              });
            }
          }
        } else if (result is Uint8List) {
          // This case handles if somehow we still get a Uint8List
          // Store the edited image data for future edits
          _layerImageData[_selectedLayer!.id] = result;

          // Get the image dimensions
          var decodedImage = await decodeImageFromList(result);
          final imageSize = Size(
              decodedImage.width.toDouble(), decodedImage.height.toDouble());

          // Create a new image widget with the edited image
          final editedImage = Image.memory(
            result,
            width: imageSize.width,
            height: imageSize.height,
            fit: BoxFit.cover,
          );

          // Find the index of the selected layer
          final index = editorKey.currentState!.stateManager.activeLayers
              .indexWhere((layer) => layer.id == _selectedLayer!.id);

          if (index != -1) {
            // Replace the layer with the edited image
            editorKey.currentState?.replaceLayer(
              layer: WidgetLayer(
                offset: widgetLayer.offset,
                scale: widgetLayer.scale,
                rotation: widgetLayer.rotation,
                widget: editedImage,
              ),
              index: index,
            );

            setState(() {
              _selectedLayer =
                  editorKey.currentState!.stateManager.activeLayers[index];
            });
          }
        }
      } finally {
        // Remove loading indicator
        loadingOverlay.remove();
      }
    }
  }

  // Simplified layer selection listener that just does initial setup
  void _setupLayerSelectionListener() {
    if (!mounted || editorKey.currentState == null) {
      // If not ready yet, try again after a short delay
      Future.delayed(
          const Duration(milliseconds: 100), _setupLayerSelectionListener);
      return;
    }

    // Initial check for selected layer
    final hasSelectedLayer =
        editorKey.currentState!.layerInteractionManager.selectedLayerId != null;
    if (hasSelectedLayer) {
      _controlsVisibleNotifier.value = true;
    }
  }
}
