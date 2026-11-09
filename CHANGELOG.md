## Tampilan: foto Beranda penuh, lencana Layanan Desa, detail pengaduan, Suara Warga & Agenda
- Beranda: foto kartu selebar penuh (tanpa bingkai abu-abu), judul lebih tegas.
- Layanan Desa (staf): lencana angka merah / centang hijau pada Surat, Suara Warga, Agenda, SOS, Peta Pengaduan.
- Detail Pengaduan didesain ulang (kepala berwarna, kartu info, isi, foto penuh); teks selalu terbaca.
- Suara Warga dan Agenda: hero berwarna, kartu bergaris warna, formulir buat dengan hero.
- Jasa/Lowongan/Lapak: strip penjelas berwarna per tab.

## Pengaduan & usulan: ubah/batal
- Pengaduan: selama "Menunggu Review" pelapor bisa **Ubah** dan **Batalkan** (dengan alasan; riwayat tetap ada). Setelah diproses, terkunci.
- Usulan Suara Warga/Agenda: warga bisa **Ubah** atau **Tarik kembali** selama "Menunggu".
- Staf menghapus polling/agenda wajib memilih alasan (dicatat di riwayat). **Deploy ulang firestore.rules.**

## Hapus lapak (ACC), surat bisa diubah/dibatalkan
- Lapak UMKM: pemilik mengajukan hapus dengan alasan siap pakai; Admin menyetujui atau menolak (Kelola Desa → Lapak UMKM, ada angka merah).
- Surat online: warga bisa **Ubah pengajuan** (selama belum disetujui Kades; kembali ke Admin), **Batalkan** (selama belum ditandatangani), dan **Hapus dari riwayat** (ditolak/dibatalkan). **Deploy ulang firestore.rules.**

## Hapus info dengan alasan, contoh per kategori, keyboard
- Hapus info wajib alasan (8 alasan siap pakai + kalimat contoh yang bisa diubah); pembuat diberi tahu alasannya.
- Warga dapat mengajukan hapus info miliknya (Info Saya); Admin/Kades menyetujui atau menolak di Kelola Desa → Hapus info. **Deploy ulang firestore.rules.**
- Ganti kategori Ajukan Info mengisi contoh judul/isi otomatis (27 kategori).
- Keyboard: menu bawah disembunyikan saat mengetik, tidak ada ubah ukuran ganda, ketuk area kosong menutup keyboard.

## Tema warna & kartu Jasa
- **Tema Aplikasi** (menu Akun): 19 tema (Hijau Desa bawaan, Crimson Aurora, Inferno Bloom, Solar Flare, Emerald Mist, Blue Nebula, Neon Frost, Oceanic Void, Purple Eclipse, Pink Stardust, Magenta Rift, Aqua Genesis, Toxic Bloom, Terra Ember, Golden Cosmos, White Nova, Midnight Phantom, Titanium Storm, Lunar Steel). Pilihan tersimpan.
- Kartu Cari Jasa, Butuh Pekerja, dan Lapak UMKM dirombak (garis warna, tarif/upah menonjol).

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

