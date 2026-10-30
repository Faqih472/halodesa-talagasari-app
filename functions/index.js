// Cloud Functions Talagasari Hub
// 1) pushNotif      : tiap notifikasi baru di Firestore -> push FCM ke HP warga
// 2) slaPengaduan   : tiap hari, ingatkan Admin/Kades bila pengaduan menunggu >= 3 hari
// 3) pengingatAgenda: tiap jam, kirim pengingat H-1 ke warga yang konfirmasi hadir
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const REGION = 'asia-southeast2'; // Jakarta

async function kirimNotifDoc(uid, judul, isi, tipe, targetId) {
  await db.collection('users').doc(uid).collection('notifications').add({
    judul, isi, tipe, target_id: targetId || null, dibaca: false,
    created_at: admin.firestore.Timestamp.now(),
  });
}

// 1) Push otomatis
exports.pushNotif = onDocumentCreated(
  { document: 'users/{uid}/notifications/{nid}', region: REGION },
  async (event) => {
    const data = event.data && event.data.data();
    if (!data) return;
    const user = await db.collection('users').doc(event.params.uid).get();
    const token = user.exists ? user.data().fcm_token : null;
    if (!token) return;
    try {
      await admin.messaging().send({
        token,
        notification: { title: data.judul || 'Talagasari Hub', body: data.isi || '' },
        data: { tipe: String(data.tipe || 'info'), target_id: String(data.target_id || '') },
        android: { priority: 'high' },
      });
    } catch (e) {
      // token kadaluarsa -> hapus
      if (String(e.code).includes('registration-token-not-registered')) {
        await user.ref.update({ fcm_token: '' });
      }
    }
  }
);

// 2) Pengingat batas respons 3 hari
exports.slaPengaduan = onSchedule(
  { schedule: 'every day 08:00', timeZone: 'Asia/Jakarta', region: REGION },
  async () => {
    const batas = Date.now() - 3 * 24 * 3600 * 1000;
    for (const [status, peran] of [['menunggu_review', 'admin'], ['pending_kades', 'kades']]) {
      const snap = await db.collection('pengaduan').where('status', '==', status).get();
      const telat = snap.docs.filter(
        (d) => !d.data().sla_notified && d.data().created_at.toMillis() <= batas
      );
      if (telat.length === 0) continue;
      const staf = await db.collection('users').where('role', '==', peran).get();
      for (const s of staf.docs) {
        await kirimNotifDoc(
          s.id,
          'Pengaduan Lewat Batas Waktu',
          `${telat.length} pengaduan sudah menunggu lebih dari 3 hari.`,
          'pengaduan'
        );
      }
      await Promise.all(telat.map((d) => d.ref.update({ sla_notified: true })));
    }
  }
);

// 3) Pengingat agenda H-1
exports.pengingatAgenda = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'Asia/Jakarta', region: REGION },
  async () => {
    const now = Date.now();
    const snap = await db.collection('agenda').get();
    for (const a of snap.docs) {
      const d = a.data();
      if (d.reminder_terkirim) continue;
      const waktu = d.waktu.toMillis();
      if (waktu <= now || waktu - now > 24 * 3600 * 1000) continue;
      const hadir = await a.ref.collection('hadir').get();
      for (const h of hadir.docs) {
        await kirimNotifDoc(h.id, 'Besok ada agenda: ' + d.judul,
          'Jangan lupa hadir. Lokasi: ' + (d.lokasi || '-'), 'agenda', a.id);
      }
      await a.ref.update({ reminder_terkirim: true });
    }
  }
);
