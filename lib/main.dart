import 'package:flutter/material.dart';

void main() => runApp(const CalamansiCareApp());

const supportedLanguages = ['English', 'Tagalog', 'Cebuano'];

const diseaseLabels = [
  'Healthy',
  'HLB / Greening',
  'Citrus Canker',
  'Anthracnose',
  'Sooty Mold',
  'Citrus Scab',
  'Brown Rot',
  'Nutrient Deficiency',
];

class CcColors {
  static const bg = Color(0xFFF8FAF2);
  static const card = Color(0xFFFFFFFF);
  static const green = Color(0xFF1F6F3D);
  static const dark = Color(0xFF0F2E1B);
  static const soft = Color(0xFFEAF5DC);
  static const lime = Color(0xFFBCE45E);
  static const orange = Color(0xFFE9962E);
  static const blue = Color(0xFF2366A8);
  static const red = Color(0xFFB74738);
  static const ink = Color(0xFF1F2A24);
  static const muted = Color(0xFF69756D);
  static const line = Color(0xFFE1E8DA);
}

class AppText {
  static const english = 'English';
  static const tagalog = 'Tagalog';
  static const cebuano = 'Cebuano';

  static const Map<String, Map<String, String>> values = {
    'Protect your\ncalamansi trees': {
      tagalog: 'Protektahan ang\ninyong calamansi',
      cebuano: 'Panalipdi ang\ninyong calamansi',
    },
    'Offline AI disease checking, treatment guidance, and barangay report preparation.': {
      tagalog:
          'Offline AI na pagsusuri ng sakit, gabay sa paggamot, at paghahanda ng ulat sa barangay.',
      cebuano:
          'Offline AI nga pagsusi sa sakit, giya sa pagtambal, ug pag-andam sa report sa barangay.',
    },
    'Choose language': {
      tagalog: 'Pumili ng wika',
      cebuano: 'Pili ug pinulongan',
    },
    'Start plant check': {
      tagalog: 'Simulan ang pagsusuri',
      cebuano: 'Sugdi ang pagsusi',
    },
    'Home': {tagalog: 'Home', cebuano: 'Home'},
    'History': {tagalog: 'Kasaysayan', cebuano: 'Kasaysayan'},
    'Settings': {tagalog: 'Settings', cebuano: 'Settings'},
    'Good morning': {tagalog: 'Magandang umaga', cebuano: 'Maayong buntag'},
    'Good afternoon': {tagalog: 'Magandang hapon', cebuano: 'Maayong hapon'},
    'Good evening': {tagalog: 'Magandang gabi', cebuano: 'Maayong gabii'},
    'Ready to check your calamansi leaves?': {
      tagalog: 'Handa na bang suriin ang inyong dahon ng calamansi?',
      cebuano: 'Andam na ba sa pagsusi sa inyong dahon sa calamansi?',
    },
    'Offline ready': {tagalog: 'Handa offline', cebuano: 'Andam offline'},
    'New disease check': {
      tagalog: 'Bagong pagsusuri',
      cebuano: 'Bag-ong pagsusi',
    },
    'Capture a clear leaf photo or upload from gallery.': {
      tagalog:
          'Kumuha ng malinaw na larawan ng dahon o pumili mula sa gallery.',
      cebuano: 'Kuhaa ang klarong litrato sa dahon o pagpili gikan sa gallery.',
    },
    'Capture': {tagalog: 'Kuhanan', cebuano: 'Kuhaa'},
    'Upload': {tagalog: 'Mag-upload', cebuano: 'Upload'},
    'Queued reports': {
      tagalog: 'Nakapilang ulat',
      cebuano: 'Nakapilang report',
    },
    'Last confidence': {
      tagalog: 'Huling confidence',
      cebuano: 'Katapusang confidence',
    },
    'Supported conditions': {
      tagalog: 'Mga sakit na kayang suriin',
      cebuano: 'Mga sakit nga masuportahan',
    },
    'Barangay reporting': {
      tagalog: 'Pag-uulat sa barangay',
      cebuano: 'Pag-report sa barangay',
    },
    'Review field alerts and prepared reports for the agriculture office.': {
      tagalog:
          'Tingnan ang field alerts at mga inihandang ulat para sa agriculture office.',
      cebuano:
          'Tan-awa ang field alerts ug andam nga reports para sa agriculture office.',
    },
    'Open barangay reports': {
      tagalog: 'Buksan ang ulat ng barangay',
      cebuano: 'Ablihi ang barangay reports',
    },
    'Capture image': {
      tagalog: 'Kumuha ng larawan',
      cebuano: 'Kuhaa ang hulagway',
    },
    'Place one affected leaf inside the guide': {
      tagalog: 'Ilagay ang isang apektadong dahon sa loob ng gabay',
      cebuano: 'Ibutang ang usa ka apektadong dahon sulod sa giya',
    },
    'Choose from gallery': {
      tagalog: 'Pumili sa gallery',
      cebuano: 'Pili gikan sa gallery',
    },
    'Checking image': {
      tagalog: 'Sinusuri ang larawan',
      cebuano: 'Gisusi ang hulagway',
    },
    'Offline model is analyzing leaf features.': {
      tagalog: 'Sinusuri ng offline model ang mga palatandaan sa dahon.',
      cebuano: 'Gisusi sa offline model ang mga timailhan sa dahon.',
    },
    'Gallery image loaded': {
      tagalog: 'Larawan mula sa gallery',
      cebuano: 'Hulagway gikan sa gallery',
    },
    'Captured image ready': {
      tagalog: 'Handa na ang nakuhang larawan',
      cebuano: 'Andam na ang nakuha nga hulagway',
    },
    'Finding disease pattern, confidence, and next action.': {
      tagalog:
          'Hinahanap ang pattern ng sakit, confidence, at susunod na hakbang.',
      cebuano:
          'Gipangita ang pattern sa sakit, confidence, ug sunod nga lakang.',
    },
    'Diagnosis result': {
      tagalog: 'Resulta ng pagsusuri',
      cebuano: 'Resulta sa pagsusi',
    },
    'Review before preparing the report.': {
      tagalog: 'Suriin muna bago ihanda ang ulat.',
      cebuano: 'Tan-awa una bago ihanda ang report.',
    },
    'Likely disease': {tagalog: 'Posibleng sakit', cebuano: 'Posibleng sakit'},
    'Warning signs': {tagalog: 'Mga babala', cebuano: 'Mga timailhan'},
    'Blotchy yellow leaves': {
      tagalog: 'Hindi pantay na paninilaw ng dahon',
      cebuano: 'Dili patas nga pag-yellow sa dahon',
    },
    'Uneven fruit color': {
      tagalog: 'Hindi pantay na kulay ng bunga',
      cebuano: 'Dili patas nga kolor sa bunga',
    },
    'Possible tree decline': {
      tagalog: 'Posibleng paghina ng puno',
      cebuano: 'Posibleng paghuyang sa kahoy',
    },
    'Ask a technician to confirm if symptoms spread. This app supports decisions, but does not replace field inspection.': {
      tagalog:
          'Magpatingin sa technician kung kumalat ang sintomas. Gabay lamang ang app at hindi kapalit ng field inspection.',
      cebuano:
          'Pangayo ug kumpirmasyon sa technician kung mokaylap ang sintomas. Giya lang ang app ug dili kapuli sa field inspection.',
    },
    'View treatment guide': {
      tagalog: 'Tingnan ang gabay sa paggamot',
      cebuano: 'Tan-awa ang giya sa pagtambal',
    },
    'Treatment guide': {
      tagalog: 'Gabay sa paggamot',
      cebuano: 'Giya sa pagtambal',
    },
    'Prioritize containment and expert confirmation.': {
      tagalog: 'Unahin ang pagpigil sa pagkalat at kumpirmasyon ng eksperto.',
      cebuano: 'Unaha ang pagpugong sa paglapad ug kumpirmasyon sa eksperto.',
    },
    'Priority: High. Isolate suspicious trees and request field confirmation.': {
      tagalog:
          'Prayoridad: Mataas. Ihiwalay ang kahina-hinalang puno at humingi ng field confirmation.',
      cebuano:
          'Prayoridad: Taas. Ilain ang kahina-hinalang kahoy ug pangayo ug field confirmation.',
    },
    'Cultural': {tagalog: 'Kultural', cebuano: 'Kultural'},
    'Organic': {tagalog: 'Organiko', cebuano: 'Organiko'},
    'Chemical': {tagalog: 'Kemikal', cebuano: 'Kemikal'},
    'Prevention': {tagalog: 'Pag-iwas', cebuano: 'Paglikay'},
    'Remove severely affected branches and avoid moving infected plant material.': {
      tagalog:
          'Tanggalin ang malubhang apektadong sanga at iwasang ilipat ang infected na bahagi ng halaman.',
      cebuano:
          'Tangtanga ang grabe nga apektadong sanga ug likayi ang pagbalhin sa infected nga bahin sa tanom.',
    },
    'Keep trees healthy with proper watering, sanitation, and nutrient balance.': {
      tagalog:
          'Panatilihing malusog ang puno sa tamang dilig, kalinisan, at balanseng nutrisyon.',
      cebuano:
          'Padayon nga himsog ang kahoy pinaagi sa sakto nga pagbisbis, kalimpyo, ug balanse nga nutrisyon.',
    },
    'Coordinate with an agriculture technician before chemical use.': {
      tagalog:
          'Makipag-ugnayan muna sa agriculture technician bago gumamit ng kemikal.',
      cebuano:
          'Makig-coordinate usa sa agriculture technician bago mogamit ug kemikal.',
    },
    'Monitor nearby trees weekly and disinfect tools after pruning.': {
      tagalog:
          'Suriin linggo-linggo ang kalapit na puno at i-disinfect ang gamit pagkatapos mag-prune.',
      cebuano:
          'Bantayi kada semana ang duol nga kahoy ug i-disinfect ang gamit human mag-prune.',
    },
    'Prepare report': {
      tagalog: 'Ihanda ang ulat',
      cebuano: 'Ihanda ang report',
    },
    'Report preview': {
      tagalog: 'Preview ng ulat',
      cebuano: 'Preview sa report',
    },
    'Prepared for barangay agriculture review.': {
      tagalog: 'Inihanda para sa pagsusuri ng barangay agriculture.',
      cebuano: 'Andam para sa pagsusi sa barangay agriculture.',
    },
    'Email': {tagalog: 'Email', cebuano: 'Email'},
    'Disease': {tagalog: 'Sakit', cebuano: 'Sakit'},
    'Confidence': {tagalog: 'Confidence', cebuano: 'Confidence'},
    'Language': {tagalog: 'Wika', cebuano: 'Pinulongan'},
    'Consent': {tagalog: 'Pahintulot', cebuano: 'Pagtugot'},
    'Allow sending diagnosis details': {
      tagalog: 'Payagan ang pagpapadala ng detalye ng pagsusuri',
      cebuano: 'Tugoti ang pagpadala sa detalye sa pagsusi',
    },
    'Required before report can be emailed through Supabase.': {
      tagalog: 'Kailangan bago ma-email ang ulat gamit ang Supabase.',
      cebuano: 'Kinahanglan bago ma-email ang report gamit ang Supabase.',
    },
    'Queue report offline': {
      tagalog: 'Ipila ang ulat offline',
      cebuano: 'Ipila ang report offline',
    },
    'Offline queue': {tagalog: 'Offline na pila', cebuano: 'Offline nga pila'},
    'Reports wait here until internet is available.': {
      tagalog: 'Dito naghihintay ang mga ulat hanggang may internet.',
      cebuano: 'Dinhi maghulat ang reports hangtod naay internet.',
    },
    'Waiting': {tagalog: 'Naghihintay', cebuano: 'Naghulat'},
    'Sent': {tagalog: 'Naipadala', cebuano: 'Napadala'},
    'HLB / Greening report': {
      tagalog: 'Ulat ng HLB / Greening',
      cebuano: 'Report sa HLB / Greening',
    },
    'Status': {tagalog: 'Status', cebuano: 'Status'},
    'Queued offline': {
      tagalog: 'Nakapila offline',
      cebuano: 'Nakapila offline',
    },
    'Sent to barangay': {
      tagalog: 'Naipadala sa barangay',
      cebuano: 'Napadala sa barangay',
    },
    'Saved database': {
      tagalog: 'Naka-save na database',
      cebuano: 'Na-save nga database',
    },
    'SQLite local history': {
      tagalog: 'Lokal na history ng SQLite',
      cebuano: 'Lokal nga history sa SQLite',
    },
    'Target email': {tagalog: 'Target na email', cebuano: 'Target email'},
    'Automatic sending will use Supabase when the phone reconnects to internet.': {
      tagalog:
          'Gagamit ng Supabase ang automatic sending kapag bumalik ang internet.',
      cebuano:
          'Mogamit ug Supabase ang automatic sending kung mobalik ang internet.',
    },
    'Try sending now': {
      tagalog: 'Subukang ipadala ngayon',
      cebuano: 'Sulayi ug padala karon',
    },
    'Report marked as sent for UI demo.': {
      tagalog: 'Namarkahan na naipadala ang ulat para sa UI demo.',
      cebuano: 'Namarkahan nga napadala ang report para sa UI demo.',
    },
    'Back to home': {tagalog: 'Bumalik sa home', cebuano: 'Balik sa home'},
    'Saved scans and report status from SQLite.': {
      tagalog: 'Mga na-save na scan at status ng ulat mula sa SQLite.',
      cebuano: 'Mga na-save nga scan ug status sa report gikan sa SQLite.',
    },
    'Queued': {tagalog: 'Nakapila', cebuano: 'Nakapila'},
    'Healthy': {tagalog: 'Malusog', cebuano: 'Himsog'},
    'Not reported': {tagalog: 'Hindi naiulat', cebuano: 'Wala gi-report'},
    'Date': {tagalog: 'Petsa', cebuano: 'Petsa'},
    'Report status': {tagalog: 'Status ng ulat', cebuano: 'Status sa report'},
    'Language, office email, model, and reporting consent.': {
      tagalog: 'Wika, email ng opisina, model, at pahintulot sa ulat.',
      cebuano: 'Pinulongan, email sa opisina, model, ug pagtugot sa report.',
    },
    'Change': {tagalog: 'Palitan', cebuano: 'Ilisi'},
    'Barangay email': {
      tagalog: 'Email ng barangay',
      cebuano: 'Email sa barangay',
    },
    'Edit': {tagalog: 'I-edit', cebuano: 'Usba'},
    'Offline model': {tagalog: 'Offline model', cebuano: 'Offline model'},
    'Calamansi disease model v1': {
      tagalog: 'Calamansi disease model v1',
      cebuano: 'Calamansi disease model v1',
    },
    'Update': {tagalog: 'I-update', cebuano: 'Update'},
    'Report consent': {
      tagalog: 'Pahintulot sa ulat',
      cebuano: 'Pagtugot sa report',
    },
    'Allow report preparation': {
      tagalog: 'Payagan ang paghahanda ng ulat',
      cebuano: 'Tugoti ang pag-andam sa report',
    },
    'Can be turned off anytime before sending.': {
      tagalog: 'Puwedeng patayin bago ipadala.',
      cebuano: 'Pwede mapalong bago ipadala.',
    },
    'Barangay reports': {
      tagalog: 'Mga ulat ng barangay',
      cebuano: 'Mga report sa barangay',
    },
    'Community reports': {
      tagalog: 'Mga ulat ng komunidad',
      cebuano: 'Mga report sa komunidad',
    },
    'Disease alerts prepared for local agriculture office.': {
      tagalog:
          'Mga disease alert na inihanda para sa lokal na agriculture office.',
      cebuano:
          'Mga disease alert nga giandam para sa lokal nga agriculture office.',
    },
    'Reports submitted by other farmers using CalamansiCare.': {
      tagalog:
          'Mga ulat na ipinasa ng ibang magsasaka gamit ang CalamansiCare.',
      cebuano:
          'Mga report nga gipasa sa ubang mag-uuma gamit ang CalamansiCare.',
    },
    '3 disease alerts near Purok 4': {
      tagalog: '3 disease alert malapit sa Purok 4',
      cebuano: '3 disease alert duol sa Purok 4',
    },
    '3 reports from nearby users': {
      tagalog: '3 ulat mula sa kalapit na users',
      cebuano: '3 report gikan sa duol nga users',
    },
    'Prioritize HLB / Greening reports for field checking.': {
      tagalog: 'Unahin ang HLB / Greening reports para sa field checking.',
      cebuano: 'Unaha ang HLB / Greening reports para sa field checking.',
    },
    'Review shared HLB / Greening reports for field validation.': {
      tagalog:
          'Suriin ang shared HLB / Greening reports para sa field validation.',
      cebuano:
          'Tan-awa ang shared HLB / Greening reports para sa field validation.',
    },
    'Shared reports': {tagalog: 'Shared na ulat', cebuano: 'Shared reports'},
    'Needs review': {
      tagalog: 'Kailangang suriin',
      cebuano: 'Kinahanglan susihon',
    },
    'Community overview': {
      tagalog: 'Kabuuang tingin sa komunidad',
      cebuano: 'Kinatibuk-ang tan-aw sa komunidad',
    },
    'Reports source': {
      tagalog: 'Pinagmulan ng ulat',
      cebuano: 'Gigikanan sa report',
    },
    'Other app users': {tagalog: 'Ibang app users', cebuano: 'Ubang app users'},
    'Review selected report': {
      tagalog: 'Suriin ang napiling ulat',
      cebuano: 'Susihon ang napiling report',
    },
    'High priority': {
      tagalog: 'Mataas na prayoridad',
      cebuano: 'Taas nga prayoridad',
    },
    'Open': {tagalog: 'Bukas', cebuano: 'Abli'},
    'Open selected report': {
      tagalog: 'Buksan ang napiling ulat',
      cebuano: 'Ablihi ang napiling report',
    },
    'Email address': {tagalog: 'Email address', cebuano: 'Email address'},
    'Cancel': {tagalog: 'Kanselahin', cebuano: 'Kanselahon'},
    'Save': {tagalog: 'I-save', cebuano: 'I-save'},
  };

