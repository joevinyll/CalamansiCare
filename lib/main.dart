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
  'Healthy',
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

/// Confidence banding for the on-device classifier. Matches the standard
/// range used for agricultural image classifiers: below 0.40 the model is
/// unreliable and the result is rejected outright (never shown as if it
/// were real), 0.40-0.60 is shown but flagged as low confidence, and 0.60+
/// is accepted cleanly.
enum ConfidenceTier { accepted, lowConfidence, rejected }

ConfidenceTier confidenceTier(double confidence) {
  if (confidence >= 0.60) return ConfidenceTier.accepted;
  if (confidence >= 0.40) return ConfidenceTier.lowConfidence;
  return ConfidenceTier.rejected;
}

const lowConfidenceWarningMessage =
    'Low Confidence: Please retake the photo closer to the leaf under better lighting.';
const lowConfidenceRejectionMessage =
    'Disease could not be identified. Please ensure the leaf lesion is centered and clear.';
const reportAcceptanceConfidenceThreshold = 0.80;

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
    case 'Healthy':
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
    'Start plant check': {
      tagalog: 'Simulan ang pagsusuri',
      cebuano: 'Sugdi ang pagsusi',
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
    'Waiting for internet connection': {
      tagalog: 'Naghihintay ng internet connection',
      cebuano: 'Naghulat sa internet connection',
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
    'No reports waiting to send': {
      tagalog: 'Walang ulat na naghihintay ipadala',
      cebuano: 'Walay report nga naghuwat ipadala',
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
    'Healthy': {tagalog: 'Malusog', cebuano: 'Himsog'},
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
  AppState({this.persistSettings = true}) {
    termsAccepted = !persistSettings;
  }

  final bool persistSettings;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

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
  int checksCount = 0;
  int queuedReportsCount = 0;
  int sentReportsCount = 0;
  double? lastConfidence;

  String get readinessLabel => isOnline ? 'Online ready' : 'Offline ready';
  bool get hasCompleteReportProfile =>
      farmerName.trim().isNotEmpty &&
      farmerLocation.trim().isNotEmpty &&
      officeEmail.trim().isNotEmpty;

  Future<void> loadSavedSettings() async {
    if (!persistSettings) return;
    final settings = await DiagnosisRepository.instance.loadSettings();
    language = settings.language;
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
                const BrandMark(onDark: true),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Text(
                              'CalamansiCare',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'AI disease detection and treatment guide for calamansi farmers.',
                              ),
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
                        context.t('Choose language'),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      value: '${state.queuedReportsCount}',
                      label: 'Queued',
                      valueColor: CcColors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      value: '${state.sentReportsCount}',
                      label: 'Sent',
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
                children: diseaseLabels.map((item) => SmallPill(item)).toList(),
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

      if (confidenceTier(prediction.confidence) == ConfidenceTier.rejected) {
        // Below the 50% floor: don't save this as a diagnosis and don't let
        // a wild guess (e.g. a photo of anything but a leaf) reach the
        // farmer looking like a real result.
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
    final guidance = guidanceFor(prediction.label);
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
                  const SizedBox(height: 14),
                  TreatmentRecommendationCard(guidance: guidance),
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
          const TopLine(
            title: 'Treatment guide',
            subtitle: 'Prioritize containment and expert confirmation.',
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
          const TopLine(
            title: 'Report preview',
            subtitle: 'Prepared for barangay agriculture review.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barangay Agriculture Office',
            child: Column(
              children: [
                InfoRow(
                  label: 'Farmer',
                  value: state.farmerName.trim().isEmpty
                      ? 'Tap to add'
                      : state.farmerName,
                ),
                InfoRow(
                  label: 'Location',
                  value: state.farmerLocation.trim().isEmpty
                      ? 'Tap to add'
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
                      ? 'Tap to add'
                      : state.officeEmail,
                ),
              ],
            ),
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
            color: CcColors.orange,
            isLoading: isSubmitting,
            onPressed: state.consentEnabled && !isSubmitting
                ? () async {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.t(
                                sentNow
                                    ? 'Report saved. Sending to barangay now.'
                                    : 'Report is pending and waiting for internet connection.',
                              ),
                            ),
                          ),
                        );
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

  final editSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Complete farmer information first')),
        content: Text(
          context.t(
            'Please add farmer name, farm location, and barangay email before sending a report.',
          ),
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

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  bool isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final statusLabel = state.queuedReportsCount == 0
        ? 'Sent'
        : state.isOnline
            ? 'Ready to send when online'
            : 'Waiting for internet connection';
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Offline queue',
            subtitle: 'Reports wait here until internet is available.',
            pill: state.readinessLabel,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'HLB / Greening report',
            child: Column(
              children: [
                InfoRow(
                  label: 'Status',
                  value: statusLabel,
                ),
                const InfoRow(
                  label: 'Saved in',
                  value: 'This phone',
                ),
                InfoRow(label: 'Target email', value: state.officeEmail),
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
                      if (!context.mounted) return;
                      final sent = before > 0 && state.queuedReportsCount == 0;
                      final message = sent
                          ? 'Report sent successfully.'
                          : 'Report is still waiting. Please connect to the internet and try again.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t(message))),
                      );
                    },
            ),
            const SizedBox(height: 10),
          ],
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
      return 'Sent';
    case reportStatusWaitingInternet:
      return 'Waiting for internet connection';
    case reportStatusSyncing:
      return 'Sending report...';
    case reportStatusFailedRetry:
      return 'Saved locally, will retry';
    default:
      return 'Not reported';
  }
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
                  SettingTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Device signature',
                    value: state.deviceSignature,
                    action: 'View',
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.t(state.locationNote),
                      style: const TextStyle(
                        color: CcColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                    InfoRow(
                      label: 'Status',
                      value: state.isOnline
                          ? 'Needs review'
                          : 'Waiting for internet connection',
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
                                  status: report.priority,
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
                        InfoRow(label: 'Location', value: report.location),
                        InfoRow(label: 'Status', value: report.priority),
                        InfoRow(
                          label: 'Device signature',
                          value: report.deviceSignature,
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
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: CcColors.dark,
          backgroundColor: Colors.white,
          side: const BorderSide(color: CcColors.line),
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
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(CcColors.green),
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
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        context.t(text),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
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
  });

  final String disease;
  final String status;
  final String date;
  final String confidence;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  Color _statusColor() {
    return switch (status) {
      'Sent' => CcColors.green,
      'Not reported' => CcColors.red,
      'Saved locally, will retry' => CcColors.red,
      'Waiting for internet connection' => CcColors.orange,
      'Sending report...' => CcColors.orange,
      _ => CcColors.muted,
    };
  }

  Color _statusBackground() {
    return switch (status) {
      'Sent' => CcColors.soft,
      'Not reported' => CcColors.red.withValues(alpha: .08),
      'Saved locally, will retry' => CcColors.red.withValues(alpha: .08),
      'Waiting for internet connection' => CcColors.orangeSoft,
      'Sending report...' => CcColors.orangeSoft,
      _ => CcColors.softStrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusBackground = _statusBackground();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: selected ? CcColors.soft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? CcColors.green : CcColors.line,
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
