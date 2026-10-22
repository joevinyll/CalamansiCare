part of '../main.dart';

class ScreenFrame extends StatelessWidget {
  const ScreenFrame(
      {super.key,
      required this.child,
      this.showNav = true,
      this.allowCameraOverlap = false});

  final Widget child;
  final bool showNav;
  final bool allowCameraOverlap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CcColors.bg,
      extendBody: showNav,
      body: SafeArea(
        bottom: !showNav,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                showNav
                    ? (allowCameraOverlap ? 78 : 112) +
                        MediaQuery.viewPaddingOf(context).bottom
                    : 16,
              ),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: showNav ? const AppBottomNav() : null,
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  void _openTab(BuildContext context, int index) {
    final state = AppScope.of(context);
    state.setTab(index);
    if (Navigator.of(context).canPop()) {
      replaceWith(context, const MainShell());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SizedBox(
            height: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  top: 26,
                  child: Material(
                    color: const Color(0xFF194F29),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(children: [
                      Expanded(
                          child: NavDot(
                        label: 'Home',
                        icon: Icons.home_rounded,
                        selected: state.tabIndex == 0,
                        onTap: () => _openTab(context, 0),
                      )),
                      Expanded(
                          child: NavDot(
                        label: 'History',
                        icon: Icons.history_rounded,
                        selected: state.tabIndex == 1,
                        onTap: () => _openTab(context, 1),
                      )),
                      const Expanded(child: SizedBox()),
                      Expanded(
                          child: NavDot(
                        label: 'Community',
                        icon: Icons.groups_rounded,
                        selected: state.tabIndex == 3,
                        onTap: () => _openTab(context, 3),
                      )),
                      Expanded(
                          child: NavDot(
                        label: 'Settings',
                        icon: Icons.settings_rounded,
                        selected: state.tabIndex == 2,
                        onTap: () => _openTab(context, 2),
                      )),
                    ]),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    label: context.t('Camera'),
                    button: true,
                    child: Tooltip(
                      message: context.t('Camera'),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD7EF91), width: 4),
                          color: const Color(0xFF347E42),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x24000000),
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => go(context, const CaptureScreen()),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavDot extends StatelessWidget {
  const NavDot({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFD7EF91) : Colors.white;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedScale(
                      duration: duration,
                      scale: selected ? 1.08 : 1,
                      child: Icon(
                        icon,
                        color: color,
                        size: 26,
                      )),
                ),
                const SizedBox(height: 3),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          context.t(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ))),
                const SizedBox(height: 5),
                AnimatedContainer(
                    duration: duration,
                    width: selected ? 16 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD7EF91),
                        borderRadius: BorderRadius.circular(2))),
              ],
            ),
          )),
    );
  }
}

