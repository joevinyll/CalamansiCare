// Mirrors the English guidance in lib/data/treatment_content.dart; parity tested.
export const careContent: Record<string, {kind: string; cultural: string; chemical: string; prevention: string}> = {
  "HLB (Greening)": {
    "kind": "Bacterial disease",
    "cultural": "Use disease-free seedlings from a trusted source. Ask an agriculture technician to check suspected trees. Do not move their seedlings, branches, or cuttings to another farm. Give enough water and the right fertilizer. Remove infected trees only when advised.",
    "chemical": "There is no proven spray that cures HLB. If citrus psyllids - the small insects that spread HLB - are present, ask a technician which insect spray to use. Controlling these insects helps reduce spread but does not cure the tree.",
    "prevention": "Monitor new flush for psyllids, avoid moving infected seedlings or budwood, report suspected HLB, and protect young trees from psyllid access where possible."
  },
  "Citrus Canker": {
    "kind": "Bacterial disease",
    "cultural": "Avoid handling trees while leaves are wet. Clean and disinfect tools after use. Water the soil instead of the leaves. Do not move infected seedlings or cuttings. Use suitable wind barriers where practical. Do not strip off leaves or cut back many branches.",
    "chemical": "After confirmation, a suitable copper-based spray may help prevent new infections. It cannot remove existing spots. Rain and new growth can reduce protection, so follow the advised spraying schedule.",
    "prevention": "Reduce leaf wounds, manage citrus leafminer if present, plant windbreaks where practical, and avoid moving infected plant material."
  },
  "Anthracnose": {
    "kind": "Fungal disease",
    "cultural": "Remove dead or clearly diseased branches using clean tools. Collect and properly dispose of affected cuttings and fallen material. Trim only what is needed to let sunlight and air through. Avoid keeping leaves wet, and provide enough water and nutrients.",
    "chemical": "After confirmation, use an approved copper-based spray or another suitable treatment when advised. Apply it at the recommended time to protect against further infection. Existing spots will remain.",
    "prevention": "Keep the canopy open, sanitize pruning tools, maintain balanced nutrition, and inspect after long wet periods."
  },
  "Melanose": {
    "kind": "Fungal disease",
    "cultural": "Remove dead twigs, branches, and piles of dead wood where practical. Maintain proper watering, fertilizer, and airflow. Focus on dead wood; do not remove spotted living leaves or fruit just to control melanose.",
    "chemical": "A suitable copper-based spray may protect young fruit and new growth when infection is likely. Ask a technician when to apply it, especially during rainy weather. Existing rough spots and scars will remain.",
    "prevention": "Regularly remove dead twigs, avoid dense canopy growth, and monitor fruit during rainy weather."
  },
  "Citrus Scab": {
    "kind": "Fungal disease",
    "cultural": "Water the soil and avoid keeping young leaves and fruit wet. Allow air through the branches and check new growth often. Ask for advice before cutting affected shoots. Avoid heavy pruning. Removing damaged fruit alone will not protect new growth.",
    "chemical": "Use an approved treatment at the right stage of leaf and fruit growth. Copper sprays may be less effective when scab is severe. Ask a technician which treatment to use and how to alternate treatments so they keep working.",
    "prevention": "Inspect spring flush and young fruit, reduce leaf wetness, sanitize pruning tools, and remove carryover infected material."
  },
  "Brown Spot": {
    "kind": "Fungal disease",
    "cultural": "Ask a technician to confirm whether the spots are caused by Alternaria, the fungus covered by this advice. Avoid too much water or fertilizer. Keep drainage clear and allow air through the branches. Ask for advice before pruning.",
    "chemical": "For confirmed Alternaria brown spot, an approved copper-based spray or another suitable treatment may protect young leaves and fruit. Ask how to alternate treatments. Changing brands alone may still mean using the same type of chemical.",
    "prevention": "Monitor new flush and young fruit, reduce long leaf-wetness periods, and remove diseased debris from the farm."
  }
};
