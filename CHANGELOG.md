# CHANGELOG — Pembaruan Talagasari Hub

## Terbaru: Jasa + Butuh Pekerja
- Tab Butuh Pekerja (lowongan warga, lamaran, terima/tolak, notifikasi), panduan lengkap dan kotak contoh di form jasa, pesanan, lowongan, dan lamaran.

## Terbaru: Surat lengkap + foto profil ACC Admin
- Surat: form data tambahan (agama, status kawin, pekerjaan, tanda per jenis), PDF lengkap siap tanda tangan Kades, kolom tanda tangan pemohon, pas foto, chip contoh CPNS/TNI/Polri.
- Foto profil: wajib disetujui Admin (tab Foto). Rules diperbarui.

## 1. Kelola informasi di Beranda + masa berlaku wajib
- Admin & Kades: tombol **Buat Info** (+) di Beranda; menu ⋮ pada kartu / tombol di detail untuk **Ubah** dan **Hapus**.
- Admin yang mengubah info kategori sensitif yang sudah tayang -> kembali ke Kades untuk ACC ulang.
- **Masa berlaku wajib** di semua form (default 14 hari, tombol cepat, maks. 1 tahun).
- Info lama tanpa masa berlaku dianggap permanen -> disembunyikan dan **dihapus otomatis** (sapuan sekali oleh Admin/Kades).
- Info lewat masa berlaku +7 hari dihapus otomatis.

## 2. Gambar (gratis, tanpa Firebase Storage)
Informasi, foto KTP (wajib, dihapus setelah diperiksa), polling, agenda, ditambah yang sudah ada (pengaduan, jasa, profil).
Chat tidak diberi gambar (lihat usulan).

## 3. SOS untuk Admin & Kades
Staf punya tab Riwayat + Kirim SOS. Pengirim staf -> petugas lain menerima notifikasi (pengirim dikecualikan).

## 4 & 5. Perbaikan menu yang tidak pas
- "Buat Konten" dipindah dari tab Tertunda ke Beranda.
- Tertunda kini hanya berisi: Draf (Admin & Kades) dan Menunggu Kades (Admin). Duplikat antrean Kades dihapus.
- Admin tidak bisa lagi mem-publish kategori sensitif sendiri dari draf (harus ke Kades).
- Laporan Jasa dipindah dari Akun ke Kelola (tab untuk Admin).
- "Audit Log" bernama **Log Keputusan**, dengan filter.

## 6. Sebaran Pengaduan
Default berupa daftar teks + ringkasan per kategori. Peta hanya dibuka lewat ikon peta (atau ikon peta pada tiap laporan).

## 7. Alasan penolakan & retensi
- Dialog alasan baku (per jenis: informasi, jasa, pengaduan, KTP, surat) + "Lainnya" wajib teks. Dikirim ke pemohon dan dicatat di Log Keputusan (kotak merah).
- Retensi: notifikasi dibaca 14 hari / semua 30 hari; Log Keputusan 90 hari; Riwayat SOS 90 hari; laporan jasa selesai 30 hari; info ditolak 30 hari; umpan balik 180 hari.
- Aturan Firestore mencegah log dihapus sebelum 90 hari.

## 8. Nilai & Saran
Warga menilai Aplikasi / Admin / Kades (bintang + aspek + komentar, opsi anonim, 1x/14 hari, pelayanan hanya warga terverifikasi).
Admin & Kades membaca di Akun -> Umpan Balik Warga (ringkasan + distribusi bintang). Penilaian Admin dibaca Kades, penilaian Kades dibaca Admin.

## 9. Saklar ketersediaan jasa
Buka / Penuh / Tutup + catatan + buka otomatis pada tanggal tertentu. Profil tetap tampil (diberi label & diurutkan paling bawah), tombol chat dinonaktifkan.

## Pin peta, SOS real, Info sosial
- Widget `PemilihPeta` (Lokasi saya + Cari alamat) di pengaduan, jasa, pesanan.
- SOS: terkirim instan, lokasi diperbarui live, tombol "sudah aman", Admin lihat waktu & sumber posisi.
- Info desa: 7 kelompok/30 kategori dengan contoh, sampai 3 foto, suka, komentar, simpan, bagikan, dilihat.

## Lokasi realtime, pengaduan lengkap, hapus dengan ACC
- Tombol "Lokasi saya" realtime di semua peta (pin form, peta jasa, detail jasa, peta pengaduan); pin otomatis mengikuti GPS; pesan jelas bila GPS/izin bermasalah.
- Pengaduan: 6 kelompok, 28 kategori + contoh laporan, urgensi, dampak, lokasi, harapan, panduan langkah.
- Hapus jasa/lowongan: pemilik wajib alasan; Admin setuju/tolak dengan keterangan; data disembunyikan (soft delete) sehingga tidak gagal lagi.

## Alamat terkunci, kategori bertingkat, lowongan foto + pin
- Alamat pengaduan & lowongan: Desa Talagasari, Kec. Cikupa, Kab. Tangerang, Banten terkunci; isi kampung, RT, RW, jalan.
- Pengaduan: pilih kelompok lalu jenis, contoh laporan, tombol kerangka 4 pertanyaan.
- Lowongan: sampai 3 foto, pin peta realtime, tampil di detail.
- Perbaikan aturan Firestore lowongan agar pengajuan hapus tidak gagal.

## Lokasi andal, SOS serius, lokasi di info, ikon
- Lokasi: tidak lagi otomatis (kecuali SOS); galat dijelaskan; tidak crash saat scroll; izin diminta satu per satu.
- SOS: jenis darurat wajib, keterangan + foto opsional, titik GPS segar (posisi lama tidak dipercaya), peta live di Admin, konfirmasi "sudah aman", Admin tutup kasus wajib hasil + catatan, penilaian warga.
- Tambah Info: lokasi opsional (pin + alamat terkunci Talagasari), tampil di detail dengan rute.
- Ikon adaptif full dan manifest izin lokasi di android_patch/.

## Ikon baru
- Ikon adaptif memakai logo "TALAGASARI HUB" (latar hijau penuh, teks di zona aman, tidak terpotong).

## SOS instan
- Tombol SOS di urutan pertama, tahan 2 detik langsung terkirim tanpa isi apa pun.
- Jenis, keterangan, dan foto opsional: bisa diisi sebelum atau sesudah SOS terkirim.
