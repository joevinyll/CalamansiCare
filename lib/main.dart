import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'data/diagnosis_repository.dart';
import 'disease_classifier.dart';

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
  'Nutrient Deficiency',
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
  debugPrint('CalamansiCare account error: $error');
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
  switch (disease) {
    case 'Healthy Fruit':
    case 'Healthy Leaf':
      return const DiseaseGuidance(
        kind: 'Healthy plant',
        recommendation:
            'Continue weekly checks, proper watering, sanitation, and balanced nutrition.',
        conventionalTreatment:
            'No insecticide, fungicide, or bactericide is needed. Do not spray a healthy tree unless a pest or disease is confirmed.',
        organicTreatment:
            'Keep the tree healthy with proper watering, compost or balanced citrus nutrition, pruning for airflow, and weekly inspection of leaves, fruit, and stems.',
        prevention:
            'Use clean planting materials, sanitize pruning tools, remove fallen diseased debris, and monitor nearby trees for early symptoms.',
      );
    case 'HLB (Greening)':
      return const DiseaseGuidance(
        kind: 'Bacterial disease',
        recommendation:
            'Isolate suspicious trees and ask an agriculture technician for field confirmation before removing trees.',
        conventionalTreatment:
            'There is no curative spray for HLB. If Asian citrus psyllids are present, use only labeled psyllid insecticides under technician guidance to reduce spread. Severely infected trees may need removal after confirmation.',
        organicTreatment:
            'Use clean disease-free seedlings, remove or isolate confirmed infected trees, control ants that protect sap-sucking pests, prune weak branches, improve irrigation, and keep the tree nutritionally balanced.',
        prevention:
            'Monitor new flush for psyllids, avoid moving infected seedlings or budwood, report suspected HLB, and protect young trees from psyllid access where possible.',
      );
    case 'Citrus Canker':
      return const DiseaseGuidance(
        kind: 'Bacterial disease',
        recommendation:
            'Prune badly affected parts with disinfected tools and avoid working on wet trees to limit spread.',
        conventionalTreatment:
            'Use a labeled copper-based bactericide/fungicide only as a protectant and only after field confirmation. It helps reduce new infection but will not heal existing spots.',
        organicTreatment:
            'Prune light infections, remove fallen infected leaves and fruit, disinfect tools between cuts, avoid overhead watering, and do not handle trees while leaves are wet.',
        prevention:
            'Reduce leaf wounds, manage citrus leafminer if present, plant windbreaks where practical, and avoid moving infected plant material.',
      );
    case 'Anthracnose':
      return const DiseaseGuidance(
        kind: 'Fungal disease',
        recommendation:
            'Remove infected plant material, improve airflow, and confirm the disease before applying any spray.',
        conventionalTreatment:
            'If anthracnose was severe or confirmed, use a labeled copper fungicide or other locally approved citrus fungicide as a protectant. Follow the label and avoid spraying during very hot weather.',
        organicTreatment:
            'Prune dead twigs and infected branches, remove fallen diseased material, improve sunlight and airflow, avoid overhead watering, and reduce plant stress.',
        prevention:
            'Keep the canopy open, sanitize pruning tools, maintain balanced nutrition, and inspect after long wet periods.',
      );
    case 'Melanose':
      return const DiseaseGuidance(
        kind: 'Fungal disease',
        recommendation:
            'Remove dead twigs and dead wood because melanose commonly survives there.',
        conventionalTreatment:
            'Use a labeled copper fungicide protectively when disease pressure is high, especially during wet periods. Copper protects new growth and fruit but does not repair old damage.',
        organicTreatment:
            'Prune and remove dead wood, collect fallen infected debris, improve airflow, and keep the tree vigorous with proper water and nutrition.',
        prevention:
            'Regularly remove dead twigs, avoid dense canopy growth, and monitor fruit during rainy weather.',
      );
    case 'Citrus Scab':
      return const DiseaseGuidance(
        kind: 'Fungal disease',
        recommendation:
            'Protect new leaves and young fruit early; old scab marks will not disappear.',
        conventionalTreatment:
            'Use labeled citrus fungicides such as copper-based protectants or other technician-approved fungicides at the correct early-growth timing.',
        organicTreatment:
            'Prune infected shoots, remove badly affected fruit, improve airflow, avoid overhead watering, and use organic-approved copper only if allowed and needed.',
        prevention:
            'Inspect spring flush and young fruit, reduce leaf wetness, sanitize pruning tools, and remove carryover infected material.',
      );
    case 'Brown Spot':
      return const DiseaseGuidance(
        kind: 'Fungal disease',
        recommendation:
            'Remove infected plant material, improve airflow, and consult a technician before applying any approved treatment.',
        conventionalTreatment:
            'Use labeled copper fungicide or other locally approved citrus fungicide preventively when brown spot is confirmed. Rotate products as advised to reduce resistance risk.',
        organicTreatment:
            'Remove infected leaves and twigs, prune dense canopy, improve drainage and airflow, avoid overhead watering, and avoid excessive nitrogen that causes tender flush.',
        prevention:
            'Monitor new flush and young fruit, reduce long leaf-wetness periods, and remove diseased debris from the farm.',
      );
    case 'Nutrient Deficiency':
      return const DiseaseGuidance(
        kind: 'Nutritional condition',
        recommendation:
            'Check soil and fertiliser practice, then correct nutrients with guidance from an agriculture technician.',
        conventionalTreatment:
            'Do not use insecticide or fungicide for nutrient deficiency. Use soil or leaf testing, correct soil pH if needed, and apply the proper citrus fertilizer or micronutrient product.',
        organicTreatment:
            'Improve soil health with compost, mulch kept away from the trunk, proper watering, drainage correction, and organic citrus fertilizer where available.',
        prevention:
            'Avoid overwatering, maintain drainage, fertilize on schedule, and inspect roots and soil pH when yellowing continues.',
      );
    default:
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
    case 'Nutrient Deficiency':
      return 'A nutrition problem, not an infection. Leaves may yellow or look weak when the tree lacks nutrients, has root stress, or has soil problems.';
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
    'Shared to barangay: name, location, diagnosis, and photo. Shared to other farmers: diagnosis, photo, and general area only.':
        {
      tagalog:
          'Ipinapadala sa barangay: pangalan, lokasyon, diagnosis, at larawan. Nakikita ng ibang farmer: diagnosis, larawan, at pangkalahatang lugar lamang.',
      cebuano:
          'Ipadala sa barangay: ngalan, lokasyon, diagnosis, ug hulagway. Makita sa ubang farmer: diagnosis, hulagway, ug kinatibuk-ang lugar lamang.',
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
    return values[text]?[language] ??
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

  String language = 'English';
  int tabIndex = 0;
  bool consentEnabled = true;
  bool termsAccepted = false;
  bool isOnline = false;
  bool isDetectingLocation = false;
  double fontScale = 1;
  String farmerName = '';
  String farmerLocation = '';
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
    farmerLocation = settings.farmerLocation;
    locationNote = settings.locationNote;
    officeEmail = settings.officeEmail;
    deviceId = settings.deviceId;
    deviceSignature = settings.deviceSignature;
    deviceModel = settings.deviceModel;
    deviceBrand = settings.deviceBrand;
    androidVersion = settings.androidVersion;
    authConfigured = DiagnosisRepository.instance.isSupabaseConfigured;
    accountEmail = DiagnosisRepository.instance.currentUser?.email ?? '';
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
      farmerLocation: farmerLocation,
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
    await checkConnectivityAndSync();
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) {
      checkConnectivityAndSync();
    });
  }

  Future<void> checkConnectivityAndSync() async {
    final result = await Connectivity().checkConnectivity();
    final hasNetwork = result.any((item) => item != ConnectivityResult.none);
    final hasInternet = hasNetwork && await _hasUsableInternet();
    final wasOnline = isOnline;
    isOnline = hasInternet;
    notifyListeners();
    if (isOnline) {
      await DiagnosisRepository.instance.syncSettings();
      await DiagnosisRepository.instance.syncQueuedReports();
      await refreshStats();
      if (!wasOnline) notifyListeners();
    }
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

  void setLanguage(String value) {
    language = value;
    notifyListeners();
    _persistSettings();
  }

  void setTab(int value) {
    tabIndex = value;
    notifyListeners();
  }

  void setConsent(bool value) {
    consentEnabled = value;
    notifyListeners();
    _persistSettings();
  }

  Future<void> acceptTermsAgreement() async {
    termsAccepted = true;
    notifyListeners();
    await _persistSettings();
  }

  void setEmail(String value) {
    officeEmail = value;
    notifyListeners();
    _persistSettings();
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
    var restoredSettings = false;
    final profile = await DiagnosisRepository.instance.fetchFarmerProfile();
    if (profile != null) {
      _applyFarmerProfile(profile);
      language = supportedLanguages.contains(profile.language)
          ? profile.language
          : language;
      consentEnabled = profile.consentEnabled;
      fontScale = profile.fontScale;
      restoredSettings = true;
    }
    if (!hasCompleteReportProfile) {
      final reportProfile =
          await DiagnosisRepository.instance.fetchLatestReportProfile();
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
    final clearedSettings = AppSettings(
      language: language,
      consentEnabled: true,
      termsAccepted: false,
      fontScale: fontScale,
      farmerName: '',
      farmerLocation: '',
      locationNote: 'Location not set',
      officeEmail: '',
      deviceId: deviceId,
      deviceSignature: deviceSignature,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      androidVersion: androidVersion,
    );
    try {
      await DiagnosisRepository.instance.signOut();
    } catch (_) {
      // Continue clearing local data so another account cannot see it.
    }
    await DiagnosisRepository.instance.clearLocalAccountData(clearedSettings);
    accountEmail = '';
    farmerName = '';
    farmerLocation = '';
    locationNote = 'Location not set';
    officeEmail = '';
    consentEnabled = true;
    termsAccepted = false;
    checksCount = 0;
    queuedReportsCount = 0;
    sentReportsCount = 0;
    lastConfidence = null;
    notifyListeners();
  }

  void setFarmerName(String value) {
    farmerName = value;
    notifyListeners();
    _persistSettings();
  }

  void setFarmerLocation(String value, {String note = 'Manual location'}) {
    farmerLocation = value;
    locationNote = note;
    notifyListeners();
    _persistSettings();
  }

  void setFontScale(double value) {
    fontScale = value.clamp(.9, 1.3);
    notifyListeners();
    _persistSettings();
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
      final nextLocation = address?.isNotEmpty == true ? address! : coordinates;
      if (nextLocation == null || nextLocation.isEmpty) {
        locationNote = 'Location unavailable. Enter it manually.';
        return locationNote;
      }
      farmerLocation = nextLocation;
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

class _CalamansiCareAppState extends State<CalamansiCareApp> {
  late final AppState state =
      AppState(persistSettings: widget.enableSettingsPersistence);
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _loadApp();
  }

  Future<void> _loadApp() async {
    await Future.wait([
      _loadAppData(),
      Future<void>.delayed(const Duration(seconds: 4)),
    ]);
  }

  Future<void> _loadAppData() async {
    if (widget.enableSettingsPersistence) {
      await state.loadSavedSettings();
    }
    await state.startAuthMonitor();
    if (widget.enableConnectivityMonitor) {
      await state.startConnectivityMonitor();
    }
    if (widget.enableInitialStatsRefresh) {
      await state.refreshStats();
    }
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
            showSemanticsDebugger: false,
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
                    borderRadius: BorderRadius.circular(14),
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
                  fontWeight: FontWeight.w900,
                ),
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(
                  fontSize: 32,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  color: CcColors.dark,
                ),
                headlineMedium: TextStyle(
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: CcColors.dark,
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: CcColors.ink,
                ),
                titleMedium: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: CcColors.ink,
                ),
                bodyLarge: TextStyle(
                  fontSize: 14,
                  height: 1.38,
                  color: CcColors.ink,
                ),
                bodyMedium: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: CcColors.muted,
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

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CcColors.hero,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(onDark: true, centered: true),
                const SizedBox(height: 38),
                Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CcColors.lime.withValues(alpha: .55),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        color: CcColors.lime,
                        backgroundColor: CcColors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  context.t('Preparing CalamansiCare'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('Loading saved settings and reports.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
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

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: CcColors.hero,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: HeroLeafPainter()),
                      ),
                      Positioned(
                        top: 8,
                        right: 24,
                        child: OfflinePill(label: state.readinessLabel),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CalamansiCare',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'AI disease detection and treatment guide for calamansi farmers.',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white),
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
                    color: CcColors.bgAlt,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t(
                          'Choose language / Pumili ng wika / Pili og pinulongan',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: LanguageChoice(
                              language: supportedLanguages[0],
                              selected: state.language == supportedLanguages[0],
                              onSelected: () =>
                                  state.setLanguage(supportedLanguages[0]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LanguageChoice(
                              language: supportedLanguages[1],
                              selected: state.language == supportedLanguages[1],
                              onSelected: () =>
                                  state.setLanguage(supportedLanguages[1]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: LanguageChoice(
                                language: supportedLanguages[2],
                                selected:
                                    state.language == supportedLanguages[2],
                                onSelected: () =>
                                    state.setLanguage(supportedLanguages[2]),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Start plant check',
                        icon: Icons.eco,
                        onPressed: () async {
                          final accepted =
                              await ensureTermsAgreementAccepted(context);
                          if (accepted && context.mounted) {
                            replaceWith(context, const MainShell());
                          }
                        },
                      ),
                      if (!state.isSignedIn) ...[
                        const SizedBox(height: 10),
                        OutlineAction(
                          label: 'Sign in or create account',
                          icon: Icons.account_circle_outlined,
                          onTap: () => go(context, const AuthLandingScreen()),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            context
                                .t('You can check plants without an account.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CcColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
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

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen> {
  AuthFormMode _mode = AuthFormMode.signIn;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ScreenFrame(
      showNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Account',
            subtitle:
                'Sign in to sync reports and restore saved data after reinstalling.',
            trailing: IconButton(
              tooltip: context.t('Close'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isSignedIn
                ? SectionCard(
                    title: 'Account connected',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.accountEmail,
                          style: const TextStyle(
                            color: CcColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                    ),
                  )
                : AuthPanel(
                    mode: _mode,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                  ),
          ),
          if (!isKeyboardOpen) ...[
            const SizedBox(height: 14),
            const NoticeCard(
              text:
                  'You can still scan offline. Sign in is only needed before sending reports online.',
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Continue offline',
              icon: Icons.eco_rounded,
              onPressed: () => replaceWith(context, const MainShell()),
            ),
          ],
        ],
      ),
    );
  }
}

enum AuthFormMode { signIn, create }

class AuthPanel extends StatelessWidget {
  const AuthPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.authConfigured) {
      return const SectionCard(
        title: 'Account',
        child: NoticeCard(
          text:
              'Supabase is not configured on this build. Add env keys before using accounts.',
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          AuthModeToggle(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Sign in with Google',
            icon: Icons.g_mobiledata_rounded,
            onTap: () async {
              try {
                await state.signInWithGoogle();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t(
                          'Google sign-in opened. Complete it in the browser.',
                        ),
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t(
                          'Google sign-in is not ready yet. Check Supabase Google setup.',
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          AuthFormContent(
            mode: mode,
            onSwitchMode: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle(
      {super.key, required this.mode, required this.onChanged});

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AuthFormMode>(
      segments: [
        ButtonSegment(
          value: AuthFormMode.signIn,
          label: Text(context.t('Sign in')),
          icon: const Icon(Icons.login_rounded),
        ),
        ButtonSegment(
          value: AuthFormMode.create,
          label: Text(context.t('Create account')),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({super.key, required this.mode});

  final AuthFormMode mode;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class AuthFormContent extends StatefulWidget {
  const AuthFormContent({
    super.key,
    required this.mode,
    this.onSwitchMode,
  });

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode>? onSwitchMode;

  @override
  State<AuthFormContent> createState() => _AuthFormContentState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == AuthFormMode.create;
    return ScreenFrame(
      showNav: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: isCreate ? 'Create account' : 'Sign in',
              subtitle: isCreate
                  ? 'Use this account to restore synced reports later.'
                  : 'Use your account to sync and restore reports.',
              trailing: IconButton(
                tooltip: context.t('Back'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 16),
            AuthFormContent(mode: widget.mode),
          ],
        ),
      ),
    );
  }
}

class _AuthFormContentState extends State<AuthFormContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _officeEmailController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  bool get _isCreate => widget.mode == AuthFormMode.create;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    _nameController.text =
        _nameController.text.isEmpty ? state.farmerName : _nameController.text;
    _locationController.text = _locationController.text.isEmpty
        ? state.farmerLocation
        : _locationController.text;
    _officeEmailController.text = _officeEmailController.text.isEmpty
        ? state.officeEmail
        : _officeEmailController.text;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _officeEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppScope.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('Enter an email and a password with at least 6 letters.'),
          ),
        ),
      );
      return;
    }
    if (_isCreate &&
        (_nameController.text.trim().isEmpty ||
            _locationController.text.trim().isEmpty ||
            _officeEmailController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('Please complete name, farm location, and barangay email.'),
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_isCreate) {
        state.setFarmerName(_nameController.text.trim());
        state.setFarmerLocation(_locationController.text.trim());
        state.setEmail(_officeEmailController.text.trim());
        await state.createAccount(email: email, password: password);
      } else {
        await state.signIn(email: email, password: password);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                _isCreate
                    ? (state.isSignedIn
                        ? 'Account created and signed in.'
                        : 'Please check your email, then sign in.')
                    : 'Signed in successfully.',
              ),
            ),
          ),
        );
        Navigator.maybePop(context);
      }
    } on AccountCreatedNeedsSignInException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Please check your email, then sign in.')),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(accountErrorMessage(error)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          title: _isCreate ? 'Farmer account' : 'Account details',
          child: Column(
            children: [
              if (_isCreate) ...[
                AuthTextField(
                  controller: _nameController,
                  label: 'Farmer name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                AuthTextField(
                  controller: _locationController,
                  label: 'Farm location',
                  icon: Icons.place_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                AuthTextField(
                  controller: _officeEmailController,
                  label: 'Barangay email',
                  icon: Icons.mark_email_unread_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
              ],
              AuthTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  tooltip: context.t(
                    _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (!_isCreate) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => go(context, const ForgotPasswordScreen()),
                    child: Text(context.t('Forgot password?')),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _isSubmitting
              ? (_isCreate ? 'Creating account...' : 'Signing in...')
              : (_isCreate ? 'Create account' : 'Sign in'),
          icon:
              _isCreate ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.onSwitchMode == null
              ? null
              : () => widget.onSwitchMode!(
                    _isCreate ? AuthFormMode.signIn : AuthFormMode.create,
                  ),
          child: Text(
            context.t(
              _isCreate
                  ? 'Already have an account? Sign in'
                  : 'New here? Create account',
            ),
          ),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await AppScope.of(context).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Password reset email sent.')),
          ),
        );
        Navigator.maybePop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Could not send reset email. Try again.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Forgot password',
            subtitle: 'Enter your email to receive a reset link.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Email address',
            child: AuthTextField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: _isSending ? 'Sending email...' : 'Send reset email',
            icon: Icons.mark_email_read_outlined,
            isLoading: _isSending,
            onPressed: _isSending ? null : _send,
          ),
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: context.t(label),
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class LanguageChoice extends StatelessWidget {
  const LanguageChoice({
    super.key,
    required this.language,
    required this.selected,
    required this.onSelected,
  });

  final String language;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onSelected,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? CcColors.green : Colors.white,
          foregroundColor: selected ? Colors.white : CcColors.ink,
          side: const BorderSide(color: CcColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: Text(language, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    return screens[state.tabIndex];
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: timeGreetingKey(),
              subtitle: 'Ready to check leaves and fruits in the field.',
              pill: state.readinessLabel,
            ),
            const SizedBox(height: 16),
            DarkActionCard(
              title: 'New disease check',
              subtitle: 'Run AI diagnosis offline using your phone camera.',
              buttonLabel: 'Capture',
              secondaryLabel: 'Upload',
              onPrimary: () => go(context, const CaptureScreen()),
              onSecondary: () => selectLeafImage(context, ImageSource.gallery),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Field summary',
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      value: '${state.checksCount}',
                      label: 'Checks',
                      onTap: () => showFieldSummaryOverlay(
                        context,
                        FieldSummaryKind.checks,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      value: '${state.queuedReportsCount}',
                      label: 'Queued',
                      valueColor: CcColors.orange,
                      onTap: () => showFieldSummaryOverlay(
                        context,
                        FieldSummaryKind.queued,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      value: '${state.sentReportsCount}',
                      label: 'Sent',
                      onTap: () => showFieldSummaryOverlay(
                        context,
                        FieldSummaryKind.sent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Supported conditions',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: diseaseLabels
                    .map(
                      (item) => SmallPill(
                        item,
                        onTap: () => showDiseaseInfoOverlay(context, item),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Barangay reporting',
              child: OutlineAction(
                label: 'Open barangay reports',
                icon: Icons.map_outlined,
                onTap: () => go(context, const BarangayReportsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FieldSummaryKind { checks, queued, sent }

String _fieldSummaryTitle(FieldSummaryKind kind) {
  return switch (kind) {
    FieldSummaryKind.checks => 'Checks details',
    FieldSummaryKind.queued => 'Queued reports',
    FieldSummaryKind.sent => 'Sent reports',
  };
}

String _fieldSummaryEmptyText(FieldSummaryKind kind) {
  return switch (kind) {
    FieldSummaryKind.checks => 'No checks yet.',
    FieldSummaryKind.queued => 'No reports waiting.',
    FieldSummaryKind.sent => 'No sent reports yet.',
  };
}

bool _matchesFieldSummaryKind(
  FieldSummaryKind kind,
  Map<String, Object?> row,
) {
  final status = row['report_status'];
  return switch (kind) {
    FieldSummaryKind.checks => true,
    FieldSummaryKind.queued => status == reportStatusWaitingInternet ||
        status == reportStatusSyncing ||
        status == reportStatusFailedRetry,
    FieldSummaryKind.sent => status == reportStatusSynced,
  };
}

void showFieldSummaryOverlay(BuildContext context, FieldSummaryKind kind) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: DiagnosisRepository.instance.getRecentDiagnoses(),
              builder: (context, snapshot) {
                final rows = (snapshot.data ?? const <Map<String, Object?>>[])
                    .where((row) => _matchesFieldSummaryKind(kind, row))
                    .toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(_fieldSummaryTitle(kind)),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('Close'),
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (rows.isEmpty)
                      NoticeCard(text: _fieldSummaryEmptyText(kind))
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return FieldSummaryDetailTile(
                              row: rows[index],
                              kind: kind,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class FieldSummaryDetailTile extends StatelessWidget {
  const FieldSummaryDetailTile({
    super.key,
    required this.row,
    required this.kind,
  });

  final Map<String, Object?> row;
  final FieldSummaryKind kind;

  @override
  Widget build(BuildContext context) {
    final disease = '${row['disease'] ?? 'Unknown'}';
    final confidence = ((row['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final createdAt = '${row['created_at'] ?? ''}';
    final queuedAt = row['report_created_at'] as String?;
    final syncedAt = row['report_synced_at'] as String?;
    final reportEmail = row['report_email'] as String?;
    final status = _reportStatusLabel(row['report_status'] as String?);
    final dateLabel = switch (kind) {
      FieldSummaryKind.checks => 'Scan date',
      FieldSummaryKind.queued => 'Report date',
      FieldSummaryKind.sent => 'Sent',
    };
    final dateValue = switch (kind) {
      FieldSummaryKind.checks =>
        createdAt.isEmpty ? '---' : _formatHistoryDateTime(createdAt),
      FieldSummaryKind.queued =>
        queuedAt == null ? '---' : _formatHistoryDateTime(queuedAt),
      FieldSummaryKind.sent =>
        syncedAt == null ? '---' : _formatHistoryDateTime(syncedAt),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CcColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(disease),
            style: const TextStyle(
              color: CcColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Confidence',
            value: '${confidence.toStringAsFixed(0)}%',
          ),
          InfoRow(label: 'Status', value: status),
          if (kind != FieldSummaryKind.checks)
            InfoRow(label: 'Target email', value: reportEmail ?? '---'),
          InfoRow(label: dateLabel, value: dateValue),
        ],
      ),
    );
  }
}

void showDiseaseInfoOverlay(BuildContext context, String disease) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 650),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(disease),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GuideTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Description',
                  text: diseaseDescriptionFor(disease),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    },
  );
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
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CcColors.limeLight, width: 3),
                      ),
                    ),
                  ),
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
              onPressed: () => selectLeafImage(context, ImageSource.camera),
              child: const Icon(Icons.camera_alt_rounded, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => selectLeafImage(context, ImageSource.gallery),
            icon: const SizedBox.shrink(),
            label: Text(context.t('Choose from gallery')),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .14),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckingScreen extends StatefulWidget {
  const CheckingScreen(
      {super.key, required this.imageFile, required this.fromGallery});

  final XFile imageFile;
  final bool fromGallery;

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  String? _error;
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _classifyImage();
  }

  Future<void> _classifyImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final prediction =
          await DiseaseClassifier.instance.classify(bytes, diseaseLabels);

      if (confidenceTier(prediction.confidence) != ConfidenceTier.accepted) {
        // Below the report confidence threshold: don't save this as a
        // diagnosis, so unclear scans do not appear in History.
        if (mounted) {
          setState(() {
            _error = lowConfidenceRejectionMessage;
            _isAnalyzing = false;
          });
        }
        return;
      }

      final diagnosisId = await DiagnosisRepository.instance.saveDiagnosis(
        disease: prediction.label,
        confidence: prediction.confidence,
        imagePath: widget.imageFile.path,
      );
      if (mounted) {
        await AppScope.of(context).refreshStats();
      }
      if (mounted) {
        replaceWith(
            context,
            DiagnosisScreen(
                prediction: prediction,
                imageFile: widget.imageFile,
                diagnosisId: diagnosisId));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Checking image',
            subtitle: 'Offline model is analyzing image features.',
          ),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 285,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: CcColors.softStrong,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LeafImage(
                              imageFile: widget.imageFile,
                              height: 250,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 18,
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            borderRadius: BorderRadius.circular(99),
                            color: CcColors.lime,
                            backgroundColor: CcColors.softStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionCard(
                    title: _error == null
                        ? 'Analyzing visual patterns'
                        : 'Unable to check image',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error == null) ...[
                          Center(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                color: _isAnalyzing
                                    ? CcColors.green
                                    : CcColors.lime,
                                backgroundColor: CcColors.softStrong,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.t('Please wait while AI checks the photo.'),
                            style: const TextStyle(
                              color: CcColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'Checking image color, spots, texture, and shape.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const SmallPill('Offline model active'),
                        ] else ...[
                          Text(
                            context.t(_error!),
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: CcColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                replaceWith(context, const CaptureScreen()),
                            child: Text(context.t('Scan Again')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Cancel',
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen(
      {super.key,
      required this.prediction,
      required this.imageFile,
      required this.diagnosisId});

  final DiseasePrediction prediction;
  final XFile imageFile;
  final int diagnosisId;

  @override
  Widget build(BuildContext context) {
    final shouldRetakePhoto =
        prediction.confidence < reportAcceptanceConfidenceThreshold;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Diagnosis result',
            subtitle: 'Review before preparing the report.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                Container(
                  width: double.infinity,
                  height: 190,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CcColors.softStrong,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LeafImage(
                            imageFile: imageFile,
                            width: double.infinity,
                            height: 160,
                          ),
                        ),
                      ),
                      if (!shouldRetakePhoto)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: CcColors.green.withValues(alpha: .35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              context.t('Analyzed photo'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (shouldRetakePhoto)
                  const RetakePhotoNoticeCard()
                else ...[
                  SectionCard(
                    title: 'Likely disease',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SmallPill(
                          'Likely disease',
                          color: CcColors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.t(prediction.label),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: CcColors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: prediction.confidence.clamp(0, 1),
                            minHeight: 8,
                            color: CcColors.green,
                            backgroundColor: CcColors.softStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Uneven yellowing and blotchy leaf pattern match common HLB symptoms.',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shouldRetakePhoto)
            PrimaryButton(
              label: 'Scan Again',
              icon: Icons.camera_alt_rounded,
              onPressed: () => replaceWith(context, const CaptureScreen()),
            )
          else
            PrimaryButton(
              label: 'View treatment guide',
              icon: Icons.medical_services_outlined,
              onPressed: () => go(
                  context,
                  TreatmentScreen(
                      disease: prediction.label,
                      diagnosisId: diagnosisId,
                      confidence: prediction.confidence)),
            ),
        ],
      ),
    );
  }
}

class LeafImage extends StatelessWidget {
  const LeafImage({
    super.key,
    required this.imageFile,
    required this.width,
    required this.height,
  });

  final XFile imageFile;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: imageFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => PlantIllustration(size: height),
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

Future<void> selectLeafImage(BuildContext context, ImageSource source) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (file != null && context.mounted) {
      go(
        context,
        CheckingScreen(
          imageFile: file,
          fromGallery: source == ImageSource.gallery,
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open ${source == ImageSource.camera ? 'the camera' : 'the photo gallery'}: $error',
          ),
        ),
      );
    }
  }
}

class TreatmentScreen extends StatelessWidget {
  const TreatmentScreen({
    super.key,
    required this.disease,
    required this.diagnosisId,
    this.confidence,
  });

  final String disease;
  final int diagnosisId;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceFor(disease);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Treatment guide',
            subtitle: 'Prioritize containment and expert confirmation.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          PriorityCard(message: guidance.recommendation),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SectionCard(
                    title: 'Disease type',
                    child: Text(
                      '${context.t(disease)} is classified as ${guidance.kind.toLowerCase()}.',
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.4, color: CcColors.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GuideTile(
                    icon: Icons.science_outlined,
                    title: 'Conventional treatment',
                    text: guidance.conventionalTreatment,
                  ),
                  GuideTile(
                    icon: Icons.spa_outlined,
                    title: 'Organic / natural management',
                    text: guidance.organicTreatment,
                  ),
                  GuideTile(
                    icon: Icons.shield_outlined,
                    title: 'Prevention',
                    text: guidance.prevention,
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Prepare report',
            icon: Icons.description_outlined,
            onPressed: () => go(
              context,
              ReportPreviewScreen(
                disease: disease,
                diagnosisId: diagnosisId,
                confidence: confidence,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.disease,
    required this.diagnosisId,
    this.confidence,
  });

  final String disease;
  final int diagnosisId;
  final double? confidence;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Report preview',
            subtitle: 'Prepared for barangay agriculture review.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barangay Agriculture Office',
            child: Column(
              children: [
                InfoRow(
                  label: 'Farmer',
                  value: state.farmerName.trim().isEmpty
                      ? '---'
                      : state.farmerName,
                ),
                InfoRow(
                  label: 'Location',
                  value: state.farmerLocation.trim().isEmpty
                      ? '---'
                      : state.farmerLocation,
                ),
                const InfoRow(label: 'Plant part', value: 'Leaf'),
                InfoRow(label: 'Diagnosis', value: widget.disease),
                InfoRow(
                  label: 'Confidence',
                  value: widget.confidence == null
                      ? '-'
                      : '${(widget.confidence! * 100).toStringAsFixed(0)}%',
                ),
                const InfoRow(label: 'Status', value: 'Ready to send'),
                InfoRow(
                  label: 'Email',
                  value: state.officeEmail.trim().isEmpty
                      ? '---'
                      : state.officeEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const NoticeCard(
            text:
                'Shared to barangay: name, location, diagnosis, and photo. Shared to other farmers: diagnosis, photo, and general area only.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CcColors.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: state.consentEnabled,
                  onChanged: (value) => state.setConsent(value ?? false),
                  activeColor: CcColors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('Allow sending diagnosis details'),
                    style: const TextStyle(
                      color: CcColors.green,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: isSubmitting ? 'Sending report...' : 'Report',
            icon: Icons.outbox_rounded,
            color: CcColors.hero,
            isLoading: isSubmitting,
            onPressed: state.consentEnabled && !isSubmitting
                ? () async {
                    final isSignedIn = await ensureAccountReady(context);
                    if (!isSignedIn || !context.mounted) return;
                    final canSend = await ensureReportProfileComplete(context);
                    if (!canSend || !context.mounted) return;
                    setState(() => isSubmitting = true);
                    try {
                      await DiagnosisRepository.instance.queueReport(
                        diagnosisId: widget.diagnosisId,
                        officeEmail: state.officeEmail,
                        consent: state.consentEnabled,
                        settings: state.currentSettings(),
                      );
                      await state.checkConnectivityAndSync();
                      if (context.mounted) {
                        final sentNow = state.queuedReportsCount == 0;
                        if (sentNow) {
                          await showReportSentDialog(context);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t(
                                  'Report is pending and waiting for internet connection.',
                                ),
                              ),
                            ),
                          );
                        }
                        if (!context.mounted) return;
                        go(context, const OfflineQueueScreen());
                      }
                    } finally {
                      if (mounted) setState(() => isSubmitting = false);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

Future<bool> ensureReportProfileComplete(BuildContext context) async {
  final state = AppScope.of(context);
  if (state.hasCompleteReportProfile) return true;
  final missingFields = state.missingReportProfileFields;

  final editSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Complete farmer information first')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Please complete this information before sending:'),
            ),
            const SizedBox(height: 10),
            for (final field in missingFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- ${context.t(field)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('Edit settings')),
          ),
        ],
      );
    },
  );

  if (editSettings == true && context.mounted) {
    state.setTab(2);
    replaceWith(context, const MainShell());
  }
  return false;
}

Future<bool> ensureAccountReady(BuildContext context) async {
  final state = AppScope.of(context);
  await state.refreshAuthState();
  if (!context.mounted) return false;
  if (state.isSignedIn) return true;

  final openAuth = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Sign in to send this report')),
        content: Text(
          context.t(
            'Your scan is already saved on your phone. Sign in when you are ready to send it online.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('Not now, keep it on my phone')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('Sign in')),
          ),
        ],
      );
    },
  );

  if (openAuth == true && context.mounted) {
    go(context, const AuthLandingScreen());
  }
  return false;
}

Future<void> showReportSentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Report sent')),
        content: Text(context.t('Your report was sent to the barangay.')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('OK')),
          ),
        ],
      );
    },
  );
}

Future<bool> ensureTermsAgreementAccepted(BuildContext context) async {
  final state = AppScope.of(context);
  if (state.termsAccepted) return true;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Terms of agreement')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(
                  'Before using CalamansiCare, please acknowledge how the app handles report information.',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const TermsAgreementPoint(
                title: 'What we collect',
                body:
                    'Device signature, model, Android version, farmer name, farm location, barangay email, diagnosis result, confidence score, report date, and report image when you send a report.',
              ),
              const TermsAgreementPoint(
                title: 'How we use it',
                body:
                    'This information is used to save reports offline, avoid duplicate uploads, send reports to the barangay office, and show community disease alerts.',
              ),
              const TermsAgreementPoint(
                title: 'Offline and online storage',
                body:
                    'Reports are saved locally on this phone first. When internet is available, approved reports are uploaded to Supabase and may be emailed to the target barangay email.',
              ),
              const TermsAgreementPoint(
                title: 'Farmer responsibility',
                body:
                    'The app gives guidance only. Confirm serious disease findings with the local agriculture office before applying treatment.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('I understand and agree')),
          ),
        ],
      );
    },
  );

  if (accepted == true) {
    await state.acceptTermsAgreement();
    return true;
  }
  return false;
}

class TermsAgreementPoint extends StatelessWidget {
  const TermsAgreementPoint({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_rounded,
              color: CcColors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: const TextStyle(
                    color: CcColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(body),
                  style: const TextStyle(
                    color: CcColors.muted,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showAboutAppDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('About CalamansiCare'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TermsAgreementPoint(
                          title: 'About CalamansiCare',
                          body:
                              'CalamansiCare helps farmers check calamansi leaves and fruits using an offline AI model, view simple disease information, save scan history on the phone, and prepare reports for the barangay agriculture office.',
                        ),
                        TermsAgreementPoint(
                          title: 'Treatment recommendation',
                          body:
                              'The treatment and recommendation content is based on expert-verified guidance for calamansi disease management and should be used as support for farmer decisions.',
                        ),
                        TermsAgreementPoint(
                          title: 'Important reminder',
                          body:
                              'For serious or spreading symptoms, farmers should still confirm findings with the local agriculture office before removing trees or applying chemical treatment.',
                        ),
                        TermsAgreementPoint(
                          title: 'What we collect',
                          body:
                              'Device signature, model, Android version, farmer name, farm location, barangay email, diagnosis result, confidence score, report date, and report image when you send a report.',
                        ),
                        TermsAgreementPoint(
                          title: 'How we use it',
                          body:
                              'This information is used to save reports offline, avoid duplicate uploads, send reports to the barangay office, and show community disease alerts.',
                        ),
                        TermsAgreementPoint(
                          title: 'Offline and online storage',
                          body:
                              'Reports are saved locally on this phone first. When internet is available, approved reports are uploaded to Supabase and may be emailed to the target barangay email.',
                        ),
                        TermsAgreementPoint(
                          title: 'Farmer responsibility',
                          body:
                              'The app gives guidance only. Confirm serious disease findings with the local agriculture office before applying treatment.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  bool isSyncing = false;
  late Future<Map<String, Object?>?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = DiagnosisRepository.instance.getLatestReportSummary();
  }

  void _refreshSummary() {
    setState(() {
      _summaryFuture = DiagnosisRepository.instance.getLatestReportSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: FutureBuilder<Map<String, Object?>?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          final imagePath = summary?['image_path'] as String?;
          final disease = '${summary?['disease'] ?? '---'}';
          final statusLabel = _reportStatusLabel(summary?['status'] as String?);
          final confidence =
              ((summary?['confidence'] as num?)?.toDouble() ?? 0) * 100;
          final farmerName = _summaryValue(summary?['farmer_name']);
          final farmerLocation = _summaryValue(summary?['farmer_location']);
          final targetEmail = _summaryValue(summary?['office_email']);
          final scanDate = _summaryDate(summary?['scan_created_at']);
          final reportDate = _summaryDate(summary?['report_created_at']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopLine(
                title: 'Report Summary',
                subtitle: 'Details of the latest reported scan.',
                pill: state.readinessLabel,
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary == null) ...[
                const NoticeCard(text: 'No reported scans yet.'),
                const Spacer(),
              ] else ...[
                SectionCard(
                  title: 'Reported scan',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReportSummaryImage(imagePath: imagePath),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                InfoRow(label: 'Diagnosis', value: disease),
                                InfoRow(
                                  label: 'Confidence',
                                  value: '${confidence.toStringAsFixed(0)}%',
                                ),
                                InfoRow(label: 'Status', value: statusLabel),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow(label: 'Farmer', value: farmerName),
                      InfoRow(label: 'Location', value: farmerLocation),
                      InfoRow(label: 'Target email', value: targetEmail),
                      InfoRow(label: 'Scan date', value: scanDate),
                      InfoRow(label: 'Report date', value: reportDate),
                      const InfoRow(label: 'Saved in', value: 'This phone'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NoticeCard(
                  text: state.queuedReportsCount == 0
                      ? 'No reports waiting to send'
                      : 'Reports will send automatically when internet is available.',
                ),
                const Spacer(),
                if (state.queuedReportsCount > 0) ...[
                  OutlineAction(
                    label: isSyncing ? 'Sending now...' : 'Try sending now',
                    icon: Icons.wifi_rounded,
                    isLoading: isSyncing,
                    onTap: isSyncing
                        ? null
                        : () async {
                            setState(() => isSyncing = true);
                            final before = state.queuedReportsCount;
                            await state.checkConnectivityAndSync();
                            if (mounted) setState(() => isSyncing = false);
                            _refreshSummary();
                            if (!context.mounted) return;
                            final sent =
                                before > 0 && state.queuedReportsCount == 0;
                            final message = sent
                                ? 'Report sent successfully.'
                                : 'Report is still waiting. Please connect to the internet and try again.';
                            if (sent) {
                              await showReportSentDialog(context);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t(message))),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              PrimaryButton(
                label: 'Back to home',
                icon: Icons.home_rounded,
                onPressed: () => replaceWith(context, const MainShell()),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _summaryValue(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? '---' : text;
}

String _summaryDate(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? '---' : _formatHistoryDateTime(text);
}

class ReportSummaryImage extends StatelessWidget {
  const ReportSummaryImage({super.key, required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    final hasImage = path != null && path.isNotEmpty && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        height: 86,
        color: CcColors.softStrong,
        child: hasImage
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
              )
            : const Icon(
                Icons.image_not_supported_outlined,
                color: CcColors.muted,
              ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DiagnosisRepository.instance.getRecentDiagnoses();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          final rows = snapshot.data;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopLine(
                  title: 'History',
                  subtitle: 'Saved scans and report status on this phone.',
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rows == null || rows.isEmpty)
                  SectionCard(
                    title: 'No scans yet',
                    child: Text(
                        context.t('Scan a leaf from Home to see it here.')),
                  )
                else
                  for (final row in rows)
                    HistoryTile(
                      disease: row['disease'] as String,
                      status:
                          _reportStatusLabel(row['report_status'] as String?),
                      date: _formatHistoryDate(row['created_at'] as String),
                      confidence:
                          '${(((row['confidence'] as num).toDouble()) * 100).toStringAsFixed(0)}%',
                      onRetry: _canRetryHistoryReport(row)
                          ? () async {
                              final diagnosisId = row['id'] as int?;
                              if (diagnosisId == null) return;
                              final state = AppScope.of(context);
                              await DiagnosisRepository.instance
                                  .markDiagnosisReportForRetry(diagnosisId);
                              await state.checkConnectivityAndSync();
                              await state.refreshStats();
                              if (!mounted) return;
                              setState(() {
                                _future = DiagnosisRepository.instance
                                    .getRecentDiagnoses();
                              });
                              if (!context.mounted) return;
                              final message = state.queuedReportsCount == 0
                                  ? 'Report sent successfully.'
                                  : 'No internet. Your report is saved and will send later.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t(message))),
                              );
                            }
                          : null,
                      onTap: () => showHistoryDetailSheet(
                        context,
                        row,
                        onDeleted: () async {
                          await AppScope.of(context).refreshStats();
                          if (mounted) {
                            setState(() {
                              _future = DiagnosisRepository.instance
                                  .getRecentDiagnoses();
                            });
                          }
                        },
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void showHistoryDetailSheet(
  BuildContext context,
  Map<String, Object?> row, {
  required Future<void> Function() onDeleted,
}) {
  final disease = row['disease'] as String? ?? 'Unknown';
  final diagnosisId = row['id'] as int?;
  final confidence = ((row['confidence'] as num?)?.toDouble() ?? 0) * 100;
  final createdAt = row['created_at'] as String? ?? '';
  final imagePath = row['image_path'] as String?;
  final reportStatus = _reportStatusLabel(row['report_status'] as String?);
  final hasQueuedReport = row['report_status'] == reportStatusWaitingInternet ||
      row['report_status'] == reportStatusFailedRetry ||
      row['report_status'] == reportStatusSyncing;
  final canRetryReport = diagnosisId != null && hasQueuedReport;
  final hasAnyReport = row['report_status'] != null;
  final canReportFromHistory = diagnosisId != null &&
      !hasAnyReport &&
      confidence / 100 >= reportAcceptanceConfidenceThreshold;
  final reportEmail = row['report_email'] as String?;
  final reportConsent = row['report_consent'] == null
      ? '-'
      : row['report_consent'] == 1
          ? 'Allowed'
          : 'Not allowed';
  final reportCreatedAt = row['report_created_at'] as String?;
  final reportSyncedAt = row['report_synced_at'] as String?;
  final guidance = guidanceFor(disease);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CcColors.bgAlt,
    showDragHandle: true,
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .94,
        builder: (_, controller) {
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              mediaQuery.padding.bottom + 92,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('Diagnosis details'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('Close'),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Scan result',
                child: Column(
                  children: [
                    InfoRow(label: 'Diagnosis', value: disease),
                    InfoRow(
                      label: 'Confidence',
                      value: '${confidence.toStringAsFixed(0)}%',
                    ),
                    InfoRow(
                      label: 'Scan date',
                      value: _formatHistoryDateTime(createdAt),
                    ),
                    InfoRow(label: 'Report status', value: reportStatus),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Treatment recommendation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow(label: 'Condition type', value: guidance.kind),
                    const SizedBox(height: 10),
                    TreatmentMethodBlock(
                      icon: Icons.science_outlined,
                      title: 'Conventional treatment',
                      text: guidance.conventionalTreatment,
                      color: CcColors.red,
                    ),
                    const SizedBox(height: 8),
                    TreatmentMethodBlock(
                      icon: Icons.spa_outlined,
                      title: 'Organic / natural management',
                      text: guidance.organicTreatment,
                      color: CcColors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Saved details',
                child: Column(
                  children: [
                    InfoRow(label: 'Local ID', value: '${row['id'] ?? '-'}'),
                    if (imagePath != null && imagePath.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: CcColors.link,
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          onPressed: () => showHistoryImageDialog(
                            context,
                            imagePath.trim(),
                          ),
                          child: Text(context.t('See Image taken')),
                        ),
                      ),
                    InfoRow(label: 'Consent', value: reportConsent),
                    InfoRow(label: 'Target email', value: reportEmail ?? '-'),
                    InfoRow(
                      label: 'Queued at',
                      value: reportCreatedAt == null
                          ? '-'
                          : _formatHistoryDateTime(reportCreatedAt),
                    ),
                    InfoRow(
                      label: 'Synced at',
                      value: reportSyncedAt == null
                          ? '-'
                          : _formatHistoryDateTime(reportSyncedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (canRetryReport) ...[
                NoticeCard(
                  text: row['report_status'] == reportStatusSynced
                      ? 'Already reported'
                      : 'Report is saved locally. Tap retry when internet is stable.',
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Retry upload',
                  icon: Icons.sync_rounded,
                  onPressed: () async {
                    final appState = AppScope.of(context);
                    await DiagnosisRepository.instance
                        .markDiagnosisReportForRetry(diagnosisId);
                    await appState.checkConnectivityAndSync();
                    await onDeleted();
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      final message = appState.queuedReportsCount == 0
                          ? 'Report sent successfully.'
                          : 'Report is still waiting. Please connect to the internet and try again.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t(message))),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ] else if (canReportFromHistory) ...[
                PrimaryButton(
                  label: 'Report this scan',
                  icon: Icons.description_outlined,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    go(
                      context,
                      ReportPreviewScreen(
                        disease: disease,
                        diagnosisId: diagnosisId,
                        confidence: confidence / 100,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ] else if (hasAnyReport) ...[
                const NoticeCard(text: 'Already reported'),
                const SizedBox(height: 10),
              ] else if (diagnosisId != null) ...[
                const NoticeCard(
                  text:
                      'Only scans with 80% confidence or higher can be reported.',
                ),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: 'Delete history',
                icon: Icons.delete_outline_rounded,
                color: CcColors.red,
                onPressed: diagnosisId == null
                    ? null
                    : () async {
                        final confirmed = await showDeleteHistoryConfirmation(
                          context,
                          hasQueuedReport: hasQueuedReport,
                        );
                        if (!confirmed) return;
                        await DiagnosisRepository.instance
                            .deleteDiagnosis(diagnosisId);
                        await onDeleted();
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.t('History deleted')),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showDeleteHistoryConfirmation(
  BuildContext context, {
  required bool hasQueuedReport,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Are you sure to delete this history?')),
        content: Text(
          context.t(
            hasQueuedReport
                ? 'This will cancel the queued report and delete this history.'
                : 'This will permanently remove this scan from local history.',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CcColors.softStrong,
                    foregroundColor: CcColors.dark,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.t('Cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CcColors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.t('Delete')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> showSignOutConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Sign out?')),
        content: Text(
          context.t(
            'When you log out, this account\'s saved data on this phone will be deleted. Reports already sent online will stay in Barangay Reports.',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CcColors.softStrong,
                    foregroundColor: CcColors.dark,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.t('Stay signed in')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CcColors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.t('Sign out')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

void showHistoryImageDialog(BuildContext context, String imagePath) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('Image taken'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: CcColors.soft,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            context.t('Image unavailable'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CcColors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _reportStatusLabel(String? status) {
  switch (status) {
    case reportStatusSynced:
      return 'Sent to barangay';
    case reportStatusWaitingInternet:
      return 'Waiting for internet';
    case reportStatusSyncing:
      return 'Sending...';
    case reportStatusFailedRetry:
      return 'Could not send. Tap to try again';
    default:
      return 'Saved on phone';
  }
}

bool _canRetryHistoryReport(Map<String, Object?> row) {
  return row['id'] != null &&
      (row['report_status'] == reportStatusWaitingInternet ||
          row['report_status'] == reportStatusFailedRetry);
}

String _formatHistoryDate(String isoTimestamp) {
  final date = DateTime.tryParse(isoTimestamp)?.toLocal();
  if (date == null) return isoTimestamp;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatHistoryDateTime(String isoTimestamp) {
  final date = DateTime.tryParse(isoTimestamp)?.toLocal();
  if (date == null) return isoTimestamp;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_formatHistoryDate(isoTimestamp)} at $hour:$minute $period';
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

class BarangayReportsScreen extends StatefulWidget {
  const BarangayReportsScreen({super.key});

  @override
  State<BarangayReportsScreen> createState() => _BarangayReportsScreenState();
}

class _BarangayReportsScreenState extends State<BarangayReportsScreen> {
  late Future<List<CommunityReport>> _future;
  CommunityReport? _selectedReport;

  @override
  void initState() {
    super.initState();
    _future = DiagnosisRepository.instance.fetchCommunityReports();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isOnline) {
      return ScreenFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: 'Community reports',
              subtitle:
                  'Reports submitted by other farmers using CalamansiCare.',
              pill: state.readinessLabel,
            ),
            const SizedBox(height: 16),
            const NoticeCard(
              text: 'Please connect to the internet to see barangay reports.',
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Back to home',
              icon: Icons.home_rounded,
              onPressed: () => replaceWith(context, const MainShell()),
            ),
          ],
        ),
      );
    }
    return ScreenFrame(
      child: FutureBuilder<List<CommunityReport>>(
        future: _future,
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <CommunityReport>[];
          if (_selectedReport == null && reports.isNotEmpty) {
            _selectedReport = reports.first;
          }
          final highRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'High risk')
              .length;
          final mediumRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'Medium risk')
              .length;
          final lowRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'Low risk')
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopLine(
                title: 'Community reports',
                subtitle:
                    'Reports submitted by other farmers using CalamansiCare.',
                pill: state.readinessLabel,
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Community overview',
                child: Column(
                  children: [
                    const InfoRow(
                        label: 'Reports source', value: 'Other app users'),
                    InfoRow(
                        label: 'Shared reports',
                        value: '${reports.length} reports from nearby users'),
                    RiskOverviewRow(
                      lowRiskCount: lowRiskCount,
                      mediumRiskCount: mediumRiskCount,
                      highRiskCount: highRiskCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : reports.isEmpty
                        ? const NoticeCard(
                            text:
                                'No barangay reports yet. Please try again later.',
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                _future = DiagnosisRepository.instance
                                    .fetchCommunityReports();
                              });
                              await _future;
                            },
                            child: ListView.builder(
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                final selected =
                                    _selectedReport?.id == report.id;
                                return HistoryTile(
                                  disease: report.disease,
                                  status: communityRiskLabel(report),
                                  date: report.location,
                                  confidence:
                                      '${(report.confidence * 100).toStringAsFixed(0)}% confidence',
                                  imageUrl: report.imageUrl,
                                  selected: selected,
                                  onTap: () =>
                                      setState(() => _selectedReport = report),
                                );
                              },
                            ),
                          ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Review selected report',
                icon: Icons.open_in_new_rounded,
                onPressed: _selectedReport == null
                    ? null
                    : () => go(
                          context,
                          BarangayReportDetailScreen(report: _selectedReport!),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool isLowRiskCommunityReport(CommunityReport report) {
  final disease = report.disease.toLowerCase();
  return disease.contains('healthy') || disease.contains('nutrient');
}

bool isHighRiskCommunityReport(CommunityReport report) {
  final disease = report.disease.toLowerCase();
  return disease.contains('hlb') ||
      disease.contains('greening') ||
      disease.contains('canker');
}

String communityRiskLabel(CommunityReport report) {
  if (isHighRiskCommunityReport(report)) return 'High risk';
  if (isLowRiskCommunityReport(report)) return 'Low risk';
  return 'Medium risk';
}

String communityReportCountText(int count) {
  return count == 1 ? '1 report' : '$count reports';
}

class BarangayReportDetailScreen extends StatelessWidget {
  const BarangayReportDetailScreen({super.key, required this.report});

  final CommunityReport report;

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceFor(report.disease);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Review selected report',
            subtitle: 'Reports submitted by other farmers using CalamansiCare.',
            pill: AppScope.of(context).readinessLabel,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CommunityReportPhoto(
                    imageUrl: report.imageUrl,
                    height: 220,
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Diagnosis details',
                    child: Column(
                      children: [
                        InfoRow(label: 'Disease', value: report.disease),
                        InfoRow(
                          label: 'Confidence',
                          value:
                              '${(report.confidence * 100).toStringAsFixed(0)}%',
                        ),
                        InfoRow(
                          label: 'Farmer',
                          value: report.farmerName.trim().isEmpty
                              ? '---'
                              : report.farmerName,
                        ),
                        InfoRow(label: 'Location', value: report.location),
                        InfoRow(
                          label: 'Status',
                          value: communityRiskLabel(report),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TreatmentRecommendationCard(guidance: guidance),
                  const SizedBox(height: 12),
                  GuideTile(
                    icon: Icons.shield_outlined,
                    title: 'Prevention',
                    text: guidance.prevention,
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Back to home',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class CommunityReportPhoto extends StatelessWidget {
  const CommunityReportPhoto({
    super.key,
    required this.imageUrl,
    required this.height,
  });

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: height,
        color: CcColors.softStrong,
        child: url == null || url.isEmpty
            ? const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: CcColors.muted,
                  size: 34,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: CcColors.muted,
                    size: 34,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
      ),
    );
  }
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.showNav = true});

  final Widget child;
  final bool showNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CcColors.bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(color: CcColors.bgAlt),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NavDot(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  selected: state.tabIndex == 0,
                  onTap: () => _openTab(context, 0),
                ),
                NavDot(
                  label: 'Check',
                  icon: Icons.add_circle_rounded,
                  selected: false,
                  onTap: () => go(context, const CaptureScreen()),
                ),
                NavDot(
                  label: 'History',
                  icon: Icons.history_rounded,
                  selected: state.tabIndex == 1,
                  onTap: () => _openTab(context, 1),
                ),
                NavDot(
                  label: 'Settings',
                  icon: Icons.settings_rounded,
                  selected: state.tabIndex == 2,
                  onTap: () => _openTab(context, 2),
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
    final color = selected ? CcColors.green : CcColors.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? CcColors.green : CcColors.soft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : color,
                size: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              context.t(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
                              fontSize: 12, fontWeight: FontWeight.w900),
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
                              fontSize: 12, fontWeight: FontWeight.w900),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CcColors.line),
        boxShadow: [
          BoxShadow(
            color: CcColors.dark.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
    'A nutrition problem, not an infection. Leaves may yellow or look weak when the tree lacks nutrients, has root stress, or has soil problems.':
        {
      AppText.tagalog:
          'Problema sa nutrisyon ito, hindi impeksyon. Maaaring manilaw o manghina ang dahon kapag kulang sa sustansya, stressed ang ugat, o may problema ang lupa.',
      AppText.cebuano:
          'Problema kini sa nutrisyon, dili impeksyon. Mahimong mo-yellow o maluya ang dahon kung kulang sa sustansya, stressed ang gamot, o naay problema sa yuta.',
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
    'Nutrient Deficiency': {
      AppText.tagalog: 'Kakulangan sa nutrisyon',
      AppText.cebuano: 'Kulang sa nutrisyon',
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
    'Nutritional condition': {
      AppText.tagalog: 'Kondisyon sa nutrisyon',
      AppText.cebuano: 'Kondisyon sa nutrisyon',
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
    'Check soil and fertiliser practice, then correct nutrients with guidance from an agriculture technician.':
        {
      AppText.tagalog:
          'Suriin ang lupa at paraan ng fertilizer, pagkatapos ay ayusin ang nutrisyon sa gabay ng agriculture technician.',
      AppText.cebuano:
          'Susiha ang yuta ug pamaagi sa fertilizer, unya ayuha ang nutrisyon uban sa giya sa agriculture technician.',
    },
    'Do not use insecticide or fungicide for nutrient deficiency. Use soil or leaf testing, correct soil pH if needed, and apply the proper citrus fertilizer or micronutrient product.':
        {
      AppText.tagalog:
          'Huwag gumamit ng insecticide o fungicide para sa nutrient deficiency. Gumamit ng soil o leaf testing, ayusin ang soil pH kung kailangan, at maglagay ng tamang citrus fertilizer o micronutrient product.',
      AppText.cebuano:
          'Ayaw gamit ug insecticide o fungicide para sa nutrient deficiency. Gamit ug soil o leaf testing, ayuha ang soil pH kung kinahanglan, ug butangi ug sakto nga citrus fertilizer o micronutrient product.',
    },
    'Improve soil health with compost, mulch kept away from the trunk, proper watering, drainage correction, and organic citrus fertilizer where available.':
        {
      AppText.tagalog:
          'Pagandahin ang lupa gamit ang compost, mulch na malayo sa puno, tamang dilig, pag-ayos ng drainage, at organic citrus fertilizer kung mayroon.',
      AppText.cebuano:
          'Paayosa ang yuta gamit ang compost, mulch nga layo sa punoan, sakto nga pagbisbis, pag-ayo sa drainage, ug organic citrus fertilizer kung naa.',
    },
    'Avoid overwatering, maintain drainage, fertilize on schedule, and inspect roots and soil pH when yellowing continues.':
        {
      AppText.tagalog:
          'Iwasan ang sobrang dilig, panatilihin ang drainage, mag-fertilize sa tamang schedule, at suriin ang ugat at soil pH kung tuloy ang paninilaw.',
      AppText.cebuano:
          'Likayi ang sobra nga pagbisbis, panatilihing maayo ang drainage, pag-fertilize sa sakto nga schedule, ug susiha ang gamot ug soil pH kung padayon ang pag-yellow.',
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
              child: Text(
                context.t(text),
                style: const TextStyle(
                    fontSize: 13.5, height: 1.4, color: CcColors.ink),
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
            title: 'Conventional treatment',
            text: guidance.conventionalTreatment,
            color: CcColors.red,
          ),
          const SizedBox(height: 8),
          TreatmentMethodBlock(
            icon: Icons.spa_outlined,
            title: 'Organic / natural management',
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
                Text(
                  context.t(text),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: CcColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                state.setFarmerName(value);
              }
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
                        onPressed: () {
                          final value = controller.text.trim();
                          if (value.isNotEmpty) {
                            state.setFarmerLocation(value);
                          }
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