  static String of(String language, String text) {
    if (language == english) return text;
    return values[text]?[language] ?? text;
  }
}

extension AppTextLookup on BuildContext {
  String t(String text) => AppText.of(AppScope.of(this).language, text);
}

String timeGreetingKey([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class AppState extends ChangeNotifier {
  String language = 'English';
  int tabIndex = 0;
  bool consentEnabled = true;
  bool reportQueued = true;
  String officeEmail = 'agri.office@barangay.gov.ph';

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void setTab(int value) {
    tabIndex = value;
    notifyListeners();
  }

  void setConsent(bool value) {
    consentEnabled = value;
    notifyListeners();
  }

  void setEmail(String value) {
    officeEmail = value;
    notifyListeners();
  }

  void markSent() {
    reportQueued = false;
    notifyListeners();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.state, required super.child});

  final AppState state;

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => true;
}

class CalamansiCareApp extends StatefulWidget {
  const CalamansiCareApp({super.key});

  @override
  State<CalamansiCareApp> createState() => _CalamansiCareAppState();
}

class _CalamansiCareAppState extends State<CalamansiCareApp> {
  final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AppScope(
          state: state,
          child: MaterialApp(
            title: 'CalamansiCare',
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: false,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: mediaQuery.textScaler.clamp(
                    minScaleFactor: 1,
                    maxScaleFactor: 1.15,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: CcColors.bg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: CcColors.green,
                primary: CcColors.green,
                secondary: CcColors.orange,
                surface: CcColors.card,
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: CcColors.dark,
                ),
                headlineMedium: TextStyle(
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: CcColors.dark,
                ),
                titleLarge: TextStyle(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: CcColors.ink,
                ),
                titleMedium: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CcColors.ink,
                ),
                bodyLarge: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: CcColors.ink,
                ),
                bodyMedium: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: CcColors.muted,
                ),
              ),
            ),
            home: const WelcomeScreen(),
          ),
        );
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: CcColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: HeroLeafPainter()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BrandMark(onDark: true),
                        const Spacer(),
                        Text(
                          context.t('Protect your\ncalamansi trees'),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(color: Colors.white, fontSize: 38),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.t(
                            'Offline AI disease checking, treatment guidance, and barangay report preparation.',
                          ),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: .78),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              decoration: const BoxDecoration(
                color: CcColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('Choose language'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final language in supportedLanguages)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(language),
                              selected: state.language == language,
                              onSelected: (_) => state.setLanguage(language),
                              selectedColor: CcColors.green,
                              labelStyle: TextStyle(
                                color: state.language == language
                                    ? Colors.white
                                    : CcColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: CcColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Start plant check',
                    icon: Icons.eco,
                    onPressed: () => replaceWith(context, const MainShell()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const screens = [HomeScreen(), HistoryScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(child: screens[state.tabIndex]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: state.tabIndex,
          onTap: state.setTab,
          selectedItemColor: CcColors.green,
          unselectedItemColor: CcColors.muted,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: context.t('Home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              label: context.t('History'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: context.t('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: 'Good morning',
              subtitle: 'Ready to check your calamansi leaves?',
              pill: 'Offline ready',
              trailing: IconButton.filledTonal(
                onPressed: () => showLanguageSheet(context),
                icon: const Icon(Icons.language),
              ),
            ),
            const SizedBox(height: 18),
            DarkActionCard(
              title: 'New disease check',
              subtitle: 'Capture a clear leaf photo or upload from gallery.',
              buttonLabel: 'Capture',
              secondaryLabel: 'Upload',
              onPrimary: () => go(context, const CaptureScreen()),
              onSecondary: () =>
                  go(context, const CheckingScreen(fromGallery: true)),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: StatCard(value: '3', label: 'Queued reports'),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: StatCard(value: '91%', label: 'Last confidence'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Supported conditions',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: diseaseLabels.map((item) => SmallPill(item)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Barangay reporting',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review field alerts and prepared reports for the agriculture office.',
                  ),
                  const SizedBox(height: 12),
                  OutlineAction(
                    label: 'Open barangay reports',
                    icon: Icons.map_rounded,
                    onTap: () => go(context, const BarangayReportsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DarkScreen(
      title: 'Capture image',
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
              ),
              child: Stack(
                children: [
                  const Center(child: PlantIllustration(size: 220, dark: true)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Text(
                      context.t('Place one affected leaf inside the guide'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 76,
            height: 76,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CcColors.dark,
                shape: const CircleBorder(),
              ),
              onPressed: () => go(context, const CheckingScreen()),
              child: const Icon(Icons.camera_alt_rounded, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                go(context, const CheckingScreen(fromGallery: true)),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(context.t('Choose from gallery')),
          ),
        ],
      ),
    );
  }
}

class CheckingScreen extends StatefulWidget {
  const CheckingScreen({super.key, this.fromGallery = false});

  final bool fromGallery;

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) replaceWith(context, const DiagnosisScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Checking image',
            subtitle: 'Offline model is analyzing leaf features.',
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Center(
              child: SectionCard(
                title: widget.fromGallery
                    ? 'Gallery image loaded'
                    : 'Captured image ready',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PlantIllustration(size: 210),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(99),
                      color: CcColors.green,
                      backgroundColor: CcColors.soft,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Finding disease pattern, confidence, and next action.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Diagnosis result',
            subtitle: 'Review before preparing the report.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Likely disease',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PlantIllustration(size: 96),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HLB / Greening',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          const SmallPill(
                            '91% confidence',
                            color: CcColors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const WarningBox(
                  title: 'Warning signs',
                  lines: [
                    'Blotchy yellow leaves',
                    'Uneven fruit color',
                    'Possible tree decline',
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ask a technician to confirm if symptoms spread. This app supports decisions, but does not replace field inspection.',
                ),
              ],
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'View treatment guide',
            icon: Icons.medical_services_outlined,
            onPressed: () => go(context, const TreatmentScreen()),
          ),
        ],
      ),
    );
  }
}

class TreatmentScreen extends StatelessWidget {
  const TreatmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Treatment guide',
            subtitle: 'Prioritize containment and expert confirmation.',
          ),
          const SizedBox(height: 16),
          const PriorityCard(),
          const SizedBox(height: 12),
          const Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GuideTile(
                    icon: Icons.yard_outlined,
                    title: 'Cultural',
                    text:
                        'Remove severely affected branches and avoid moving infected plant material.',
                  ),
                  GuideTile(
                    icon: Icons.spa_outlined,
                    title: 'Organic',
                    text:
                        'Keep trees healthy with proper watering, sanitation, and nutrient balance.',
                  ),
                  GuideTile(
                    icon: Icons.science_outlined,
                    title: 'Chemical',
                    text:
                        'Coordinate with an agriculture technician before chemical use.',
                  ),
                  GuideTile(
                    icon: Icons.shield_outlined,
                    title: 'Prevention',
                    text:
                        'Monitor nearby trees weekly and disinfect tools after pruning.',
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Prepare report',
            icon: Icons.description_outlined,
            onPressed: () => go(context, const ReportPreviewScreen()),
          ),
        ],
      ),
    );
  }
}

