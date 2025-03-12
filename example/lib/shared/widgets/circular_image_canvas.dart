import 'package:flutter/material.dart';
import 'dart:typed_data';

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

  /// Indicates if debug information should be displayed.
  final bool showDebug;

  /// Creates a [CircularImageCanvas] widget.
  ///
  /// The [size] parameter defines the width and height of the circular canvas.
  /// The [imageBytes] parameter is the image data to display, or null if no image is set.
  /// The [onImageAdd] callback is triggered when the user wants to add an image.
  /// The [showDebug] parameter controls whether debug information is displayed.
  const CircularImageCanvas({
    Key? key,
    required this.size,
    this.imageBytes,
    required this.onImageAdd,
    this.showDebug = false,
  }) : super(key: key);

  @override
  State<CircularImageCanvas> createState() => _CircularImageCanvasState();
}

class _CircularImageCanvasState extends State<CircularImageCanvas> {
  // Variables to manage image panning
  Offset _imageOffset = Offset.zero;
  bool _isPanning = false;

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
              'Canvas Size: ${widget.size.toInt()}x${widget.size.toInt()}',
              style: TextStyle(
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
          child: OverflowBox(
            maxWidth: widget.size,
            maxHeight: widget.size,
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
              style: TextStyle(
                color: Colors.black,
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// Resets the panning offset to center the image.
  void resetPanningOffset() {
    setState(() {
      _imageOffset = Offset.zero;
    });
  }
}
