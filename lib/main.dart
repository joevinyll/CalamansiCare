import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'data/diagnosis_repository.dart';
import 'data/treatment_content.dart';
import 'data/community_repository.dart';
import 'data/community_time.dart';
import 'disease_classifier.dart';

part 'features/auth/auth_screens.dart';
part 'features/diagnosis/diagnosis_screens.dart';
part 'features/diagnosis/capture_screen.dart';
part 'features/diagnosis/batch_results_screen.dart';
part 'features/diagnosis/batch_history_screen.dart';
part 'features/settings/settings_screen.dart';
part 'features/community/community_screens.dart';
part 'features/community/community_feed.dart';
part 'widgets/shared_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DiagnosisRepository.instance.initialise();
  runApp(const CalamansiCareApp());
}

const supportedLanguages = ['English', 'Tagalog', 'Cebuano'];

const diseaseLabels = [
  'Anthracnose',
  'Brown Spot',
  'Citrus Canker',
  'Citrus Scab',
  'HLB (Greening)',
  'Healthy Fruit',
  'Healthy Leaf',
  'Melanose',
];

const locationChannel = MethodChannel('calamansi_care/location');

const locationSuggestions = [
  'Calinan, Davao City',
  'Toril, Davao City',
  'Mintal, Davao City',
  'Tugbok, Davao City',
  'Baguio District, Davao City',
  'Marilog District, Davao City',
  'Bansalan, Davao del Sur',
  'Digos City, Davao del Sur',
];

/// Confidence banding for the on-device classifier.
///
/// Scans below [reportAcceptanceConfidenceThreshold] are treated as unclear:
/// they are not saved in History and the farmer is asked to take another photo.
enum ConfidenceTier { accepted, lowConfidence, rejected }

ConfidenceTier confidenceTier(double confidence) {
  if (confidence >= reportAcceptanceConfidenceThreshold) {
    return ConfidenceTier.accepted;
  }
  if (confidence >= 0.40) return ConfidenceTier.lowConfidence;
  return ConfidenceTier.rejected;
}

const lowConfidenceWarningMessage =
    'Low Confidence: Please retake the photo closer to the leaf under better lighting.';
const lowConfidenceRejectionMessage =
    'Disease could not be identified. Please ensure the leaf lesion is centered and clear.';
const reportAcceptanceConfidenceThreshold = 0.80;

class AccountCreatedNeedsSignInException implements Exception {
  const AccountCreatedNeedsSignInException();
}

String accountErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('email not confirmed') ||
      text.contains('not confirmed') ||
      text.contains('confirm')) {
    return 'Please confirm your email first, then sign in again.';
  }
  if (text.contains('invalid email') ||
      text.contains('email_address_invalid') ||
      text.contains('unable to validate email') ||
      text.contains('email address is invalid')) {
    return 'Please enter a valid email address.';
  }
  if (text.contains('invalid login') ||
      text.contains('invalid credentials') ||
      text.contains('invalid email or password')) {
    return 'Email or password is incorrect. Please try again.';
  }
  if (text.contains('already registered') ||
      text.contains('already exists') ||
      text.contains('user already')) {
    return 'This email already has an account. Please sign in instead.';
  }
  if (text.contains('signup') && text.contains('disabled')) {
    return 'Account creation is not enabled yet. Please check Supabase settings.';
  }
  if ((text.contains('password') && text.contains('weak')) ||
      text.contains('weak_password') ||
      text.contains('password should be')) {
    return 'Please use a stronger password.';
  }
  if (text.contains('rate limit') ||
      text.contains('over_email_send_rate_limit') ||
      text.contains('security purposes')) {
    return 'Please wait a minute, then try again.';
  }
  if (text.contains('database error saving new user')) {
    return 'Account setup needs a Supabase database check.';
  }
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection')) {
    return 'Please check your internet connection and try again.';
  }
  if (text.contains('supabase') || text.contains('not configured')) {
    return 'Account setup is not ready yet. Please check Supabase settings.';
  }
  return 'Account action failed. Please check internet, email, and password.';
}

class DiseaseGuidance {
  const DiseaseGuidance({
    required this.kind,
    required this.recommendation,
    required this.conventionalTreatment,
    required this.organicTreatment,
    required this.prevention,
  });

  final String kind;
  final String recommendation;
  final String conventionalTreatment;
  final String organicTreatment;
  final String prevention;
}

DiseaseGuidance guidanceFor(String disease) {
  final advice = treatmentAdviceByDisease[disease];
  if (advice != null) {
    return DiseaseGuidance(
      kind: advice.kind,
      recommendation: advice.cultural.english,
      conventionalTreatment: advice.chemical.english,
      organicTreatment: advice.cultural.english,
      prevention: advice.prevention,
    );
  }
  return const DiseaseGuidance(
    kind: 'Needs field confirmation',
    recommendation:
        'Take another clear leaf photo and ask an agriculture technician to inspect the tree if symptoms spread.',
    conventionalTreatment:
        'Do not apply pesticide until the disease is confirmed. Wrong treatment can waste money and harm the tree.',
    organicTreatment:
        'Retake a clear photo, isolate suspicious plant material, remove fallen debris, and keep the tree watered and nourished while waiting for confirmation.',
    prevention:
        'Monitor nearby trees weekly and disinfect tools after pruning.',
  );
}

String diseaseDescriptionFor(String disease) {
  switch (disease) {
    case 'Healthy Fruit':
      return 'The fruit looks normal, with no clear disease marks. Keep checking often so problems can be found early.';
    case 'Healthy Leaf':
      return 'The leaf looks healthy, with no clear disease signs. Continue regular watering, nutrition, and farm sanitation.';
    case 'HLB (Greening)':
      return 'A serious bacterial disease that can cause uneven yellow leaves, weak growth, and poor fruit quality. It can spread through infected planting material and citrus psyllids.';
    case 'Citrus Canker':
      return 'A bacterial disease that often creates raised corky spots on leaves, stems, or fruit. It spreads easily through wind-driven rain and infected plant material.';
    case 'Anthracnose':
      return 'A fungal disease that can cause dark sunken spots, twig dieback, and fruit damage, especially during wet or stressful conditions.';
    case 'Melanose':
      return 'A fungal disease linked to dead twigs and old infected wood. It can leave rough dark specks or streaks on fruit and leaves.';
    case 'Citrus Scab':
      return 'A fungal disease that can make rough raised scab marks on young leaves and fruit. It is common when new growth stays wet.';
    case 'Brown Spot':
      return 'A fungal disease that can cause brown leaf spots, fruit spots, and leaf drop. Wet weather and dense canopies can make it worse.';
    default:
      return 'The condition needs a clearer photo or field checking before making a treatment decision.';
  }
}

