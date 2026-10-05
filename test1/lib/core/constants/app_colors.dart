import 'package:flutter/material.dart';

class AppColors {
  // WhatsApp Signature Emerald & Green Accents
  static const Color primary = Color(0xFF008069); // WhatsApp Classic Teal (Light)
  static const Color primaryDark = Color(0xFF00A884); // WhatsApp Emerald (Dark)
  static const Color primaryLight = Color(0xFF25D366); // WhatsApp Bright Green Accent
  static const Color accent = Color(0xFF00A884); // Teal/Emerald Accent
  static const Color secondary = Color(0xFF128C7E);

  // Backgrounds & Surfaces (Dark Theme)
  static const Color backgroundDark = Color(0xFF0B141B); // Deep Sleek Dark Wallpaper
  static const Color surfaceDark = Color(0xFF111B21); // Header & Bar Surface
  static const Color cardDark = Color(0xFF1F2C34); // WhatsApp Card Surface
  static const Color cardElevatedDark = Color(0xFF233138); // Highlighted Container
  static const Color borderDark = Color(0xFF222E35); // Subtle Border Separator

  // Backgrounds & Surfaces (Light Theme)
  static const Color backgroundLight = Color(0xFFF0F2F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE9EDEF);

  // Message Bubbles
  static const Color bubbleOutgoingLight = Color(0xFFD9FDD3);
  static const Color bubbleIncomingLight = Color(0xFFFFFFFF);
  static const Color bubbleOutgoingDark = Color(0xFF005C4B);
  static const Color bubbleIncomingDark = Color(0xFF202C33);

  // Typography - High-Contrast Dark Mode (WCAG AAA)
  static const Color textPrimaryDark = Color(0xFFE9EDEF); // 95% Crisp White
  static const Color textSecondaryDark = Color(0xFF8696A0); // High-readability Subtitles
  static const Color textMutedDark = Color(0xFF667781); // Subtle Hints & Timestamps

  // Typography - Light Mode
  static const Color textPrimaryLight = Color(0xFF111B21);
  static const Color textSecondaryLight = Color(0xFF667781);
  static const Color textMutedLight = Color(0xFF8696A0);

  // Status & Alerts
  static const Color success = Color(0xFF25D366);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

