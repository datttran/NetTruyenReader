import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_provider.dart';

/// A Text widget that automatically applies font scaling from FontProvider
/// This ensures all text in the app scales consistently with user preferences
class ScaledText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool? enableInteractiveSelection;

  const ScaledText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.enableInteractiveSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        // If no custom style is provided, use the theme's text style
        if (style == null) {
          return Text(
            data,
            key: key,
            strutStyle: strutStyle,
            textAlign: textAlign,
            textDirection: textDirection,
            locale: locale,
            softWrap: softWrap,
            overflow: overflow,
            textScaleFactor: textScaleFactor,
            maxLines: maxLines,
            semanticsLabel: semanticsLabel,
            textWidthBasis: textWidthBasis,
            textHeightBehavior: textHeightBehavior,
            selectionColor: selectionColor,
            enableInteractiveSelection: enableInteractiveSelection,
          );
        }

        // If custom style is provided, apply font scaling to it
        final scaledStyle = fontProvider.scaleTextStyle(style!);
        
        return Text(
          data,
          key: key,
          style: scaledStyle,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
          enableInteractiveSelection: enableInteractiveSelection,
        );
      },
    );
  }
}

/// A Text.rich widget that automatically applies font scaling from FontProvider
class ScaledTextRich extends StatelessWidget {
  final InlineSpan textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool? enableInteractiveSelection;

  const ScaledTextRich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.enableInteractiveSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        // If no custom style is provided, use the theme's text style
        if (style == null) {
          return Text.rich(
            textSpan,
            key: key,
            strutStyle: strutStyle,
            textAlign: textAlign,
            textDirection: textDirection,
            locale: locale,
            softWrap: softWrap,
            overflow: overflow,
            textScaleFactor: textScaleFactor,
            maxLines: maxLines,
            semanticsLabel: semanticsLabel,
            textWidthBasis: textWidthBasis,
            textHeightBehavior: textHeightBehavior,
            selectionColor: selectionColor,
            enableInteractiveSelection: enableInteractiveSelection,
          );
        }

        // If custom style is provided, apply font scaling to it
        final scaledStyle = fontProvider.scaleTextStyle(style!);
        
        return Text.rich(
          textSpan,
          key: key,
          style: scaledStyle,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
          enableInteractiveSelection: enableInteractiveSelection,
        );
      },
    );
  }
}