class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Report preview',
            subtitle: 'Prepared for barangay agriculture review.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barangay Agriculture Office',
            child: Column(
              children: [
                InfoRow(label: 'Email', value: state.officeEmail),
                const InfoRow(label: 'Disease', value: 'HLB / Greening'),
                const InfoRow(label: 'Confidence', value: '91%'),
                const InfoRow(
                  label: 'Language',
                  value: 'English, Tagalog, Cebuano',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Consent',
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('Allow sending diagnosis details')),
                subtitle: Text(
                  context.t(
                    'Required before report can be emailed through Supabase.',
                  ),
                ),
                value: state.consentEnabled,
                onChanged: state.setConsent,
              ),
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Queue report offline',
            icon: Icons.outbox_rounded,
            color: CcColors.orange,
            onPressed: state.consentEnabled
                ? () => go(context, const OfflineQueueScreen())
                : null,
          ),
        ],
      ),
    );
  }
}

class OfflineQueueScreen extends StatelessWidget {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Offline queue',
            subtitle: 'Reports wait here until internet is available.',
            pill: state.reportQueued ? 'Waiting' : 'Sent',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'HLB / Greening report',
            child: Column(
              children: [
                InfoRow(
                  label: 'Status',
                  value: state.reportQueued
                      ? 'Queued offline'
                      : 'Sent to barangay',
                ),
                const InfoRow(
                  label: 'Saved database',
                  value: 'SQLite local history',
                ),
                InfoRow(label: 'Target email', value: state.officeEmail),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const NoticeCard(
            text:
                'Automatic sending will use Supabase when the phone reconnects to internet.',
          ),
          const Spacer(),
          OutlineAction(
            label: 'Try sending now',
            icon: Icons.wifi_rounded,
            onTap: () {
              state.markSent();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.t('Report marked as sent for UI demo.'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Back to home',
            icon: Icons.home_rounded,
            onPressed: () => replaceWith(context, const MainShell()),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: 'History',
              subtitle: 'Saved scans and report status from SQLite.',
            ),
            SizedBox(height: 16),
            HistoryTile(
              disease: 'HLB / Greening',
              status: 'Queued',
              date: 'July 27, 2026',
              confidence: '91%',
            ),
            HistoryTile(
              disease: 'Healthy',
              status: 'Not reported',
              date: 'July 26, 2026',
              confidence: '96%',
            ),
            HistoryTile(
              disease: 'Citrus Canker',
              status: 'Sent',
              date: 'July 24, 2026',
              confidence: '88%',
            ),
          ],
        ),
      ),
    );
  }
}

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
              subtitle: 'Language, office email, model, and reporting consent.',
            ),
            const SizedBox(height: 16),
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
              value: state.officeEmail,
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
          ],
        ),
      ),
    );
  }
}

