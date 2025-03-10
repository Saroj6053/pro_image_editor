// Dart imports:
import 'dart:async';
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/rendering.dart' hide Layer;
import 'dart:ui' as ui;

// Package imports:
import 'package:google_fonts/google_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/shared/widgets/layer/interaction_helper/layer_interaction_button.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_matrix.dart';
import 'package:pro_image_editor/features/filter_editor/widgets/filtered_image.dart';
import 'package:pro_image_editor/shared/widgets/transform/transformed_content_generator.dart';
import 'package:pro_image_editor/features/crop_rotate_editor/models/transform_factors.dart';

// Project imports:
import '/core/constants/example_constants.dart';
import '/core/mixin/example_helper.dart';
import '/shared/widgets/material_icon_button.dart';

/// A widget that demonstrates a custom app bar and bottom bar layout.
///
/// The [CustomWidgetsExample] widget is a stateful widget that provides
/// an example of how to implement a custom app bar at the top and a custom
/// bottom bar at the bottom of the screen. This is useful in applications
/// where a unique layout or custom controls are needed in both the app bar
/// and the bottom bar.
///
/// The state for this widget is managed by the
/// [_CustomWidgetsExampleState] class.
///
/// Example usage:
/// ```dart
/// CustomAppbarBottombarExample();
/// ```
class CustomWidgetsExample extends StatefulWidget {
  /// Creates a new [CustomWidgetsExample] widget.
  const CustomWidgetsExample({super.key});

  @override
  State<CustomWidgetsExample> createState() => _CustomWidgetsExampleState();
}

