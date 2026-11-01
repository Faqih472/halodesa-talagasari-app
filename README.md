# Talagasari Hub

Platform komunitas terpadu Desa Talagasari: informasi warga, pengaduan, surat online, dan layanan jasa lokal berbasis lokasi dalam satu aplikasi Flutter.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase)
![State](https://img.shields.io/badge/State-GetX-8A2BE2)

## Daftar Isi

1. [Tentang Proyek](#tentang-proyek)
2. [Fitur Utama](#fitur-utama)
3. [Peran Pengguna](#peran-pengguna)
4. [Teknologi](#teknologi)
5. [Struktur Proyek](#struktur-proyek)
6. [Prasyarat](#prasyarat)
7. [Instalasi](#instalasi)
8. [Konfigurasi](#konfigurasi)
9. [Aturan Keamanan Firestore](#aturan-keamanan-firestore)
10. [Membuat Akun Admin dan Kades](#membuat-akun-admin-dan-kades)
11. [Alur Kerja Fitur](#alur-kerja-fitur)
12. [Koleksi Firestore](#koleksi-firestore)
13. [Skenario Pengujian Cepat](#skenario-pengujian-cepat)
14. [Catatan Penting](#catatan-penting)
15. [Pemecahan Masalah](#pemecahan-masalah)
16. [Kontribusi](#kontribusi)

## Tentang Proyek

Talagasari Hub menghubungkan warga, admin desa, dan kepala desa (kades) dalam satu aplikasi. Warga dapat membaca informasi desa, melapor, mengajukan surat, serta mencari dan memesan jasa dari sesama warga. Admin dan kades memverifikasi, menyaring, dan memutuskan tindak lanjut.

Seluruh data disimpan di Firebase (Authentication dan Cloud Firestore). Aplikasi **tidak memakai Firebase Storage maupun Cloud Functions**: foto disimpan dalam ukuran kecil sebagai teks di Firestore, sehingga dapat dijalankan tanpa biaya tambahan.

## Fitur Utama

### Informasi Desa
- Pengajuan informasi oleh warga wajib disetujui admin.
- Masa berlaku 3 hari sampai 12 bulan, atau kustom (maksimal 1 tahun).
- Informasi yang melewati tanggal berlaku otomatis tidak tampil.
- Admin atau kades dapat memperpanjang masa berlaku (total sisa maksimal 12 bulan).

### Verifikasi Identitas
- Warga mengisi nama, NIK, dan alamat, lalu mengambil 2 foto lewat kamera di dalam aplikasi (selfie memegang KTP dengan garis panduan, dan foto KTP saja).
- Admin mencocokkan data, lalu warga mendapat lencana **Terverifikasi**.
- Foto hanya dapat dibaca pemilik dan admin, dan dihapus otomatis setelah admin memutuskan.

### Pengaduan
- Warga membuat pengaduan dengan foto dan lokasi.
- Admin menyaring: kasus ringan diproses admin, kasus berat (keamanan atau kekerasan) diteruskan ke kades.
- Setelah selesai, pelapor memberi rating.
- Peta sebaran pengaduan dengan filter kategori dan rentang waktu (7 hari, 30 hari, semua).

### Surat Online
- Alur: warga mengajukan, admin memeriksa, kades menyetujui, warga mencetak PDF.
- Surat ditandatangani basah dan dicap di kantor desa, lalu admin menekan **Sudah ditandatangani**.
- Kode surat dapat dicek keasliannya lewat halaman Cek Surat.

### Layanan Jasa Lokal
- Pencarian dan filter: kategori, buka sekarang, terverifikasi, rating, jarak, harga, favorit.
- Pengurutan: rekomendasi, terdekat, rating, terlaris, termurah, terbaru.
- Tampilan daftar atau peta (OpenStreetMap).
- Profil penyedia: tarif, jadwal mingguan, tanggal libur, katalog layanan, portofolio, ulasan, dan sebaran bintang.
- Pesanan: pilih paket, tanggal, jam, alamat, dan foto kebutuhan. Mendukung penawaran harga atau jadwal.
- Status pesanan: menunggu, diterima, dikerjakan, selesai, lalu ulasan.
- Status penyedia: Buka, Penuh, Tutup. Status otomatis **Penuh** bila pesanan berjalan mencapai kapasitas.
- Pembayaran dilakukan langsung antara warga dan penyedia (tidak lewat aplikasi).
- Pelaporan jasa oleh warga. Tiga peringatan membuat jasa otomatis nonaktif.

### Layanan Desa Lainnya
- **SOS**: tombol darurat (tahan 3 detik) yang mengirim notifikasi dan lokasi ke admin dan kades, serta daftar nomor penting.
- **Polling**: admin membuat polling, warga memilih.
- **Agenda**: warga mengonfirmasi kehadiran.
- **Chat**: percakapan antarpengguna, otomatis berisi ringkasan saat pesanan dibuat.
- **Notifikasi** di dalam aplikasi (tab Notifikasi dan banner saat aplikasi terbuka). Tidak ada push saat aplikasi tertutup.
- **Umpan balik**: warga menilai aplikasi, jasa, atau layanan; staf meninjau.
- **Statistik** dan **Log Keputusan** (audit) untuk admin.

### Pengaturan dan Aksesibilitas
- Dua bahasa: Indonesia dan Inggris.
- Ukuran huruf dapat diubah.
- Login cepat multi-akun dengan penyimpanan terenkripsi (Keystore/Keychain).
- Pusat Bantuan (WhatsApp dan telepon admin/kades).

## Peran Pengguna

| Peran | Warna Tema | Kewenangan Utama |
|-------|-----------|------------------|
| Warga (`warga`) | Teal | Membaca informasi, melapor, mengajukan surat, memesan atau menyediakan jasa (setelah verifikasi) |
| Admin (`admin`) | Biru | Verifikasi KTP, persetujuan informasi dan jasa, moderasi ulasan dan laporan, menyaring pengaduan |
| Kades (`kades`) | Ungu | Menyetujui surat, menangani pengaduan berat, menerima SOS |

Fitur yang terkunci sebelum verifikasi identitas: membuka jasa, pengaduan, mengajukan informasi, surat online, dan polling.

## Teknologi

| Kebutuhan | Paket |
|-----------|-------|
| Framework | Flutter (Dart `>=3.0.0 <4.0.0`) |
| Backend | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| State management dan routing | `get` (GetX) |
| Lokasi dan izin | `geolocator`, `permission_handler` |
| Peta | `flutter_map`, `latlong2` (OpenStreetMap, tanpa API key) |
| Gambar dan kamera | `image_picker`, `camera`, `image` |
| Penyimpanan lokal | `get_storage`, `flutter_secure_storage` |
| PDF | `pdf`, `printing` |
| Utilitas | `url_launcher`, `intl`, `flutter_localizations` |

## Struktur Proyek

```
talagasari_hub/
├── lib/
│   ├── main.dart                 # Titik masuk, binding controller, rute
│   ├── firebase_options.dart     # Konfigurasi Firebase per platform
│   ├── core/
│   │   ├── core.dart             # Tema, util, widget umum, LocalStore, AppSettings
│   │   ├── models.dart           # Model utama (user, jasa, ulasan, chat, pengaduan, KTP)
│   │   ├── models_extra.dart     # Model tambahan (SOS, polling, agenda, surat, audit, pesanan)
│   │   ├── translations.dart     # Terjemahan Indonesia dan Inggris
│   │   ├── ui_helpers.dart       # Pemilih masa berlaku, pemilih foto, alasan tolak, retensi
│   │   └── app_contact.dart      # Nomor kontak dan kop surat (WAJIB disesuaikan)
│   ├── controllers/              # Logika bisnis (GetX)
│   │   ├── auth_controller.dart
│   │   ├── data_controller.dart  # Informasi, jasa, pesanan
│   │   ├── complaint_controller.dart
│   │   ├── village_controller.dart  # SOS, polling, agenda, surat, audit, retensi
│   │   ├── chat_controller.dart
│   │   └── feedback_controller.dart
│   └── views/                    # Tampilan
│       ├── auth_view.dart, home_view.dart, account_view.dart, profile_view.dart
│       ├── jasa_view.dart, chat_view.dart, complaint_view.dart
│       ├── letter_view.dart, village_view.dart, verification_view.dart
│       ├── camera_view.dart, feedback_view.dart, stats_view.dart
│       └── admin_view.dart, admin_tools_view.dart
├── firestore.rules               # Aturan keamanan Firestore
├── google-services.json          # Konfigurasi Firebase Android
├── AndroidManifest.xml           # Izin dan konfigurasi Android
├── pubspec.yaml                  # Dependensi
└── SETUP.md                      # Panduan setup dari nol
```

## Prasyarat

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) terpasang (`flutter doctor` tanpa error).
2. Android Studio atau VS Code, beserta emulator atau HP Android.
3. Akun [Firebase](https://console.firebase.google.com) dengan satu proyek.

## Instalasi

```bash
# 1. Salin repositori
git clone <URL-REPOSITORI>
cd talagasari_hub

# 2. Pasang dependensi
flutter pub get

# 3. Jalankan
flutter run
```

## Konfigurasi

### 1. Firebase
1. Buka Firebase Console, pilih proyek.
2. **Build → Authentication → Sign-in method**: aktifkan **Email/Password**.
3. **Build → Firestore Database**: buat database bila belum ada.
4. Pastikan `google-services.json` (Android) dan `lib/firebase_options.dart` sesuai dengan proyek Firebase Anda. Nama paket Android saat ini: `com.example.talagasari_hub`.

### 2. Kontak dan kop surat
Buka `lib/core/app_contact.dart`, lalu ubah:
- `adminTelp` dan `kadesTelp` (format `628xxxxxxxxxx`, tanpa `+` dan tanpa `0` di depan).
- Daftar `nomorPenting` (polisi, ambulans, pemadam kebakaran, dan lain-lain) sesuai daerah.
- `kopPemerintah`, `kopKecamatan`, `kopDesa`, `kopAlamat` untuk kop surat.

> Nomor di file tersebut saat ini hanya contoh.

### 3. Izin Android
Kamera dipakai untuk verifikasi identitas. Izin lokasi diperlukan untuk SOS dan peta. Izin diminta saat pertama kali fitur digunakan.

## Aturan Keamanan Firestore

Aturan wajib dipasang ulang setiap kali `firestore.rules` berubah.

1. Firebase Console → **Build → Firestore Database → Rules**.
2. Hapus seluruh isi kotak aturan.
3. Salin seluruh isi `firestore.rules` dari repositori, lalu tempel.
4. Klik **Publish**.

## Membuat Akun Admin dan Kades

1. Daftar 2 akun lewat aplikasi (keduanya awalnya berperan warga).
2. Firebase Console → **Firestore Database → Data → users** → buka dokumen akun.
3. Ubah field `role` menjadi `admin` (akun pertama) dan `kades` (akun kedua), lalu simpan.
4. Login ulang di aplikasi.

## Alur Kerja Fitur

**Pengaduan**: warga membuat → admin menyaring → ringan diproses admin / berat ke kades → selesai → pelapor memberi rating.

**Surat**: warga mengajukan → admin memeriksa → kades menyetujui → warga mencetak PDF → tanda tangan basah dan stempel di kantor desa → admin menekan **Sudah ditandatangani** → surat sah dan masa berlaku mulai dihitung.

**Pesanan jasa**: menunggu → (penawaran harga atau jadwal) → diterima → dikerjakan → selesai (dikonfirmasi pemesan) → ulasan.

**Moderasi jasa**: laporan warga → admin memilih abaikan, peringatan, nonaktifkan, atau blokir. Semua tindakan tercatat di Log Keputusan.

## Koleksi Firestore

| Koleksi | Keterangan |
|---------|------------|
| `users` (+ `notifications`) | Akun, peran, notifikasi pengguna |
| `announcements` | Informasi desa |
| `penyedia_jasa` (+ `reviews`, `portofolio`) | Profil jasa, ulasan, portofolio |
| `pesanan_jasa` | Pesanan jasa |
| `laporan_jasa` | Laporan warga terhadap jasa |
| `chat_rooms` (+ `messages`) | Percakapan |
| `pengaduan` (+ `aktivitas`) | Pengaduan dan riwayat aktivitas |
| `verifikasi_ktp` | Data dan foto verifikasi identitas |
| `surat`, `surat_verifikasi` | Pengajuan surat dan kode keaslian |
| `polling` (+ `suara`) | Polling dan suara |
| `agenda` (+ `hadir`) | Agenda dan kehadiran |
| `sos` | Kejadian darurat |
| `audit_log` | Log keputusan |
| `umpan_balik` | Umpan balik pengguna |
| `counters`, `meta` | Penomoran dan metadata (khusus staf) |

## Skenario Pengujian Cepat

1. Daftar warga baru, login. Buka jasa: terkunci, muncul ajakan verifikasi.
2. Akun → Verifikasi Identitas → isi data. Login admin → Kelola → tab KTP → ACC. Warga bertanda Terverifikasi.
3. Warga membuat pengaduan. Admin ACC. Warga memberi rating setelah selesai.
4. Warga menahan tombol SOS 3 detik. Admin dan kades menerima notifikasi beserta lokasi.
5. Admin membuat Polling dan Agenda. Warga memilih dan mengonfirmasi hadir.
6. Warga mengajukan surat → admin meneruskan → kades menyetujui → warga cetak PDF → admin menandai ditandatangani → cek kode di halaman Surat.
7. Warga mengajukan informasi bertanggal berlaku → admin ACC → informasi hilang setelah tanggal lewat.
8. Uji jasa (3 akun: A penyedia, B pemesan, admin):
   1. A: verifikasi identitas, isi profil jasa, kirim.
   2. Admin: Kelola → tab Jasa → setujui profil A.
   3. B: tab Jasa → buka jasa A → Pesan Jasa.
   4. A: terima (atau ajukan harga) → mulai kerjakan → tandai selesai.
   5. B: konfirmasi selesai → beri ulasan.
   6. B: laporkan jasa A → admin: tab Laporan Jasa.

## Catatan Penting

- Kode telah diperiksa dengan analyzer Dart, tetapi belum pernah diuji penuh di perangkat nyata. Laporkan error yang ditemukan lewat Issues.
- Foto disimpan sebagai teks di Firestore. Bila terlalu besar, aplikasi menampilkan pesan "Foto terlalu besar".
- Pembersihan data lama berjalan otomatis di perangkat admin atau kades, bukan lewat Cloud Functions.
- Tombol SOS membutuhkan izin lokasi aktif.
- Pertimbangkan membatasi API key Firebase di Google Cloud Console sebelum rilis publik.
- Ganti `com.example.talagasari_hub` dengan ID paket sendiri sebelum dipublikasikan ke Play Store.

## Pemecahan Masalah

| Masalah | Solusi |
|---------|--------|
| `flutter pub get` gagal | Jalankan `flutter doctor`, pastikan versi Dart sesuai, lalu ulangi |
| Login gagal atau data tidak muncul | Pastikan Email/Password aktif dan aturan Firestore sudah di-Publish |
| `PERMISSION_DENIED` di Firestore | Salin ulang seluruh isi `firestore.rules` dan Publish |
| Kamera tidak terbuka | Izinkan akses kamera di pengaturan HP |
| Peta kosong | Periksa koneksi internet (tile OpenStreetMap) |
| Akun tidak menjadi admin | Ubah field `role` di koleksi `users`, lalu login ulang |

## Kontribusi

1. Fork repositori ini.
2. Buat cabang: `git checkout -b feat/nama-fitur`.
3. Commit dengan format [Conventional Commits](https://www.conventionalcommits.org), misalnya `feat(jasa): tambah filter harga`.
4. Push, lalu buka Pull Request.

---

Dikembangkan untuk Desa Talagasari, Kecamatan Cikupa, Kabupaten Tangerang, Banten.

## Desain Visual: "Sawah & Telaga"

Identitas visual khas Desa Talagasari, digambar dengan kode (`lib/core/motif.dart`), tanpa file gambar:

- **Kawung**: pola batik halus pada header.
- **Matahari, bukit, dan padi**: pemandangan sawah pada header Beranda dan Login.
- **Gelombang telaga**: tepi bawah header (arti "talaga").
- **Pita batik**: hiasan di atas bilah navigasi bawah.
- **Palet**: hijau padi (warga), biru telaga (admin), ungu wulung (kades), aksen emas padi dan terakota, latar krem hangat.
- **Font**: Poppins (isi) dan DM Serif Display (judul), keduanya berlisensi OFL, ada di `assets/fonts/`.
- **Salam Sunda** sesuai waktu: Wilujeng enjing, siang, sonten, wengi.
