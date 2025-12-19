import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../app_theme.dart';

class MockIndicatorResizeble extends StatefulWidget {
  final void Function(double dx, double dy)? onDrag;
  final void Function(bool isPressed)? isPressed;
  final void Function(DragEndDetails details)? onPanEnd;
  final Widget? iconWidget;
  final double? sizeIndicator;

  const MockIndicatorResizeble({
    super.key,
    this.onDrag,
    this.isPressed,
    this.onPanEnd,
    this.iconWidget,
    this.sizeIndicator,
  });

  @override
  State<MockIndicatorResizeble> createState() => _MockIndicatorResizebleState();
}

class _MockIndicatorResizebleState extends State<MockIndicatorResizeble> {
  double initX = 0;
  double initY = 0;

  void _handleDrag(DragStartDetails details) {
    setState(() {
      initX = details.globalPosition.dx;
      initY = details.globalPosition.dy;
    });
  }

  void _handleUpdate(DragUpdateDetails details) {
    var dx = details.globalPosition.dx - initX;
    var dy = details.globalPosition.dy - initY;
    initX = details.globalPosition.dx;
    initY = details.globalPosition.dy;
    widget.onDrag?.call(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handleDrag,
      onPanUpdate: _handleUpdate,
      onPanDown: (details) {
        widget.isPressed?.call(true);
      },
      onPanCancel: () {
        widget.isPressed?.call(false);
      },
      onPanEnd: (details) {
        widget.isPressed?.call(false);
        widget.onPanEnd?.call(details);
      },
      onTapUp: (details) {
        widget.isPressed?.call(false);
      },
      child: (widget.iconWidget != null)
          ? widget.iconWidget!
          : Container(
              width: widget.sizeIndicator,
              height: widget.sizeIndicator,
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(128),
                shape: BoxShape.circle,
              ),
            ),
    );
  }
}

class Resizeble extends StatefulWidget {
  final Widget? child;
  final bool unSelect;
  final Function(
      double scaleLeft,
      double scaleTop,
      double scaleWidth,
      double scaleHeight,
      double? left,
      double? top,
      double? width,
      double? height)? onFromLTWH;
  final VoidCallback? onSelected;
  final VoidCallback? onPressDelete;
  final double? documentWidthSize;
  final double? documentHeightSize;
  final double? documentWidthView;
  final double? documentHeightView;
  final double? height;
  final double? width;
  final double? top;
  final double? left;

  const Resizeble({
    super.key,
    this.child,
    this.unSelect = false,
    this.onSelected,
    this.onPressDelete,
    this.documentWidthSize = 0.0,
    this.documentHeightSize = 0.0,
    this.documentWidthView = 0.0,
    this.documentHeightView = 0.0,
    this.height = 0.0,
    this.width = 0.0,
    this.top = 0.0,
    this.left = 0.0,
    this.onFromLTWH,
  });

  @override
  State<Resizeble> createState() => _ResizebleState();
}

const sizeDiameter = 30.0;

class _ResizebleState extends State<Resizeble> {
  // final GlobalKey _globalKey = GlobalKey();
  double height = 0;
  double width = 0;

  double top = 45;
  double left = 0;

  bool isPressed = false;

  @override
  void initState() {
    height = widget.height!;
    width = widget.width!;
    top = widget.top ?? 45;
    left = widget.left ?? 0;
    super.initState();
  }

  // void getSizeObject() => WidgetsBinding.instance!.addPostFrameCallback((_) {
  //       final box = _globalKey.currentContext;

  //       setState(() {
  //         final Size sizeObject = box!.size!;
  //         height = sizeObject.height;
  //         width = sizeObject.width;
  //         debugPrint('WIDTH : $width - HEIGHT : $height');
  //       });
  //     });

