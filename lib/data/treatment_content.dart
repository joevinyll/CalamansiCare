typedef TreatmentText = ({String english, String tagalog, String cebuano});

class TreatmentAdvice {
  const TreatmentAdvice({
    required this.kind,
    required this.cultural,
    required this.chemical,
    required this.prevention,
  });

  final String kind;
  final TreatmentText cultural;
  final TreatmentText chemical;
  final String prevention;
}

const chemicalTreatmentReminder = (
  english:
      'For all chemical treatments, use only products approved for the crop and target problem. Follow label directions, required protective clothing, and waiting times before entering the treated area or harvesting.',
  tagalog:
      'Sa lahat ng kemikal na paggamot, gumamit lamang ng produktong aprubado para sa pananim at sa pesteng o sakit na ginagamot. Sundin ang tagubilin sa label, magsuot ng kailangang kasuotang pangkaligtasan, at sundin ang itinakdang paghihintay bago pumasok sa ginamot na lugar o mag-ani.',
  cebuano:
      'Sa tanang kemikal nga pagtambal, gamita lamang ang mga produktong aprobahan para sa tanom ug sa peste o sakit nga tambalan. Sunda ang panudlo sa label, isul-ob ang gikinahanglang panagang nga sinina, ug hulata ang gitakdang panahon sa dili pa mosulod sa gitambalan nga lugar o mag-ani.',
);

const healthyTreatmentAdvice = TreatmentAdvice(
  kind: 'Healthy plant',
  cultural: (
    english:
        'Continue proper watering, the right fertilizer, regular cleaning, and light pruning when needed. Check often for insects or new symptoms. Compost can help improve the soil. A healthy-looking photo may not show early or hidden disease.',
    tagalog:
        'Ipagpatuloy ang tamang pagdidilig, paggamit ng tamang pataba, regular na paglilinis, at kaunting pagputol ng sanga kung kailangan. Madalas na tingnan kung may peste o bagong sintomas. Makakatulong ang compost sa lupa. Maaaring hindi makita sa larawan ang sakit na nagsisimula pa lang o nakatago.',
    cebuano:
        'Ipadayon ang hustong pagbisbis, sakto nga abono, regular nga pagpanglimpyo, ug gamay nga pagpul-ong kung kinahanglan. Susiha kanunay kung naay peste o bag-ong sintomas. Makatabang ang compost sa pagpaayo sa yuta. Mahimong dili makita sa hulagway ang sayo o natagong sakit.',
  ),
  chemical: (
    english:
        'A healthy-looking photo alone is not a reason to spray. Use treatment only for a confirmed problem or when a technician recommends preventive protection.',
    tagalog:
        'Hindi sapat na dahilan para mag-spray ang larawang mukhang malusog. Gumamit lamang ng paggamot kung may kumpirmadong problema o kung ipinayo ng technician para makaiwas sa sakit o peste.',
    cebuano:
        'Ang hulagway nga murag himsog dili igo nga rason aron mag-spray. Gamit lamang ug pagtambal kung kumpirmado ang problema o kung gitambag sa technician aron malikayan ang sakit o peste.',
  ),
  prevention:
      'Use clean planting materials, sanitize pruning tools, remove fallen diseased debris, and monitor nearby trees for early symptoms.',
);

