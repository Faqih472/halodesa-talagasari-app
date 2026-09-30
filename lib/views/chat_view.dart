// ============================================================
// chat_view.dart — ChatListView + ChatRoomView
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../core/core.dart';
import '../core/models.dart';

// ============================================================
// chat_list_view.dart
// Daftar percakapan aktif (Elisitasi #25-26): pratinjau pesan
// terakhir, waktu, dan badge jumlah pesan belum dibaca.
// ============================================================

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final ChatController chatCtrl = Get.find<ChatController>();

    return Obx(() {
      final me = authCtrl.currentUser.value;
      final Color primaryColor = AppTheme.primaryColor(authCtrl.role);
      final list = chatCtrl.daftarChat;

      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: const Text('Obrolan'),
        ),
        body: me == null
            ? const SizedBox.shrink()
            : list.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Belum ada percakapan',
                    subtitle:
                        'Buka menu Jasa, pilih penyedia jasa, lalu tekan "Mulai Chat" untuk bernegosiasi langsung.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 80),
                    itemBuilder: (context, i) {
                      final room = list[i];
                      return FadeSlideIn(
                        key: ValueKey(room.id),
                        delay: Duration(milliseconds: 50 * (i % 8)),
                        dy: 14,
                        child: _buildTile(room, me.uid, primaryColor),
                      );
                    },
                  ),
      );
    });
  }

  Widget _buildTile(ChatRoomModel room, String myUid, Color primaryColor) {
    final int unread = room.unreadUntuk(myUid);
    final String nama = room.namaLawan(myUid);
    final String foto = room.fotoLawan(myUid);
    final bool belumAdaPesan = room.pesanTerakhir.isEmpty;
    final bool sayaPengirim = room.idPengirimTerakhir == myUid;

    return InkWell(
      onTap: () => Get.to(() => ChatRoomView(
            roomId: room.id,
            otherUid: room.uidLawan(myUid),
            namaLawan: nama,
            fotoLawan: foto,
          )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: primaryColor.withOpacity(0.12),
              backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
              child: foto.isEmpty
                  ? Text(AppUtils.inisial(nama),
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              unread > 0 ? FontWeight.bold : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    belumAdaPesan
                        ? 'Mulai percakapan...'
                        : '${sayaPengirim ? 'Anda: ' : ''}${room.pesanTerakhir}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle:
                          belumAdaPesan ? FontStyle.italic : FontStyle.normal,
                      color: unread > 0
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (room.waktuTerakhir != null && !belumAdaPesan)
                  Text(AppUtils.formatRelatif(room.waktuTerakhir!),
                      style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? primaryColor
                              : AppTheme.textSecondary)),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// chat_room_view.dart
// Ruang obrolan real-time (Bab 4.2.3.c, 4.5.6)
// Firestore Realtime Listener + StreamBuilder: pesan baru muncul
// instan tanpa memuat ulang. Bubble baru masuk dengan animasi.
// ============================================================

class ChatRoomView extends StatefulWidget {
  final String roomId;
  final String otherUid;
  final String namaLawan;
  final String fotoLawan;

  const ChatRoomView({
    super.key,
    required this.roomId,
    required this.otherUid,
    required this.namaLawan,
    this.fotoLawan = '',
  });

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final AuthController _authCtrl = Get.find<AuthController>();
  final ChatController _chatCtrl = Get.find<ChatController>();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _bisaKirim = false;
  int _jumlahPesanSebelumnya = 0;

  @override
  void initState() {
    super.initState();
    _chatCtrl.tandaiDibaca(widget.roomId);
    _inputCtrl.addListener(() {
      final ada = _inputCtrl.text.trim().isNotEmpty;
      if (ada != _bisaKirim) setState(() => _bisaKirim = ada);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final teks = _inputCtrl.text;
    if (teks.trim().isEmpty) return;
    _inputCtrl.clear();
    await _chatCtrl.kirimPesan(widget.roomId, teks, otherUid: widget.otherUid);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = _authCtrl.currentUser.value?.uid ?? '';
    final Color primaryColor = AppTheme.primaryColor(_authCtrl.role);

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD).withOpacity(0.55),
      appBar: AppBar(
        backgroundColor: primaryColor,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: widget.fotoLawan.isNotEmpty
                  ? NetworkImage(widget.fotoLawan)
                  : null,
              child: widget.fotoLawan.isEmpty
                  ? Text(AppUtils.inisial(widget.namaLawan),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.namaLawan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatCtrl.pesanStream(widget.roomId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Gagal memuat pesan',
                    subtitle: 'Periksa koneksi internet Anda lalu coba lagi.',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pesan = snap.data!;

                // Pesan baru masuk saat layar terbuka → tandai dibaca
                if (pesan.length != _jumlahPesanSebelumnya) {
                  final adaMasukBaru = pesan.isNotEmpty &&
                      pesan.last.idPengirim != myUid &&
                      !pesan.last.sudahDibaca;
                  _jumlahPesanSebelumnya = pesan.length;
                  if (adaMasukBaru) {
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _chatCtrl.tandaiDibaca(widget.roomId));
                  }
                }

                if (pesan.isEmpty) {
                  return const EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Sapa dulu yuk!',
                    subtitle:
                        'Kirim pesan pertama untuk menanyakan ketersediaan dan harga jasa.',
                  );
                }

                // reverse: true → pesan terbaru menempel di bawah
                final terbalik = pesan.reversed.toList();
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: terbalik.length,
                  itemBuilder: (context, i) {
                    final m = terbalik[i];
                    final bool saya = m.idPengirim == myUid;

                    // Tampilkan pemisah tanggal bila hari berbeda dari pesan sebelumnya
                    final bool tampilTanggal = i == terbalik.length - 1 ||
                        !_hariSama(m.waktu, terbalik[i + 1].waktu);

                    return Column(
                      key: ValueKey(m.id),
                      children: [
                        if (tampilTanggal) _buildPemisahTanggal(m.waktu),
                        // ValueKey stabil → hanya bubble BARU yang beranimasi
                        FadeSlideIn(
                          dy: 12,
                          duration: const Duration(milliseconds: 260),
                          child: _buildBubble(m, saya, primaryColor),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(primaryColor),
        ],
      ),
    );
  }

  bool _hariSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildPemisahTanggal(DateTime d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(AppUtils.formatTanggal(d),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ),
    );
  }

  Widget _buildBubble(MessageModel m, bool saya, Color primaryColor) {
    final String jam = DateFormat('HH:mm').format(m.waktu);
    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: saya ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(saya ? 14 : 3),
            bottomRight: Radius.circular(saya ? 3 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              m.isi,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: saya ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(jam,
                    style: TextStyle(
                        fontSize: 10,
                        color: saya ? Colors.white70 : AppTheme.textSecondary)),
                if (saya) ...[
                  const SizedBox(width: 4),
                  Icon(
                    m.sudahDibaca ? Icons.done_all : Icons.done,
                    size: 14,
                    color: m.sudahDibaca
                        ? const Color(0xFF80D8FF)
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(Color primaryColor) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: _bisaKirim ? 1.0 : 0.85,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bisaKirim ? primaryColor : Colors.grey.shade400,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _bisaKirim ? _kirim : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
