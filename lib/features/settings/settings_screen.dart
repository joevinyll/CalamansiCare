part of '../../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TopLine(
              title: 'Settings',
              subtitle:
                  'Profile, location, language, email, model, and consent.',
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Account',
              child: Column(
                children: [
                  SettingTile(
                    icon: Icons.account_circle_outlined,
                    title: state.isSignedIn ? 'Signed in' : 'Account',
                    value: state.isSignedIn
                        ? state.accountEmail
                        : 'Sign in to restore reports',
                    action: state.isSignedIn ? 'View' : 'Edit',
                    onTap: () => go(context, const AuthLandingScreen()),
                  ),
                  if (state.isSignedIn) ...[
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      color: CcColors.red,
                      onPressed: () async {
                        final confirmed =
                            await showSignOutConfirmation(context);
                        if (!confirmed || !context.mounted) return;
                        await state.signOut();
                        state.setTab(0);
                        if (context.mounted) {
                          replaceWith(context, const WelcomeScreen());
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Farmer profile',
              child: Column(
                children: [
                  SettingTile(
                    icon: Icons.person_outline,
                    title: 'Name',
                    value: state.farmerName.trim().isEmpty
                        ? 'Tap to add'
                        : state.farmerName,
                    action: 'Edit',
                    onTap: () => showNameDialog(context),
                  ),
                  SettingTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    value: state.farmerLocation.trim().isEmpty
                        ? 'Tap to add'
                        : state.farmerLocation,
                    action: 'Edit',
                    onTap: () => showLocationSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Font size',
              child: FontScaleControl(
                value: state.fontScale,
                onChanged: state.setFontScale,
              ),
            ),
            const SizedBox(height: 14),
            SettingTile(
              icon: Icons.language,
              title: 'Language',
              value: state.language,
              action: 'Change',
              onTap: () => showLanguageSheet(context),
            ),
            SettingTile(
              icon: Icons.mail_outline,
              title: 'Barangay email',
              value: state.officeEmail.trim().isEmpty
                  ? 'Tap to add'
                  : state.officeEmail,
              action: 'Edit',
              onTap: () => showEmailDialog(context),
            ),
            const SettingTile(
              icon: Icons.memory_outlined,
              title: 'Offline model',
              value: 'Calamansi disease model v1',
              action: 'Update',
            ),
            SectionCard(
              title: 'Report consent',
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('Allow report preparation')),
                  subtitle: Text(
                    context.t('Can be turned off anytime before sending.'),
                  ),
                  value: state.consentEnabled,
                  onChanged: state.setConsent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'About CalamansiCare',
              child: OutlineAction(
                label: 'Read app details and terms of agreement.',
                icon: Icons.info_outline_rounded,
                backgroundColor: CcColors.soft,
                foregroundColor: CcColors.green,
                borderColor: CcColors.green,
                onTap: () => showAboutAppDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
