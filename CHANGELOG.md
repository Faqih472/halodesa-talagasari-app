## Jenis info + Beranda lebih menarik
- Ajukan Info dirombak: langkah bernomor, 10 jenis (Biasa, Kehilangan, Ditemukan, Dijual, Bantuan, Kabar Duka, Syukuran, Sebelum-Sesudah, Galeri, Tanya Cepat). Judul dan isi contoh terisi otomatis, bisa diubah. Pilih warna kartu.
- Beranda: banner geser (Admin: menu titik tiga > Jadikan banner), strip Kabar Duka (3 hari), filter cepat per jenis, kartu khusus (foto digeser sebelum-sesudah, mosaik galeri, polling mini, kolom harga/kontak/waktu).
- firestore.rules berubah (subkoleksi announcements/pilih): WAJIB deploy ulang.

## Alamat Blok/No, Suara Warga & Agenda, Kelola Desa, README
- Alamat: Blok + No. rumah + RT/RW wajib; nama jalan dan kampung opsional (lowongan, lapak, pengaduan, jasa, pesanan jasa). Info desa: semua kolom opsional.
- Suara Warga: tab terbaca (putih), usulan topik 4 langkah dengan kartu kategori + contoh, tidak lag lagi (notifikasi paralel di latar belakang), perbaikan error layar Buat Suara Warga.
- Agenda: warga bisa Usulkan Kegiatan (tab Usulan); Admin menjadikan agenda atau menolak dengan alasan.
- Kelola Desa: tab geser diganti halaman kotak dengan angka merah per bagian + lencana di menu bawah.
- README baru. firestore.rules berubah (usulan_agenda): WAJIB deploy ulang.

## Contoh syarat lowongan + lisensi
- Formulir lowongan: 3 contoh syarat (dasar, lengkap, pemula) yang menyesuaikan bidang dan jenis kerja; contoh lowongan ikut mengisi syarat. Tersedia juga saat ubah lowongan.
- Tambah berkas LICENSE (MIT).

## Info Saya, ubah info dengan ACC admin, perbaikan foto, README
- Beranda: tombol 'Info Saya' (cari + filter status). Warga bisa Ajukan perubahan info (alasan wajib); info lama tetap tayang sampai disetujui.
- Admin/Kades: tab 'Revisi Info' (Sebelum -> Sesudah, Setujui/Tolak dengan alasan). Kategori sensitif hanya Kades.
- Perbaikan: foto/peta di formulir tidak hilang lagi saat digulir (keep-alive).
- README baru lengkap dengan gambar (docs/img). firestore.rules berubah: WAJIB deploy ulang.

## Suara Warga (polling) & Agenda Desa dirombak, peta daftar
- Polling lama diganti 'Suara Warga': kategori, tipe pilihan, template contoh, sasaran RW/kampung, suara rahasia, hasil per RW, diskusi, keputusan desa, usulan dari warga, panduan.
- Agenda Desa baru: 11 jenis kegiatan + contoh, kalender bulanan, kegiatan rutin, konfirmasi Hadir/Mungkin/Tidak, kuota, check-in, diskusi, batal dengan alasan, peta opsional, panduan.
- Tab Lapak dan Butuh Pekerja: toggle Daftar/Peta (hanya yang memasang lokasi tampil).
- firestore.rules: aturan polling (suara rahasia, penghitung), usulan_polling, agenda (rsvp, komentar). WAJIB deploy ulang.

