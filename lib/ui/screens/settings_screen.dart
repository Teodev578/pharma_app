import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pharma_app/services/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Français';

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir la langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Français'),
              leading: Radio<String>(
                value: 'Français',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() => _selectedLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _selectedLanguage = 'Français');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() => _selectedLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => AlertDialog(
          title: const Text('Rayon de recherche'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.controller.searchRadius.toInt()} km'),
              Slider(
                value: widget.controller.searchRadius,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${widget.controller.searchRadius.toInt()} km',
                onChanged: (value) {
                  widget.controller.updateSearchRadius(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apparence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('Système', ThemeMode.system),
            _buildThemeOption('Clair', ThemeMode.light),
            _buildThemeOption('Sombre', ThemeMode.dark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode) {
    return ListTile(
      title: Text(label),
      leading: Radio<ThemeMode>(
        value: mode,
        groupValue: widget.controller.themeMode,
        onChanged: (value) {
          widget.controller.updateThemeMode(value);
          Navigator.pop(context);
        },
      ),
      onTap: () {
        widget.controller.updateThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionHeader(theme, 'Application'),
              _buildSettingsTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Apparence',
                subtitle: widget.controller.themeMode == ThemeMode.system
                    ? 'Système'
                    : widget.controller.themeMode == ThemeMode.light
                        ? 'Clair'
                        : 'Sombre',
                onTap: _showThemeDialog,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.language_rounded,
                title: 'Langue',
                subtitle: _selectedLanguage,
                onTap: _showLanguageDialog,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.near_me_rounded,
                title: 'Rayon de recherche',
                subtitle: 'Actuellement ${widget.controller.searchRadius.toInt()} km',
                onTap: _showRadiusDialog,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Alertes et rappels',
                trailing: Switch(
                  value: widget.controller.notificationsEnabled,
                  onChanged: (value) {
                    widget.controller.updateNotificationsEnabled(value);
                  },
                ),
              ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Support & Feedback'),
          _buildSettingsTile(
            context,
            icon: Icons.bug_report_outlined,
            title: 'Signaler un bug',
            subtitle: 'Aidez-nous à nous améliorer',
            onTap: () => _launchURL('mailto:support@pharmaapp.com?subject=Bug%20Report%20PharmaApp'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.mail_outline_rounded,
            title: 'Nous contacter',
            subtitle: 'Une question ou une suggestion ?',
            onTap: () => _launchURL('mailto:contact@pharmaapp.com'),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Légal & À propos'),
          _buildSettingsTile(
            context,
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            subtitle: 'Les règles de l\'application',
            onTap: () => _launchURL('https://pharmaapp.com/terms'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            subtitle: 'Comment nous traitons vos données',
            onTap: () => _launchURL('https://pharmaapp.com/privacy'),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'À propos',
            subtitle: 'Version 0.1.0 (Beta)',
            onTap: () {},
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Fait avec ❤️ pour votre santé',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        )),
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}