/// The state for the [CustomWidgetsExample] widget.
///
/// This class manages the layout and behavior of the custom app bar and
/// bottom bar within the [CustomWidgetsExample] widget.
class _CustomWidgetsExampleState extends State<CustomWidgetsExample>
    with ExampleHelperState<CustomWidgetsExample> {
  late ScrollController _bottomBarScrollCtrl;
  late ScrollController _paintBottomBarScrollCtrl;
  late ScrollController _cropBottomBarScrollCtrl;

  // Add a key for the selected layer
  Layer? _selectedLayer;

  // Map to store the latest image data for each layer
  final Map<String, Uint8List> _layerImageData = {};

  final List<TextStyle> _customTextStyles = [
    GoogleFonts.roboto(),
    GoogleFonts.averiaLibre(),
    GoogleFonts.lato(),
    GoogleFonts.comicNeue(),
    GoogleFonts.actor(),
    GoogleFonts.odorMeanChey(),
    GoogleFonts.nabla(),
  ];

  final _bottomTextStyle = const TextStyle(fontSize: 10.0, color: Colors.white);
  final List<PaintModeBottomBarItem> paintModes = [
    const PaintModeBottomBarItem(
      mode: PaintMode.freeStyle,
      icon: Icons.edit,
      label: 'Freestyle',
    ),
    const PaintModeBottomBarItem(
      mode: PaintMode.arrow,
      icon: Icons.arrow_right_alt_outlined,
      label: 'Arrow',
    ),
    const PaintModeBottomBarItem(
      mode: PaintMode.line,
      icon: Icons.horizontal_rule,
      label: 'Line',
    ),
    const PaintModeBottomBarItem(
      mode: PaintMode.rect,
      icon: Icons.crop_free,
      label: 'Rectangle',
    ),
    const PaintModeBottomBarItem(
      mode: PaintMode.circle,
      icon: Icons.lens_outlined,
      label: 'Circle',
    ),
    const PaintModeBottomBarItem(
      mode: PaintMode.dashLine,
      icon: Icons.power_input,
      label: 'Dash line',
    ),
  ];

  final String _url = 'https://picsum.photos/id/237/2000';

  final _layerInteractionButtonRadius = 15.0;

  final double _initScale = 10; // Added for image scaling

  @override
  void initState() {
    super.initState();
    preCacheImage(networkUrl: _url);
    _bottomBarScrollCtrl = ScrollController();
    _paintBottomBarScrollCtrl = ScrollController();
    _cropBottomBarScrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _bottomBarScrollCtrl.dispose();
    _paintBottomBarScrollCtrl.dispose();
    _cropBottomBarScrollCtrl.dispose();
    super.dispose();
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

    // Create a simple Image widget without GestureDetector or MouseRegion
    final imageWidget = Image.memory(
      bytes,
      width: decodedImage.width.toDouble(),
      height: decodedImage.height.toDouble(),
      fit: BoxFit.cover,
    );

    // Add the layer to the editor
    final newLayer = WidgetLayer(
      offset: Offset.zero,
      scale: _initScale * 0.5,
      widget: imageWidget,
    );

    editorKey.currentState!.addLayer(newLayer);

    // Store the image data for future edits
    _layerImageData[newLayer.id] = bytes;

    // Set this as the selected layer
    setState(() {
      _selectedLayer = newLayer;
    });
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

  // Method to open crop editor for the selected layer
  Future<void> _openCropEditorForLayer(ProImageEditorState editor) async {
    if (_selectedLayer == null || _selectedLayer is! WidgetLayer) {
      return;
    }

    Navigator.pop(context); // Close the bottom sheet

    final widgetLayer = _selectedLayer as WidgetLayer;
    Widget layerWidget = widgetLayer.widget;

    // Extract the image data - handle both direct Image widgets and wrapped transformed images
    Uint8List? imageData;

    // Check if we have stored image data for this layer
    if (_layerImageData.containsKey(_selectedLayer!.id)) {
      // Use the stored image data
      imageData = _layerImageData[_selectedLayer!.id];
    } else if (layerWidget is Image) {
      final image = layerWidget;

      if (image.image is MemoryImage) {
        // Direct memory image
        imageData = (image.image as MemoryImage).bytes;
      } else if (image.frameBuilder != null) {
        // This might be our wrapped image with a transformed content
        // Try to extract the original image data from the frameBuilder
        try {
          // The original image data is stored in the Image.memory constructor
          imageData = (image.image as MemoryImage).bytes;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot extract image data')),
          );
          return;
        }
      }
    }

    if (imageData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit this image')),
      );
      return;
    }

    // Precache the image
    await precacheImage(MemoryImage(imageData), context);
    if (!mounted) return;

    // Show loading indicator
    final loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Open the crop editor
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => CropRotateEditor.memory(
          imageData!,
          initConfigs: CropRotateEditorInitConfigs(
            theme: Theme.of(context),
            convertToUint8List: false, // Set to false to get TransformConfigs
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

    // Handle the result
    if (result != null && mounted) {
      // Show loading indicator while processing
      Overlay.of(context).insert(loadingOverlay);

      try {
        // When convertToUint8List is false, we get TransformConfigs instead of Uint8List
        if (result is TransformConfigs) {
          // Create an EditorImage from the memory image
          final editorImage = EditorImage(byteArray: imageData);

          // Get the image dimensions
          var decodedImage = await decodeImageFromList(imageData);
          final imageSize = Size(
              decodedImage.width.toDouble(), decodedImage.height.toDouble());

          // Create a transformed image widget
          final transformedImageWidget = TransformedContentGenerator(
            transformConfigs: result,
            configs: ProImageEditorConfigs(designMode: platformDesignMode),
            child: FilteredImage(
              width: imageSize.width,
              height: imageSize.height,
              configs: ProImageEditorConfigs(designMode: platformDesignMode),
              image: editorImage,
              filters: [], // No filters
              tuneAdjustments: [], // No tune adjustments
              blurFactor: 0, // No blur
              fit: BoxFit.cover,
            ),
          );

          // Capture the transformed image as Uint8List for future edits
          final capturedImage =
              await captureWidgetAsImage(transformedImageWidget, imageSize);

          if (capturedImage != null) {
            // Store the captured image data for future edits
            _layerImageData[_selectedLayer!.id] = capturedImage;

            // Create a simple Image widget that wraps the transformed content
            final wrappedImage = Image.memory(
              capturedImage,
              width: imageSize.width,
              height: imageSize.height,
              fit: BoxFit.cover,
            );

            // Find the index of the selected layer
            final index = editor.activeLayers
                .indexWhere((layer) => layer.id == _selectedLayer!.id);

            if (index != -1) {
              // Replace the layer with the transformed image
              editor.replaceLayer(
                index: index,
                layer: WidgetLayer(
                  offset: widgetLayer.offset,
                  scale: widgetLayer.scale,
                  rotation: widgetLayer.rotation,
                  widget: wrappedImage,
                ),
              );

              setState(() {
                _selectedLayer = editor.activeLayers[index];
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
          final index = editor.activeLayers
              .indexWhere((layer) => layer.id == _selectedLayer!.id);

          if (index != -1) {
            // Replace the layer with the edited image
            editor.replaceLayer(
              index: index,
              layer: WidgetLayer(
                offset: widgetLayer.offset,
                scale: widgetLayer.scale,
                rotation: widgetLayer.rotation,
                widget: editedImage,
              ),
            );

            setState(() {
              _selectedLayer = editor.activeLayers[index];
            });
          }
        }
      } finally {
        // Remove loading indicator
        loadingOverlay.remove();
      }
    }
  }

  // Method to open filter editor for the selected layer
  Future<void> _openFilterEditorForLayer(ProImageEditorState editor) async {
    if (_selectedLayer == null || _selectedLayer is! WidgetLayer) {
      return;
    }

    Navigator.pop(context); // Close the bottom sheet

    final widgetLayer = _selectedLayer as WidgetLayer;
    Widget layerWidget = widgetLayer.widget;

    // Extract the image data - handle both direct Image widgets and wrapped transformed images
    Uint8List? imageData;

    // Check if we have stored image data for this layer
    if (_layerImageData.containsKey(_selectedLayer!.id)) {
      // Use the stored image data
      imageData = _layerImageData[_selectedLayer!.id];
    } else if (layerWidget is Image) {
      final image = layerWidget;

      if (image.image is MemoryImage) {
        // Direct memory image
        imageData = (image.image as MemoryImage).bytes;
      } else if (image.frameBuilder != null) {
        // This might be our wrapped image with a transformed content
        // Try to extract the original image data from the frameBuilder
        try {
          // The original image data is stored in the Image.memory constructor
          imageData = (image.image as MemoryImage).bytes;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot extract image data')),
          );
          return;
        }
      }
    }

    if (imageData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit this image')),
      );
      return;
    }

    // Precache the image
    await precacheImage(MemoryImage(imageData), context);
    if (!mounted) return;

    // Show loading indicator
    final loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Open the filter editor
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => FilterEditor.memory(
          imageData!,
          initConfigs: FilterEditorInitConfigs(
            theme: Theme.of(context),
            convertToUint8List: false, // Set to false to get FilterMatrix
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

    // Handle the result
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
            final index = editor.activeLayers
                .indexWhere((layer) => layer.id == _selectedLayer!.id);

            if (index != -1) {
              // Replace the layer with the filtered image
              editor.replaceLayer(
                index: index,
                layer: WidgetLayer(
                  offset: widgetLayer.offset,
                  scale: widgetLayer.scale,
                  rotation: widgetLayer.rotation,
                  widget: wrappedImage,
                ),
              );

              setState(() {
                _selectedLayer = editor.activeLayers[index];
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
          final index = editor.activeLayers
              .indexWhere((layer) => layer.id == _selectedLayer!.id);

          if (index != -1) {
            // Replace the layer with the edited image
            editor.replaceLayer(
              index: index,
              layer: WidgetLayer(
                offset: widgetLayer.offset,
                scale: widgetLayer.scale,
                rotation: widgetLayer.rotation,
                widget: editedImage,
              ),
            );

            setState(() {
              _selectedLayer = editor.activeLayers[index];
            });
          }
        }
      } finally {
        // Remove loading indicator
        loadingOverlay.remove();
      }
    }
  }

  void _editSelectedImageLayer(ProImageEditorState editor) {
    if (_selectedLayer == null || _selectedLayer is! WidgetLayer) {
      return;
    }

    final widgetLayer = _selectedLayer as WidgetLayer;
    Widget layerWidget = widgetLayer.widget;

    // Simplify the image layer detection
    bool isImageLayer = layerWidget is Image;

    if (!isImageLayer) {
      return;
    }

    // Show a bottom sheet with editing options
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
                    primaryColor: const Color(0xFF42A5F5),
                    secondaryColor: const Color(0xFF1976D2),
                    icon: Icons.crop,
                    text: 'Crop',
                    onTap: () => _openCropEditorForLayer(editor),
                  ),
                  MaterialIconActionButton(
                    primaryColor: const Color(0xFF66BB6A),
                    secondaryColor: const Color(0xFF388E3C),
                    icon: Icons.filter,
                    text: 'Filter',
                    onTap: () => _openFilterEditorForLayer(editor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isPreCached) return const PrepareImageWidget();

    return LayoutBuilder(builder: (context, constraints) {
      return ProImageEditor.network(
        _url,
        key: editorKey,
        callbacks: ProImageEditorCallbacks(
          onImageEditingStarted: onImageEditingStarted,
          onImageEditingComplete: onImageEditingComplete,
          onCloseEditor: () =>
              onCloseEditor(enablePop: !isDesktopMode(context)),
          // Add a callback to handle layer selection
          mainEditorCallbacks: MainEditorCallbacks(
            onAddLayer: (Layer layer) {
              // This will be called when a layer is added
              setState(() {
                _selectedLayer = layer;
              });
            },
            onUpdateLayer: (Layer layer) {
              // This will be called when a layer is updated
              setState(() {
                _selectedLayer = layer;
              });
            },
          ),
        ),
        configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
          mainEditor: MainEditorConfigs(
            enableCloseButton: !isDesktopMode(context),
            widgets: MainEditorWidgets(
              appBar: (editor, rebuildStream) => ReactiveAppbar(
                  stream: rebuildStream, builder: (_) => _buildAppBar(editor)),
              bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                  stream: rebuildStream,
                  builder: (_) =>
                      _bottomNavigationBar(editor, key, constraints)),
            ),
          ),
          paintEditor: PaintEditorConfigs(
            widgets: PaintEditorWidgets(
              appBar: (paintEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => _appBarPaintEditor(paintEditor),
              ),
              bottomBar: (paintEditor, rebuildStream) => ReactiveWidget(
                stream: rebuildStream,
                builder: (_) => _bottomBarPaintEditor(paintEditor, constraints),
              ),
            ),
          ),
          textEditor: TextEditorConfigs(
              showSelectFontStyleBottomBar: true,
              customTextStyles: _customTextStyles,
              widgets: TextEditorWidgets(
                appBar: (textEditor, rebuildStream) => ReactiveAppbar(
                  stream: rebuildStream,
                  builder: (_) => _appBarTextEditor(textEditor),
                ),
                bottomBar: (textEditor, rebuildStream) => null,
                bodyItems: (textEditor, rebuildStream) {
                  return [
                    ReactiveWidget(
                      stream: rebuildStream,
                      builder: (_) =>
                          _bottomBarTextEditor(textEditor, constraints),
                    ),
                  ];
                },
              )),
          cropRotateEditor: CropRotateEditorConfigs(
            widgets: CropRotateEditorWidgets(
              appBar: (cropRotateEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => _appBarCropRotateEditor(cropRotateEditor),
              ),
              bottomBar: (cropRotateEditor, rebuildStream) => ReactiveWidget(
                stream: rebuildStream,
                builder: (_) =>
                    _bottomBarCropEditor(cropRotateEditor, constraints),
              ),
            ),
          ),
          filterEditor: FilterEditorConfigs(
            widgets: FilterEditorWidgets(
              appBar: (filterEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => _appBarFilterEditor(filterEditor),
              ),
            ),
          ),
          blurEditor: BlurEditorConfigs(
            widgets: BlurEditorWidgets(
              appBar: (blurEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => _appBarBlurEditor(blurEditor),
              ),
            ),
          ),
          layerInteraction: LayerInteractionConfigs(
            selectable: LayerInteractionSelectable.enabled,
            initialSelected: true,
            style: LayerInteractionStyle(
              buttonRadius: _layerInteractionButtonRadius,
              strokeWidth: 2.0,
              borderElementWidth: 10,
              borderElementSpace: 5,
              borderColor: Colors.blue,
              removeCursor: SystemMouseCursors.click,
              rotateScaleCursor: SystemMouseCursors.click,
              editCursor: SystemMouseCursors.click,
              hoverCursor: SystemMouseCursors.move,
              borderStyle: LayerInteractionBorderStyle.solid,
              showTooltips: true,
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
                            // First call the original onTap handler
                            onTap();

                            // Then open our custom edit options if it's an image
                            if (_selectedLayer is WidgetLayer &&
                                (_selectedLayer as WidgetLayer).widget
                                    is Image) {
                              _editSelectedImageLayer(editorKey.currentState!);
                            }
                          },
                          child: Tooltip(
                            message: 'Edit',
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    _layerInteractionButtonRadius * 2),
                                color: Colors.red,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 3,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: _layerInteractionButtonRadius * 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              removeButton: (rebuildStream, onTap, rotation) => ReactiveWidget(
                builder: (_) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    child: Transform.rotate(
                      angle: rotation,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onTap,
                          child: Tooltip(
                            message: 'Remove',
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    _layerInteractionButtonRadius * 2),
                                color: Colors.red,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: _layerInteractionButtonRadius * 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                stream: rebuildStream,
              ),
              rotateScaleButton: (rebuildStream, onScaleRotateDown,
                      onScaleRotateUp, rotation) =>
                  ReactiveWidget(
                builder: (_) {
                  return Positioned(
                    /// IMPORTANT: The editor currently only supports this
                    /// position for rotation to function correctly
                    bottom: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: rotation,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Listener(
                          onPointerDown: onScaleRotateDown,
                          onPointerUp: onScaleRotateUp,
                          child: Tooltip(
                            message: 'Rotate',
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    _layerInteractionButtonRadius * 2),
                                color: Colors.green,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.rotate_90_degrees_ccw,
                                color: Colors.white,
                                size: _layerInteractionButtonRadius * 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                stream: rebuildStream,
              ),
            ),
          ),
        ),
      );
    });
  }

  AppBar _buildAppBar(ProImageEditorState editor) {
    return AppBar(
      automaticallyImplyLeading: false,
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
      actions: [
        if (!isDesktopMode(context))
          IconButton(
            tooltip: 'Cancel',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            icon: const Icon(Icons.close),
            onPressed: editor.closeEditor,
          ),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Undo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.undo,
            color: editor.canUndo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: editor.undoAction,
        ),
        IconButton(
          tooltip: 'Redo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.redo,
            color: editor.canRedo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: editor.redoAction,
        ),
        IconButton(
          tooltip: 'Done',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: editor.doneEditing,
        ),
      ],
    );
  }

  AppBar _appBarPaintEditor(PaintEditorState paintEditor) {
    return AppBar(
      automaticallyImplyLeading: false,
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.arrow_back),
          onPressed: paintEditor.close,
        ),
        const SizedBox(width: 80),
        const Spacer(),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.line_weight_rounded,
            color: Colors.white,
          ),
          onPressed: paintEditor.openLinWidthBottomSheet,
        ),
        IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            icon: Icon(
              paintEditor.fillBackground == true
                  ? Icons.format_color_reset
                  : Icons.format_color_fill,
              color: Colors.white,
            ),
            onPressed: paintEditor.toggleFill),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Undo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.undo,
            color: paintEditor.canUndo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: paintEditor.undoAction,
        ),
        IconButton(
          tooltip: 'Redo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.redo,
            color: paintEditor.canRedo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: paintEditor.redoAction,
        ),
        IconButton(
          tooltip: 'Done',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: paintEditor.done,
        ),
      ],
    );
  }

  AppBar _appBarTextEditor(TextEditorState textEditor) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.arrow_back),
          onPressed: textEditor.close,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          onPressed: textEditor.toggleTextAlign,
          icon: Icon(
            textEditor.align == TextAlign.left
                ? Icons.align_horizontal_left_rounded
                : textEditor.align == TextAlign.right
                    ? Icons.align_horizontal_right_rounded
                    : Icons.align_horizontal_center_rounded,
          ),
        ),
        IconButton(
          onPressed: textEditor.toggleBackgroundMode,
          icon: const Icon(Icons.layers_rounded),
        ),
        const Spacer(),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: textEditor.done,
        ),
      ],
    );
  }

  AppBar _appBarCropRotateEditor(CropRotateEditorState cropRotateEditor) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.arrow_back),
          onPressed: cropRotateEditor.close,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Undo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.undo,
            color: cropRotateEditor.canUndo
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: cropRotateEditor.undoAction,
        ),
        IconButton(
          tooltip: 'Redo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.redo,
            color: cropRotateEditor.canRedo
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: cropRotateEditor.redoAction,
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: cropRotateEditor.done,
        ),
      ],
    );
  }

  AppBar _appBarFilterEditor(FilterEditorState filterEditor) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.arrow_back),
          onPressed: filterEditor.close,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: filterEditor.done,
        ),
      ],
    );
  }

  AppBar _appBarBlurEditor(BlurEditorState blurEditor) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.arrow_back),
          onPressed: blurEditor.close,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'My Button',
          color: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(
            Icons.bug_report,
            color: Colors.amber,
          ),
          onPressed: () {},
        ),
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: blurEditor.done,
        ),
      ],
    );
  }

  Widget _bottomNavigationBar(
      ProImageEditorState editor, Key key, BoxConstraints constraints) {
    return Scrollbar(
      /// Key is important for correct layer calculations
      key: key,
      controller: _bottomBarScrollCtrl,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: isDesktop ? null : 0,
      child: BottomAppBar(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            controller: _bottomBarScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: min(constraints.maxWidth, 500),
                maxWidth: 500,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                      label: Text('Add Image', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: _chooseCameraOrGallery,
                    ),
                    FlatIconTextButton(
                      label: Text('My Button',
                          style:
                              _bottomTextStyle.copyWith(color: Colors.amber)),
                      icon: const Icon(
                        Icons.new_releases_outlined,
                        size: 22.0,
                        color: Colors.amber,
                      ),
                      onPressed: () {},
                    ),
                    FlatIconTextButton(
                      label: Text('Crop/ Rotate', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.crop_rotate_rounded,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openCropRotateEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Filter', style: _bottomTextStyle),
                      icon: const Icon(
                        Icons.filter,
                        size: 22.0,
                        color: Colors.white,
                      ),
                      onPressed: editor.openFilterEditor,
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
                    /* Be careful with the sticker editor. It's important you 
                    add your own logic how to load items in 
                    `stickerEditorConfigs`.
                      FlatIconTextButton(
                        key: const ValueKey('open-sticker-editor-btn'),
                        label: Text('Sticker', style: bottomTextStyle),
                        icon: const Icon(
                          Icons.layers_outlined,
                          size: 22.0,
                          color: Colors.white,
                        ),
                        onPressed: editor.openStickerEditor,
                      ), */
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBarPaintEditor(
      PaintEditorState paintEditor, BoxConstraints constraints) {
    return Scrollbar(
      controller: _paintBottomBarScrollCtrl,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: isDesktop ? null : 0,
      child: BottomAppBar(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            controller: _paintBottomBarScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: min(constraints.maxWidth, 500),
                maxWidth: 500,
              ),
              child: Wrap(
                direction: Axis.horizontal,
                alignment: WrapAlignment.spaceAround,
                children: <Widget>[
                  FlatIconTextButton(
                    label: Text('My Button',
                        style: _bottomTextStyle.copyWith(color: Colors.amber)),
                    icon: const Icon(
                      Icons.new_releases_outlined,
                      size: 22.0,
                      color: Colors.amber,
                    ),
                    onPressed: () {},
                  ),
                  ...List.generate(
                    paintModes.length,
                    (index) => Builder(
                      builder: (_) {
                        var item = paintModes[index];
                        var color = paintEditor.paintMode == item.mode
                            ? kImageEditorPrimaryColor
                            : const Color(0xFFEEEEEE);

                        return FlatIconTextButton(
                          label: Text(
                            item.label,
                            style: TextStyle(fontSize: 10.0, color: color),
                          ),
                          icon: Icon(item.icon, color: color),
                          onPressed: () {
                            paintEditor.setMode(item.mode);
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBarTextEditor(
      TextEditorState textEditor, BoxConstraints constraints) {
    var items = _customTextStyles;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: kBottomNavigationBarHeight,
      child: Container(
        color: Colors.black,
        height: kBottomNavigationBarHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minWidth: MediaQuery.sizeOf(context).width),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                items.length,
                (index) {
                  bool isSelected = textEditor.selectedTextStyle.hashCode ==
                      items[index].hashCode;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: IconButton(
                      onPressed: () {
                        textEditor.setTextStyle(items[index]);
                      },
                      icon: Text(
                        'Aa',
                        style: items[index].copyWith(
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            isSelected ? Colors.white : Colors.black38,
                        foregroundColor:
                            isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBarCropEditor(
      CropRotateEditorState cropRotateEditor, BoxConstraints constraints) {
    return Scrollbar(
      controller: _cropBottomBarScrollCtrl,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: isDesktop ? null : 0,
      child: BottomAppBar(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            controller: _cropBottomBarScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: min(MediaQuery.sizeOf(context).width, 500),
                maxWidth: 500,
              ),
              child: Builder(builder: (context) {
                Color foregroundColor = Colors.white;
                return Wrap(
                  direction: Axis.horizontal,
                  alignment: WrapAlignment.spaceAround,
                  children: <Widget>[
                    FlatIconTextButton(
                      key: const ValueKey('crop-rotate-editor-rotate-btn'),
                      label: Text(
                        'Rotate',
                        style:
                            TextStyle(fontSize: 10.0, color: foregroundColor),
                      ),
                      icon: Icon(Icons.rotate_90_degrees_ccw_outlined,
                          color: foregroundColor),
                      onPressed: cropRotateEditor.rotate,
                    ),
                    FlatIconTextButton(
                      key: const ValueKey('crop-rotate-editor-flip-btn'),
                      label: Text(
                        'Flip',
                        style:
                            TextStyle(fontSize: 10.0, color: foregroundColor),
                      ),
                      icon: Icon(Icons.flip, color: foregroundColor),
                      onPressed: cropRotateEditor.flip,
                    ),
                    FlatIconTextButton(
                      key: const ValueKey('crop-rotate-editor-ratio-btn'),
                      label: Text(
                        'Ratio',
                        style:
                            TextStyle(fontSize: 10.0, color: foregroundColor),
                      ),
                      icon: Icon(Icons.crop, color: foregroundColor),
                      onPressed: cropRotateEditor.openAspectRatioOptions,
                    ),
                    FlatIconTextButton(
                      key: const ValueKey('crop-rotate-editor-reset-btn'),
                      label: Text(
                        'Reset',
                        style:
                            TextStyle(fontSize: 10.0, color: foregroundColor),
                      ),
                      icon: Icon(Icons.restore, color: foregroundColor),
                      onPressed: cropRotateEditor.reset,
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