class DarkScreen extends StatelessWidget {
  const DarkScreen({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CcColors.blackGreen,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: context.t('Back'),
                        onPressed: () => Navigator.maybePop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: CcColors.soft,
                          foregroundColor: CcColors.dark,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      OfflinePill(
                        label: AppScope.of(context).readinessLabel,
                        onDark: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.t(title),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('Place one affected leaf inside the guide'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TopLine extends StatelessWidget {
  const TopLine({
    super.key,
    required this.title,
    required this.subtitle,
    this.pill,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? pill;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                context.t(title),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (trailing != null)
              trailing!
            else if (pill != null)
              OfflinePill(label: context.t(pill!)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.t(subtitle),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class OfflinePill extends StatelessWidget {
  const OfflinePill(
      {super.key, this.label = 'Offline ready', this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final online = label.toLowerCase().contains('online') &&
        !label.toLowerCase().contains('offline');
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: online ? CcColors.soft : CcColors.orangeSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          context.t(label),
          style: TextStyle(
            color: online ? CcColors.green : CcColors.orange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onDark = false, this.centered = false});

  final bool onDark;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: onDark ? CcColors.lime : CcColors.green,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.eco_rounded,
            color: onDark ? CcColors.dark : Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'CalamansiCare',
          style: TextStyle(
            color: onDark ? Colors.white : CcColors.dark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class DarkActionCard extends StatelessWidget {
  const DarkActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: CcColors.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(subtitle),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onPrimary,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: CcColors.dark,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        child: Text(
                          context.t(buttonLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onSecondary,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: CcColors.dark,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        child: Text(
                          context.t(secondaryLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const PlantIllustration(size: 92, dark: true),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CcColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = CcColors.green,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CcColors.line,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
              fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.t(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  key: const ValueKey('label'),
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

class OutlineAction extends StatelessWidget {
  const OutlineAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.backgroundColor = Colors.white,
    this.foregroundColor = CcColors.dark,
    this.borderColor = CcColors.line,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
              fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: isLoading
              ? Row(
                  key: const ValueKey('outline-loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(foregroundColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.t(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  key: const ValueKey('outline-label'),
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = CcColors.green,
    this.onTap,
  });

  final String value;
  final String label;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CcColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CcColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: valueColor, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(context.t(label)),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallPill extends StatelessWidget {
  const SmallPill(this.text,
      {super.key, this.color = CcColors.green, this.onTap});

  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t(text),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 5),
            Icon(Icons.info_outline_rounded, color: color, size: 12),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: content,
      ),
    );
  }
}

class DiseaseTranslations {
  static const Map<String, Map<String, String>> descriptions = {
    'The fruit looks normal, with no clear disease marks. Keep checking often so problems can be found early.':
        {
      AppText.tagalog:
          'Mukhang normal ang bunga at walang malinaw na marka ng sakit. Patuloy na mag-check para maagapan ang problema.',
      AppText.cebuano:
          'Normal tan-awon ang bunga ug walay klarong marka sa sakit. Padayon nga mag-check aron maagapan ang problema.',
    },
    'The leaf looks healthy, with no clear disease signs. Continue regular watering, nutrition, and farm sanitation.':
        {
      AppText.tagalog:
          'Mukhang malusog ang dahon at walang malinaw na senyales ng sakit. Ipagpatuloy ang tamang dilig, nutrisyon, at kalinisan sa taniman.',
      AppText.cebuano:
          'Himsog tan-awon ang dahon ug walay klarong timailhan sa sakit. Padayon ang sakto nga pagbisbis, nutrisyon, ug kalimpyo sa uma.',
    },
    'A serious bacterial disease that can cause uneven yellow leaves, weak growth, and poor fruit quality. It can spread through infected planting material and citrus psyllids.':
        {
      AppText.tagalog:
          'Seryosong bacterial disease na maaaring magdulot ng hindi pantay na paninilaw ng dahon, mahinang paglaki, at mababang kalidad ng bunga. Kumakalat ito sa infected na pananim at citrus psyllids.',
      AppText.cebuano:
          'Seryosong bacterial disease nga mahimong makapahinungdan sa dili patas nga pag-yellow sa dahon, hinay nga pagtubo, ug bati nga kalidad sa bunga. Mokaylap kini pinaagi sa infected nga tanom ug citrus psyllids.',
    },
    'A bacterial disease that often creates raised corky spots on leaves, stems, or fruit. It spreads easily through wind-driven rain and infected plant material.':
        {
      AppText.tagalog:
          'Bacterial disease na madalas gumawa ng nakaangat at magaspang na batik sa dahon, sanga, o bunga. Madali itong kumalat sa ulan na tinatangay ng hangin at infected na bahagi ng halaman.',
      AppText.cebuano:
          'Bacterial disease nga kasagarang naghimo ug baga ug rough nga lama sa dahon, sanga, o bunga. Dali kini mokaylap sa ulan nga dala sa hangin ug infected nga bahin sa tanom.',
    },
    'A fungal disease that can cause dark sunken spots, twig dieback, and fruit damage, especially during wet or stressful conditions.':
        {
      AppText.tagalog:
          'Fungal disease na maaaring magdulot ng maitim at lubog na batik, pagkamatay ng maliliit na sanga, at sira sa bunga lalo na kapag basa o stressed ang puno.',
      AppText.cebuano:
          'Fungal disease nga mahimong makahatag ug itom nga lubog nga lama, pagkamatay sa gagmay nga sanga, ug kadaot sa bunga labi na kung basa o stressed ang kahoy.',
    },
    'A fungal disease linked to dead twigs and old infected wood. It can leave rough dark specks or streaks on fruit and leaves.':
        {
      AppText.tagalog:
          'Fungal disease na kaugnay ng patay na maliliit na sanga at lumang infected na kahoy. Maaari itong mag-iwan ng magaspang na maiitim na tuldok o guhit sa bunga at dahon.',
      AppText.cebuano:
          'Fungal disease nga konektado sa patay nga gagmay nga sanga ug daang infected nga kahoy. Makabiya kini ug rough nga itom nga tuldok o linya sa bunga ug dahon.',
    },
    'A fungal disease that can make rough raised scab marks on young leaves and fruit. It is common when new growth stays wet.':
        {
      AppText.tagalog:
          'Fungal disease na maaaring gumawa ng magaspang at nakaangat na scab marks sa batang dahon at bunga. Karaniwan ito kapag matagal na basa ang bagong tubo.',
      AppText.cebuano:
          'Fungal disease nga makahimo ug rough ug baga nga scab marks sa batan-ong dahon ug bunga. Kasagaran kini kung dugay mabasa ang bag-ong tubo.',
    },
    'A fungal disease that can cause brown leaf spots, fruit spots, and leaf drop. Wet weather and dense canopies can make it worse.':
        {
      AppText.tagalog:
          'Fungal disease na maaaring magdulot ng brown spots sa dahon at bunga, at paglagas ng dahon. Mas lumalala ito kapag basa ang panahon at siksik ang canopy.',
      AppText.cebuano:
          'Fungal disease nga mahimong makahatag ug brown spots sa dahon ug bunga, ug pagkalagas sa dahon. Mas mograbe kini kung basa ang panahon ug dasok ang canopy.',
    },
    'A black surface mold that grows on sticky honeydew from insects like scale, aphids, mealybugs, or whiteflies. It can cover leaves and fruit and reduce sunlight reaching the leaf.':
        {
      AppText.tagalog:
          'Itim na amag sa ibabaw ng dahon o bunga na tumutubo sa malagkit na honeydew mula sa peste tulad ng scale, aphids, mealybugs, o whiteflies. Maaari nitong takpan ang dahon at bunga at bawasan ang sikat ng araw na umaabot sa dahon.',
      AppText.cebuano:
          'Itom nga amag sa ibabaw sa dahon o bunga nga motubo sa sticky honeydew gikan sa peste sama sa scale, aphids, mealybugs, o whiteflies. Mahimo niini matabunan ang dahon ug bunga ug maminusan ang adlaw nga maabot sa dahon.',
    },
    'The condition needs a clearer photo or field checking before making a treatment decision.':
        {
      AppText.tagalog:
          'Kailangan ng mas malinaw na larawan o field checking bago magdesisyon sa paggamot.',
      AppText.cebuano:
          'Kinahanglan ug mas klarong hulagway o field checking bago magdesisyon sa pagtambal.',
    },
  };

  static const Map<String, Map<String, String>> guidance = {
    'Healthy Fruit': {
      AppText.tagalog: 'Malusog na bunga',
      AppText.cebuano: 'Himsog nga bunga',
    },
    'Healthy Leaf': {
      AppText.tagalog: 'Malusog na dahon',
      AppText.cebuano: 'Himsog nga dahon',
    },
    'HLB (Greening)': {
      AppText.tagalog: 'HLB / Greening',
      AppText.cebuano: 'HLB / Greening',
    },
    'Citrus Canker': {
      AppText.tagalog: 'Citrus Canker',
      AppText.cebuano: 'Citrus Canker',
    },
    'Anthracnose': {
      AppText.tagalog: 'Anthracnose',
      AppText.cebuano: 'Anthracnose',
    },
    'Melanose': {
      AppText.tagalog: 'Melanose',
      AppText.cebuano: 'Melanose',
    },
    'Citrus Scab': {
      AppText.tagalog: 'Citrus Scab',
      AppText.cebuano: 'Citrus Scab',
    },
    'Brown Spot': {
      AppText.tagalog: 'Brown Spot',
      AppText.cebuano: 'Brown Spot',
    },
    'Description': {
      AppText.tagalog: 'Paglalarawan',
      AppText.cebuano: 'Paglarawan',
    },
    'Healthy plant': {
      AppText.tagalog: 'Malusog na halaman',
      AppText.cebuano: 'Himsog nga tanom',
    },
    'Bacterial disease': {
      AppText.tagalog: 'Bacterial disease',
      AppText.cebuano: 'Bacterial disease',
    },
    'Fungal disease': {
      AppText.tagalog: 'Fungal disease',
      AppText.cebuano: 'Fungal disease',
    },
    'Surface fungal growth': {
      AppText.tagalog: 'Amag sa ibabaw ng dahon',
      AppText.cebuano: 'Amag sa ibabaw sa dahon',
    },
    'Needs field confirmation': {
      AppText.tagalog: 'Kailangan ng field confirmation',
      AppText.cebuano: 'Kinahanglan ug field confirmation',
    },
    'Continue weekly checks, proper watering, sanitation, and balanced nutrition.':
        {
      AppText.tagalog:
          'Ipagpatuloy ang lingguhang check, tamang dilig, kalinisan, at balanseng nutrisyon.',
      AppText.cebuano:
          'Padayon ang kada semana nga check, sakto nga pagbisbis, kalimpyo, ug balanse nga nutrisyon.',
    },
    'No insecticide, fungicide, or bactericide is needed. Do not spray a healthy tree unless a pest or disease is confirmed.':
        {
      AppText.tagalog:
          'Hindi kailangan ng insecticide, fungicide, o bactericide. Huwag mag-spray sa malusog na puno maliban kung kumpirmado ang peste o sakit.',
      AppText.cebuano:
          'Dili kinahanglan ug insecticide, fungicide, o bactericide. Ayaw pag-spray sa himsog nga kahoy gawas kung kumpirmado ang peste o sakit.',
    },
    'Keep the tree healthy with proper watering, compost or balanced citrus nutrition, pruning for airflow, and weekly inspection of leaves, fruit, and stems.':
        {
      AppText.tagalog:
          'Panatilihing malusog ang puno sa tamang dilig, compost o balanseng citrus nutrition, pruning para sa hangin, at lingguhang pag-check ng dahon, bunga, at sanga.',
      AppText.cebuano:
          'Padayon nga himsog ang kahoy gamit ang sakto nga pagbisbis, compost o balanse nga citrus nutrition, pruning para sa airflow, ug kada semana nga check sa dahon, bunga, ug sanga.',
    },
    'Use clean planting materials, sanitize pruning tools, remove fallen diseased debris, and monitor nearby trees for early symptoms.':
        {
      AppText.tagalog:
          'Gumamit ng malinis na pananim, linisin ang pruning tools, alisin ang nalaglag na may sakit na debris, at bantayan ang kalapit na puno.',
      AppText.cebuano:
          'Gamit ug limpyo nga tanom, limpyohi ang pruning tools, tangtanga ang nahulog nga diseased debris, ug bantayi ang duol nga kahoy.',
    },
    'Isolate suspicious trees and ask an agriculture technician for field confirmation before removing trees.':
        {
      AppText.tagalog:
          'Ihiwalay ang kahina-hinalang puno at humingi muna ng field confirmation sa agriculture technician bago magtanggal ng puno.',
      AppText.cebuano:
          'Ilain ang kahina-hinalang kahoy ug pangayo una ug field confirmation sa agriculture technician bago tangtangon ang kahoy.',
    },
    'There is no curative spray for HLB. If Asian citrus psyllids are present, use only labeled psyllid insecticides under technician guidance to reduce spread. Severely infected trees may need removal after confirmation.':
        {
      AppText.tagalog:
          'Walang spray na nakapagpapagaling sa HLB. Kung may Asian citrus psyllids, gumamit lamang ng labeled psyllid insecticide sa gabay ng technician para mabawasan ang pagkalat. Ang malubhang infected na puno ay maaaring kailangang tanggalin matapos makumpirma.',
      AppText.cebuano:
          'Walay spray nga makaayo sa HLB. Kung naay Asian citrus psyllids, gamit lang ug labeled psyllid insecticide ubos sa giya sa technician aron maminusan ang pagkaylap. Ang grabe nga infected nga kahoy mahimong tangtangon human makumpirma.',
    },
    'Use clean disease-free seedlings, remove or isolate confirmed infected trees, control ants that protect sap-sucking pests, prune weak branches, improve irrigation, and keep the tree nutritionally balanced.':
        {
      AppText.tagalog:
          'Gumamit ng malinis at disease-free seedlings, alisin o ihiwalay ang kumpirmadong infected na puno, kontrolin ang langgam na nagpoprotekta sa pesteng sumisipsip ng dagta, putulin ang mahihinang sanga, ayusin ang patubig, at panatilihing balanse ang nutrisyon.',
      AppText.cebuano:
          'Gamit ug limpyo ug disease-free seedlings, tangtanga o ilain ang kumpirmadong infected nga kahoy, kontrola ang hulmigas nga nagpanalipod sa sap-sucking pests, putla ang huyang nga sanga, ayuha ang irigasyon, ug panatilihing balanse ang nutrisyon.',
    },
    'Monitor new flush for psyllids, avoid moving infected seedlings or budwood, report suspected HLB, and protect young trees from psyllid access where possible.':
        {
      AppText.tagalog:
          'Bantayan ang bagong tubo para sa psyllids, iwasang ilipat ang infected seedlings o budwood, i-report ang suspected HLB, at protektahan ang batang puno kung maaari.',
      AppText.cebuano:
          'Bantayi ang bag-ong tubo para sa psyllids, likayi ang pagbalhin sa infected seedlings o budwood, i-report ang suspected HLB, ug protektahi ang batan-ong kahoy kung mahimo.',
    },
    'Prune badly affected parts with disinfected tools and avoid working on wet trees to limit spread.':
        {
      AppText.tagalog:
          'Putulin ang malubhang apektadong bahagi gamit ang disinfected tools at iwasang magtrabaho sa basang puno para hindi kumalat.',
      AppText.cebuano:
          'Putla ang grabe nga apektadong bahin gamit ang disinfected tools ug likayi ang pagtrabaho sa basa nga kahoy aron dili mokaylap.',
    },
    'Use a labeled copper-based bactericide/fungicide only as a protectant and only after field confirmation. It helps reduce new infection but will not heal existing spots.':
        {
      AppText.tagalog:
          'Gumamit ng labeled copper-based bactericide/fungicide bilang proteksyon lamang at pagkatapos ng field confirmation. Nakakatulong itong bawasan ang bagong impeksyon pero hindi nito pinapagaling ang lumang batik.',
      AppText.cebuano:
          'Gamit ug labeled copper-based bactericide/fungicide isip proteksyon lang ug human sa field confirmation. Makatabang kini sa pagpamenos sa bag-ong impeksyon pero dili makaayo sa daang lama.',
    },
    'Prune light infections, remove fallen infected leaves and fruit, disinfect tools between cuts, avoid overhead watering, and do not handle trees while leaves are wet.':
        {
      AppText.tagalog:
          'Putulin ang kaunting infected na bahagi, alisin ang nalaglag na infected na dahon at bunga, linisin ang tools sa bawat putol, iwasan ang overhead watering, at huwag hawakan ang puno habang basa ang dahon.',
      AppText.cebuano:
          'Putla ang gaan nga infected nga bahin, tangtanga ang nahulog nga infected nga dahon ug bunga, limpyohi ang tools matag putol, likayi ang overhead watering, ug ayaw hilabti ang kahoy samtang basa ang dahon.',
    },
    'Reduce leaf wounds, manage citrus leafminer if present, plant windbreaks where practical, and avoid moving infected plant material.':
        {
      AppText.tagalog:
          'Bawasan ang sugat sa dahon, kontrolin ang citrus leafminer kung mayroon, magtanim ng windbreaks kung kaya, at iwasang ilipat ang infected na bahagi ng halaman.',
      AppText.cebuano:
          'Pamenosi ang samad sa dahon, kontrola ang citrus leafminer kung naa, pagtanom ug windbreaks kung mahimo, ug likayi ang pagbalhin sa infected nga bahin sa tanom.',
    },
    'Remove infected plant material, improve airflow, and confirm the disease before applying any spray.':
        {
      AppText.tagalog:
          'Alisin ang infected na bahagi ng halaman, pagandahin ang daloy ng hangin, at kumpirmahin muna ang sakit bago mag-spray.',
      AppText.cebuano:
          'Tangtanga ang infected nga bahin sa tanom, ayuha ang airflow, ug kumpirmaha una ang sakit bago mag-spray.',
    },
    'If anthracnose was severe or confirmed, use a labeled copper fungicide or other locally approved citrus fungicide as a protectant. Follow the label and avoid spraying during very hot weather.':
        {
      AppText.tagalog:
          'Kung malala o kumpirmado ang anthracnose, gumamit ng labeled copper fungicide o ibang locally approved citrus fungicide bilang proteksyon. Sundin ang label at iwasang mag-spray kapag sobrang init.',
      AppText.cebuano:
          'Kung grabe o kumpirmado ang anthracnose, gamit ug labeled copper fungicide o uban pang locally approved citrus fungicide isip proteksyon. Sunda ang label ug likayi ang pag-spray kung init kaayo.',
    },
    'Prune dead twigs and infected branches, remove fallen diseased material, improve sunlight and airflow, avoid overhead watering, and reduce plant stress.':
        {
      AppText.tagalog:
          'Putulin ang patay na maliliit na sanga at infected branches, alisin ang nalaglag na may sakit na materyal, pagandahin ang araw at airflow, iwasan ang overhead watering, at bawasan ang stress ng halaman.',
      AppText.cebuano:
          'Putla ang patay nga gagmay nga sanga ug infected branches, tangtanga ang nahulog nga diseased material, paayosa ang adlaw ug airflow, likayi ang overhead watering, ug pamenosi ang stress sa tanom.',
    },
    'Keep the canopy open, sanitize pruning tools, maintain balanced nutrition, and inspect after long wet periods.':
        {
      AppText.tagalog:
          'Panatilihing bukas ang canopy, linisin ang pruning tools, panatilihin ang balanseng nutrisyon, at mag-inspect pagkatapos ng mahabang basang panahon.',
      AppText.cebuano:
          'Panatilihing bukas ang canopy, limpyohi ang pruning tools, panatilihing balanse ang nutrisyon, ug mag-inspect human sa taas nga basa nga panahon.',
    },
    'Remove dead twigs and dead wood because melanose commonly survives there.':
        {
      AppText.tagalog:
          'Alisin ang patay na maliliit na sanga at patay na kahoy dahil doon madalas nabubuhay ang melanose.',
      AppText.cebuano:
          'Tangtanga ang patay nga gagmay nga sanga ug patay nga kahoy kay didto kasagarang mabuhi ang melanose.',
    },
    'Use a labeled copper fungicide protectively when disease pressure is high, especially during wet periods. Copper protects new growth and fruit but does not repair old damage.':
        {
      AppText.tagalog:
          'Gumamit ng labeled copper fungicide bilang proteksyon kapag mataas ang pressure ng sakit, lalo na sa basang panahon. Pinoprotektahan ng copper ang bagong tubo at bunga pero hindi nito inaayos ang lumang sira.',
      AppText.cebuano:
          'Gamit ug labeled copper fungicide isip proteksyon kung taas ang pressure sa sakit, labi na sa basa nga panahon. Giprotektahan sa copper ang bag-ong tubo ug bunga pero dili niini ayohon ang daang kadaot.',
    },
    'Prune and remove dead wood, collect fallen infected debris, improve airflow, and keep the tree vigorous with proper water and nutrition.':
        {
      AppText.tagalog:
          'Putulin at alisin ang patay na kahoy, kolektahin ang nalaglag na infected debris, pagandahin ang airflow, at panatilihing malakas ang puno sa tamang tubig at nutrisyon.',
      AppText.cebuano:
          'Putla ug tangtanga ang patay nga kahoy, kolektaha ang nahulog nga infected debris, ayuha ang airflow, ug panatilihing kusgan ang kahoy sa sakto nga tubig ug nutrisyon.',
    },
    'Regularly remove dead twigs, avoid dense canopy growth, and monitor fruit during rainy weather.':
        {
      AppText.tagalog:
          'Regular na alisin ang patay na maliliit na sanga, iwasan ang sobrang siksik na canopy, at bantayan ang bunga sa tag-ulan.',
      AppText.cebuano:
          'Regular nga tangtanga ang patay nga gagmay nga sanga, likayi ang sobra kadense nga canopy, ug bantayi ang bunga sa ting-ulan.',
    },
    'Protect new leaves and young fruit early; old scab marks will not disappear.':
        {
      AppText.tagalog:
          'Protektahan agad ang bagong dahon at batang bunga; hindi mawawala ang lumang scab marks.',
      AppText.cebuano:
          'Protektahi dayon ang bag-ong dahon ug batan-ong bunga; dili mawala ang daang scab marks.',
    },
    'Use labeled citrus fungicides such as copper-based protectants or other technician-approved fungicides at the correct early-growth timing.':
        {
      AppText.tagalog:
          'Gumamit ng labeled citrus fungicides tulad ng copper-based protectants o ibang fungicide na aprubado ng technician sa tamang early-growth timing.',
      AppText.cebuano:
          'Gamit ug labeled citrus fungicides sama sa copper-based protectants o uban pang fungicide nga approved sa technician sa sakto nga early-growth timing.',
    },
    'Prune infected shoots, remove badly affected fruit, improve airflow, avoid overhead watering, and use organic-approved copper only if allowed and needed.':
        {
      AppText.tagalog:
          'Putulin ang infected shoots, alisin ang malubhang apektadong bunga, pagandahin ang airflow, iwasan ang overhead watering, at gumamit ng organic-approved copper kung pinapayagan at kailangan.',
      AppText.cebuano:
          'Putla ang infected shoots, tangtanga ang grabe nga apektadong bunga, ayuha ang airflow, likayi ang overhead watering, ug gamit ug organic-approved copper kung tugot ug kinahanglan.',
    },
    'Inspect spring flush and young fruit, reduce leaf wetness, sanitize pruning tools, and remove carryover infected material.':
        {
      AppText.tagalog:
          'Suriin ang bagong tubo at batang bunga, bawasan ang pagkabasa ng dahon, linisin ang pruning tools, at alisin ang natirang infected material.',
      AppText.cebuano:
          'Susiha ang bag-ong tubo ug batan-ong bunga, pamenosi ang kabasa sa dahon, limpyohi ang pruning tools, ug tangtanga ang nahabilin nga infected material.',
    },
    'Remove infected plant material, improve airflow, and consult a technician before applying any approved treatment.':
        {
      AppText.tagalog:
          'Alisin ang infected na bahagi ng halaman, pagandahin ang airflow, at kumonsulta muna sa technician bago gumamit ng aprubadong treatment.',
      AppText.cebuano:
          'Tangtanga ang infected nga bahin sa tanom, ayuha ang airflow, ug konsultaha una ang technician bago mogamit ug approved treatment.',
    },
    'Use labeled copper fungicide or other locally approved citrus fungicide preventively when brown spot is confirmed. Rotate products as advised to reduce resistance risk.':
        {
      AppText.tagalog:
          'Gumamit ng labeled copper fungicide o ibang locally approved citrus fungicide bilang pag-iwas kapag kumpirmado ang brown spot. Magpalit-palit ng produkto ayon sa payo para mabawasan ang resistance risk.',
      AppText.cebuano:
          'Gamit ug labeled copper fungicide o uban pang locally approved citrus fungicide isip prevention kung kumpirmado ang brown spot. Ilisi-ilisi ang produkto sumala sa tambag aron maminusan ang resistance risk.',
    },
    'Remove infected leaves and twigs, prune dense canopy, improve drainage and airflow, avoid overhead watering, and avoid excessive nitrogen that causes tender flush.':
        {
      AppText.tagalog:
          'Alisin ang infected na dahon at maliliit na sanga, putulin ang siksik na canopy, ayusin ang drainage at airflow, iwasan ang overhead watering, at iwasan ang sobrang nitrogen.',
      AppText.cebuano:
          'Tangtanga ang infected nga dahon ug gagmay nga sanga, putla ang dense canopy, ayuha ang drainage ug airflow, likayi ang overhead watering, ug likayi ang sobra nga nitrogen.',
    },
    'Monitor new flush and young fruit, reduce long leaf-wetness periods, and remove diseased debris from the farm.':
        {
      AppText.tagalog:
          'Bantayan ang bagong tubo at batang bunga, bawasan ang matagal na pagkabasa ng dahon, at alisin ang diseased debris sa taniman.',
      AppText.cebuano:
          'Bantayi ang bag-ong tubo ug batan-ong bunga, pamenosi ang dugay nga kabasa sa dahon, ug tangtanga ang diseased debris sa uma.',
    },
    'Check for honeydew insects such as scale, aphids, mealybugs, or whiteflies, then control the insects causing the mold.':
        {
      AppText.tagalog:
          'Suriin kung may peste na gumagawa ng honeydew tulad ng scale, aphids, mealybugs, o whiteflies, pagkatapos kontrolin ang pesteng sanhi ng amag.',
      AppText.cebuano:
          'Susiha kung naay peste nga naghimo ug honeydew sama sa scale, aphids, mealybugs, o whiteflies, unya kontrola ang peste nga hinungdan sa amag.',
    },
    'Wash or wipe heavy black coating from leaves and fruit where practical, prune crowded branches for airflow, control ants, and use insecticidal soap or horticultural oil only when allowed and advised.':
        {
      AppText.tagalog:
          'Hugasan o punasan ang makapal na itim na patong sa dahon at bunga kung kaya, putulin ang siksik na sanga para sa hangin, kontrolin ang langgam, at gumamit lamang ng insecticidal soap o horticultural oil kung pinapayagan at ipinayo.',
      AppText.cebuano:
          'Hugasi o pahiri ang baga nga itom nga patong sa dahon ug bunga kung mahimo, putla ang dasok nga sanga para sa airflow, kontrola ang hulmigas, ug gamit lang ug insecticidal soap o horticultural oil kung tugot ug gitambagan.',
    },
    'Inspect the underside of leaves and young shoots weekly for sap-sucking insects, manage ants that protect them, and keep the canopy open so pests are easier to see.':
        {
      AppText.tagalog:
          'Suriin linggo-linggo ang ilalim ng dahon at bagong tubo para sa pesteng sumisipsip ng dagta, kontrolin ang langgam na nagpoprotekta sa peste, at panatilihing bukas ang canopy para madaling makita ang peste.',
      AppText.cebuano:
          'Susiha kada semana ang ilalom sa dahon ug bag-ong tubo para sa pesteng mosuyop ug duga, kontrola ang hulmigas nga nagpanalipod sa peste, ug panatilihing bukas ang canopy aron dali makita ang peste.',
    },
    'Take another clear leaf photo and ask an agriculture technician to inspect the tree if symptoms spread.':
        {
      AppText.tagalog:
          'Kumuha ng panibagong malinaw na larawan ng dahon at magpasuri sa agriculture technician kung kumalat ang sintomas.',
      AppText.cebuano:
          'Kuha ug laing klarong hulagway sa dahon ug magpasusi sa agriculture technician kung mokaylap ang sintomas.',
    },
    'Do not apply pesticide until the disease is confirmed. Wrong treatment can waste money and harm the tree.':
        {
      AppText.tagalog:
          'Huwag gumamit ng pesticide hanggang hindi kumpirmado ang sakit. Ang maling treatment ay sayang sa pera at maaaring makasama sa puno.',
      AppText.cebuano:
          'Ayaw paggamit ug pesticide hangtod dili kumpirmado ang sakit. Ang sayop nga treatment makausik sa kwarta ug makadaot sa kahoy.',
    },
    'Retake a clear photo, isolate suspicious plant material, remove fallen debris, and keep the tree watered and nourished while waiting for confirmation.':
        {
      AppText.tagalog:
          'Ulitin ang malinaw na larawan, ihiwalay ang kahina-hinalang bahagi, alisin ang nalaglag na debris, at panatilihing nadidiligan at may nutrisyon ang puno habang naghihintay ng kumpirmasyon.',
      AppText.cebuano:
          'Balika ug kuha ang klarong hulagway, ilain ang kahina-hinalang bahin, tangtanga ang nahulog nga debris, ug panatilihing nadidiligan ug naay nutrisyon ang kahoy samtang naghuwat ug kumpirmasyon.',
    },
  };
}

class PriorityCard extends StatelessWidget {
  const PriorityCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CcColors.orange.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CcColors.orange.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.priority_high_rounded, color: CcColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(message),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideTile extends StatelessWidget {
  const GuideTile({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        title: title,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: CcColors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TreatmentBody(
                text: text,
                showChemicalReminder: title == 'Chemical Options',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TreatmentRecommendationCard extends StatelessWidget {
  const TreatmentRecommendationCard({super.key, required this.guidance});

  final DiseaseGuidance guidance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CcColors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Treatment recommendation'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: CcColors.red,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(guidance.kind),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              height: 1.35,
              color: CcColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          TreatmentMethodBlock(
            icon: Icons.science_outlined,
            title: 'Chemical Options',
            text: guidance.conventionalTreatment,
            color: CcColors.red,
          ),
          const SizedBox(height: 8),
          TreatmentMethodBlock(
            icon: Icons.spa_outlined,
            title: 'Cultural / Nonchemical Methods',
            text: guidance.organicTreatment,
            color: CcColors.green,
          ),
        ],
      ),
    );
  }
}

class TreatmentMethodBlock extends StatelessWidget {
  const TreatmentMethodBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                TreatmentBody(
                  text: text,
                  showChemicalReminder: title == 'Chemical Options',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TreatmentBody extends StatelessWidget {
  const TreatmentBody({
    super.key,
    required this.text,
    required this.showChemicalReminder,
  });

  final String text;
  final bool showChemicalReminder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(text),
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: CcColors.ink,
          ),
        ),
        if (showChemicalReminder) ...[
          const SizedBox(height: 12),
          Text(
            context.t(chemicalTreatmentReminder.english),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: CcColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CcColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: CcColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(text),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the diagnosis screen when confidence lands in the 50-70% band:
/// the prediction is still displayed, but flagged so the farmer knows to
/// double check it rather than treating it as certain.
class LowConfidenceNotice extends StatelessWidget {
  const LowConfidenceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CcColors.orange.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CcColors.orange.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: CcColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(lowConfidenceWarningMessage),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RetakePhotoNoticeCard extends StatelessWidget {
  const RetakePhotoNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CcColors.orangeSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CcColors.orange.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.photo_camera_back_outlined,
            color: CcColors.orange,
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            context.t('Please kindly take/provide another photo'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CcColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t(
              'To improve accuracy, make sure the photo shows only a calamansi fruit or leaf against a plain background. Avoid other objects, patterned surfaces, shadows, or clutter that can confuse the AI.',
            ),
            style: const TextStyle(
              color: CcColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.disease,
    required this.status,
    required this.date,
    required this.confidence,
    this.imageUrl,
    this.selected = false,
    this.onTap,
    this.onRetry,
  });

  final String disease;
  final String status;
  final String date;
  final String confidence;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;
  final Future<void> Function()? onRetry;

  Color _statusColor() {
    return switch (status) {
      'Sent' => CcColors.green,
      'Open' => CcColors.green,
      'Needs review' => CcColors.orange,
      'High priority' => CcColors.red,
      'Low risk' => CcColors.green,
      'Medium risk' => CcColors.orange,
      'High risk' => CcColors.red,
      'Saved on phone' => CcColors.muted,
      'Could not send. Tap to try again' => CcColors.red,
      'Waiting for internet' => CcColors.orange,
      'Sending...' => CcColors.orange,
      'Sent to barangay' => CcColors.green,
      _ => CcColors.muted,
    };
  }

  Color _statusBackground() {
    return switch (status) {
      'Sent' => CcColors.soft,
      'Open' => CcColors.soft,
      'Needs review' => CcColors.orangeSoft,
      'High priority' => CcColors.red.withValues(alpha: .1),
      'Low risk' => CcColors.soft,
      'Medium risk' => CcColors.orangeSoft,
      'High risk' => CcColors.red.withValues(alpha: .1),
      'Saved on phone' => CcColors.softStrong,
      'Could not send. Tap to try again' => CcColors.red.withValues(alpha: .08),
      'Waiting for internet' => CcColors.orangeSoft,
      'Sending...' => CcColors.orangeSoft,
      'Sent to barangay' => CcColors.soft,
      _ => CcColors.softStrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusBackground = _statusBackground();
    final selectedBorderColor =
        selected && status == 'High risk' ? CcColors.red : CcColors.green;
    final selectedBackground = selected && status == 'High risk'
        ? CcColors.red.withValues(alpha: .06)
        : CcColors.soft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: selected ? selectedBackground : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? selectedBorderColor : CcColors.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: imageUrl == null || imageUrl!.trim().isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: CcColors.soft,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              context.t(disease).characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: CcColors.orange,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              alignment: Alignment.center,
                              color: CcColors.soft,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: CcColors.muted,
                                size: 22,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(disease),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: CcColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CcColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (confidence.isNotEmpty)
                            Text(
                              confidence,
                              style: const TextStyle(
                                fontSize: 11,
                                color: CcColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBackground,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              context.t(status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (onRetry != null)
                            TextButton.icon(
                              onPressed: () => onRetry!(),
                              icon: const Icon(Icons.sync_rounded, size: 14),
                              label: Text(context.t('Retry')),
                              style: TextButton.styleFrom(
                                foregroundColor: CcColors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: CcColors.muted,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String action;
  final VoidCallback? onTap;

  IconData get actionIcon {
    return switch (action) {
      'Change' => Icons.swap_horiz_rounded,
      'Update' => Icons.system_update_alt_rounded,
      _ => Icons.edit_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CcColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: CcColors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(title),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: CcColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t(value),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CcColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: context.t(action),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: CcColors.soft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      actionIcon,
                      color: CcColors.green,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FontScaleControl extends StatelessWidget {
  const FontScaleControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'A',
          style: TextStyle(
            color: CcColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: CcColors.green,
              inactiveTrackColor: CcColors.softStrong,
              thumbColor: CcColors.green,
              overlayColor: CcColors.green.withValues(alpha: .12),
              trackHeight: 3,
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1),
              activeTickMarkColor: Colors.white.withValues(alpha: .72),
              inactiveTickMarkColor: CcColors.muted.withValues(alpha: .28),
            ),
            child: Slider(
              value: value,
              min: .9,
              max: 1.3,
              divisions: 8,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'A',
          style: TextStyle(
            color: CcColors.muted,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              context.t(label),
              style: const TextStyle(
                color: CcColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.t(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: CcColors.ink,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class RiskOverviewRow extends StatelessWidget {
  const RiskOverviewRow({
    super.key,
    required this.lowRiskCount,
    required this.mediumRiskCount,
    required this.highRiskCount,
  });

  final int lowRiskCount;
  final int mediumRiskCount;
  final int highRiskCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              context.t('Status'),
              style: const TextStyle(
                color: CcColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RiskCountLine(
                  count: lowRiskCount,
                  label: 'Low risk',
                  color: CcColors.green,
                ),
                const SizedBox(height: 4),
                RiskCountLine(
                  count: mediumRiskCount,
                  label: 'Medium risk',
                  color: CcColors.orange,
                ),
                const SizedBox(height: 4),
                RiskCountLine(
                  count: highRiskCount,
                  label: 'High risk',
                  color: CcColors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RiskCountLine extends StatelessWidget {
  const RiskCountLine({
    super.key,
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${context.t(label)}',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: color,
      ),
      softWrap: true,
    );
  }
}

class PlantIllustration extends StatelessWidget {
  const PlantIllustration({super.key, required this.size, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .78,
            height: size * .78,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: .1) : CcColors.soft,
              shape: BoxShape.circle,
            ),
          ),
          Transform.rotate(
            angle: -.55,
            child: Container(
              width: size * .3,
              height: size * .62,
              decoration: BoxDecoration(
                color: CcColors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size),
                  bottomRight: Radius.circular(size),
                  topRight: Radius.circular(size * .25),
                  bottomLeft: Radius.circular(size * .25),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: .55,
            child: Container(
              width: size * .26,
              height: size * .54,
              decoration: BoxDecoration(
                color: CcColors.lime,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(size),
                  bottomLeft: Radius.circular(size),
                  topLeft: Radius.circular(size * .25),
                  bottomRight: Radius.circular(size * .25),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size * .2,
            child: Container(
              width: size * .2,
              height: size * .2,
              decoration: const BoxDecoration(
                color: CcColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroLeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final leaf = Paint()..color = CcColors.green.withValues(alpha: .7);
    final lime = Paint()..color = CcColors.lime.withValues(alpha: .75);
    final orange = Paint()..color = CcColors.orange.withValues(alpha: .9);

    void oval(
      double x,
      double y,
      double w,
      double h,
      double angle,
      Paint paint,
    ) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(w),
        ),
        paint,
      );
      canvas.restore();
    }

    oval(size.width * .78, size.height * .24, 92, 220, .75, leaf);
    oval(size.width * .55, size.height * .38, 74, 170, -.7, lime);
    oval(size.width * .2, size.height * .18, 68, 150, .7, leaf);
    canvas.drawCircle(Offset(size.width * .8, size.height * .58), 36, orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void showLanguageSheet(BuildContext context) {
  final state = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Choose language'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final language in supportedLanguages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  state.language == language
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: CcColors.green,
                ),
                title: Text(language),
                onTap: () async {
                  await state.setLanguage(language);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      );
    },
  );
}

void showEmailDialog(BuildContext context) {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: state.officeEmail);
  showDialog<void>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text(context.t('Barangay email')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: context.t('Email address')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await state.setEmail(controller.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text(context.t('Save')),
          ),
        ],
      );
    },
  );
}

void showNameDialog(BuildContext context) {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: state.farmerName);
  showDialog<void>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text(context.t('Name')),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.t('Farmer name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                await state.setFarmerName(value);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text(context.t('Save')),
          ),
        ],
      );
    },
  );
}

void showLocationSheet(BuildContext context) {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: state.farmerLocation);
  var query = controller.text;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CcColors.bgAlt,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final matches = locationSuggestions
              .where(
                (location) =>
                    query.trim().isEmpty ||
                    location.toLowerCase().contains(query.toLowerCase()),
              )
              .take(5)
              .toList();

          Future<void> usePhoneLocation() async {
            final message = await state.usePhoneLocation();
            controller.text = state.farmerLocation;
            query = controller.text;
            setSheetState(() {});
            if (message != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t(message))),
              );
            }
          }

          final mediaQuery = MediaQuery.of(context);
          return SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 20),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t('Location'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: context.t('Close'),
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: context.t('Farm location'),
                          prefixIcon: const Icon(Icons.place_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CcColors.soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CcColors.line),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: CcColors.green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.t(
                                  'Manual location is better for farm tracking. Type the farm area, purok, or barangay clearly.',
                                ),
                                style: const TextStyle(
                                  color: CcColors.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final suggestion in matches)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width - 72,
                              ),
                              child: ActionChip(
                                label: Text(
                                  suggestion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  controller.text = suggestion;
                                  setSheetState(() => query = suggestion);
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlineAction(
                        label: state.isDetectingLocation
                            ? 'Checking phone location...'
                            : 'Use phone location',
                        icon: Icons.my_location_rounded,
                        onTap: state.isDetectingLocation
                            ? () {}
                            : usePhoneLocation,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t(state.locationNote),
                        style: const TextStyle(
                          color: CcColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Save location',
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          final value = controller.text.trim();
                          if (value.isNotEmpty) {
                            await state.setFarmerLocation(value);
                          }
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void go(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

void replaceWith(BuildContext context, Widget screen) {
  Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
}
