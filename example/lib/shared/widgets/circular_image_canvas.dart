import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:pro_image_editor/pro_image_editor.dart';
import '/core/constants/example_constants.dart';

/// A circular canvas widget with image panning capabilities.
///
/// This widget provides a circular frame for displaying images with
/// panning functionality. The widget maintains a fixed size and allows
/// the user to adjust the position of the image within the circular frame.
class CircularImageCanvas extends StatefulWidget {
  /// The size of the circular canvas.
  final double size;

  /// The image to display within the canvas.
  final Uint8List? imageBytes;

  /// Callback when an image is selected.
  final Function() onImageAdd;

  /// Callback when the image is updated (filtered or replaced).
  final Function(Uint8List) onImageUpdated;

  /// Indicates if debug information should be displayed.
  final bool showDebug;

  /// Creates a [CircularImageCanvas] widget.
  ///
  /// The [size] parameter defines the width and height of the circular canvas.
  /// The [imageBytes] parameter is the image data to display, or null if no image is set.
  /// The [onImageAdd] callback is triggered when the user wants to add an image.
  /// The [onImageUpdated] callback is triggered when the image is updated.
  /// The [showDebug] parameter controls whether debug information is displayed.
  const CircularImageCanvas({
    Key? key,
    required this.size,
    this.imageBytes,
    required this.onImageAdd,
    required this.onImageUpdated,
    this.showDebug = false,
  }) : super(key: key);

  @override
  State<CircularImageCanvas> createState() => _CircularImageCanvasState();
}

class _CircularImageCanvasState extends State<CircularImageCanvas> {
  // Variables to manage image panning
  Offset _imageOffset = Offset.zero;
  bool _isPanning = false;

  // Image scale multiplier (for zoom in/out)
  double _imageScale = 1.0;

  // Constants for size limits and steps
  static const double _minImageScale = 0.8; // 80% of original size
  static const double _maxImageScale = 1.2; // 120% of original size
  static const double _imageScaleStep = 0.1; // 10% per step

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Debug size text
        if (widget.showDebug)
          Positioned(
            top: -30,
            child: Text(
              'Canvas Size: ${widget.size.toInt()}x${widget.size.toInt()}, Scale: ${(_imageScale * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.black,
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Circular canvas
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.showDebug ? Colors.red : Colors.transparent,
              width: widget.showDebug ? 4.0 : 0.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: widget.imageBytes != null
                ? GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        _isPanning = true;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        // Scale the panning to make it more natural
                        _imageOffset += details.delta / 2;
                        _imageOffset = Offset(
                          _imageOffset.dx.clamp(-50.0, 50.0),
                          _imageOffset.dy.clamp(-50.0, 50.0),
                        );
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _isPanning = false;
                      });
                    },
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Image.memory(
                        widget.imageBytes!,
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.cover,
                        scale: 1 / _imageScale, // Apply scaling to the image
                        alignment: Alignment(
                          _imageOffset.dx / 50,
                          _imageOffset.dy / 50,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ),

        // Add image button
        if (widget.imageBytes == null)
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.add_photo_alternate,
                color: Colors.white,
                size: 40,
              ),
              onPressed: widget.onImageAdd,
            ),
          ),

        // Panning indicator
        if (_isPanning && widget.imageBytes != null)
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.pan_tool,
                color: Colors.white,
                size: widget.size * 0.15,
              ),
            ),
          ),

        // Debug panning instruction
        if (widget.showDebug && widget.imageBytes != null)
          Positioned(
            bottom: -25,
            child: Text(
              'Pan to adjust image position',
              style: const TextStyle(
                color: Colors.black,
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Top bar with buttons (only shown when image is loaded)
        if (widget.imageBytes != null)
          Positioned(
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter button
                  _buildTopBarButton(
                    icon: Icons.filter,
                    label: 'Filter',
                    onPressed: _openFilterEditor,
                  ),
                ],
              ),
            ),
          ),

        // Resize buttons (only shown when image is loaded)
        if (widget.imageBytes != null)
          Positioned(
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom in button
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _increaseImageSize,
                    tooltip: 'Zoom In',
                  ),
                ),
                // Zoom out button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: _decreaseImageSize,
                    tooltip: 'Zoom Out',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds a button for the top bar
  Widget _buildTopBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the filter editor for the selected image
  void _openFilterEditor() async {
    if (widget.imageBytes == null) return;

    try {
      // Pre-cache the image to avoid rendering issues
      await precacheImage(MemoryImage(widget.imageBytes!), context);

      if (!mounted) return;

      // Show a simple loading indicator in the UI
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Opening filter editor...'),
          duration: Duration(seconds: 1)));

      // Create a variable to store the filtered image bytes
      Uint8List? filteredBytes;

      // Use a simpler approach with MaterialPageRoute
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FilterEditor.memory(
            widget.imageBytes!,
            initConfigs: FilterEditorInitConfigs(
              theme: Theme.of(context),
              convertToUint8List: true,
              configs: ProImageEditorConfigs(
                designMode: platformDesignMode,
              ),
              onImageEditingStarted: () async {
                // Optional: Add loading indicator logic here
              },
              onImageEditingComplete: (Uint8List bytes) async {
                // Store the filtered image bytes
                filteredBytes = bytes;
              },
              onCloseEditor: () {
                // This ensures proper navigation back from the filter screen
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      );

      // After navigation completes, check if we have filtered bytes
      if (filteredBytes != null && mounted) {
        // Apply the filter changes to the image
        widget.onImageUpdated(filteredBytes!);
      }
    } catch (e) {
      print("Error in filter editor: $e");
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error in filter editor: $e')),
        );
      }
    }
  }

  /// Increases the image size by one step
  void _increaseImageSize() {
    setState(() {
      if (_imageScale < _maxImageScale) {
        _imageScale += _imageScaleStep;
      }
    });
  }

  /// Decreases the image size by one step
  void _decreaseImageSize() {
    setState(() {
      if (_imageScale > _minImageScale) {
        _imageScale -= _imageScaleStep;
      }
    });
  }

  /// Resets the panning offset to center the image.
  void resetPanningOffset() {
    setState(() {
      _imageOffset = Offset.zero;
    });
  }
}
