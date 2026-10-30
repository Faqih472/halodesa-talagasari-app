# SETUP — Talagasari Hub (panduan dari nol)

> Catatan jujur: kode sudah diperiksa dengan analyzer Dart (tanpa error di fitur jasa), tetapi BELUM pernah dijalankan di HP/emulator.
> Setelah langkah 2, kalau muncul error merah di terminal atau layar, kirim ke saya, nanti saya perbaiki.

## 1. Siapkan file
1. Ekstrak zip. Timpa folder `lib/` dan file `pubspec.yaml` di proyek Flutter kamu.
2. Folder `functions/` dan file `firebase.json` sudah tidak dipakai. Hapus kalau masih ada.

## 2. Pasang paket
1. Buka terminal di folder proyek.
2. Ketik `flutter pub get` lalu Enter.
3. Ketik `flutter run` untuk mencoba di HP/emulator.

## 3. Isi nomor kontak & kop surat
1. Buka `lib/core/app_contact.dart`.
2. Ganti `adminTelp` dan `kadesTelp` dengan nomor asli (format `628xxxxxxxxxx`).
3. Ganti daftar `nomorPenting` (polisi, ambulans, damkar) sesuai daerah.
4. Cek `kopPemerintah`, `kopKecamatan`, `kopDesa`, `kopAlamat` untuk kop surat.

## 4. Aktifkan layanan Firebase
1. Buka https://console.firebase.google.com → pilih proyek kamu.
2. Menu **Build → Authentication** → Sign-in method → aktifkan **Email/Password**.
3. Menu **Build → Firestore Database** → buat database (kalau belum).


## 5. Pasang aturan keamanan Firestore  (WAJIB diulang: aturan berubah di versi ini)
1. Buka https://console.firebase.google.com → klik proyek kamu.
2. Menu kiri: **Build** → **Firestore Database**.
3. Klik tab **Rules** (di bagian atas).
4. Hapus semua isi kotak aturan (Ctrl+A lalu Delete).
5. Buka file `firestore.rules` dari zip, salin (Ctrl+A, Ctrl+C) semua isinya.
6. Tempel (Ctrl+V) di kotak aturan.
7. Klik tombol **Publish**. Selesai.

## 6. Semua gratis (tanpa Storage, tanpa Cloud Functions)
- Foto (profil, jasa, pengaduan, informasi, polling, agenda, KTP) disimpan kecil-kecil sebagai teks langsung di Firestore. Tidak perlu Firebase Storage (yang berbayar). Foto otomatis dikecilkan; kalau masih terlalu besar muncul pesan "Foto terlalu besar".
- Verifikasi identitas: data teks + 2 foto lewat kamera (1: selfie kamera depan sambil memegang KTP dengan garis panduan kepala/badan/KTP, 2: foto KTP saja). Foto hanya terbaca pemilik & Admin, dan DIHAPUS otomatis setelah Admin memutuskan. Setelah ganti pubspec, jalankan `flutter pub get` (paket baru: camera, image). Izin kamera akan diminta saat pertama dipakai.
- Masa berlaku informasi: pilihan 3 hari sampai 12 bulan + Kustom (maks 1 tahun). Admin/Kades bisa Perpanjang dari menu ⋮ pada kartu atau detail informasi: sisa masa berlaku + bulan tambahan, total sisa maksimal 12 bulan.
- Pembersihan data lama berjalan otomatis di perangkat Admin/Kades (lihat CHANGELOG.md), tanpa Cloud Functions.
- Notifikasi muncul di dalam aplikasi (tab Notifikasi + banner saat aplikasi terbuka). Tidak ada push saat aplikasi tertutup.

## 7. Buat akun Admin & Kades pertama
1. Daftar 2 akun lewat aplikasi (akan jadi warga).
2. Firebase Console → **Firestore Database → Data → users** → klik dokumen akun tersebut.
3. Ubah field `role` jadi `admin` (akun pertama) dan `kades` (akun kedua). Simpan.
4. Login ulang di aplikasi.

