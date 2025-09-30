# TravelX 🚀

**Advanced Trip Capture app (modular, failproof detection, offline-first)**

TravelX is a next-generation trip-tracking application developed for the Smart India Hackathon (SIH). It's designed to be a robust, offline-first, and feature-rich platform for capturing, analyzing, and sharing travel experiences.



---

## 🌟 Key Features

* **Effortless Trip Recording:** Automatically detects and records your trips with high precision, using a sophisticated sensor-fusion algorithm. Also supports manual start/stop for full control.
* **Offline-First Sync:** Trips are always saved locally first. The app intelligently syncs with the backend when an internet connection is available, ensuring no data is ever lost.
* **Peer-to-Peer Syncing with Bluetooth:**  In areas with no internet, TravelX can sync the trip data with nearby "Travel Buddies" using Bluetooth Low Energy (BLE), creating a mesh network for data transfer.
* **Intelligent Activity Detection:** Utilizes a combination of GPS, accelerometer, and gyroscope data to accurately determine   mode of transport (walk, run, bike, car, bus, train).
* **Advanced Analytics & Insights:**
    * **Trip History:** A detailed log of all the past trips, with maps and statistics.
    * **Personalized Insights:** Understand your travel patterns with charts and graphs.
    * **Heatmaps:** Visualize the most frequented routes and destinations.
* **Travel Buddy Discovery:** Discover and connect with other TravelX users nearby, turning solo trips into social experiences.
* **Secure & Private:** User data is anonymized and securely handled.

---

## 🛠️ Tech Stack

### Frontend (Mobile App)

* **Framework:** Flutter
* **Language:** Dart
* **State Management:** Provider
* **Local Storage:** Hive (for offline-first data persistence)
* **Maps:** Google Maps Flutter, flutter\_map
* **Sensors & Connectivity:** `geolocator`, `sensors_plus`, `flutter_blue_plus`, `connectivity_plus`
* **Authentication:** Firebase Authentication (Google Sign-In)

### Backend

* **Framework:** Node.js with Express.js
* **Database:**
    * **Primary:** PostgreSQL (with Prisma ORM)
    * **Secondary:** MongoDB
* **Task Queue:** BullMQ with Redis for background job processing
* **Deployment:** Docker-ready for easy deployment

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (version 3.35.4 or higher)
* Node.js (version 16.x or higher)
* Android Studio or VS Code
* Access to a PostgreSQL and MongoDB database (local or cloud-hosted)
* Redis instance (local or cloud-hosted)

### Frontend Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Newt-Shadow/TravelX.git
    cd TravelX
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Firebase:**
    * Follow the FlutterFire CLI instructions to configure Firebase for the project.
    * Place the generated `google-services.json` file in `android/app/`.
    * Add the iOS bundle ID to the Firebase project and download the `GoogleService-Info.plist` into `ios/Runner/`.

4.  **Add Google Maps API Key:**
    * Add your Google Maps API key to the `android/app/src/main/AndroidManifest.xml` file.

5.  **Run the app:**
    ```bash
    flutter run
    ```

### Backend Setup

1.  **Navigate to the backend directory:**
    ```bash
    cd Backend
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Set up environment variables:**
    * Create a `.env` file in the `Backend` directory by copying the `.env.example`.
    * Fill in the required credentials for your PostgreSQL database, MongoDB, and Redis.

4.  **Run database migrations:**
    ```bash
    npx prisma migrate dev --name init
    ```

5.  **Start the server:**
    ```bash
    npm run dev
    ```
    The server will be running on `http://localhost:5000`.

