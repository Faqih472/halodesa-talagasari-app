# CHANGELOG — Pembaruan Talagasari Hub

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