const treatmentAdviceByDisease = <String, TreatmentAdvice>{
  'Healthy Leaf': healthyTreatmentAdvice,
  'Healthy Fruit': healthyTreatmentAdvice,
  'HLB (Greening)': TreatmentAdvice(
    kind: 'Bacterial disease',
    cultural: (
      english:
          'Use disease-free seedlings from a trusted source. Ask an agriculture technician to check suspected trees. Do not move their seedlings, branches, or cuttings to another farm. Give enough water and the right fertilizer. Remove infected trees only when advised.',
      tagalog:
          'Gumamit ng mga punlang walang sakit mula sa mapagkakatiwalaang pinagmulan. Ipasuri sa agriculture technician ang mga punong pinaghihinalaang may sakit. Huwag ilipat ang kanilang mga punla, sanga, o pinagputulan sa ibang bukid. Magbigay ng sapat na tubig at tamang pataba. Alisin lamang ang mga punong may sakit kapag ipinayo.',
      cebuano:
          'Gamit ug mga semilyang walay sakit gikan sa kasaligan nga tinubdan. Ipasusi sa agriculture technician ang mga kahoy nga gidudahang adunay sakit. Ayaw ibalhin ang ilang semilya, sanga, o pinutol nga bahin ngadto sa laing uma. Hatagi ug igong tubig ug hustong abono. Tangtanga lamang ang mga kahoy nga adunay sakit kung gitambag.',
    ),
    chemical: (
      english:
          'There is no proven spray that cures HLB. If citrus psyllids - the small insects that spread HLB - are present, ask a technician which insect spray to use. Controlling these insects helps reduce spread but does not cure the tree.',
      tagalog:
          'Walang napatunayang spray na nakagagamot ng HLB. Kung may citrus psyllids, ang maliliit na insektong nagpapakalat ng HLB, itanong sa technician kung anong spray ang dapat gamitin. Nakakatulong ang pagkontrol sa mga ito para mabawasan ang pagkalat, pero hindi nito napapagaling ang puno.',
      cebuano:
          'Walay napamatud-ang spray nga makaayo sa HLB. Kung naay citrus psyllids, ang gagmay nga insekto nga nagpakaylap sa HLB, pangutan-a ang technician unsang spray ang gamiton. Ang pagkontrol niini makatabang sa pagpamenos sa pagkaylap apan dili makaayo sa kahoy.',
    ),
    prevention:
        'Monitor new flush for psyllids, avoid moving infected seedlings or budwood, report suspected HLB, and protect young trees from psyllid access where possible.',
  ),
  'Citrus Canker': TreatmentAdvice(
    kind: 'Bacterial disease',
    cultural: (
      english:
          'Avoid handling trees while leaves are wet. Clean and disinfect tools after use. Water the soil instead of the leaves. Do not move infected seedlings or cuttings. Use suitable wind barriers where practical. Do not strip off leaves or cut back many branches.',
      tagalog:
          'Iwasang humawak sa mga puno habang basa ang dahon. Linisin at disimpektahin ang mga kagamitan pagkatapos gamitin. Diligan ang lupa sa halip na ang dahon. Huwag ilipat ang mga punla o pinagputulang may sakit. Gumamit ng angkop na harang sa hangin kung kaya. Huwag kalbuhin ang dahon o putulin ang maraming sanga.',
      cebuano:
          'Likayi ang paghawid sa mga kahoy samtang basa ang mga dahon. Limpyohi ug disimpektahi ang mga gamit human gamiton. Bisbisi ang yuta imbes ang mga dahon. Ayaw ibalhin ang semilya o pinutol nga bahin nga adunay sakit. Gamit ug angay nga babag sa hangin kung mahimo. Ayaw hubo-a ang mga dahon o putla ang daghang sanga.',
    ),
    chemical: (
      english:
          'After confirmation, a suitable copper-based spray may help prevent new infections. It cannot remove existing spots. Rain and new growth can reduce protection, so follow the advised spraying schedule.',
      tagalog:
          'Kapag nakumpirma ang sakit, maaaring makatulong ang angkop na spray na may copper para maiwasan ang bagong impeksyon. Hindi nito maaalis ang dati nang mga batik. Maaaring mabawasan ang proteksyon dahil sa ulan at bagong tubo, kaya sundin ang ipinayong iskedyul ng pag-spray.',
      cebuano:
          'Human makumpirma ang sakit, mahimong makatabang ang angay nga spray nga adunay copper aron malikayan ang bag-ong impeksyon. Dili niini matangtang ang daan nang mga spots. Makapamenos sa proteksyon ang ulan ug bag-ong tubo, busa sunda ang gitambag nga iskedyul sa pag-spray.',
    ),
    prevention:
        'Reduce leaf wounds, manage citrus leafminer if present, plant windbreaks where practical, and avoid moving infected plant material.',
  ),
  'Anthracnose': TreatmentAdvice(
    kind: 'Fungal disease',
    cultural: (
      english:
          'Remove dead or clearly diseased branches using clean tools. Collect and properly dispose of affected cuttings and fallen material. Trim only what is needed to let sunlight and air through. Avoid keeping leaves wet, and provide enough water and nutrients.',
      tagalog:
          'Alisin ang patay o malinaw na may sakit na sanga gamit ang malinis na kagamitan. Ipunin at itapon nang maayos ang apektadong pinagputulan at nalaglag na bahagi. Putulin lamang ang kailangan para makapasok ang araw at hangin. Iwasang manatiling basa ang dahon, at magbigay ng sapat na tubig at sustansya.',
      cebuano:
          'Tangtanga ang patay o klarong adunay sakit nga sanga gamit ang limpyo nga mga gamit. Tigoma ug ilabay sa hustong paagi ang apektadong mga pinutol ug nangahulog nga bahin. Pul-onga lamang ang kinahanglan aron makasulod ang adlaw ug hangin. Likayi nga dugay mabasa ang mga dahon, ug hatagi ug igong tubig ug sustansya.',
    ),
    chemical: (
      english:
          'After confirmation, use an approved copper-based spray or another suitable treatment when advised. Apply it at the recommended time to protect against further infection. Existing spots will remain.',
      tagalog:
          'Kapag nakumpirma ang sakit, gumamit ng aprubadong spray na may copper o ibang angkop na paggamot kung ipinayo. Gamitin ito sa itinakdang oras para maprotektahan laban sa dagdag na impeksyon. Mananatili ang dati nang mga batik.',
      cebuano:
          'Human makumpirma ang sakit, gamit ug aprobahan nga spray nga adunay copper o laing angay nga pagtambal kung gitambag. Gamita kini sa girekomendang panahon aron mapugngan ang dugang nga impeksyon. Magpabilin ang daan nang mga spots.',
    ),
    prevention:
        'Keep the canopy open, sanitize pruning tools, maintain balanced nutrition, and inspect after long wet periods.',
  ),
  'Melanose': TreatmentAdvice(
    kind: 'Fungal disease',
    cultural: (
      english:
          'Remove dead twigs, branches, and piles of dead wood where practical. Maintain proper watering, fertilizer, and airflow. Focus on dead wood; do not remove spotted living leaves or fruit just to control melanose.',
      tagalog:
          'Alisin ang mga patay na maliliit na sanga, malalaking sanga, at tambak ng patay na kahoy kung kaya. Panatilihin ang tamang pagdidilig, pataba, at pagdaloy ng hangin. Unahin ang patay na kahoy; huwag alisin ang buhay na dahon o bungang may batik para lang makontrol ang melanose.',
      cebuano:
          'Tangtanga ang patay nga gagmay ug dagkong sanga ug mga pundok sa patay nga kahoy kung mahimo. Ipadayon ang hustong pagbisbis, abono, ug agi sa hangin. Tutoki ang patay nga kahoy; ayaw tangtanga ang buhing dahon o bunga nga adunay spots para lamang makontrol ang melanose.',
    ),
    chemical: (
      english:
          'A suitable copper-based spray may protect young fruit and new growth when infection is likely. Ask a technician when to apply it, especially during rainy weather. Existing rough spots and scars will remain.',
      tagalog:
          'Maaaring maprotektahan ng angkop na spray na may copper ang batang bunga at bagong tubo kapag may panganib ng impeksyon. Itanong sa technician kung kailan ito gagamitin, lalo na kapag maulan. Mananatili ang dati nang magagaspang na batik at peklat.',
      cebuano:
          'Mahimong mapanalipdan sa angay nga spray nga adunay copper ang batan-ong bunga ug bag-ong tubo kung lagmit adunay impeksyon. Pangutan-a ang technician kanus-a kini gamiton, labi na kung ting-ulan. Magpabilin ang daan nang bagis nga spots ug mga ulat.',
    ),
    prevention:
        'Regularly remove dead twigs, avoid dense canopy growth, and monitor fruit during rainy weather.',
  ),
  'Citrus Scab': TreatmentAdvice(
    kind: 'Fungal disease',
    cultural: (
      english:
          'Water the soil and avoid keeping young leaves and fruit wet. Allow air through the branches and check new growth often. Ask for advice before cutting affected shoots. Avoid heavy pruning. Removing damaged fruit alone will not protect new growth.',
      tagalog:
          'Diligan ang lupa at iwasang manatiling basa ang batang dahon at bunga. Hayaang makadaan ang hangin sa mga sanga at madalas suriin ang bagong tubo. Humingi ng payo bago putulin ang apektadong usbong. Iwasan ang sobrang pagputol ng sanga. Hindi sapat ang pag-alis ng sirang bunga para maprotektahan ang bagong tubo.',
      cebuano:
          'Bisbisi ang yuta ug likayi nga dugay mabasa ang batan-ong dahon ug bunga. Paagia ang hangin sa mga sanga ug susiha kanunay ang bag-ong tubo. Pangayo ug tambag sa dili pa putlon ang apektadong mga saha. Likayi ang sobrang pagpul-ong. Dili igo ang pagtangtang sa nadaot nga bunga aron mapanalipdan ang bag-ong tubo.',
    ),
    chemical: (
      english:
          'Use an approved treatment at the right stage of leaf and fruit growth. Copper sprays may be less effective when scab is severe. Ask a technician which treatment to use and how to alternate treatments so they keep working.',
      tagalog:
          'Gumamit ng aprubadong paggamot sa tamang yugto ng paglaki ng dahon at bunga. Maaaring hindi gaanong mabisa ang copper spray kapag malala ang scab. Itanong sa technician kung anong paggamot ang gagamitin at paano pagsasalitin ang mga ito para manatiling mabisa.',
      cebuano:
          'Gamit ug aprobahan nga pagtambal sa hustong yugto sa pagtubo sa dahon ug bunga. Mahimong dili kaayo epektibo ang copper spray kung grabe ang scab. Pangutan-a ang technician unsang pagtambal ang gamiton ug unsaon pagpuli-puli niini aron magpabiling epektibo.',
    ),
    prevention:
        'Inspect spring flush and young fruit, reduce leaf wetness, sanitize pruning tools, and remove carryover infected material.',
  ),
  'Brown Spot': TreatmentAdvice(
    kind: 'Fungal disease',
    cultural: (
      english:
          'Ask a technician to confirm whether the spots are caused by Alternaria, the fungus covered by this advice. Avoid too much water or fertilizer. Keep drainage clear and allow air through the branches. Ask for advice before pruning.',
      tagalog:
          'Ipakumpirma sa technician kung Alternaria, ang amag na tinutukoy ng payong ito, ang sanhi ng mga batik. Iwasan ang sobrang tubig o pataba. Panatilihing maayos ang daluyan ng tubig at hayaang makadaan ang hangin sa mga sanga. Humingi ng payo bago magputol ng sanga.',
      cebuano:
          'Ipakumpirma sa technician kung Alternaria, ang fungus nga gitumong niini nga tambag, ang hinungdan sa mga spots. Likayi ang sobra nga tubig o abono. Hupti nga hawan ang agianan sa tubig ug paagia ang hangin sa mga sanga. Pangayo ug tambag sa dili pa magpul-ong.',
    ),
    chemical: (
      english:
          'For confirmed Alternaria brown spot, an approved copper-based spray or another suitable treatment may protect young leaves and fruit. Ask how to alternate treatments. Changing brands alone may still mean using the same type of chemical.',
      tagalog:
          'Para sa kumpirmadong Alternaria brown spot, maaaring maprotektahan ng aprubadong copper spray o ibang angkop na paggamot ang batang dahon at bunga. Itanong kung paano pagsasalitin ang mga paggamot. Ang pagpapalit lang ng brand ay maaaring pareho pa rin ang uri ng kemikal na ginagamit.',
      cebuano:
          'Para sa kumpirmadong Alternaria brown spot, mahimong mapanalipdan sa aprobahan nga copper spray o laing angay nga pagtambal ang batan-ong dahon ug bunga. Pangutana unsaon pagpuli-puli sa mga pagtambal. Bisan mag-ilis ug brand, mahimong pareho ra gihapon ang matang sa kemikal nga gigamit.',
    ),
    prevention:
        'Monitor new flush and young fruit, reduce long leaf-wetness periods, and remove diseased debris from the farm.',
  ),
};

const treatmentHeadings = <TreatmentText>[
  (
    english: 'Cultural / Nonchemical Methods',
    tagalog: 'Pangangalaga na Walang Kemikal',
    cebuano: 'Pag-atiman nga Walay Kemikal',
  ),
  (
    english: 'Chemical Options',
    tagalog: 'Mga Kemikal na Paggamot',
    cebuano: 'Mga Kemikal nga Pagtambal',
  ),
  chemicalTreatmentReminder,
];

final _treatmentTranslations = <String, TreatmentText>{
  for (final advice in treatmentAdviceByDisease.values)
    for (final text in [advice.cultural, advice.chemical]) text.english: text,
  for (final text in treatmentHeadings) text.english: text,
};

String? translateTreatmentText(String language, String text) {
  final translated = _treatmentTranslations[text];
  if (translated == null) return null;
  return switch (language) {
    'Tagalog' => translated.tagalog,
    'Cebuano' => translated.cebuano,
    _ => translated.english,
  };
}
