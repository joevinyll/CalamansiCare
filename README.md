# CalamansiCare UI

CalamansiCare is an offline-first mobile application designed to detect calamansi plant diseases, provide treatment recommendations, and facilitate community-level agricultural reporting.

---

## Overview

This repository contains the Flutter frontend implementation and initial UI prototypes for the CalamansiCare capstone system.

### Key Features & Screen Flows
* **Localization & Onboarding:** Welcome screen with multi-language selection.
* **Triage & Scanning:** Step-by-step camera guidance, capture screen, and real-time AI scanning visualization.
* **Diagnosis & Advisory:** Detailed disease detection results with actionable treatment guides.
* **Offline-First Workflow:** Local diagnostic history, offline report queue, and automatic synchronization.
* **Community Reporting:** Barangay inbox integration and privacy-focused report submission previews.

---

## Tech Stack & Architecture Decisions

| Area | Selection | Rationale |
| :--- | :--- | :--- |
| **Framework** | Flutter | Cross-platform UI development (Android/iOS) |
| **Language** | Dart | Type-safe, high-performance client runtime |
| **Edge AI** | On-device Model | Offline inference without field connectivity |
| **Local Database** | SQLite (`sqflite`) | Local caching for history and offline sync queues |
| **Backend / Sync** | Supabase | Auth, cloud storage, and reporting database |
| **Supported Locales**| English, Tagalog, Cebuano | Local accessibility for target farming communities |

---

## Supported Disease Classes

All classification outputs, database schemas, and localization files must strictly adhere to the following target labels:

* `Healthy`
* `Citrus Canker`
* `HLB / Greening`
* `Anthracnose`
* `Sooty Mold`
* `Citrus Scab`
* `Brown Rot`
* `Nutrient Deficiency`

---

## Getting Started

### Prerequisites
* Flutter SDK (Stable channel)
* Dart SDK
* Android Studio / VS Code with Flutter extension
* Android SDK (API 21+) or iOS development environment

### Installation & First Run

1. **Verify Environment:**
   
   ```bash
   flutter --version
   flutter doctor