  @override
  Widget build(BuildContext context) {
    if (widget.onFromLTWH != null &&
        widget.documentWidthView != null &&
        widget.documentHeightView != null) {
      // Get MediaQuery
      // final mediaQuery = MediaQuery.of(context).size;
      // final widthMedia = mediaQuery.width;
      // final heightMedia = mediaQuery.height;
      // final heightAppBar = AppBar().preferredSize.height;

      final widthViewPdf = widget.documentWidthView;
      final heightViewPdf = widget.documentHeightView;

      // Get Document Size
      final widthDocument = widget.documentWidthSize;
      final heightDocument = widget.documentHeightSize;

      // Get the size of the left distance of the comparison of the PDF document
      // with the size of the original PDF document
      final scaleLeft = left / widthViewPdf! * widthDocument!;

      // Get the size of the top distance of the comparison of the PDF document
      // with the size of the original PDF document

      // final heightMediaMinAppBar = heightMedia - heightAppBar;
      // final heightDocumentMinAppBar = heightDocument - heightAppBar;

      // final skalaTop = top /
      //     (heightMedia - mediaQuery.height * 0.34 + heightAppBar) *
      //     heightDocument;
      final scaleTop = top / heightViewPdf! * heightDocument!;

      // Get the size of the width distance of the comparison of the PDF document
      // with the size of the original PDF document
      final scaleWidth = width / widthViewPdf * widthDocument;

      // Get the size of the height distance of the comparison of the PDF document
      // with the size of the original PDF document
      // final skalaHeight =
      //     height / (heightMedia - mediaQuery.height * 0.34) * heightDocument;
      final scaleHeight = height / heightViewPdf * heightDocument;

      widget.onFromLTWH!(scaleLeft, scaleTop, scaleWidth, scaleHeight, left,
          top, width, height);
    }
    return Stack(
      children: <Widget>[
        // Initial Position Object
        Positioned(
          top: top,
          left: left,
          child: GestureDetector(
            onTap: widget.onSelected,
            child: Container(
              // key: _globalKey,
              width: width,
              height: height,
              decoration: BoxDecoration(
                border:
                    (widget.unSelect) ? Border.all(color: Colors.blue) : null,
              ),
              child: widget.child,
            ),
          ),
        ),

        // Drag Object
        if (widget.unSelect)
          Positioned(
            top: top + height / 2 - height / 2,
            left: left + width / 2 - width / 2,
            child: MockIndicatorResizeble(
              sizeIndicator: sizeDiameter,
              onDrag: (dx, dy) {
                // Set drag object height constraint minimum and maximum
                if (top >= 0 && top <= widget.documentHeightView! - height) {
                  setState(() {
                    top += dy;
                  });
                }

                // Set drag object height constraint minimum
                if (top < 0) {
                  setState(() {
                    top = 0;
                  });
                }

                // Set drag object height constraint maximum
                if (top > widget.documentHeightView! - height) {
                  setState(() {
                    top = widget.documentHeightView! - height;
                  });
                }

                // Set drag object width constraint minimum and maximum
                if (left >= 0 && left <= widget.documentWidthView! - width) {
                  setState(() {
                    left += dx;
                  });
                }

                // Set drag object width constraint minimum
                if (left < 0) {
                  setState(() {
                    left = 0;
                  });
                }

                // Set drag object width constraint maximum
                if (left > widget.documentWidthView! - width) {
                  setState(() {
                    left = widget.documentWidthView! - width;
                  });
                }
              },
              isPressed: (newValue) {
                setState(() {
                  isPressed = newValue;
                });
              },
              onPanEnd: (details) {
                // Set drag object height maximum after pressed end
                if (top >= widget.documentHeightView! - height - 20) {
                  setState(() {
                    top = widget.documentHeightView! - height - 20;
                  });
                }
                // Set drag object height minimum after pressed end
                else if (top <= 45) {
                  setState(() {
                    top = 45;
                  });
                }

                // Set drag object width maximum after pressed end
                if (left >= widget.documentWidthView! - width - 20) {
                  setState(() {
                    left = widget.documentWidthView! - width - 20;
                  });
                }
              },
              iconWidget: Container(
                height: height,
                width: width,
                color: Colors.transparent,
              ),
            ),
          ),

        // Scale Bottom Right
        if (widget.unSelect)
          if (isPressed == false)
            Positioned(
              top: top + height - sizeDiameter / 2,
              left: left + width - sizeDiameter / 2,
              child: MockIndicatorResizeble(
                sizeIndicator: sizeDiameter,
                onDrag: (dx, dy) {
                  var mid = (dx + dy) / 2;

                  var newHeight = height + 2 * mid;
                  var newWidth = width + 2 * mid;

                  // Set the largest maximum size
                  if (newHeight <= 200 && newWidth <= 200) {
                    // Set the largest minimum size
                    if (newHeight > 25 && newWidth > 25) {
                      // Set the height constraint minimum and maximum
                      if (top <= widget.documentHeightView! - height &&
                          top >= 0) {
                        // Set the width constraint minimum and maximum
                        if (left <= widget.documentWidthView! - width &&
                            left >= 0) {
                          setState(() {
                            width = newWidth > 0 ? newWidth : 0;
                            height = newHeight > 0 ? newHeight : 0;
                            top -= mid;
                            left -= mid;
                          });
                        }

                        // Set the width constraint minimum
                        if (left < 0) {
                          setState(() {
                            left = 0;
                          });
                        }

                        // Set the width constraint maximum
                        if (left > widget.documentWidthView! - width) {
                          setState(() {
                            left = widget.documentWidthView! - width;
                          });
                        }
                      }

                      // Set the height constraint minimum
                      if (top < 0) {
                        setState(() {
                          top = 0;
                        });
                      }

                      // Set the height constraint maximum
                      if (top > widget.documentHeightView! - height) {
                        setState(() {
                          top = widget.documentHeightView! - height;
                        });
                      }
                    }
                  }
                },
                onPanEnd: (details) {
                  // Set drag object height maximum after pressed end
                  if (top >= widget.documentHeightView! - height - 20) {
                    setState(() {
                      top = widget.documentHeightView! - height - 20;
                    });
                  }
                  // Set drag object height minimum after pressed end
                  else if (top <= 45) {
                    setState(() {
                      top = 45;
                    });
                  }

                  // Set drag object width maximum after pressed end
                  if (left >= widget.documentWidthView! - width - 20) {
                    setState(() {
                      left = widget.documentWidthView! - width - 20;
                    });
                  }
                },
                iconWidget: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.secoundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MdiIcons.arrowTopLeftBottomRight,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

        // Action delete signature
        if (widget.unSelect)
          if (isPressed == false)
            Positioned(
              top: (top >= 45) ? top - sizeDiameter - 15 : top,
              left: (top >= 45)
                  ? left - sizeDiameter / 25
                  : (top < 45 && left < 45)
                      ? left + width + 5
                      : left - sizeDiameter - 15,
              child: MockIndicatorResizeble(
                sizeIndicator: sizeDiameter,
                onDrag: (dx, dy) {
                  var mid = (dx + dy) / 2;
                  var newHeight = height - 2 * mid;
                  var newWidth = width - 2 * mid;

                  setState(() {
                    height = newHeight > 0 ? newHeight : 0;
                    width = newWidth > 0 ? newWidth : 0;
                    top = top + mid;
                    left = left + mid;
                  });
                },
                iconWidget: Container(
                  color: Colors.black,
                  padding: EdgeInsets.zero,
                  child: IconButton(
                    color: Colors.white,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    onPressed: widget.onPressDelete,
                    icon: Icon(MdiIcons.trashCan),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