class CcColors {
  static const bg = Color(0xFFF0F4EA);
  static const bgAlt = Color(0xFFF7FAF3);
  static const card = Color(0xFFFFFFFF);
  static const green = Color(0xFF2F6B3F);
  static const dark = Color(0xFF17251D);
  static const hero = Color(0xFF1F4D30);
  static const blackGreen = Color(0xFF0B120E);
  static const soft = Color(0xFFEAF5DF);
  static const softStrong = Color(0xFFDDE8D8);
  static const lime = Color(0xFFB7D857);
  static const limeLight = Color(0xFFDDF28A);
  static const orange = Color(0xFFD97828);
  static const orangeSoft = Color(0xFFFFF2D6);
  static const blue = Color(0xFFDDF2F6);
  static const link = Color(0xFF1565C0);
  static const red = Color(0xFFC6483A);
  static const ink = Color(0xFF17251D);
  static const muted = Color(0xFF667568);
  static const line = Color(0xFFDDE8D8);
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
    'Offline AI disease checking, treatment guidance, and barangay report preparation.':
        {
      tagalog:
          'Offline AI na pagsusuri ng sakit, gabay sa paggamot, at paghahanda ng ulat sa barangay.',
      cebuano:
          'Offline AI nga pagsusi sa sakit, giya sa pagtambal, ug pag-andam sa report sa barangay.',
    },
    'Choose language': {
      tagalog: 'Pumili ng wika',
      cebuano: 'Pili ug pinulongan',
    },
    'Choose language / Pumili ng wika / Pili og pinulongan': {
      tagalog: 'Choose language / Pumili ng wika / Pili og pinulongan',
      cebuano: 'Choose language / Pumili ng wika / Pili og pinulongan',
    },
    'AI disease detection and treatment guide for calamansi farmers.': {
      tagalog:
          'AI disease detection at gabay sa paggamot para sa calamansi farmers.',
      cebuano:
          'AI disease detection ug giya sa pagtambal para sa calamansi farmers.',
    },
    'Preparing CalamansiCare': {
      tagalog: 'Inihahanda ang CalamansiCare',
      cebuano: 'Giandam ang CalamansiCare',
    },
    'Loading saved settings and reports.': {
      tagalog: 'Nilo-load ang naka-save na settings at reports.',
      cebuano: 'Gi-load ang na-save nga settings ug reports.',
    },
    'Run AI diagnosis offline using your phone camera.': {
      tagalog: 'Magpatakbo ng AI diagnosis offline gamit ang camera ng phone.',
      cebuano: 'Padagana ang AI diagnosis offline gamit ang camera sa phone.',
    },
    'Field summary': {
      tagalog: 'Buod ng field',
      cebuano: 'Field summary',
    },
    'Checks': {tagalog: 'Checks', cebuano: 'Checks'},
    'Checks details': {
      tagalog: 'Detalye ng checks',
      cebuano: 'Detalye sa checks',
    },
    'Sent reports': {
      tagalog: 'Naipadalang reports',
      cebuano: 'Napadalang reports',
    },
    'No checks yet.': {
      tagalog: 'Wala pang checks.',
      cebuano: 'Wala pay checks.',
    },
    'No reports waiting.': {
      tagalog: 'Walang report na naghihintay.',
      cebuano: 'Walay report nga naghuwat.',
    },
    'No sent reports yet.': {
      tagalog: 'Wala pang naipadalang reports.',
      cebuano: 'Wala pay napadalang reports.',
    },
    'Tap to see details': {
      tagalog: 'Pindutin para makita ang detalye',
      cebuano: 'Pislita aron makita ang detalye',
    },
    'Start plant check': {
      tagalog: 'Simulan ang pagsusuri',
      cebuano: 'Sugdi ang pagsusi',
    },
    'Sign in or create account': {
      tagalog: 'Mag-sign in o gumawa ng account',
      cebuano: 'Sign in o paghimo ug account',
    },
    'You can check plants without an account.': {
      tagalog: 'Puwede kang magsuri ng halaman kahit walang account.',
      cebuano: 'Pwede ka magsusi sa tanom bisan walay account.',
    },
    'Terms of agreement': {
      tagalog: 'Kasunduan sa paggamit',
      cebuano: 'Kasabutan sa paggamit',
    },
    'Before using CalamansiCare, please acknowledge how the app handles report information.':
        {
      tagalog:
          'Bago gamitin ang CalamansiCare, paki-acknowledge kung paano hinahawakan ng app ang impormasyon ng ulat.',
      cebuano:
          'Sa dili pa gamiton ang CalamansiCare, palihug dawata kung giunsa pagdumala sa app ang impormasyon sa report.',
    },
    'What we collect': {
      tagalog: 'Impormasyong kinokolekta',
      cebuano: 'Impormasyon nga kolektahon',
    },
    'Device signature, model, Android version, farmer name, farm location, barangay email, diagnosis result, confidence score, report date, and report image when you send a report.':
        {
      tagalog:
          'Device signature, model, Android version, pangalan ng farmer, lokasyon ng farm, barangay email, resulta ng diagnosis, confidence score, petsa ng ulat, at larawan kapag nagpadala ng report.',
      cebuano:
          'Device signature, model, Android version, ngalan sa farmer, lokasyon sa uma, barangay email, resulta sa diagnosis, confidence score, petsa sa report, ug hulagway kung magpadala ka ug report.',
    },
    'How we use it': {
      tagalog: 'Paano ito ginagamit',
      cebuano: 'Giunsa kini paggamit',
    },
    'This information is used to save reports offline, avoid duplicate uploads, send reports to the barangay office, and show community disease alerts.':
        {
      tagalog:
          'Ginagamit ito para mag-save ng reports offline, maiwasan ang duplicate uploads, magpadala ng reports sa barangay office, at magpakita ng community disease alerts.',
      cebuano:
          'Gigamit kini para masave ang reports offline, malikayan ang duplicate uploads, ipadala ang reports sa barangay office, ug ipakita ang community disease alerts.',
    },
    'Offline and online storage': {
      tagalog: 'Offline at online na pag-save',
      cebuano: 'Offline ug online nga pagtipig',
    },
    'Reports are saved locally on this phone first. When internet is available, approved reports are uploaded to Supabase and may be emailed to the target barangay email.':
        {
      tagalog:
          'Ang reports ay unang sine-save sa phone. Kapag may internet, ang approved reports ay ia-upload sa Supabase at maaaring i-email sa target barangay email.',
      cebuano:
          'Ang reports una nga isave sa phone. Kung naay internet, ang approved reports i-upload sa Supabase ug mahimong i-email sa target barangay email.',
    },
    'Farmer responsibility': {
      tagalog: 'Responsibilidad ng farmer',
      cebuano: 'Responsibilidad sa farmer',
    },
    'The app gives guidance only. Confirm serious disease findings with the local agriculture office before applying treatment.':
        {
      tagalog:
          'Gabay lamang ang app. I-confirm muna sa local agriculture office ang seryosong sakit bago gumamit ng treatment.',
      cebuano:
          'Giya lamang ang app. I-confirm una sa local agriculture office ang seryosong sakit sa dili pa mogamit ug treatment.',
    },
    'I understand and agree': {
      tagalog: 'Nauunawaan ko at sumasang-ayon ako',
      cebuano: 'Nakasabot ko ug mouyon ko',
    },
    'About CalamansiCare': {
      tagalog: 'Tungkol sa CalamansiCare',
      cebuano: 'Mahitungod sa CalamansiCare',
    },
    'App information and terms': {
      tagalog: 'Impormasyon ng app at kasunduan',
      cebuano: 'Impormasyon sa app ug kasabutan',
    },
    'CalamansiCare helps farmers check calamansi leaves and fruits using an offline AI model, view simple disease information, save scan history on the phone, and prepare reports for the barangay agriculture office.':
        {
      tagalog:
          'Tinutulungan ng CalamansiCare ang farmers na suriin ang dahon at bunga ng calamansi gamit ang offline AI model, makita ang simpleng impormasyon tungkol sa sakit, mag-save ng scan history sa phone, at maghanda ng report para sa barangay agriculture office.',
      cebuano:
          'Gitabangan sa CalamansiCare ang farmers nga susihon ang dahon ug bunga sa calamansi gamit ang offline AI model, makita ang simple nga impormasyon sa sakit, ma-save ang scan history sa phone, ug maandam ang report para sa barangay agriculture office.',
    },
    'The treatment and recommendation content is based on expert-verified guidance for calamansi disease management and should be used as support for farmer decisions.':
        {
      tagalog:
          'Ang treatment at recommendation content ay batay sa expert-verified guidance para sa calamansi disease management at dapat gamitin bilang gabay sa desisyon ng farmer.',
      cebuano:
          'Ang treatment ug recommendation content gibase sa expert-verified guidance para sa calamansi disease management ug gamiton isip giya sa desisyon sa farmer.',
    },
    'Important reminder': {
      tagalog: 'Mahalagang paalala',
      cebuano: 'Importante nga pahinumdom',
    },
    'For serious or spreading symptoms, farmers should still confirm findings with the local agriculture office before removing trees or applying chemical treatment.':
        {
      tagalog:
          'Para sa seryoso o kumakalat na sintomas, dapat pa ring magpa-confirm ang farmers sa local agriculture office bago magtanggal ng puno o gumamit ng kemikal na treatment.',
      cebuano:
          'Para sa seryoso o mokaylap nga sintomas, kinahanglan gihapon magpa-confirm ang farmers sa local agriculture office bago magtangtang ug kahoy o mogamit ug kemikal nga treatment.',
    },
    'Read app details and terms of agreement.': {
      tagalog: 'Basahin ang detalye ng app at kasunduan.',
      cebuano: 'Basaha ang detalye sa app ug kasabutan.',
    },
    'Home': {tagalog: 'Home', cebuano: 'Home'},
    'Check': {tagalog: 'Suriin', cebuano: 'Susi'},
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
    'Online ready': {tagalog: 'Handa online', cebuano: 'Andam online'},
    'Internet connected': {
      tagalog: 'May internet',
      cebuano: 'Naay internet',
    },
    'Offline checking ready': {
      tagalog: 'Handa ang offline checking',
      cebuano: 'Andam ang offline checking',
    },
    'Waiting for internet connection': {
      tagalog: 'Naghihintay ng internet connection',
      cebuano: 'Naghulat sa internet connection',
    },
    'Waiting for internet': {
      tagalog: 'Naghihintay ng internet',
      cebuano: 'Naghulat sa internet',
    },
    'Saved on phone': {
      tagalog: 'Naka-save sa phone',
      cebuano: 'Na-save sa phone',
    },
    'Sending...': {
      tagalog: 'Ipinapadala...',
      cebuano: 'Gipadala...',
    },
    'Could not send. Tap to try again': {
      tagalog: 'Hindi naipadala. Pindutin para subukan muli',
      cebuano: 'Wala napadala. Pislita aron sulayan usab',
    },
    'Retry': {tagalog: 'Subukan muli', cebuano: 'Sulayi usab'},
    'No internet. Your report is saved and will send later.': {
      tagalog: 'Walang internet. Naka-save ang report at ipapadala mamaya.',
      cebuano: 'Walay internet. Na-save ang report ug ipadala unya.',
    },
    'Saved locally, will retry': {
      tagalog: 'Naka-save lokal, susubukan muli',
      cebuano: 'Na-save lokal, sulayan usab',
    },
    'Location not set': {
      tagalog: 'Wala pang lokasyon',
      cebuano: 'Wala pay lokasyon',
    },
    'Tap to add': {
      tagalog: 'Pindutin para magdagdag',
      cebuano: 'Pislita aron makadugang',
    },
    'Complete farmer information first': {
      tagalog: 'Kumpletuhin muna ang impormasyon ng farmer',
      cebuano: 'Kompletoha una ang impormasyon sa farmer',
    },
    'Please add farmer name, farm location, and barangay email before sending a report.':
        {
      tagalog:
          'Ilagay muna ang pangalan ng farmer, lokasyon ng farm, at barangay email bago magpadala ng ulat.',
      cebuano:
          'Ibutang una ang ngalan sa farmer, lokasyon sa farm, ug barangay email bago magpadala ug report.',
    },
    'Edit settings': {
      tagalog: 'Ayusin ang settings',
      cebuano: 'Usba ang settings',
    },
    'Ready to send when online': {
      tagalog: 'Handa nang ipadala kapag online',
      cebuano: 'Andam ipadala kung online',
    },
    'Report Summary': {
      tagalog: 'Buod ng Report',
      cebuano: 'Summary sa Report',
    },
    'Details of the latest reported scan.': {
      tagalog: 'Detalye ng pinakahuling nai-report na scan.',
      cebuano: 'Detalye sa pinakabag-o nga gi-report nga scan.',
    },
    'No reports waiting to send': {
      tagalog: 'Walang ulat na naghihintay ipadala',
      cebuano: 'Walay report nga naghuwat ipadala',
    },
    'No reported scans yet.': {
      tagalog: 'Wala pang nai-report na scan.',
      cebuano: 'Wala pay gi-report nga scan.',
    },
    'Sending report...': {
      tagalog: 'Ipinapadala ang ulat...',
      cebuano: 'Gipadala ang report...',
    },
    'Back': {tagalog: 'Bumalik', cebuano: 'Balik'},
    'Online': {tagalog: 'Online', cebuano: 'Online'},
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
    'Offline model is analyzing image features.': {
      tagalog: 'Sinusuri ng offline model ang mga palatandaan sa larawan.',
      cebuano: 'Gisusi sa offline model ang mga timailhan sa hulagway.',
    },
    'Checking image color, spots, texture, and shape.': {
      tagalog: 'Sinusuri ang kulay, batik, texture, at hugis sa larawan.',
      cebuano: 'Gisusi ang kolor, mga lama, texture, ug porma sa hulagway.',
    },
    'Please wait while AI checks the photo.': {
      tagalog: 'Maghintay habang sinusuri ng AI ang larawan.',
      cebuano: 'Palihug hulat samtang gisusi sa AI ang hulagway.',
    },
    'Analyzed photo': {
      tagalog: 'Nasuring larawan',
      cebuano: 'Nasusi nga hulagway',
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
    'Low confidence': {
      tagalog: 'Mababang confidence',
      cebuano: 'Ubos nga confidence',
    },
    'Please kindly take/provide another photo': {
      tagalog: 'Pakiusap kumuha o magbigay ng panibagong larawan',
      cebuano: 'Palihug kuha o hatag ug laing hulagway',
    },
    'To improve accuracy, make sure the photo shows only a calamansi fruit or leaf against a plain background. Avoid other objects, patterned surfaces, shadows, or clutter that can confuse the AI.':
        {
      tagalog:
          'Para mas tama ang resulta, siguraduhing calamansi na bunga o dahon lamang ang nasa larawan at plain ang background. Iwasan ang ibang bagay, patterned na ibabaw, anino, o kalat na maaaring makalito sa AI.',
      cebuano:
          'Para mas sakto ang resulta, siguroha nga calamansi nga bunga o dahon lang ang naa sa hulagway ug plain ang background. Likayi ang ubang butang, patterned nga ibabaw, landong, o samok nga makalibog sa AI.',
    },
    lowConfidenceWarningMessage: {
      tagalog:
          'Mababang Confidence: Paki-ulit ang litrato, mas malapit sa dahon at may sapat na liwanag.',
      cebuano:
          'Ubos nga Confidence: Kuhaa pag-usab ang litrato, mas duol sa dahon ug may igo nga suga.',
    },
    lowConfidenceRejectionMessage: {
      tagalog:
          'Hindi matukoy ang sakit. Siguraduhing nasa gitna at malinaw ang bahaging apektado ng dahon.',
      cebuano:
          'Dili matino ang sakit. Siguroha nga naa sa tunga ug klaro ang apektadong bahin sa dahon.',
    },
    'Scan a leaf from Home to see it here.': {
      tagalog: 'Mag-scan ng dahon mula sa Home para makita ito dito.',
      cebuano: 'Pag-scan og dahon gikan sa Home aron makita kini dinhi.',
    },
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
    'Ask a technician to confirm if symptoms spread. This app supports decisions, but does not replace field inspection.':
        {
      tagalog:
          'Magpatingin sa technician kung kumalat ang sintomas. Gabay lamang ang app at hindi kapalit ng field inspection.',
      cebuano:
          'Pangayo ug kumpirmasyon sa technician kung mokaylap ang sintomas. Giya lang ang app ug dili kapuli sa field inspection.',
    },
    'View treatment guide': {
      tagalog: 'Tingnan ang gabay sa paggamot',
      cebuano: 'Tan-awa ang giya sa pagtambal',
    },
    'Scan Again': {
      tagalog: 'Mag-scan muli',
      cebuano: 'Scan usab',
    },
    'Treatment guide': {
      tagalog: 'Gabay sa paggamot',
      cebuano: 'Giya sa pagtambal',
    },
    'Prioritize containment and expert confirmation.': {
      tagalog: 'Unahin ang pagpigil sa pagkalat at kumpirmasyon ng eksperto.',
      cebuano: 'Unaha ang pagpugong sa paglapad ug kumpirmasyon sa eksperto.',
    },
    'Priority: High. Isolate suspicious trees and request field confirmation.':
        {
      tagalog:
          'Prayoridad: Mataas. Ihiwalay ang kahina-hinalang puno at humingi ng field confirmation.',
      cebuano:
          'Prayoridad: Taas. Ilain ang kahina-hinalang kahoy ug pangayo ug field confirmation.',
    },
    'Cultural': {tagalog: 'Kultural', cebuano: 'Kultural'},
    'Organic': {tagalog: 'Organiko', cebuano: 'Organiko'},
    'Chemical': {tagalog: 'Kemikal', cebuano: 'Kemikal'},
    'Prevention': {tagalog: 'Pag-iwas', cebuano: 'Paglikay'},
    'Disease type': {tagalog: 'Uri ng sakit', cebuano: 'Klase sa sakit'},
    'Treatment options': {
      tagalog: 'Mga opsyon sa paggamot',
      cebuano: 'Mga opsyon sa pagtambal',
    },
    'Conventional treatment': {
      tagalog: 'Conventional na paggamot',
      cebuano: 'Conventional nga pagtambal',
    },
    'Organic / natural management': {
      tagalog: 'Organiko / natural na paraan',
      cebuano: 'Organiko / natural nga pamaagi',
    },
    'Remove severely affected branches and avoid moving infected plant material.':
        {
      tagalog:
          'Tanggalin ang malubhang apektadong sanga at iwasang ilipat ang infected na bahagi ng halaman.',
      cebuano:
          'Tangtanga ang grabe nga apektadong sanga ug likayi ang pagbalhin sa infected nga bahin sa tanom.',
    },
    'Keep trees healthy with proper watering, sanitation, and nutrient balance.':
        {
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
    'Report this scan': {
      tagalog: 'I-report ang scan na ito',
      cebuano: 'I-report kini nga scan',
    },
    'Already reported': {
      tagalog: 'Nai-report na',
      cebuano: 'Na-report na',
    },
    'Only scans with 80% confidence or higher can be reported.': {
      tagalog:
          'Tanging scan na may 80% confidence pataas ang maaaring i-report.',
      cebuano:
          'Ang scan nga adunay 80% confidence pataas ra ang mahimong i-report.',
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
    'Shared to barangay: name, city or municipality, diagnosis, and photo. Shared to other farmers: diagnosis, photo, and city or municipality only.':
        {
      tagalog:
          'Ipinapadala sa barangay: pangalan, lungsod o munisipalidad, diagnosis, at larawan. Nakikita ng ibang farmer: diagnosis, larawan, at lungsod o munisipalidad lamang.',
      cebuano:
          'Ipadala sa barangay: ngalan, siyudad o munisipyo, diagnosis, ug hulagway. Makita sa ubang farmer: diagnosis, hulagway, ug siyudad o munisipyo lamang.',
    },
    'Required before report can be emailed through Supabase.': {
      tagalog: 'Kailangan bago ma-email ang ulat gamit ang Supabase.',
      cebuano: 'Kinahanglan bago ma-email ang report gamit ang Supabase.',
    },
    'Report': {
      tagalog: 'I-report',
      cebuano: 'I-report',
    },
    'Report is pending and waiting for internet connection.': {
      tagalog: 'Pending ang ulat at naghihintay ng internet connection.',
      cebuano: 'Pending ang report ug naghuwat sa internet connection.',
    },
    'Report saved. Sending to barangay now.': {
      tagalog: 'Naka-save ang ulat. Ipinapadala na sa barangay.',
      cebuano: 'Na-save ang report. Gipadala na sa barangay.',
    },
    'Offline queue': {tagalog: 'Offline na pila', cebuano: 'Offline nga pila'},
    'Reports wait here until internet is available.': {
      tagalog: 'Dito naghihintay ang mga ulat hanggang may internet.',
      cebuano: 'Dinhi maghulat ang reports hangtod naay internet.',
    },
    'Waiting': {tagalog: 'Naghihintay', cebuano: 'Naghulat'},
    'Sent': {tagalog: 'Naipadala', cebuano: 'Napadala'},
    'Nutrient Def.': {
      tagalog: 'Kulang nutrisyon',
      cebuano: 'Kulang nutrisyon',
    },
    'HLB / Greening report': {
      tagalog: 'Ulat ng HLB / Greening',
      cebuano: 'Report sa HLB / Greening',
    },
    'Reported scan': {
      tagalog: 'Nai-report na scan',
      cebuano: 'Gi-report nga scan',
    },
    'Scan image': {
      tagalog: 'Larawan ng scan',
      cebuano: 'Hulagway sa scan',
    },
    'Report details': {
      tagalog: 'Detalye ng report',
      cebuano: 'Detalye sa report',
    },
    'Farmer': {tagalog: 'Farmer', cebuano: 'Mag-uuma'},
    'Scan date': {
      tagalog: 'Petsa ng scan',
      cebuano: 'Petsa sa scan',
    },
    'Report date': {
      tagalog: 'Petsa ng report',
      cebuano: 'Petsa sa report',
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
    'Saved in': {
      tagalog: 'Naka-save sa',
      cebuano: 'Na-save sa',
    },
    'SQLite local history': {
      tagalog: 'Lokal na history ng SQLite',
      cebuano: 'Lokal nga history sa SQLite',
    },
    'This phone': {
      tagalog: 'Sa phone na ito',
      cebuano: 'Sa kini nga phone',
    },
    'Target email': {tagalog: 'Target na email', cebuano: 'Target email'},
    'Automatic sending will use Supabase when the phone reconnects to internet.':
        {
      tagalog:
          'Gagamit ng Supabase ang automatic sending kapag bumalik ang internet.',
      cebuano:
          'Mogamit ug Supabase ang automatic sending kung mobalik ang internet.',
    },
    'Reports will send automatically when internet is available.': {
      tagalog: 'Awtomatikong ipapadala ang ulat kapag may internet.',
      cebuano: 'Awtomatikong ipadala ang report kung naay internet.',
    },
    'Connect to the internet first.': {
      tagalog: 'Kumonekta muna sa internet.',
      cebuano: 'Konek una sa internet.',
    },
    'Please connect to the internet to see barangay reports.': {
      tagalog:
          'Kumonekta muna sa internet para makita ang mga ulat ng barangay.',
      cebuano: 'Konek una sa internet para makita ang mga report sa barangay.',
    },
    'No barangay reports yet. Please try again later.': {
      tagalog: 'Wala pang ulat ng barangay. Subukan muli mamaya.',
      cebuano: 'Wala pay report sa barangay. Sulayi usab unya.',
    },
    'Try sending now': {
      tagalog: 'Subukang ipadala ngayon',
      cebuano: 'Sulayi ug padala karon',
    },
    'Sending now...': {
      tagalog: 'Ipinapadala ngayon...',
      cebuano: 'Gipadala karon...',
    },
    'Retry upload': {
      tagalog: 'Subukang i-upload muli',
      cebuano: 'Sulayi usab ug upload',
    },
    'Report is saved locally. Tap retry when internet is stable.': {
      tagalog:
          'Naka-save ang ulat sa phone. Subukang muli kapag stable ang internet.',
      cebuano:
          'Na-save ang report sa phone. Sulayi usab kung stable na ang internet.',
    },
    'Report sent successfully.': {
      tagalog: 'Matagumpay na naipadala ang ulat.',
      cebuano: 'Malampuson nga napadala ang report.',
    },
    'Report sent': {
      tagalog: 'Naipadala ang ulat',
      cebuano: 'Napadala ang report',
    },
    'Your report was sent to the barangay.': {
      tagalog: 'Naipadala na ang ulat sa barangay.',
      cebuano: 'Napadala na ang report sa barangay.',
    },
    'OK': {tagalog: 'OK', cebuano: 'OK'},
    'Still saved locally. Please check internet or Supabase setup, then retry.':
        {
      tagalog:
          'Naka-save pa rin sa phone. Suriin ang internet o Supabase setup, tapos subukan muli.',
      cebuano:
          'Na-save gihapon sa phone. Susiha ang internet o Supabase setup, unya sulayi usab.',
    },
    'Report is still waiting. Please connect to the internet and try again.': {
      tagalog:
          'Naghihintay pa ang ulat. Kumonekta sa internet at subukan muli.',
      cebuano: 'Naghulat pa ang report. Konek sa internet ug sulayi usab.',
    },
    'Report marked as sent for UI demo.': {
      tagalog: 'Namarkahan na naipadala ang ulat para sa UI demo.',
      cebuano: 'Namarkahan nga napadala ang report para sa UI demo.',
    },
    'Sync attempted. Reports stay saved locally until Supabase confirms upload.':
        {
      tagalog:
          'Sinubukan ang sync. Mananatiling lokal ang ulat hanggang makumpirma ng Supabase ang upload.',
      cebuano:
          'Gisulayan ang sync. Magpabilin lokal ang report hangtod makumpirma sa Supabase ang upload.',
    },
    'Back to home': {tagalog: 'Bumalik sa home', cebuano: 'Balik sa home'},
    'Saved scans and report status from SQLite.': {
      tagalog: 'Mga na-save na scan at status ng ulat mula sa SQLite.',
      cebuano: 'Mga na-save nga scan ug status sa report gikan sa SQLite.',
    },
    'Saved scans and report status on this phone.': {
      tagalog: 'Mga na-save na scan at status ng ulat sa phone na ito.',
      cebuano: 'Mga na-save nga scan ug status sa report sa kini nga phone.',
    },
    'Queued': {tagalog: 'Nakapila', cebuano: 'Nakapila'},
    'Healthy Fruit': {
      tagalog: 'Malusog na bunga',
      cebuano: 'Himsog nga prutas',
    },
    'Healthy Leaf': {
      tagalog: 'Malusog na dahon',
      cebuano: 'Himsog nga dahon',
    },
    'Not reported': {tagalog: 'Hindi naiulat', cebuano: 'Wala gi-report'},
    'Date': {tagalog: 'Petsa', cebuano: 'Petsa'},
    'Report status': {tagalog: 'Status ng ulat', cebuano: 'Status sa report'},
    'Diagnosis details': {
      tagalog: 'Detalye ng diagnosis',
      cebuano: 'Detalye sa diagnosis',
    },
    'Scan result': {tagalog: 'Resulta ng scan', cebuano: 'Resulta sa scan'},
    'Saved details': {
      tagalog: 'Na-save na detalye',
      cebuano: 'Na-save nga detalye',
    },
    'Delete history': {
      tagalog: 'Burahin ang history',
      cebuano: 'Papasa ang history',
    },
    'Are you sure to delete this history?': {
      tagalog: 'Sigurado ka bang burahin ang history na ito?',
      cebuano: 'Sigurado ka nga papason kini nga history?',
    },
    'This will permanently remove this scan from local history.': {
      tagalog: 'Permanenteng aalisin nito ang scan na ito sa lokal na history.',
      cebuano:
          'Permanenteng tangtangon niini ang scan gikan sa lokal nga history.',
    },
    'This will cancel the queued report and delete this history.': {
      tagalog:
          'Kakanselahin nito ang queued report at buburahin ang history na ito.',
      cebuano:
          'Kanselahon niini ang queued report ug papason kini nga history.',
    },
    'History deleted': {
      tagalog: 'Nabura ang history',
      cebuano: 'Napapas ang history',
    },
    'Delete': {tagalog: 'Burahin', cebuano: 'Papasa'},
    'See Image taken': {
      tagalog: 'Tingnan ang larawang kinuha',
      cebuano: 'Tan-awa ang hulagway nga gikuha',
    },
    'Image taken': {
      tagalog: 'Larawang kinuha',
      cebuano: 'Hulagway nga gikuha',
    },
    'Image unavailable': {
      tagalog: 'Hindi makita ang larawan',
      cebuano: 'Dili makita ang hulagway',
    },
    'Close': {tagalog: 'Isara', cebuano: 'Sirado'},
    'Language, office email, model, and reporting consent.': {
      tagalog: 'Wika, email ng opisina, model, at pahintulot sa ulat.',
      cebuano: 'Pinulongan, email sa opisina, model, ug pagtugot sa report.',
    },
    'Profile, location, language, email, model, and consent.': {
      tagalog: 'Profile, lokasyon, wika, email, model, at pahintulot.',
      cebuano: 'Profile, lokasyon, pinulongan, email, model, ug pagtugot.',
    },
    'Farmer profile': {
      tagalog: 'Profile ng magsasaka',
      cebuano: 'Profile sa mag-uuma',
    },
    'Name': {tagalog: 'Pangalan', cebuano: 'Ngalan'},
    'Location': {tagalog: 'Lokasyon', cebuano: 'Lokasyon'},
    'Manual location is better for farm tracking. Type the farm area, purok, or barangay clearly.':
        {
      tagalog:
          'Mas mabuti ang manual na lokasyon para matukoy nang mas tama ang farm. Ilagay nang malinaw ang lugar, purok, o barangay.',
      cebuano:
          'Mas maayo ang manual nga lokasyon para mas sakto matultolan ang farm. Ibutang og klaro ang lugar, purok, o barangay.',
    },
    'Device signature': {
      tagalog: 'Pirma ng device',
      cebuano: 'Pirma sa device',
    },
    'Font size': {tagalog: 'Laki ng font', cebuano: 'Gidak-on sa font'},
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
    'Agriculture office monitoring view.': {
      tagalog: 'Monitoring view ng agriculture office.',
      cebuano: 'Monitoring view sa agriculture office.',
    },
    'Open selected report': {
      tagalog: 'Buksan ang napiling ulat',
      cebuano: 'Ablihi ang napiling report',
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
    'No reports yet': {
      tagalog: 'Wala pang ulat',
      cebuano: 'Wala pay report',
    },
    'High risk': {
      tagalog: 'Mataas ang panganib',
      cebuano: 'Taas ang risgo',
    },
    'Medium risk': {
      tagalog: 'Katamtaman ang panganib',
      cebuano: 'Katamtaman ang risgo',
    },
    'Low risk': {
      tagalog: 'Mababa ang panganib',
      cebuano: 'Ubos ang risgo',
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
    'Community report opened for review.': {
      tagalog: 'Binuksan ang community report para suriin.',
      cebuano: 'Giablihan ang community report para susihon.',
    },
    'High priority': {
      tagalog: 'Mataas na prayoridad',
      cebuano: 'Taas nga prayoridad',
    },
    'Open': {tagalog: 'Bukas', cebuano: 'Abli'},
    'Email address': {tagalog: 'Email address', cebuano: 'Email address'},
    'Account': {tagalog: 'Account', cebuano: 'Account'},
    'Sign in to sync reports and restore saved data after reinstalling.': {
      tagalog:
          'Mag-sign in para ma-sync ang reports at maibalik ang naka-save na data pagkatapos mag-reinstall.',
      cebuano:
          'Pag-sign in para ma-sync ang reports ug mabalik ang na-save nga data human mag-reinstall.',
    },
    'Account connected': {
      tagalog: 'Nakakonekta ang account',
      cebuano: 'Nakakonekta ang account',
    },
    'Save with account': {
      tagalog: 'I-save gamit ang account',
      cebuano: 'I-save gamit ang account',
    },
    'Create an account or sign in before sending reports online.': {
      tagalog:
          'Gumawa ng account o mag-sign in bago magpadala ng report online.',
      cebuano:
          'Paghimo ug account o pag-sign in bago magpadala ug report online.',
    },
    'Supabase is not configured on this build. Add env keys before using accounts.':
        {
      tagalog:
          'Hindi pa naka-configure ang Supabase sa build na ito. Ilagay muna ang env keys bago gumamit ng account.',
      cebuano:
          'Wala pa ma-configure ang Supabase sa build niini. Ibutang una ang env keys bago mogamit ug account.',
    },
    'Sign out': {tagalog: 'Mag-sign out', cebuano: 'Sign out'},
    'Sign out?': {tagalog: 'Mag-sign out?', cebuano: 'Sign out?'},
    'Stay signed in': {
      tagalog: 'Manatiling naka-sign in',
      cebuano: 'Magpabilin nga naka-sign in',
    },
    'When you log out, this account\'s saved data on this phone will be deleted. Reports already sent online will stay in Barangay Reports.':
        {
      tagalog:
          'Kapag nag-log out ka, mabubura sa phone ang naka-save na data ng account na ito. Mananatili online ang mga report na naipadala na.',
      cebuano:
          'Kung mag-log out ka, mapapas ang naka-save nga data sa account nga kini sa phone. Magpabilin online ang mga report nga napadala na.',
    },
    'Create account': {
      tagalog: 'Gumawa ng account',
      cebuano: 'Paghimo ug account',
    },
    'Sign in': {tagalog: 'Mag-sign in', cebuano: 'Sign in'},
    'Already have an account? Sign in': {
      tagalog: 'May account na? Mag-sign in',
      cebuano: 'Naa nay account? Sign in',
    },
    'New here? Create account': {
      tagalog: 'Bago dito? Gumawa ng account',
      cebuano: 'Bag-o diri? Paghimo ug account',
    },
    'Sign in with Google': {
      tagalog: 'Mag-sign in gamit ang Google',
      cebuano: 'Sign in gamit ang Google',
    },
    'Google sign-in opened. Complete it in the browser.': {
      tagalog: 'Nabuksan ang Google sign-in. Tapusin ito sa browser.',
      cebuano: 'Naablihan ang Google sign-in. Humanon kini sa browser.',
    },
    'Google sign-in is not ready yet. Check Supabase Google setup.': {
      tagalog:
          'Hindi pa handa ang Google sign-in. Suriin ang Supabase Google setup.',
      cebuano:
          'Dili pa andam ang Google sign-in. Susiha ang Supabase Google setup.',
    },
    'You can still scan offline. Sign in is only needed before sending reports online.':
        {
      tagalog:
          'Puwede pa ring mag-scan offline. Kailangan lang ang sign in bago magpadala ng report online.',
      cebuano:
          'Pwede gihapon mag-scan offline. Kinahanglan lang ang sign in bago magpadala ug report online.',
    },
    'Continue offline': {
      tagalog: 'Magpatuloy offline',
      cebuano: 'Padayon offline',
    },
    'Go to Dashboard': {
      tagalog: 'Pumunta sa dashboard',
      cebuano: 'Adto sa dashboard',
    },
    'Use this account to restore synced reports later.': {
      tagalog:
          'Gamitin ang account na ito para maibalik ang synced reports sa susunod.',
      cebuano: 'Gamita kini nga account para mabalik ang synced reports puhon.',
    },
    'Use your account to sync and restore reports.': {
      tagalog: 'Gamitin ang account para ma-sync at maibalik ang reports.',
      cebuano: 'Gamita ang account para ma-sync ug mabalik ang reports.',
    },
    'Farmer account': {
      tagalog: 'Account ng magsasaka',
      cebuano: 'Account sa mag-uuma',
    },
    'Account details': {
      tagalog: 'Detalye ng account',
      cebuano: 'Detalye sa account',
    },
    'Password': {tagalog: 'Password', cebuano: 'Password'},
    'Forgot password?': {
      tagalog: 'Nakalimutan ang password?',
      cebuano: 'Nakalimot sa password?',
    },
    'Creating account...': {
      tagalog: 'Gumagawa ng account...',
      cebuano: 'Naghimo ug account...',
    },
    'Signing in...': {
      tagalog: 'Nagsa-sign in...',
      cebuano: 'Nag-sign in...',
    },
    'Enter an email and a password with at least 6 letters.': {
      tagalog:
          'Maglagay ng email at password na may hindi bababa sa 6 na letra.',
      cebuano:
          'Ibutang ang email ug password nga adunay labing menos 6 ka letra.',
    },
    'Please complete name, farm location, and barangay email.': {
      tagalog:
          'Pakikumpleto ang pangalan, lokasyon ng farm, at barangay email.',
      cebuano:
          'Palihug kompletoha ang ngalan, lokasyon sa farm, ug barangay email.',
    },
    'Please complete this information before sending:': {
      tagalog: 'Pakikumpleto muna ito bago ipadala:',
      cebuano: 'Palihug kompletoha una kini bago ipadala:',
    },
    'Farm location': {
      tagalog: 'Lokasyon ng farm',
      cebuano: 'Lokasyon sa farm',
    },
    'Please check your email, then sign in.': {
      tagalog: 'Pakisuri ang email, pagkatapos mag-sign in.',
      cebuano: 'Palihug susiha ang email, unya pag-sign in.',
    },
    'Please confirm your email first, then sign in again.': {
      tagalog: 'Pakikumpirma muna ang email, pagkatapos mag-sign in ulit.',
      cebuano: 'Palihug kumpirmaha una ang email, unya sign in usab.',
    },
    'Email or password is incorrect. Please try again.': {
      tagalog: 'Mali ang email o password. Pakisubukan muli.',
      cebuano: 'Sayop ang email o password. Palihug sulayi usab.',
    },
    'Please check your internet connection and try again.': {
      tagalog: 'Pakisuri ang internet connection at subukan muli.',
      cebuano: 'Palihug susiha ang internet connection ug sulayi usab.',
    },
    'Please enter a valid email address.': {
      tagalog: 'Maglagay ng tamang email address.',
      cebuano: 'Ibutang ang sakto nga email address.',
    },
    'This email already has an account. Please sign in instead.': {
      tagalog: 'May account na ang email na ito. Mag-sign in na lang.',
      cebuano: 'Naa nay account kini nga email. Pag-sign in na lang.',
    },
    'Account creation is not enabled yet. Please check Supabase settings.': {
      tagalog:
          'Hindi pa naka-enable ang paggawa ng account. Pakisuri ang Supabase settings.',
      cebuano:
          'Wala pa ma-enable ang paghimo ug account. Palihug susiha ang Supabase settings.',
    },
    'Please use a stronger password.': {
      tagalog: 'Gumamit ng mas malakas na password.',
      cebuano: 'Gamit ug mas lig-on nga password.',
    },
    'Please wait a minute, then try again.': {
      tagalog: 'Maghintay ng isang minuto, pagkatapos subukan muli.',
      cebuano: 'Hulat usa ka minuto, unya sulayi usab.',
    },
    'Account setup needs a Supabase database check.': {
      tagalog: 'Kailangang suriin ang Supabase database setup ng account.',
      cebuano: 'Kinahanglan susihon ang Supabase database setup sa account.',
    },
    'Account setup is not ready yet. Please check Supabase settings.': {
      tagalog:
          'Hindi pa handa ang account setup. Pakisuri ang Supabase settings.',
      cebuano:
          'Dili pa andam ang account setup. Palihug susiha ang Supabase settings.',
    },
    'Account created. Check email if confirmation is required.': {
      tagalog:
          'Nagawa na ang account. Suriin ang email kung kailangan ng confirmation.',
      cebuano:
          'Nahimo na ang account. Susiha ang email kung kinahanglan ug confirmation.',
    },
    'Account created and signed in.': {
      tagalog: 'Nagawa na ang account at naka-sign in na.',
      cebuano: 'Nahimo na ang account ug naka-sign in na.',
    },
    'Signed in successfully.': {
      tagalog: 'Matagumpay na naka-sign in.',
      cebuano: 'Malampuson nga naka-sign in.',
    },
    'Account action failed. Please check internet, email, and password.': {
      tagalog:
          'Hindi natuloy ang account action. Suriin ang internet, email, at password.',
      cebuano:
          'Wala nadayon ang account action. Susiha ang internet, email, ug password.',
    },
    'Forgot password': {
      tagalog: 'Nakalimutan ang password',
      cebuano: 'Nakalimot sa password',
    },
    'Enter your email to receive a reset link.': {
      tagalog: 'Ilagay ang email para makatanggap ng reset link.',
      cebuano: 'Ibutang ang email para makadawat ug reset link.',
    },
    'Password reset email sent.': {
      tagalog: 'Naipadala na ang password reset email.',
      cebuano: 'Napadala na ang password reset email.',
    },
    'Could not send reset email. Try again.': {
      tagalog: 'Hindi maipadala ang reset email. Subukan muli.',
      cebuano: 'Dili mapadala ang reset email. Sulayi usab.',
    },
    'Send reset email': {
      tagalog: 'Ipadala ang reset email',
      cebuano: 'Ipadala ang reset email',
    },
    'Sending email...': {
      tagalog: 'Nagpapadala ng email...',
      cebuano: 'Nagpadala ug email...',
    },
    'Sign in to send this report': {
      tagalog: 'Mag-sign in para ipadala ang report',
      cebuano: 'Sign in para ipadala ang report',
    },
    'Your scan is already saved on your phone. Sign in when you are ready to send it online.':
        {
      tagalog:
          'Naka-save na ang scan sa phone. Mag-sign in kapag handa ka nang ipadala ito online.',
      cebuano:
          'Na-save na ang scan sa phone. Pag-sign in kung andam na ka ipadala kini online.',
    },
    'Not now, keep it on my phone': {
      tagalog: 'Hindi muna, itago sa phone',
      cebuano: 'Dili sa karon, itago sa phone',
    },
    'Signed in': {tagalog: 'Naka-sign in', cebuano: 'Naka-sign in'},
    'Sign in to restore reports': {
      tagalog: 'Mag-sign in para maibalik ang reports',
      cebuano: 'Sign in para mabalik ang reports',
    },
    'Please enter the farmer name.': {
      tagalog: 'Ilagay ang pangalan ng farmer.',
      cebuano: 'Ibutang ang ngalan sa farmer.',
    },
    'Show password': {
      tagalog: 'Ipakita ang password',
      cebuano: 'Ipakita ang password',
    },
    'Hide password': {
      tagalog: 'Itago ang password',
      cebuano: 'Tagoa ang password',
    },
    'Cancel': {tagalog: 'Kanselahin', cebuano: 'Kanselahon'},
    'Save': {tagalog: 'I-save', cebuano: 'I-save'},
  };

  static String of(String language, String text) {
    if (language == english) return text;
    return translateTreatmentText(language, text) ??
        values[text]?[language] ??
        DiseaseTranslations.descriptions[text]?[language] ??
        DiseaseTranslations.guidance[text]?[language] ??
        text;
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

String _phonePreferredLanguage(String fallback) {
  final locale = Platform.localeName.toLowerCase();
  if (locale.startsWith('fil') || locale.startsWith('tl')) {
    return AppText.tagalog;
  }
  if (locale.startsWith('ceb')) return AppText.cebuano;
  return supportedLanguages.contains(fallback) ? fallback : AppText.english;
}

class AppState extends ChangeNotifier {
  AppState({this.persistSettings = true}) {
    termsAccepted = !persistSettings;
  }

  final bool persistSettings;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<dynamic>? _authSubscription;
  Timer? _connectivityPollTimer;
  Future<void>? _connectivityCheck;
  int _accountGeneration = 0;
  Future<void>? _accountCleanup;

  String language = 'English';
  int tabIndex = 0;
  bool consentEnabled = true;
  bool termsAccepted = false;
  bool isOnline = false;
  bool isDetectingLocation = false;
  double fontScale = 1;
  String farmerName = '';
  String avatarPath = '';
  String farmerLocation = '';
  double? latitude;
  double? longitude;
  String locationNote = 'Location not set';
  String officeEmail = '';
  String deviceId = 'device-local';
  String deviceSignature = 'CC-Device-LOCAL';
  String deviceModel = 'Device';
  String deviceBrand = 'Unknown';
  String androidVersion = 'Unknown';
  bool authConfigured = false;
  String accountEmail = '';
  int checksCount = 0;
  int queuedReportsCount = 0;
  int sentReportsCount = 0;
  double? lastConfidence;

  String get readinessLabel =>
      isOnline ? 'Internet connected' : 'Offline checking ready';
  bool get isSignedIn => accountEmail.trim().isNotEmpty;
  bool get hasCompleteReportProfile =>
      farmerName.trim().isNotEmpty &&
      farmerLocation.trim().isNotEmpty &&
      officeEmail.trim().isNotEmpty;
  List<String> get missingReportProfileFields {
    final missing = <String>[];
    if (farmerName.trim().isEmpty) missing.add('Farmer name');
    if (farmerLocation.trim().isEmpty) missing.add('Farm location');
    if (officeEmail.trim().isEmpty) missing.add('Barangay email');
    return missing;
  }

  Future<void> loadSavedSettings() async {
    if (!persistSettings) return;
    final settings = await DiagnosisRepository.instance.loadSettings();
    language = settings.termsAccepted
        ? settings.language
        : _phonePreferredLanguage(settings.language);
    consentEnabled = settings.consentEnabled;
    termsAccepted = settings.termsAccepted;
    fontScale = settings.fontScale.clamp(.9, 1.3);
    farmerName = settings.farmerName;
    avatarPath = settings.avatarPath;
    farmerLocation = settings.farmerLocation;
    latitude = settings.latitude;
    longitude = settings.longitude;
    locationNote = settings.locationNote;
    officeEmail = settings.officeEmail;
    deviceId = settings.deviceId;
    deviceSignature = settings.deviceSignature;
    deviceModel = settings.deviceModel;
    deviceBrand = settings.deviceBrand;
    androidVersion = settings.androidVersion;
    authConfigured = DiagnosisRepository.instance.isSupabaseConfigured;
    accountEmail = DiagnosisRepository.instance.currentUser?.email ?? '';
    if (!isSignedIn &&
        await DiagnosisRepository.instance.hasLocalAccountData()) {
      await clearSignedOutAccount();
      return;
    }
    if (isSignedIn) {
      await restoreSignedInProfile();
    }
    notifyListeners();
    DiagnosisRepository.instance.syncSettings();
  }

  Future<void> _persistSettings() async {
    if (!persistSettings) return;
    await DiagnosisRepository.instance.saveSettings(
      currentSettings(),
    );
  }

  AppSettings currentSettings() {
    return AppSettings(
      language: language,
      consentEnabled: consentEnabled,
      termsAccepted: termsAccepted,
      fontScale: fontScale,
      farmerName: farmerName,
      avatarPath: avatarPath,
      farmerLocation: farmerLocation,
      latitude: latitude,
      longitude: longitude,
      locationNote: locationNote,
      officeEmail: officeEmail,
      deviceId: deviceId,
      deviceSignature: deviceSignature,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      androidVersion: androidVersion,
    );
  }

  Future<void> startConnectivityMonitor() async {
    unawaited(checkConnectivityAndSync());
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) {
      checkConnectivityAndSync();
    });
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkConnectivityAndSync(),
    );
  }

  Future<void> checkConnectivityAndSync() => _connectivityCheck ??=
      _performConnectivityCheck().whenComplete(() => _connectivityCheck = null);

  Future<void> _performConnectivityCheck() async {
    final result = await Connectivity().checkConnectivity();
    final hasNetwork = result.any((item) => item != ConnectivityResult.none);
    final hasInternet = hasNetwork && await _hasUsableInternet();
    final wasOnline = isOnline;
    isOnline = hasInternet;
    if (wasOnline != isOnline) notifyListeners();
    if (isOnline) {
      await DiagnosisRepository.instance.syncSettings();
      await DiagnosisRepository.instance.syncQueuedReports();
    }
    await refreshStats();
  }

  Future<bool> _hasUsableInternet() async {
    try {
      final lookup = await InternetAddress.lookup('supabase.com')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Pulls fresh counts from SQLite. Call this after any scan, queue, or
  /// sync action so the Home screen's stat cards never go stale.
  Future<void> refreshStats() async {
    final stats = await DiagnosisRepository.instance.getHomeStats();
    checksCount = stats.checks;
    queuedReportsCount = stats.queuedReports;
    sentReportsCount = stats.sentReports;
    lastConfidence = stats.lastConfidence;
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    language = value;
    notifyListeners();
    await _persistSettings();
  }

  void setTab(int value) {
    tabIndex = value;
    notifyListeners();
  }

  Future<void> setConsent(bool value) async {
    consentEnabled = value;
    notifyListeners();
    await _persistSettings();
  }

  Future<void> acceptTermsAgreement() async {
    termsAccepted = true;
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setEmail(String value) async {
    officeEmail = value;
    notifyListeners();
    await _persistSettings();
  }

  Future<void> refreshAuthState() async {
    authConfigured = DiagnosisRepository.instance.isSupabaseConfigured;
    accountEmail = DiagnosisRepository.instance.currentUser?.email ?? '';
    notifyListeners();
  }

  Future<void> startAuthMonitor() async {
    await _authSubscription?.cancel();
    final stream = DiagnosisRepository.instance.authStateChanges;
    if (stream == null) return;
    _authSubscription = stream.listen((authState) async {
      if (authState.event == AuthChangeEvent.signedOut) {
        await clearSignedOutAccount();
        return;
      }
      await _accountCleanup;
      final sessionEmail = authState.session?.user.email ??
          DiagnosisRepository.instance.currentUser?.email ??
          '';
      accountEmail = sessionEmail;
      authConfigured = DiagnosisRepository.instance.isSupabaseConfigured;
      notifyListeners();
      if (sessionEmail.trim().isNotEmpty) {
        await restoreSignedInProfile();
      }
    });
  }

  Future<void> restoreSignedInProfile() async {
    final generation = _accountGeneration;
    final userId = DiagnosisRepository.instance.currentUser?.id;
    if (userId == null) return;
    await DiagnosisRepository.instance.attachLocalRowsToCurrentUser();
    var restoredSettings = false;
    final profile = await DiagnosisRepository.instance.fetchFarmerProfile();
    if (generation != _accountGeneration ||
        userId != DiagnosisRepository.instance.currentUser?.id) {
      return;
    }
    if (profile != null) {
      _applyFarmerProfile(profile);
      language = supportedLanguages.contains(profile.language)
          ? profile.language
          : language;
      consentEnabled = profile.consentEnabled;
      fontScale = profile.fontScale;
      if (avatarPath.isEmpty) {
        try {
          final restoredAvatar = await DiagnosisRepository.instance
              .restoreProfileAvatar(profile.avatarObjectPath);
          if (generation != _accountGeneration ||
              userId != DiagnosisRepository.instance.currentUser?.id) {
            return;
          }
          if (restoredAvatar != null) avatarPath = restoredAvatar;
        } catch (_) {
          // Keep the other settings available if the photo cannot download.
        }
      }
      restoredSettings = true;
    }
    if (!hasCompleteReportProfile) {
      final reportProfile =
          await DiagnosisRepository.instance.fetchLatestReportProfile();
      if (generation != _accountGeneration ||
          userId != DiagnosisRepository.instance.currentUser?.id) {
        return;
      }
      if (reportProfile != null) {
        _applyFarmerProfile(reportProfile, onlyMissing: true);
        restoredSettings = true;
      }
    }
    if (restoredSettings) {
      await _persistSettings();
    }
    await DiagnosisRepository.instance.restoreSignedInReports();
    await refreshStats();
  }

  void _applyFarmerProfile(
    FarmerProfile profile, {
    bool onlyMissing = false,
  }) {
    if ((!onlyMissing || farmerName.trim().isEmpty) &&
        profile.farmerName.trim().isNotEmpty) {
      farmerName = profile.farmerName;
    }
    if ((!onlyMissing || farmerLocation.trim().isEmpty) &&
        profile.farmerLocation.trim().isNotEmpty) {
      farmerLocation = profile.farmerLocation;
      locationNote = 'Restored from account';
    }
    if ((!onlyMissing || latitude == null) && profile.latitude != null) {
      latitude = profile.latitude;
    }
    if ((!onlyMissing || longitude == null) && profile.longitude != null) {
      longitude = profile.longitude;
    }
    if ((!onlyMissing || officeEmail.trim().isEmpty) &&
        profile.officeEmail.trim().isNotEmpty) {
      officeEmail = profile.officeEmail;
    }
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await DiagnosisRepository.instance.signUpWithEmail(
      email: email,
      password: password,
      settings: currentSettings(),
    );
    await refreshAuthState();
    if (!isSignedIn) {
      try {
        await DiagnosisRepository.instance.signInWithEmail(
          email: email,
          password: password,
        );
        await refreshAuthState();
      } catch (_) {
        // Some Supabase projects require email confirmation before sign in.
      }
    }
    if (!isSignedIn) {
      throw const AccountCreatedNeedsSignInException();
    }
    try {
      await DiagnosisRepository.instance.upsertFarmerProfile(currentSettings());
    } catch (_) {
      // The account is already active; profile sync can retry with settings sync.
    }
    await restoreSignedInProfile();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await DiagnosisRepository.instance.signInWithEmail(
      email: email,
      password: password,
    );
    await refreshAuthState();
    await restoreSignedInProfile();
  }

  Future<void> signInWithGoogle() async {
    await DiagnosisRepository.instance.signInWithGoogle();
    await refreshAuthState();
  }

  Future<void> sendPasswordReset(String email) {
    return DiagnosisRepository.instance.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    await DiagnosisRepository.instance.signOut();
    await clearSignedOutAccount();
  }

  /// Also used for server-triggered sign-out and expired persisted sessions.
  Future<void> clearSignedOutAccount() {
    return _accountCleanup ??= _clearSignedOutAccount().whenComplete(() {
      _accountCleanup = null;
    });
  }

  Future<void> _clearSignedOutAccount() async {
    _accountGeneration++;
    final clearedSettings = AppSettings(
      language: language,
      consentEnabled: true,
      termsAccepted: false,
      fontScale: fontScale,
      farmerName: '',
      farmerLocation: '',
      latitude: null,
      longitude: null,
      locationNote: 'Location not set',
      officeEmail: '',
      deviceId: deviceId,
      deviceSignature: deviceSignature,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      androidVersion: androidVersion,
    );
    accountEmail = '';
    farmerName = '';
    avatarPath = '';
    farmerLocation = '';
    latitude = null;
    longitude = null;
    locationNote = 'Location not set';
    officeEmail = '';
    consentEnabled = true;
    termsAccepted = false;
    checksCount = 0;
    queuedReportsCount = 0;
    sentReportsCount = 0;
    lastConfidence = null;
    tabIndex = 0;
    notifyListeners();
    if (persistSettings) {
      await DiagnosisRepository.instance.clearLocalAccountData(clearedSettings);
    }
  }

  Future<void> updateProfile(
      {required String name,
      required String location,
      required String photoPath}) async {
    final changedLocation = location != farmerLocation;
    final updated = AppSettings.fromMap({
      ...currentSettings().toMap(),
      'farmer_name': name.trim(),
      'farmer_location': location.trim(),
      'avatar_path': photoPath,
      if (changedLocation) ...{
        'latitude': '',
        'longitude': '',
        'location_note': 'Manual location'
      },
    });
    if (persistSettings) {
      await DiagnosisRepository.instance
          .saveSettings(updated, syncOnline: false);
    }
    final previousPhoto = avatarPath;
    farmerName = updated.farmerName;
    farmerLocation = updated.farmerLocation;
    avatarPath = photoPath;
    latitude = updated.latitude;
    longitude = updated.longitude;
    locationNote = updated.locationNote;
    notifyListeners();
    if (persistSettings) {
      unawaited(
          DiagnosisRepository.instance.syncSettings().catchError((_) => false));
      if (previousPhoto != photoPath) {
        try {
          await DiagnosisRepository.instance.deleteProfileAvatar(previousPhoto);
        } catch (_) {/* Profile is already saved. */}
      }
    }
  }

  Future<void> setFarmerName(String value) async {
    farmerName = value;
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setFarmerLocation(
    String value, {
    String note = 'Manual location',
    double? latitude,
    double? longitude,
  }) async {
    farmerLocation = value;
    this.latitude = latitude;
    this.longitude = longitude;
    locationNote = note;
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(.9, 1.3);
    notifyListeners();
    await _persistSettings();
  }

  Future<String?> usePhoneLocation() async {
    isDetectingLocation = true;
    locationNote = 'Checking phone location...';
    notifyListeners();
    try {
      final result = await locationChannel.invokeMapMethod<String, Object?>(
        'getCurrentLocation',
      );
      final address = (result?['address'] as String?)?.trim();
      final coordinates = (result?['coordinates'] as String?)?.trim();
      final detectedLatitude = (result?['latitude'] as num?)?.toDouble();
      final detectedLongitude = (result?['longitude'] as num?)?.toDouble();
      final nextLocation = address?.isNotEmpty == true ? address! : coordinates;
      if (nextLocation == null || nextLocation.isEmpty) {
        locationNote = 'Location unavailable. Enter it manually.';
        return locationNote;
      }
      farmerLocation = nextLocation;
      latitude = detectedLatitude;
      longitude = detectedLongitude;
      locationNote = address?.isNotEmpty == true
          ? 'Auto-filled from phone location'
          : 'Auto-filled from phone coordinates';
      await _persistSettings();
      return null;
    } on PlatformException catch (error) {
      locationNote = switch (error.code) {
        'offline' => 'Phone appears offline. Enter location manually.',
        'permission_denied' => 'Location permission was not allowed.',
        'service_disabled' => 'Turn on phone location, then try again.',
        _ => 'Location unavailable. Enter it manually.',
      };
      return locationNote;
    } on MissingPluginException {
      locationNote = 'Phone location is unavailable on this device.';
      return locationNote;
    } finally {
      isDetectingLocation = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    _connectivityPollTimer?.cancel();
    super.dispose();
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
  const CalamansiCareApp({
    super.key,
    this.enableInitialStatsRefresh = true,
    this.enableSettingsPersistence = true,
    this.enableConnectivityMonitor = true,
  });

  final bool enableInitialStatsRefresh;
  final bool enableSettingsPersistence;
  final bool enableConnectivityMonitor;

  @override
  State<CalamansiCareApp> createState() => _CalamansiCareAppState();
}

class _CalamansiCareAppState extends State<CalamansiCareApp>
    with WidgetsBindingObserver {
  late final AppState state =
      AppState(persistSettings: widget.enableSettingsPersistence);
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startupFuture = _loadApp();
  }

  Future<void> _loadApp() async {
    await Future.wait([
      _loadAppData(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
  }

  Future<void> _loadAppData() async {
    if (widget.enableSettingsPersistence) {
      await state.loadSavedSettings();
    }
    if (widget.enableInitialStatsRefresh) {
      await state.refreshStats();
    }
    await state.startAuthMonitor();
    if (widget.enableConnectivityMonitor) {
      await state.startConnectivityMonitor();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appLifecycleState) {
    if (appLifecycleState == AppLifecycleState.resumed &&
        widget.enableConnectivityMonitor) {
      state.checkConnectivityAndSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

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
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(state.fontScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: CcColors.bg,
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.fromSeed(
                seedColor: CcColors.green,
                primary: CcColors.green,
                secondary: CcColors.orange,
                surface: CcColors.card,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: CcColors.dark,
                elevation: 10,
                insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: CcColors.lime.withValues(alpha: .55)),
                ),
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 32,
                  height: 1.04,
                  fontWeight: FontWeight.w700,
                  color: CcColors.dark,
                ),
                headlineMedium: TextStyle(
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  color: CcColors.dark,
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: CcColors.ink,
                ),
                titleMedium: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: CcColors.ink,
                ),
                bodyLarge: TextStyle(
                  fontSize: 14,
                  height: 1.38,
                  color: CcColors.ink,
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CcColors.ink,
                ),
              ),
            ),
            home: FutureBuilder<void>(
              future: _startupFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const StartupLoadingScreen();
                }
                if (widget.enableSettingsPersistence && state.termsAccepted) {
                  return const MainShell();
                }
                return const WelcomeScreen();
              },
            ),
          ),
        );
      },
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const screens = [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
    CommunityFeedScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return screens[state.tabIndex];
  }
}
