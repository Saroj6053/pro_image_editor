// Dart imports:
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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

  // Factory constructor to create with default templates
  factory FrameTemplateManager.withDefaultTemplates({
    Function(TextFieldConfig)? onTextFieldSelected,
    Function()? onAllTextFieldsDeselected,
  }) {
    return FrameTemplateManager(
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
            // Existing text fields...
          ],
        ),

        // Greeting template
        FrameTemplate(
          name: 'Greeting',
          frameAsset: 'assets/frame.png',
          textFields: [
            // Existing text fields...
          ],
        ),

        // New Basic Circular template
        FrameTemplate(
          name: 'Basic Circular',
          frameAsset: 'assets/frame_basic.png',
          textFields: [
            // "YOU ARE INVITED TO CELEBRATE..." text field
            TextFieldConfig(
              initialText: 'YOU ARE INVITED TO CELEBRATE...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5ECCC4), // Teal color as shown in image
                letterSpacing: 1.2,
              ),
              topPosition: 0.45, // Position it in the middle section
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),

            // "Caroline's" text field (name)
            TextFieldConfig(
              initialText: 'Caroline\'s',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                fontFamily: 'Script', // Use a script font if available
                color: Color(0xFF5ECCC4), // Teal color
                letterSpacing: 0.5,
              ),
              topPosition: 0.53, // Position it below the first text
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),

            // "5TH BIRTHDAY" text field
            TextFieldConfig(
              initialText: '5TH BIRTHDAY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5ECCC4), // Teal color
                letterSpacing: 2.0,
              ),
              topPosition: 0.62, // Position it below the name
              padding: EdgeInsets.symmetric(horizontal: 0.1),
            ),

            // Event details text field
            TextFieldConfig(
              initialText:
                  'SATURDAY, AUGUST 8, 11 AM - 1 PM\nSHADY GROVE PARK, SHELTER B\nRSVP TO SHARON 555-7890',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5ECCC4), // Teal color
                height: 1.5, // Line spacing
                letterSpacing: 0.8,
              ),
              topPosition: 0.75, // Position it at the bottom section
              padding: EdgeInsets.symmetric(horizontal: 0.15),
            ),
          ],
        ),
      ],
      onTextFieldSelected: onTextFieldSelected,
      onAllTextFieldsDeselected: onAllTextFieldsDeselected,
    );
  }

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
