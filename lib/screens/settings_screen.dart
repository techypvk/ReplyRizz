import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/monetization_controller.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Unused

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const _AuthSection(),
          const Divider(height: 32),
          const _RewardsSection(),
          const Divider(height: 32),
          const _PreferencesSection(),
          const Divider(height: 32),
          const _InfoSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AuthSection extends StatelessWidget {
  const _AuthSection();

  void _showEditPasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Note: You must have signed in recently to change your password.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password too short (min 6)'
                        : null,
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          await user.updatePassword(
                            passwordController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          if (context.mounted) {
                            String errorMsg = e.message ?? "Update failed";
                            if (e.code == 'requires-recent-login') {
                              errorMsg =
                                  "Please log out and log in again to change password.";
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                            setState(() => isLoading = false);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                            setState(() => isLoading = false);
                          }
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;
    final theme = Theme.of(context);

    if (user != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.2,
                      ),
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email ?? 'User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.providerData.firstOrNull?.providerId ??
                                "Email Login",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showEditPasswordDialog(context, user),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Logged Out State
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: 12),
              const Text(
                "Sign in to save your history and access more features.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                    );
                  },
                  child: const Text("LOGIN / SIGN UP"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardsSection extends StatelessWidget {
  const _RewardsSection();

  @override
  Widget build(BuildContext context) {
    final monetization = Provider.of<MonetizationController>(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR REWARDS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Tokens',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${monetization.rewardedCredits}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: monetization.isRewardedAdLoaded
                    ? () {
                        monetization.showRewardedAd(
                          onRewardEarned: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reward Earned! +3 Tokens'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        );
                      }
                    : null,
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: Text(
                  monetization.isRewardedLoading ? 'Loading...' : 'Watch Ad',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Daily Free Limit Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Free Replies',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${monetization.remainingFreeReplies}/${MonetizationController.maxFreeRepliesPerCycle}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREFERENCES',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Magic Shake'),
          subtitle: const Text('Shake device to generate result'),
          value: settings.isMagicShakeEnabled,
          activeThumbColor: theme.colorScheme.primary,
          onChanged: (bool value) => settings.toggleMagicShake(value),
        ),
        // Theme Toggle Removed - Enforced Dark Mode
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: SelectableText('''
Link - https://sites.google.com/view/replyrizz-privacypolicy/home

📄 REPLYRIZZ – ADVANCED PRIVACY POLICY
Effective Date: 15/02/2026
Last Updated: 15/02/2026

ReplyRizz (“we,” “our,” or “us”) operates the ReplyRizz mobile application (the “App”). This Privacy Policy explains how we collect, use, disclose, and protect personal information in compliance with:

General Data Protection Regulation (GDPR – EU)

California Consumer Privacy Act (CCPA – USA)

Google Play Developer Policies


By using the App, you agree to this Privacy Policy.

1. Information We Collect
1.1 Information You Provide
Email address (account registration)

Display name (optional)

User input text for AI reply generation

Saved replies

Support/feedback messages


1.2 Automatically Collected Data
Device type & OS version

App usage statistics

Crash reports

Advertising ID

IP address (via analytics/ad services)


2. Legal Basis for Processing (GDPR)
We process personal data under the following lawful bases:

Consent – For analytics and advertising

Contractual necessity – To provide AI reply generation services

Legitimate interests – Fraud prevention, security, app improvement

Legal obligations – Compliance with applicable laws

3. How We Use Data
We use collected data to:

Provide AI-generated replies

Manage login and authentication

Track daily reply limits

Provide rewarded credits

Improve app performance

Display advertisements

Prevent abuse and fraud


We do not sell personal data.

4. AI Processing & Responsible Use
ReplyRizz uses third-party AI services to generate replies based on user input.

AI Misuse Protection Clause
Users agree NOT to use the App to:

Generate illegal content

Harass, threaten, or defame others

Create hate speech or discriminatory content

Generate explicit or adult content

Spread misinformation or harmful material


We reserve the right to:

Suspend accounts involved in misuse

Restrict access

Report illegal activity to authorities if required


User inputs may be processed automatically by AI systems.
We do not manually monitor conversations unless required for legal or abuse prevention purposes.

5. Advertising & Analytics
We use third-party services such as:

Google AdMob

Firebase Analytics

Firebase Crashlytics

These services may collect:

Advertising ID

Device information

Interaction data


You can manage ad personalization from your device settings.

6. Data Sharing
We may share data only with:

Cloud infrastructure providers (e.g., Firebase)

AI processing providers

Advertising networks

Legal authorities (if required by law)

We do not sell or rent personal data.

7. Data Retention
We retain data:

While your account is active

As required for legal obligations

Until a deletion request is received

Deleted accounts are removed from active systems within a reasonable timeframe.

8. Your Rights (GDPR – EU Users)
If you are located in the European Union, you have the right to:

Access your personal data

Rectify inaccurate data

Request data deletion

Restrict processing

Object to processing

Data portability

Withdraw consent at any time

You may also file a complaint with your local Data Protection Authority.

9. Your Rights (CCPA – California Residents)
If you are a California resident, you have the right to:

Know what personal information we collect

Request deletion of your data

Request disclosure of data shared

Opt-out of data sale (Note: We do not sell data)

Non-discrimination for exercising privacy rights

To exercise these rights, contact us at:
📧 roy@roydigital.in

10. Children’s Privacy
ReplyRizz is not intended for children under 13 years of age (or under 16 in certain regions).

We do not knowingly collect personal data from minors.

If discovered, such data will be deleted immediately.

11. Data Security
We implement reasonable technical safeguards including:

HTTPS encryption

Secure Firebase access controls

Restricted internal access

Encrypted data in transit

However, no system is 100% secure.

12. International Data Transfers
Your information may be processed in countries outside your own.
By using the App, you consent to cross-border data transfer in compliance with GDPR safeguards.

13. Changes to This Policy
We may update this Privacy Policy periodically.

Updates will be reflected by revising the “Last Updated” date.

14. Data Deletion Request – ReplyRizz
Request Account & Data Deletion
If you would like to delete your ReplyRizz account and associated data, please follow the steps below:

Send an email to:

📧 roy@roydigital.in

Include:

Registered email address

Subject: "Data Deletion Request"

Optional: Reason for deletion

We will process your request within 30 days.

15. Contact Information
App Name: ReplyRizz
Developer: Roy Digital
Country: India
Email: roy@roydigital.in
''', style: TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ReplyRizz is a creative writing assistant designed to help you craft fun and witty messages. \n\nIt offers suggestions to spark your creativity. Always review messages before sending.',
            ),
            const SizedBox(height: 16),
            Text(
              "Version: v1.0.0",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          onTap: () => _showPrivacyPolicy(context),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.info_outline),
          title: const Text('About ReplyRizz'),
          onTap: () => _showAbout(context),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ),
      ],
    );
  }
}
