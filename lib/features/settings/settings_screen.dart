part of '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _signingOut = false;
  late final Future<bool> _modelReady = rootBundle
      .load('assets/model.tflite')
      .then((data) => data.lengthInBytes > 0)
      .catchError((_) => false);
  Future<void> _edit({bool changePhoto = false}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => EditProfileScreen(changePhoto: changePhoto)));
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    if (_signingOut || !await showSignOutConfirmation(context) || !mounted) {
      return;
    }
    setState(() => _signingOut = true);
    try {
      await AppScope.of(context).signOut();
      if (!mounted) return;
      AppScope.of(context).setTab(0);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
          (_) => false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not finish signing out. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
        allowCameraOverlap: true,
        child: ListView(padding: const EdgeInsets.only(bottom: 34), children: [
          Text(context.t('Settings'),
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 0)),
          const SizedBox(height: 20),
          MediaQuery.withNoTextScaling(
              key: const ValueKey('settings-profile-card'),
              child: _BatchPanel(
                  child: Row(children: [
                _ProfileAvatar(
                    path: state.avatarPath,
                    size: MediaQuery.sizeOf(context).width < 360 ? 80 : 104,
                    onChange: () => _edit(changePhoto: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          state.farmerName.isEmpty
                              ? 'Your profile'
                              : state.farmerName,
                          style: const TextStyle(
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Community profile',
                          style:
                              TextStyle(fontSize: 14, color: CcColors.muted)),
                      const SizedBox(height: 10),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: _edit,
                              icon: const Icon(Icons.edit, size: 17),
                              label: const Text('Edit profile'),
                              style: TextButton.styleFrom(
                                  backgroundColor: CcColors.bg,
                                  foregroundColor: CcColors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6))))),
                    ])),
              ]))),
          const SizedBox(height: 14),
          _BatchPanel(
              child: Column(children: [
            if (!state.isSignedIn) ...[
              _SettingsRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  value: 'Sign in',
                  onTap: () => go(context, const AuthLandingScreen())),
              const Divider(height: 1)
            ],
            _SettingsRow(
                icon: Icons.location_on,
                stackValue: true,
                title: 'Farm location',
                value: state.farmerLocation.isEmpty
                    ? 'Tap to add'
                    : state.farmerLocation,
                onTap: () => showLocationSheet(context)),
            const Divider(height: 1),
            _SettingsRow(
                icon: Icons.mail,
                stackValue: true,
                title: 'Barangay email',
                value: state.officeEmail.isEmpty
                    ? 'Tap to add'
                    : state.officeEmail,
                onTap: () => showEmailDialog(context)),
            const Divider(height: 1),
            _SettingsRow(
                icon: Icons.mail_outline,
                title: 'My email',
                value: state.accountEmail.isEmpty
                    ? 'Not signed in'
                    : state.accountEmail,
                stackValue: true),
            const Divider(height: 1),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.text_fields,
                          size: 24, color: CcColors.dark),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(context.t('Font size'),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: CcColors.dark,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            FontScaleControl(
                                value: state.fontScale,
                                onChanged: state.setFontScale),
                          ]))
                    ])),
            const Divider(height: 1),
            _SettingsRow(
                icon: Icons.language,
                title: 'Language',
                value: state.language,
                onTap: () => showLanguageSheet(context)),
            const Divider(height: 1),
            FutureBuilder<bool>(
                future: _modelReady,
                builder: (context, snapshot) => _SettingsRow(
                    icon: Icons.cloud_download,
                    title: 'Offline model',
                    trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: CcColors.soft,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            snapshot.connectionState != ConnectionState.done
                                ? 'Checking'
                                : snapshot.data == true
                                    ? 'Ready'
                                    : 'Unavailable',
                            style: const TextStyle(
                                fontSize: 12, color: CcColors.green))),
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                                title: const Text('Offline model'),
                                content: Text(snapshot.data == true
                                    ? 'Calamansi disease model v1 is installed on this phone. It checks leaves and fruits without internet.'
                                    : 'The offline model could not be loaded. Restart the app and try again.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Close'))
                                ])))),
            const Divider(height: 1),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary:
                    const Icon(Icons.verified_user, color: CcColors.dark),
                title: Text(context.t('Report consent'),
                    style: const TextStyle(
                        fontSize: 14,
                        color: CcColors.dark,
                        fontWeight: FontWeight.w600)),
                value: state.consentEnabled,
                onChanged: state.setConsent,
                activeThumbColor: Colors.white,
                activeTrackColor: CcColors.green),
            const Divider(height: 1),
            _SettingsRow(
                icon: Icons.description_outlined,
                title: 'About & Terms',
                onTap: () => showAboutAppDialog(context)),
          ])),
          const SizedBox(height: 16),
          if (state.isSignedIn)
            OutlinedButton.icon(
                onPressed: _signingOut ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: Text(
                    _signingOut ? 'Signing out...' : context.t('Sign out')),
                style: OutlinedButton.styleFrom(
                    foregroundColor: CcColors.red,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: CcColors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
        ]));
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
      {required this.icon,
      required this.title,
      this.value,
      this.trailing,
      this.stackValue = false,
      this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final bool stackValue;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 24, color: CcColors.dark),
            const SizedBox(width: 14),
            Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t(title),
                          style: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 0,
                              color: CcColors.dark,
                              fontWeight: FontWeight.w600)),
                      if (stackValue && value != null) ...[
                        const SizedBox(height: 5),
                        Text(context.t(value!),
                            style: const TextStyle(
                                fontSize: 13,
                                color: CcColors.muted,
                                letterSpacing: 0)),
                      ],
                    ])),
            if (value != null && !stackValue) ...[
              const SizedBox(width: 8),
              Expanded(
                  flex: 3,
                  child: Text(context.t(value!),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: CcColors.muted,
                          letterSpacing: 0)))
            ],
            if (trailing != null) trailing!,
            const SizedBox(width: 6),
            Icon(onTap == null ? Icons.lock_outline : Icons.chevron_right,
                size: 19, color: CcColors.muted),
          ])));
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar(
      {required this.path, required this.size, required this.onChange});
  final String path;
  final double size;
  final VoidCallback? onChange;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Positioned.fill(
            child: ClipOval(
                child: path.isEmpty
                    ? ColoredBox(
                        color: CcColors.soft,
                        child: Icon(Icons.person,
                            size: size * .52, color: CcColors.green))
                    : Image.file(File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, __, ___) => ColoredBox(
                            color: CcColors.soft,
                            child: Icon(Icons.person,
                                size: size * .52, color: CcColors.green))))),
        Positioned(
            right: 0,
            bottom: 0,
            child: Container(
                decoration: BoxDecoration(
                    color: CcColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: IconButton(
                    tooltip: 'Change profile photo',
                    onPressed: onChange,
                    style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    constraints:
                        const BoxConstraints.tightFor(width: 26, height: 26),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white)))),
      ]));
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.changePhoto = false});
  final bool changePhoto;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late String _photo;
  bool _photoChanged = false;
  bool _busy = false;
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.of(context);
    _name = TextEditingController(text: state.farmerName);
    _location = TextEditingController(text: state.farmerLocation);
    _photo = state.avatarPath;
    if (widget.changePhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _choosePhoto();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile photo',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const Divider(),
                      ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take photo'),
                          onTap: () => Navigator.pop(sheetContext, 'camera')),
                      ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Choose from gallery'),
                          onTap: () => Navigator.pop(sheetContext, 'gallery')),
                      ListTile(
                          leading: const Icon(Icons.delete_outline,
                              color: CcColors.red),
                          title: const Text('Remove photo',
                              style: TextStyle(color: CcColors.red)),
                          enabled: _photo.isNotEmpty,
                          onTap: () => Navigator.pop(sheetContext, 'remove')),
                      SizedBox(
                          width: double.infinity,
                          child: TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: TextButton.styleFrom(
                                  backgroundColor: CcColors.bg),
                              child: const Text('Cancel'))),
                    ]))));
    if (!mounted || action == null) return;
    if (action == 'remove') {
      setState(() {
        _photo = '';
        _photoChanged = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
          source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1280,
          maxHeight: 1280);
      if (mounted && file != null) {
        setState(() {
          _photo = file.path;
          _photoChanged = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not open the photo. Check permission and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final state = AppScope.of(context);
    setState(() => _busy = true);
    String? copied;
    try {
      if (_photoChanged && _photo.isNotEmpty) {
        copied = await DiagnosisRepository.instance.cacheProfileAvatar(_photo);
      }
      await state.updateProfile(
          name: _name.text,
          location: _location.text,
          photoPath: copied ?? _photo);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (copied != null) {
        try {
          await DiagnosisRepository.instance.deleteProfileAvatar(copied);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your profile. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
        backgroundColor: CcColors.bg,
        appBar: AppBar(
            backgroundColor: CcColors.bg,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: const Text('Edit profile',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            actions: [
              TextButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Save',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8)
            ]),
        body: SafeArea(
            top: false,
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                        key: _form,
                        child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Center(
                                  child: _ProfileAvatar(
                                      path: _photo,
                                      size: 148,
                                      onChange: _busy ? null : _choosePhoto)),
                              TextButton(
                                  onPressed: _busy ? null : _choosePhoto,
                                  child: const Text('Change photo')),
                              const SizedBox(height: 20),
                              const Text('Display name',
                                  style: TextStyle(
                                      fontSize: 14, color: CcColors.muted)),
                              const SizedBox(height: 6),
                              TextFormField(
                                  key: const ValueKey('profile-name'),
                                  controller: _name,
                                  enabled: !_busy,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 80,
                                  decoration: _fieldDecoration(),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Enter your display name.'
                                          : null),
                              const SizedBox(height: 12),
                              const Text('Farm location',
                                  style: TextStyle(
                                      fontSize: 14, color: CcColors.muted)),
                              const SizedBox(height: 6),
                              TextFormField(
                                  key: const ValueKey('profile-location'),
                                  controller: _location,
                                  enabled: !_busy,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 160,
                                  decoration: _fieldDecoration(),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Enter your farm location.'
                                          : null),
                              const SizedBox(height: 12),
                              const Text('Email address',
                                  style: TextStyle(
                                      fontSize: 14, color: CcColors.muted)),
                              const SizedBox(height: 6),
                              TextFormField(
                                  initialValue: state.accountEmail.isEmpty
                                      ? 'Not signed in'
                                      : state.accountEmail,
                                  readOnly: true,
                                  decoration: _fieldDecoration().copyWith(
                                      fillColor: const Color(0xFFE9ECE9),
                                      suffixIcon: const Icon(Icons.lock_outline,
                                          size: 18))),
                              const SizedBox(height: 10),
                              const Text(
                                  'Your photo and display name appear in Community.',
                                  style: TextStyle(
                                      fontSize: 12, color: CcColors.muted)),
                            ]))))));
  }

  InputDecoration _fieldDecoration() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: CcColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: CcColors.line)));
}