class BarangayReportsScreen extends StatelessWidget {
  const BarangayReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: 'Community reports',
              subtitle:
                  'Reports submitted by other farmers using CalamansiCare.',
              trailing: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: context.t('Back to home'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CcColors.blue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.map_rounded, color: Colors.white, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    context.t('3 reports from nearby users'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'Review shared HLB / Greening reports for field validation.',
                    ),
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _AlertMetric(
                        value: '3',
                        label: context.t('Shared reports'),
                      ),
                      const SizedBox(width: 10),
                      _AlertMetric(
                        value: '1',
                        label: context.t('Needs review'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionCard(
              title: 'Community overview',
              child: Column(
                children: [
                  InfoRow(label: 'Reports source', value: 'Other app users'),
                  InfoRow(label: 'Status', value: 'Queued offline'),
                  InfoRow(
                    label: 'Saved database',
                    value: 'SQLite local history',
                  ),
                  InfoRow(
                    label: 'Target email',
                    value: 'agri.office@barangay.gov.ph',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const HistoryTile(
              disease: 'HLB / Greening',
              status: 'High priority',
              date: 'July 27, 2026',
              confidence: '91%',
            ),
            const HistoryTile(
              disease: 'Citrus Canker',
              status: 'Open',
              date: 'July 24, 2026',
              confidence: '88%',
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Review selected report',
              icon: Icons.open_in_new_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t('Report marked as sent for UI demo.'),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertMetric extends StatelessWidget {
  const _AlertMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      child: child,
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
      backgroundColor: CcColors.dark,
      appBar: AppBar(
        backgroundColor: CcColors.dark,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(title),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.t(subtitle),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (pill != null) ...[
                const SizedBox(height: 10),
                SmallPill(context.t(pill!)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CcColors.dark,
        borderRadius: BorderRadius.circular(26),
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
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(subtitle),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onPrimary,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(context.t(buttonLabel)),
                      style: FilledButton.styleFrom(
                        backgroundColor: CcColors.lime,
                        foregroundColor: CcColors.dark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onSecondary,
                      icon: const Icon(Icons.upload_rounded),
                      tooltip: context.t(secondaryLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const PlantIllustration(size: 118, dark: true),
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
        borderRadius: BorderRadius.circular(22),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(context.t(label)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CcColors.line,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(context.t(label)),
        style: OutlinedButton.styleFrom(
          foregroundColor: CcColors.green,
          side: const BorderSide(color: CcColors.green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CcColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(context.t(label)),
        ],
      ),
    );
  }
}

class SmallPill extends StatelessWidget {
  const SmallPill(this.text, {super.key, this.color = CcColors.green});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        context.t(text),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class PriorityCard extends StatelessWidget {
  const PriorityCard({super.key});

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
      child: const Row(
        children: [
          Icon(Icons.priority_high_rounded, color: CcColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Priority: High. Isolate suspicious trees and request field confirmation.',
              style: TextStyle(fontWeight: FontWeight.w800),
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
            Icon(icon, color: CcColors.green),
            const SizedBox(width: 12),
            Expanded(child: Text(context.t(text))),
          ],
        ),
      ),
    );
  }
}

class WarningBox extends StatelessWidget {
  const WarningBox({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

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
            context.t(title),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: CcColors.red,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines) Text('- ${context.t(line)}'),
        ],
      ),
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

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.disease,
    required this.status,
    required this.date,
    required this.confidence,
  });

  final String disease;
  final String status;
  final String date;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: context.t(disease),
        child: Column(
          children: [
            InfoRow(label: 'Date', value: date),
            InfoRow(label: 'Confidence', value: confidence),
            InfoRow(label: 'Report status', value: status),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: title,
        child: Row(
          children: [
            Icon(icon, color: CcColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.t(value), overflow: TextOverflow.ellipsis),
            ),
            TextButton(onPressed: onTap, child: Text(context.t(action))),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(label),
            style: const TextStyle(color: CcColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            context.t(value),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            softWrap: true,
          ),
        ],
      ),
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
                onTap: () {
                  state.setLanguage(language);
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
            onPressed: () {
              state.setEmail(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text(context.t('Save')),
          ),
        ],
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