## 8. Alur yang berlaku
- Warga: Akun → **Verifikasi Identitas** (isi nama, NIK, alamat) → Admin mencocokkan lalu ACC → muncul lencana **Terverifikasi**. Fitur yang terkunci sebelum verifikasi: buka jasa, pengaduan, ajukan informasi, surat online, polling.
- Informasi: semua pengajuan warga wajib ACC Admin. Ada tanggal kadaluarsa, informasi yang lewat tanggal otomatis tidak tampil.
- Pengaduan: Admin saring → ringan diproses Admin, berat (keamanan/kekerasan) ke Kades → selesai → pelapor beri rating.
- Surat: warga ajukan → Admin cek → Kades setujui → warga cetak PDF → datang ke kantor desa untuk tanda tangan basah + stempel → Admin tekan **Sudah ditandatangani** → surat sah dan masa berlaku mulai dihitung. Admin/Kades bisa cek kode surat di halaman Surat (ikon centang di atas).

## 8b. Fitur Jasa (baru, lengkap)
**Warga pencari jasa** (tab Jasa):
1. Cari nama/keahlian, saring kategori, buka sekarang, terverifikasi, rating, jarak, harga, favorit; urutkan (rekomendasi, terdekat, rating, terlaris, termurah, terbaru); lihat daftar atau peta.
2. Buka jasa → lihat tarif, jadwal mingguan, katalog layanan, portofolio, ulasan + sebaran bintang → tekan **Pesan Jasa** (pilih paket, tanggal, jam, alamat, foto kebutuhan).
3. Pantau di **Pesanan Saya**: menunggu → (penawaran harga/jadwal) → diterima → dikerjakan → selesai (kamu konfirmasi) → beri ulasan. Pembayaran dilakukan langsung dengan penyedia (tunai/transfer), tidak lewat aplikasi.

**Penyedia jasa** (Akun → Jasa Saya, wajib Verifikasi Identitas):
1. Isi profil lengkap: nama usaha, kategori, keahlian, tarif, area layanan, titik lokasi di peta, jam buka tiap hari, tanggal libur, kapasitas pesanan, katalog layanan, portofolio. Admin menyetujui dulu.
2. Dasbor: pesanan masuk (terima / ajukan harga / tolak / mulai / tandai selesai), ulasan (bisa dibalas), saklar Buka–Penuh–Tutup, libur. Status otomatis **Penuh** bila pesanan berjalan mencapai kapasitas.

**Admin** (Kelola → tab Jasa & Laporan Jasa):
1. Antrean verifikasi, daftar semua jasa (aktifkan, nonaktifkan, blokir, Pilihan Desa), sembunyikan ulasan tidak pantas.
2. Laporan warga: abaikan / peringatan (3 peringatan = otomatis nonaktif) / nonaktifkan / blokir. Semua tindakan tercatat di Log Keputusan.

Semua notifikasi pesanan muncul di dalam aplikasi. Chat otomatis berisi ringkasan saat pesanan dibuat.

## 9. Daftar tes cepat
1. Daftar warga baru, login. Coba buka jasa → terkunci, muncul ajakan verifikasi.
2. Akun → Verifikasi Identitas → isi data. Login Admin → Kelola → tab KTP → ACC. Warga kini bertanda Terverifikasi.
3. Warga: buat pengaduan, cek muncul di Admin. Admin ACC, warga beri rating setelah selesai.
4. Warga: tahan tombol SOS 3 detik → Admin/Kades menerima notifikasi + lokasi.
5. Admin: buat Polling dan Agenda → warga memilih / konfirmasi hadir.
6. Warga ajukan surat → Admin teruskan → Kades setujui → warga cetak PDF → Admin tandai ditandatangani → cek kode di halaman Surat.
7. Warga ajukan informasi dengan tanggal berlaku → Admin ACC → informasi hilang setelah tanggalnya lewat.
8. Tes jasa (butuh 3 akun: A penyedia, B pemesan, Admin):
   1. A: verifikasi identitas (Admin ACC) → Akun → Jasa Saya → isi profil lengkap → kirim.
   2. Admin: Kelola → tab Jasa → Setujui profil A.
   3. B: tab Jasa → buka jasa A → Pesan Jasa → kirim. A menerima notifikasi + chat otomatis.
   4. A: Terima (atau Ajukan harga) → B setujui bila ada penawaran → A: Mulai kerjakan → Tandai selesai.
   5. B: Pesanan Saya → Konfirmasi selesai → Beri ulasan. Rating A berubah; A bisa membalas ulasan.
   6. B: Laporkan jasa A → Admin: tab Laporan Jasa → coba Peringatan / Nonaktifkan.

## Catatan
- Tombol SOS butuh izin lokasi aktif di HP.
- Peta memakai OpenStreetMap (gratis, tanpa API key).
- Nomor di `app_contact.dart` saat ini hanya contoh.
